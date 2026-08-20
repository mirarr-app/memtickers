package com.mirarrapp.memtickers

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.FlutterInjector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

object IsnetSegmenter {
    private const val MODEL_ASSET = "assets/models/isnet-general-use-q8.onnx"
    private const val MODEL_SIZE = 1024
    private const val MAX_SOURCE_EDGE = 1280

    private val mutex = Mutex()
    private var ortEnvironment: OrtEnvironment? = null
    private var ortSession: OrtSession? = null
    private var inputName: String? = null
    private var outputName: String? = null

    val isLoaded: Boolean
        get() = ortSession != null

    suspend fun ensureLoaded(context: Context) = withContext(Dispatchers.IO) {
        if (ortSession != null) return@withContext
        mutex.withLock {
            if (ortSession != null) return@withLock

            val env = OrtEnvironment.getEnvironment()
            ortEnvironment = env

            val modelFile = prepareModelFile(context)
            val sessionOptions = OrtSession.SessionOptions().apply {
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                setIntraOpNumThreads(4)
            }

            val session = env.createSession(modelFile.absolutePath, sessionOptions)
            if (session.inputNames.isEmpty() || session.outputNames.isEmpty()) {
                throw IllegalStateException("IS-Net model is missing input or output names.")
            }

            inputName = session.inputNames.iterator().next()
            outputName = session.outputNames.iterator().next()
            ortSession = session
        }
    }

    private fun prepareModelFile(context: Context): File {
        val modelFile = File(context.filesDir, "isnet-general-use-q8.onnx")
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(MODEL_ASSET)
        val assetManager = context.assets

        // Copy if not present or size mismatch
        val needsCopy = if (!modelFile.exists()) {
            true
        } else {
            try {
                val fd = assetManager.openFd(assetKey)
                val assetLength = fd.length
                fd.close()
                modelFile.length() != assetLength
            } catch (_: Exception) {
                false
            }
        }

        if (needsCopy) {
            val tempFile = File(context.filesDir, "isnet-general-use-q8.onnx.tmp")
            assetManager.open(assetKey).use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (!tempFile.renameTo(modelFile)) {
                tempFile.copyTo(modelFile, overwrite = true)
                tempFile.delete()
            }
        }

        return modelFile
    }

    suspend fun removeBackground(
        context: Context,
        imagePath: String,
        outputPath: String? = null
    ): String = withContext(Dispatchers.Default) {
        ensureLoaded(context)

        val env = ortEnvironment ?: throw IllegalStateException("ONNX environment is null.")
        val session = ortSession ?: throw IllegalStateException("ONNX session is not initialized.")
        val input = inputName ?: throw IllegalStateException("ONNX input name is null.")

        val origBitmap = BitmapFactory.decodeFile(imagePath)
            ?: throw IllegalArgumentException("Could not decode image at $imagePath")

        // 1. Correct orientation using EXIF
        val sourceBitmap = fixOrientation(imagePath, origBitmap)

        // 2. Downscale if excessively large
        val workingBitmap = limitMaxEdge(sourceBitmap, MAX_SOURCE_EDGE)

        val srcW = workingBitmap.width
        val srcH = workingBitmap.height

        // 3. Resize to 1024x1024 for model input
        val inputBitmap = Bitmap.createScaledBitmap(workingBitmap, MODEL_SIZE, MODEL_SIZE, true)
        val pixels = IntArray(MODEL_SIZE * MODEL_SIZE)
        inputBitmap.getPixels(pixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)
        if (inputBitmap != workingBitmap) {
            inputBitmap.recycle()
        }

        // 4. Compute max RGB value across pixels for rembg DIS normalization
        var maxValue = 1.0f
        for (pixel in pixels) {
            val r = ((pixel shr 16) and 0xFF).toFloat()
            val g = ((pixel shr 8) and 0xFF).toFloat()
            val b = (pixel and 0xFF).toFloat()
            if (r > maxValue) maxValue = r
            if (g > maxValue) maxValue = g
            if (b > maxValue) maxValue = b
        }

        val planeSize = MODEL_SIZE * MODEL_SIZE
        val floatBuffer = ByteBuffer.allocateDirect(1 * 3 * planeSize * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

        // Populate NCHW RGB normalized buffer: (channel / maxValue) - 0.5
        for (i in 0 until planeSize) {
            val p = pixels[i]
            val r = ((p shr 16) and 0xFF).toFloat()
            val g = ((p shr 8) and 0xFF).toFloat()
            val b = (p and 0xFF).toFloat()
            floatBuffer.put(i, (r / maxValue) - 0.5f)
            floatBuffer.put(planeSize + i, (g / maxValue) - 0.5f)
            floatBuffer.put(planeSize * 2 + i, (b / maxValue) - 0.5f)
        }
        floatBuffer.rewind()

        // 5. Run inference
        val shape = longArrayOf(1, 3, MODEL_SIZE.toLong(), MODEL_SIZE.toLong())
        val inputTensor = OnnxTensor.createTensor(env, floatBuffer, shape)
        val maskFloats = FloatArray(planeSize)
        try {
            session.run(mapOf(input to inputTensor)).use { outputs ->
                val outputTensor = outputs.get(0) as OnnxTensor
                val outBuffer = outputTensor.floatBuffer
                outBuffer.rewind()
                outBuffer.get(maskFloats)
            }
        } finally {
            inputTensor.close()
        }

        // 6. Normalize mask min-max with low-confidence suppression & smoothstep
        var minVal = Float.MAX_VALUE
        var maxVal = -Float.MAX_VALUE
        for (v in maskFloats) {
            if (v < minVal) minVal = v
            if (v > maxVal) maxVal = v
        }
        val range = max(maxVal - minVal, 1e-6f)
        val rawMaskPixels = IntArray(planeSize)
        val cutoffLow = 0.20f
        val cutoffHigh = 0.85f
        for (i in 0 until planeSize) {
            val rawNorm = (maskFloats[i] - minVal) / range
            val norm = when {
                rawNorm < cutoffLow -> 0.0f
                rawNorm > cutoffHigh -> 1.0f
                else -> {
                    val u = (rawNorm - cutoffLow) / (cutoffHigh - cutoffLow)
                    u * u * (3.0f - 2.0f * u) // smoothstep
                }
            }
            val alpha = (norm * 255.0f).roundToInt().coerceIn(0, 255)
            rawMaskPixels[i] = (alpha shl 24) or (alpha shl 16) or (alpha shl 8) or alpha
        }

        // 7. Morphological Opening (Circular Erode r=1.5, Dilate r=1.5) to eliminate single-pixel wisps and noise
        val openedMaskPixels = morphologicalOpening(rawMaskPixels, MODEL_SIZE, MODEL_SIZE, radius = 1.5f)

        // 8. Connected Component Analysis: keep primary subject and prune small detached junk islands
        val cleanedMaskPixels = pruneDisconnectedIslands(openedMaskPixels, MODEL_SIZE, MODEL_SIZE, alphaThreshold = 24)

        val mask1024 = Bitmap.createBitmap(cleanedMaskPixels, MODEL_SIZE, MODEL_SIZE, Bitmap.Config.ARGB_8888)

        // 9. Scale mask back to source image size
        val scaledMask = Bitmap.createScaledBitmap(mask1024, srcW, srcH, true)
        mask1024.recycle()

        val srcPixels = IntArray(srcW * srcH)
        workingBitmap.getPixels(srcPixels, 0, srcW, 0, 0, srcW, srcH)

        val scaledMaskPixels = IntArray(srcW * srcH)
        scaledMask.getPixels(scaledMaskPixels, 0, srcW, 0, 0, srcW, srcH)
        scaledMask.recycle()

        // 10. Sub-pixel Alpha Feathering & Anti-Aliasing (Gaussian blur + S-curve contrast boost)
        val featheredMaskPixels = featherAndSmoothAlpha(scaledMaskPixels, srcW, srcH, radius = 2)

        // 11. Composite mask alpha with original source pixels & compute bounds
        val cutoutPixels = IntArray(srcW * srcH)
        var opaqueCount = 0
        var minX = srcW
        var minY = srcH
        var maxX = 0
        var maxY = 0

        for (y in 0 until srcH) {
            for (x in 0 until srcW) {
                val idx = y * srcW + x
                val alpha = (featheredMaskPixels[idx] shr 24) and 0xFF
                if (alpha > 24) {
                    opaqueCount++
                    if (x < minX) minX = x
                    if (y < minY) minY = y
                    if (x > maxX) maxX = x
                    if (y > maxY) maxY = y
                }
                val src = srcPixels[idx]
                cutoutPixels[idx] = (alpha shl 24) or (src and 0x00FFFFFF)
            }
        }

        if (opaqueCount < (srcW * srcH * 0.004)) {
            if (workingBitmap != sourceBitmap) workingBitmap.recycle()
            sourceBitmap.recycle()
            throw IllegalStateException("No subject found. Try another photo with a clearer foreground.")
        }

        val cutoutBitmap = Bitmap.createBitmap(cutoutPixels, srcW, srcH, Bitmap.Config.ARGB_8888)
        if (workingBitmap != sourceBitmap) workingBitmap.recycle()
        sourceBitmap.recycle()

        // 9. Crop to opaque bounds with padding
        val pad = 4
        val cropMinX = max(0, minX - pad)
        val cropMinY = max(0, minY - pad)
        val cropMaxX = min(srcW - 1, maxX + pad)
        val cropMaxY = min(srcH - 1, maxY + pad)
        val cropW = cropMaxX - cropMinX + 1
        val cropH = cropMaxY - cropMinY + 1

        val cropped = Bitmap.createBitmap(cutoutBitmap, cropMinX, cropMinY, cropW, cropH)
        if (cropped != cutoutBitmap) {
            cutoutBitmap.recycle()
        }

        // 10. Write PNG output
        val destFile = if (outputPath != null) {
            File(outputPath)
        } else {
            File(context.cacheDir, "cutout_${UUID.randomUUID()}.png")
        }
        destFile.parentFile?.mkdirs()

        FileOutputStream(destFile).use { out ->
            cropped.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        cropped.recycle()

        destFile.absolutePath
    }

    private fun fixOrientation(imagePath: String, bitmap: Bitmap): Bitmap {
        return try {
            val exif = ExifInterface(imagePath)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                else -> return bitmap
            }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) bitmap.recycle()
            rotated
        } catch (_: Exception) {
            bitmap
        }
    }

    private fun limitMaxEdge(bitmap: Bitmap, maxEdge: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= maxEdge) return bitmap
        val scale = maxEdge.toFloat() / longest.toFloat()
        val targetW = (bitmap.width * scale).roundToInt()
        val targetH = (bitmap.height * scale).roundToInt()
        val scaled = Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
        if (scaled != bitmap) bitmap.recycle()
        return scaled
    }

    private fun morphologicalOpening(mask: IntArray, width: Int, height: Int, radius: Float = 1.5f): IntArray {
        val rInt = radius.toInt().coerceAtLeast(1)
        val r2 = radius * radius
        val eroded = IntArray(mask.size)

        for (y in 0 until height) {
            val rowOffset = y * width
            for (x in 0 until width) {
                var minA = 255
                for (dy in -rInt..rInt) {
                    val ny = y + dy
                    if (ny !in 0 until height) { minA = 0; break }
                    val nRowOffset = ny * width
                    for (dx in -rInt..rInt) {
                        if (dx * dx + dy * dy > r2) continue
                        val nx = x + dx
                        if (nx !in 0 until width) { minA = 0; break }
                        val a = (mask[nRowOffset + nx] shr 24) and 0xFF
                        if (a < minA) minA = a
                    }
                    if (minA == 0) break
                }
                eroded[rowOffset + x] = (minA shl 24) or (minA shl 16) or (minA shl 8) or minA
            }
        }

        val opened = IntArray(mask.size)
        for (y in 0 until height) {
            val rowOffset = y * width
            for (x in 0 until width) {
                var maxA = 0
                for (dy in -rInt..rInt) {
                    val ny = y + dy
                    if (ny !in 0 until height) continue
                    val nRowOffset = ny * width
                    for (dx in -rInt..rInt) {
                        if (dx * dx + dy * dy > r2) continue
                        val nx = x + dx
                        if (nx !in 0 until width) continue
                        val a = (eroded[nRowOffset + nx] shr 24) and 0xFF
                        if (a > maxA) maxA = a
                    }
                    if (maxA == 255) break
                }
                opened[rowOffset + x] = (maxA shl 24) or (maxA shl 16) or (maxA shl 8) or maxA
            }
        }
        return opened
    }

    private fun featherAndSmoothAlpha(mask: IntArray, width: Int, height: Int, radius: Int = 2): IntArray {
        val total = width * height
        val temp = FloatArray(total)
        val smoothed = IntArray(total)

        // 1D Gaussian kernel weights for radius = 2
        val weights = floatArrayOf(0.06136f, 0.24477f, 0.38774f, 0.24477f, 0.06136f)

        // Horizontal blur pass
        for (y in 0 until height) {
            val row = y * width
            for (x in 0 until width) {
                var sum = 0f
                for (k in -2..2) {
                    val nx = (x + k).coerceIn(0, width - 1)
                    val a = ((mask[row + nx] shr 24) and 0xFF).toFloat()
                    sum += a * weights[k + 2]
                }
                temp[row + x] = sum
            }
        }

        // Vertical blur pass + smoothstep edge contrast restoration
        for (x in 0 until width) {
            for (y in 0 until height) {
                var sum = 0f
                for (k in -2..2) {
                    val ny = (y + k).coerceIn(0, height - 1)
                    sum += temp[ny * width + x] * weights[k + 2]
                }
                val norm = sum / 255.0f
                val refined = when {
                    norm <= 0.08f -> 0.0f
                    norm >= 0.92f -> 1.0f
                    else -> {
                        val t = (norm - 0.08f) / 0.84f
                        t * t * (3.0f - 2.0f * t)
                    }
                }
                val alpha = (refined * 255.0f).roundToInt().coerceIn(0, 255)
                val idx = y * width + x
                smoothed[idx] = (alpha shl 24) or (alpha shl 16) or (alpha shl 8) or alpha
            }
        }
        return smoothed
    }

    private fun pruneDisconnectedIslands(
        maskPixels: IntArray,
        width: Int,
        height: Int,
        alphaThreshold: Int = 24
    ): IntArray {
        val total = width * height
        val labels = IntArray(total)
        val componentSizes = ArrayList<Int>()
        val queue = IntArray(total)

        for (y in 0 until height) {
            for (x in 0 until width) {
                val idx = y * width + x
                val a = (maskPixels[idx] shr 24) and 0xFF
                if (a >= alphaThreshold && labels[idx] == 0) {
                    val labelId = componentSizes.size + 1
                    var head = 0
                    var tail = 0
                    var count = 0

                    queue[tail++] = idx
                    labels[idx] = labelId

                    while (head < tail) {
                        val cur = queue[head++]
                        count++
                        val cx = cur % width
                        val cy = cur / width

                        if (cx > 0) {
                            val n = cur - 1
                            if (labels[n] == 0 && ((maskPixels[n] shr 24) and 0xFF) >= alphaThreshold) {
                                labels[n] = labelId
                                queue[tail++] = n
                            }
                        }
                        if (cx < width - 1) {
                            val n = cur + 1
                            if (labels[n] == 0 && ((maskPixels[n] shr 24) and 0xFF) >= alphaThreshold) {
                                labels[n] = labelId
                                queue[tail++] = n
                            }
                        }
                        if (cy > 0) {
                            val n = cur - width
                            if (labels[n] == 0 && ((maskPixels[n] shr 24) and 0xFF) >= alphaThreshold) {
                                labels[n] = labelId
                                queue[tail++] = n
                            }
                        }
                        if (cy < height - 1) {
                            val n = cur + width
                            if (labels[n] == 0 && ((maskPixels[n] shr 24) and 0xFF) >= alphaThreshold) {
                                labels[n] = labelId
                                queue[tail++] = n
                            }
                        }
                    }
                    componentSizes.add(count)
                }
            }
        }

        if (componentSizes.isEmpty()) return maskPixels

        val maxComponentSize = componentSizes.maxOrNull() ?: 0
        val minAllowedSize = max(2000, (maxComponentSize * 0.12f).roundToInt())

        val result = IntArray(total)
        for (i in 0 until total) {
            val lbl = labels[i]
            if (lbl > 0 && componentSizes[lbl - 1] >= minAllowedSize) {
                result[i] = maskPixels[i]
            } else {
                result[i] = 0
            }
        }
        return result
    }

    fun close() {
        ortSession?.close()
        ortSession = null
        ortEnvironment?.close()
        ortEnvironment = null
        inputName = null
        outputName = null
    }
}
