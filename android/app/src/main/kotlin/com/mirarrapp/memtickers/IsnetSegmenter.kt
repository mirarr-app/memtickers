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

        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(imagePath, boundsOptions)

        val rawWidth = boundsOptions.outWidth
        val rawHeight = boundsOptions.outHeight
        if (rawWidth <= 0 || rawHeight <= 0) {
            throw IllegalArgumentException("Could not decode image bounds at $imagePath")
        }

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = computeSampleSize(rawWidth, rawHeight, MAX_SOURCE_EDGE)
        }
        val origBitmap = BitmapFactory.decodeFile(imagePath, decodeOptions)
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

        // 8. Connected Component Analysis & Topological Hole-Filling: keep primary subject, prune outer junk islands, and fill internal holes (e.g. eyes, pupils, dark features)
        val cleanedMaskPixels = pruneIslandsAndFillInternalHoles(openedMaskPixels, MODEL_SIZE, MODEL_SIZE, alphaThreshold = 24)

        val mask1024 = Bitmap.createBitmap(cleanedMaskPixels, MODEL_SIZE, MODEL_SIZE, Bitmap.Config.ARGB_8888)

        // 9. Scale mask back to source image size
        val scaledMask = Bitmap.createScaledBitmap(mask1024, srcW, srcH, true)
        mask1024.recycle()

        val srcPixels = IntArray(srcW * srcH)
        workingBitmap.getPixels(srcPixels, 0, srcW, 0, 0, srcW, srcH)

        val scaledMaskPixels = IntArray(srcW * srcH)
        scaledMask.getPixels(scaledMaskPixels, 0, srcW, 0, 0, srcW, srcH)
        scaledMask.recycle()

        // 10. Compute solid interior mask to protect internal features (eyes, pupils, dark mouth, inner details) from guided filter erosion
        val solidInterior = computeSolidInteriorMask(scaledMaskPixels, srcW, srcH, radius = 6)

        // 11. Fast Guided Filter: edge-aware refinement snapping alpha to physical RGB luminance edges
        val guidedMaskPixels = fastGuidedFilter(srcPixels, scaledMaskPixels, srcW, srcH, radius = 8, eps = 0.001f, subsample = 2)

        // 12. Sub-pixel Alpha Feathering & Anti-Aliasing (Gaussian blur + S-curve contrast boost)
        val featheredMaskPixels = featherAndSmoothAlpha(guidedMaskPixels, srcW, srcH, radius = 1)

        // 13. Composite mask alpha with original source pixels & compute bounds
        val cutoutPixels = IntArray(srcW * srcH)
        var opaqueCount = 0
        var minX = srcW
        var minY = srcH
        var maxX = 0
        var maxY = 0

        for (y in 0 until srcH) {
            for (x in 0 until srcW) {
                val idx = y * srcW + x
                // If pixel is in solid interior, guarantee full 255 alpha (prevents any cutout of dark eyes/features)
                val alpha = if (solidInterior[idx]) {
                    255
                } else {
                    (featheredMaskPixels[idx] shr 24) and 0xFF
                }
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

        // Cache working image and uncropped mask for RefineSession
        try {
            val workingFile = File(context.cacheDir, "working_${UUID.randomUUID()}.jpg")
            FileOutputStream(workingFile).use { out ->
                workingBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
            }
            val maskBytes = ByteArray(srcW * srcH)
            for (i in 0 until srcW * srcH) {
                val a = if (solidInterior[i]) 255 else ((featheredMaskPixels[i] shr 24) and 0xFF)
                maskBytes[i] = a.toByte()
            }
            val session = RefineSession(
                sessionId = UUID.randomUUID().toString(),
                originalImagePath = imagePath,
                width = srcW,
                height = srcH,
                workingImagePath = workingFile.absolutePath,
                rgbPixels = srcPixels,
                currentMask = maskBytes.clone(),
                initialMask = maskBytes.clone()
            )
            RefineSessionManager.setSession(session)
        } catch (_: Exception) {}

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

    internal fun fixOrientation(imagePath: String, bitmap: Bitmap): Bitmap {
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

    internal fun computeSampleSize(rawWidth: Int, rawHeight: Int, maxTargetEdge: Int): Int {
        var sampleSize = 1
        var longest = max(rawWidth, rawHeight)
        while (longest / 2 >= maxTargetEdge) {
            sampleSize *= 2
            longest /= 2
        }
        return sampleSize
    }

    internal fun limitMaxEdge(bitmap: Bitmap, maxEdge: Int): Bitmap {
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

    private fun pruneIslandsAndFillInternalHoles(
        maskPixels: IntArray,
        width: Int,
        height: Int,
        alphaThreshold: Int = 24
    ): IntArray {
        val total = width * height
        val labels = IntArray(total)
        val componentSizes = ArrayList<Int>()
        val queue = IntArray(total)

        // 1. Label connected foreground components
        for (y in 0 until height) {
            val rowOffset = y * width
            for (x in 0 until width) {
                val idx = rowOffset + x
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

        // 2. Identify kept foreground pixels (primary components)
        val isKeptForeground = BooleanArray(total)
        for (i in 0 until total) {
            val lbl = labels[i]
            if (lbl > 0 && componentSizes[lbl - 1] >= minAllowedSize) {
                isKeptForeground[i] = true
            }
        }

        // 3. Flood-fill from image borders on inverted mask to identify true external background
        val isExternalBg = BooleanArray(total)
        var head = 0
        var tail = 0

        // Top and bottom borders
        for (x in 0 until width) {
            val topIdx = x
            if (!isKeptForeground[topIdx] && !isExternalBg[topIdx]) {
                isExternalBg[topIdx] = true
                queue[tail++] = topIdx
            }
            val bottomIdx = (height - 1) * width + x
            if (!isKeptForeground[bottomIdx] && !isExternalBg[bottomIdx]) {
                isExternalBg[bottomIdx] = true
                queue[tail++] = bottomIdx
            }
        }

        // Left and right borders
        for (y in 0 until height) {
            val leftIdx = y * width
            if (!isKeptForeground[leftIdx] && !isExternalBg[leftIdx]) {
                isExternalBg[leftIdx] = true
                queue[tail++] = leftIdx
            }
            val rightIdx = y * width + (width - 1)
            if (!isKeptForeground[rightIdx] && !isExternalBg[rightIdx]) {
                isExternalBg[rightIdx] = true
                queue[tail++] = rightIdx
            }
        }

        // BFS traversal across outer background
        while (head < tail) {
            val cur = queue[head++]
            val cx = cur % width
            val cy = cur / width

            if (cx > 0) {
                val n = cur - 1
                if (!isKeptForeground[n] && !isExternalBg[n]) {
                    isExternalBg[n] = true
                    queue[tail++] = n
                }
            }
            if (cx < width - 1) {
                val n = cur + 1
                if (!isKeptForeground[n] && !isExternalBg[n]) {
                    isExternalBg[n] = true
                    queue[tail++] = n
                }
            }
            if (cy > 0) {
                val n = cur - width
                if (!isKeptForeground[n] && !isExternalBg[n]) {
                    isExternalBg[n] = true
                    queue[tail++] = n
                }
            }
            if (cy < height - 1) {
                val n = cur + width
                if (!isKeptForeground[n] && !isExternalBg[n]) {
                    isExternalBg[n] = true
                    queue[tail++] = n
                }
            }
        }

        // 4. Fill internal holes & assemble cleaned solid mask
        val result = IntArray(total)
        for (i in 0 until total) {
            if (isExternalBg[i]) {
                // True external background -> 0
                result[i] = 0
            } else if (isKeptForeground[i]) {
                // Foreground subject -> keep original anti-aliased mask alpha
                val origAlpha = (maskPixels[i] shr 24) and 0xFF
                val alpha = origAlpha.coerceIn(0, 255)
                result[i] = (alpha shl 24) or (alpha shl 16) or (alpha shl 8) or alpha
            } else {
                // Enclosed interior hole (e.g. black eye, dark pupil, dark mouth, inner shadows) -> solid foreground!
                val alpha = 255
                result[i] = (alpha shl 24) or (alpha shl 16) or (alpha shl 8) or alpha
            }
        }

        return result
    }

    private fun computeSolidInteriorMask(mask: IntArray, width: Int, height: Int, radius: Int = 6): BooleanArray {
        val total = width * height
        val temp = BooleanArray(total)
        val solidInterior = BooleanArray(total)

        // Horizontal min pass
        for (y in 0 until height) {
            val row = y * width
            var solidStreak = 0
            for (x in 0 until width) {
                val a = (mask[row + x] shr 24) and 0xFF
                if (a >= 250) {
                    solidStreak++
                } else {
                    solidStreak = 0
                }
                if (solidStreak >= radius * 2 + 1) {
                    temp[row + x - radius] = true
                }
            }
        }

        // Vertical min pass
        for (x in 0 until width) {
            var solidStreak = 0
            for (y in 0 until height) {
                if (temp[y * width + x]) {
                    solidStreak++
                } else {
                    solidStreak = 0
                }
                if (solidStreak >= radius * 2 + 1) {
                    solidInterior[(y - radius) * width + x] = true
                }
            }
        }

        return solidInterior
    }

    private fun fastGuidedFilter(
        guideRgbPixels: IntArray,
        maskPixels: IntArray,
        width: Int,
        height: Int,
        radius: Int = 8,
        eps: Float = 0.001f,
        subsample: Int = 2
    ): IntArray {
        val subW = max(1, width / subsample)
        val subH = max(1, height / subsample)
        val subSize = subW * subH
        val subR = max(1, radius / subsample)

        val iSub = FloatArray(subSize)
        val pSub = FloatArray(subSize)

        for (sy in 0 until subH) {
            val origY = sy * subsample
            val subRow = sy * subW
            val origRow = origY * width
            for (sx in 0 until subW) {
                val origX = sx * subsample
                val pColor = guideRgbPixels[origRow + origX]
                val r = ((pColor shr 16) and 0xFF) / 255.0f
                val g = ((pColor shr 8) and 0xFF) / 255.0f
                val b = (pColor and 0xFF) / 255.0f
                iSub[subRow + sx] = 0.299f * r + 0.587f * g + 0.114f * b

                val alpha = (maskPixels[origRow + origX] shr 24) and 0xFF
                pSub[subRow + sx] = alpha / 255.0f
            }
        }

        val iSq = FloatArray(subSize)
        val ip = FloatArray(subSize)
        for (i in 0 until subSize) {
            iSq[i] = iSub[i] * iSub[i]
            ip[i] = iSub[i] * pSub[i]
        }

        val meanI = boxFilter(iSub, subW, subH, subR)
        val meanP = boxFilter(pSub, subW, subH, subR)
        val corrI = boxFilter(iSq, subW, subH, subR)
        val corrIp = boxFilter(ip, subW, subH, subR)

        val a = FloatArray(subSize)
        val b = FloatArray(subSize)

        for (i in 0 until subSize) {
            val varI = max(0.0f, corrI[i] - meanI[i] * meanI[i])
            val covIp = corrIp[i] - meanI[i] * meanP[i]
            val aVal = covIp / (varI + eps)
            a[i] = aVal
            b[i] = meanP[i] - aVal * meanI[i]
        }

        val meanA = boxFilter(a, subW, subH, subR)
        val meanB = boxFilter(b, subW, subH, subR)

        val output = IntArray(width * height)
        for (y in 0 until height) {
            val fy = (y.toFloat() / subsample).coerceIn(0.0f, (subH - 1).toFloat())
            val y0 = fy.toInt()
            val y1 = min(subH - 1, y0 + 1)
            val dy = fy - y0
            val row0 = y0 * subW
            val row1 = y1 * subW
            val outRow = y * width

            for (x in 0 until width) {
                val fx = (x.toFloat() / subsample).coerceIn(0.0f, (subW - 1).toFloat())
                val x0 = fx.toInt()
                val x1 = min(subW - 1, x0 + 1)
                val dx = fx - x0

                val a00 = meanA[row0 + x0]
                val a01 = meanA[row0 + x1]
                val a10 = meanA[row1 + x0]
                val a11 = meanA[row1 + x1]
                val aVal = (1 - dx) * (1 - dy) * a00 + dx * (1 - dy) * a01 + (1 - dx) * dy * a10 + dx * dy * a11

                val b00 = meanB[row0 + x0]
                val b01 = meanB[row0 + x1]
                val b10 = meanB[row1 + x0]
                val b11 = meanB[row1 + x1]
                val bVal = (1 - dx) * (1 - dy) * b00 + dx * (1 - dy) * b01 + (1 - dx) * dy * b10 + dx * dy * b11

                val pColor = guideRgbPixels[outRow + x]
                val r = ((pColor shr 16) and 0xFF) / 255.0f
                val g = ((pColor shr 8) and 0xFF) / 255.0f
                val bColor = (pColor and 0xFF) / 255.0f
                val lum = 0.299f * r + 0.587f * g + 0.114f * bColor

                val q = (aVal * lum + bVal).coerceIn(0.0f, 1.0f)
                val alpha = (q * 255.0f).roundToInt().coerceIn(0, 255)
                output[outRow + x] = (alpha shl 24) or (alpha shl 16) or (alpha shl 8) or alpha
            }
        }
        return output
    }

    private fun boxFilter(src: FloatArray, width: Int, height: Int, radius: Int): FloatArray {
        val total = width * height
        val temp = FloatArray(total)
        val dest = FloatArray(total)

        for (y in 0 until height) {
            val row = y * width
            var sum = 0.0f
            for (x in -radius until radius) {
                sum += src[row + x.coerceIn(0, width - 1)]
            }
            for (x in 0 until width) {
                val right = (x + radius).coerceIn(0, width - 1)
                val left = (x - radius - 1).coerceIn(0, width - 1)
                sum += src[row + right] - src[row + left]
                val count = min(width - 1, x + radius) - max(0, x - radius) + 1
                temp[row + x] = sum / count
            }
        }

        for (x in 0 until width) {
            var sum = 0.0f
            for (y in -radius until radius) {
                sum += temp[y.coerceIn(0, height - 1) * width + x]
            }
            for (y in 0 until height) {
                val bottom = (y + radius).coerceIn(0, height - 1)
                val top = (y - radius - 1).coerceIn(0, height - 1)
                sum += temp[bottom * width + x] - temp[top * width + x]
                val count = min(height - 1, y + radius) - max(0, y - radius) + 1
                dest[y * width + x] = sum / count
            }
        }
        return dest
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
