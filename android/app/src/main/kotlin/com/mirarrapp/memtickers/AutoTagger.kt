package com.mirarrapp.memtickers

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import io.flutter.FlutterInjector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

object AutoTagger {
    private const val TAG = "AutoTagger"
    private const val MODEL_ASSET = "assets/models/mobileclip-s0-vision.onnx"
    private const val TAGS_ASSET = "assets/models/mobileclip_tags.json"
    private const val MODEL_SIZE = 256
    private const val EMBEDDING_DIM = 512

    private val mutex = Mutex()
    private var ortEnvironment: OrtEnvironment? = null
    private var ortSession: OrtSession? = null
    private var inputName: String? = null

    private var tagLabels: List<String> = emptyList()
    private var tagEmbeddings: Array<FloatArray> = emptyArray()

    val isLoaded: Boolean
        get() = ortSession != null && tagLabels.isNotEmpty()

    suspend fun ensureLoaded(context: Context) = withContext(Dispatchers.IO) {
        if (isLoaded) return@withContext
        mutex.withLock {
            if (isLoaded) return@withLock

            val env = OrtEnvironment.getEnvironment()
            ortEnvironment = env

            // 1. Prepare ONNX model
            val modelFile = prepareModelFile(context)
            val sessionOptions = OrtSession.SessionOptions().apply {
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                setIntraOpNumThreads(2)
            }

            val session = env.createSession(modelFile.absolutePath, sessionOptions)
            if (session.inputNames.isEmpty()) {
                throw IllegalStateException("AutoTagger model is missing input names.")
            }
            inputName = session.inputNames.iterator().next()
            ortSession = session

            // 2. Load tag vocabulary and precomputed embeddings
            loadTagEmbeddings(context)
            Log.d(TAG, "AutoTagger successfully loaded with ${tagLabels.size} tags.")
        }
    }

    private fun prepareModelFile(context: Context): File {
        val modelFile = File(context.filesDir, "mobileclip-s0-vision.onnx")
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(MODEL_ASSET)
        val assetManager = context.assets

        val currentAssetLength = try {
            assetManager.openFd(assetKey).use { it.length }
        } catch (_: Exception) {
            try {
                assetManager.open(assetKey).use { it.available().toLong() }
            } catch (_: Exception) {
                0L
            }
        }

        val needsCopy = !modelFile.exists() || (currentAssetLength > 0 && modelFile.length() != currentAssetLength)

        if (needsCopy) {
            Log.d(TAG, "Copying model file from assets: $MODEL_ASSET (target: ${modelFile.absolutePath})")
            val tempFile = File(context.filesDir, "mobileclip-s0-vision.onnx.tmp")
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

    private fun loadTagEmbeddings(context: Context) {
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(TAGS_ASSET)
        val jsonStr = context.assets.open(assetKey).bufferedReader().use { it.readText() }
        val root = JSONObject(jsonStr)

        val tagsArray = root.getJSONArray("tags")
        val embArray = root.getJSONArray("embeddings")
        val count = tagsArray.length()

        val labels = ArrayList<String>(count)
        val embeddings = Array(count) { FloatArray(EMBEDDING_DIM) }

        for (i in 0 until count) {
            labels.add(tagsArray.getString(i))
            val vec = embArray.getJSONArray(i)
            val target = embeddings[i]
            for (d in 0 until EMBEDDING_DIM) {
                target[d] = vec.getDouble(d).toFloat()
            }
        }

        tagLabels = labels
        tagEmbeddings = embeddings
    }

    suspend fun predictTags(
        context: Context,
        imagePath: String,
        topK: Int = 5,
        minConfidence: Float = 0.12f
    ): List<String> = withContext(Dispatchers.Default) {
        ensureLoaded(context)

        val env = ortEnvironment ?: throw IllegalStateException("ONNX environment is null.")
        val session = ortSession ?: throw IllegalStateException("ONNX session is not initialized.")
        val input = inputName ?: throw IllegalStateException("ONNX input name is null.")

        val origBitmap = BitmapFactory.decodeFile(imagePath)
            ?: throw IllegalArgumentException("Could not decode image at $imagePath")

        val sourceBitmap = fixOrientation(imagePath, origBitmap)

        // 1. Prepare clean RGB bitmap on solid white canvas (crop transparent borders if any)
        val croppedBitmap = cropAndCompositeOnWhite(sourceBitmap)

        val resizedBitmap = Bitmap.createScaledBitmap(croppedBitmap, MODEL_SIZE, MODEL_SIZE, true)

        val planeSize = MODEL_SIZE * MODEL_SIZE
        val pixels = IntArray(planeSize)
        resizedBitmap.getPixels(pixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)

        // Clean up intermediate bitmaps
        if (resizedBitmap != croppedBitmap && !resizedBitmap.isRecycled) {
            resizedBitmap.recycle()
        }
        if (croppedBitmap != sourceBitmap && !croppedBitmap.isRecycled) {
            croppedBitmap.recycle()
        }
        if (sourceBitmap != origBitmap && !sourceBitmap.isRecycled) {
            sourceBitmap.recycle()
        }
        if (!origBitmap.isRecycled) {
            origBitmap.recycle()
        }

        val floatBuffer = ByteBuffer.allocateDirect(1 * 3 * planeSize * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

        // Populate NCHW RGB normalized buffer in [0, 1]
        for (i in 0 until planeSize) {
            val p = pixels[i]
            val r = ((p shr 16) and 0xFF) / 255.0f
            val g = ((p shr 8) and 0xFF) / 255.0f
            val b = (p and 0xFF) / 255.0f
            floatBuffer.put(i, r)
            floatBuffer.put(planeSize + i, g)
            floatBuffer.put(planeSize * 2 + i, b)
        }
        floatBuffer.rewind()

        val shape = longArrayOf(1, 3, MODEL_SIZE.toLong(), MODEL_SIZE.toLong())
        val inputTensor = OnnxTensor.createTensor(env, floatBuffer, shape)
        val imageEmbedding = FloatArray(EMBEDDING_DIM)

        try {
            session.run(mapOf(input to inputTensor)).use { outputs ->
                val outputTensor = outputs.get(0) as OnnxTensor
                val outBuffer = outputTensor.floatBuffer
                outBuffer.rewind()
                outBuffer.get(imageEmbedding)
            }
        } finally {
            inputTensor.close()
        }

        // L2 Normalize image embedding
        var normSq = 0f
        for (v in imageEmbedding) normSq += v * v
        val norm = max(sqrt(normSq), 1e-8f)
        for (i in 0 until EMBEDDING_DIM) {
            imageEmbedding[i] /= norm
        }

        // Compute cosine similarities with all precomputed tags
        data class ScoredTag(val tag: String, val score: Float)
        val scored = ArrayList<ScoredTag>(tagLabels.size)

        for (i in tagLabels.indices) {
            val tagEmb = tagEmbeddings[i]
            var dot = 0f
            for (d in 0 until EMBEDDING_DIM) {
                dot += imageEmbedding[d] * tagEmb[d]
            }
            if (dot >= minConfidence) {
                scored.add(ScoredTag(tagLabels[i], dot))
            }
        }

        // Sort descending by score and pick top K
        scored.sortByDescending { it.score }
        val result = scored.take(topK).map { it.tag }
        Log.d(TAG, "Predicted tags for $imagePath: $result (top scores: ${scored.take(3).map { "${it.tag}=${it.score}" }})")
        return@withContext result
    }

    private fun cropAndCompositeOnWhite(src: Bitmap): Bitmap {
        val width = src.width
        val height = src.height

        // Find non-transparent bounds
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        val row = IntArray(width)
        for (y in 0 until height) {
            src.getPixels(row, 0, width, 0, y, width, 1)
            for (x in 0 until width) {
                val alpha = (row[x] ushr 24) and 0xFF
                if (alpha > 32) {
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                }
            }
        }

        val hasValidBounds = maxX >= minX && maxY >= minY
        val srcRect = if (hasValidBounds) {
            val pad = 8
            Rect(
                max(0, minX - pad),
                max(0, minY - pad),
                min(width, maxX + pad),
                min(height, maxY + pad)
            )
        } else {
            Rect(0, 0, width, height)
        }

        val cropW = srcRect.width()
        val cropH = srcRect.height()
        val squareDim = max(cropW, cropH)

        val out = Bitmap.createBitmap(squareDim, squareDim, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(Color.WHITE)

        val destX = (squareDim - cropW) / 2f
        val destY = (squareDim - cropH) / 2f
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)

        canvas.drawBitmap(src, srcRect, Rect(destX.toInt(), destY.toInt(), (destX + cropW).toInt(), (destY + cropH).toInt()), paint)
        return out
    }

    private fun fixOrientation(path: String, bitmap: Bitmap): Bitmap {
        return try {
            val exif = ExifInterface(path)
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
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (_: Exception) {
            bitmap
        }
    }

    fun close() {
        try {
            ortSession?.close()
        } catch (_: Exception) {}
        ortSession = null
    }
}
