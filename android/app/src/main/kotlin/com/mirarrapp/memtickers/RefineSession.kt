package com.mirarrapp.memtickers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayDeque
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

class RefineSession(
    val sessionId: String,
    val originalImagePath: String?,
    val width: Int,
    val height: Int,
    val workingImagePath: String,
    val rgbPixels: IntArray,
    var currentMask: ByteArray, // length = width * height, alpha 0..255
    val initialMask: ByteArray
) {
    private val maxHistory = 20
    private val undoStack = ArrayDeque<ByteArray>()
    private val redoStack = ArrayDeque<ByteArray>()

    // Sobel gradient magnitudes [0, 1] precomputed for fast edge snapping
    val gradients: FloatArray = computeSobelGradients(rgbPixels, width, height)

    val canUndo: Boolean get() = undoStack.isNotEmpty()
    val canRedo: Boolean get() = redoStack.isNotEmpty()

    fun pushHistory() {
        if (undoStack.size >= maxHistory) {
            undoStack.removeFirst()
        }
        undoStack.addLast(currentMask.clone())
        redoStack.clear()
    }

    fun undo(): Boolean {
        if (undoStack.isEmpty()) return false
        redoStack.addLast(currentMask.clone())
        currentMask = undoStack.removeLast()
        return true
    }

    fun redo(): Boolean {
        if (redoStack.isEmpty()) return false
        undoStack.addLast(currentMask.clone())
        currentMask = redoStack.removeLast()
        return true
    }

    fun resetToOriginal(): Boolean {
        pushHistory()
        currentMask = initialMask.clone()
        return true
    }

    fun applyStroke(
        points: List<Pair<Float, Float>>,
        radius: Float,
        isRestore: Boolean,
        isSmart: Boolean
    ): Boolean {
        if (points.isEmpty() || radius <= 0f) return false
        pushHistory()

        val rClamped = radius.coerceIn(2f, 150f)
        val stepSize = max(2.0f, rClamped * 0.32f)

        if (points.size == 1) {
            val pt = points[0]
            if (isSmart) {
                applySmartCenter(pt.first, pt.second, rClamped, isRestore)
            } else {
                applyManualCenter(pt.first, pt.second, rClamped, isRestore)
            }
            return true
        }

        for (i in 0 until points.size - 1) {
            val p0 = points[i]
            val p1 = points[i + 1]
            val dx = p1.first - p0.first
            val dy = p1.second - p0.second
            val dist = sqrt(dx * dx + dy * dy)
            val steps = max(1, (dist / stepSize).roundToInt())

            for (s in 0..steps) {
                val t = s.toFloat() / steps
                val cx = p0.first + dx * t
                val cy = p0.second + dy * t

                if (isSmart) {
                    applySmartCenter(cx, cy, rClamped, isRestore)
                } else {
                    applyManualCenter(cx, cy, rClamped, isRestore)
                }
            }
        }

        return true
    }

    private fun applyManualCenter(cx: Float, cy: Float, radius: Float, isRestore: Boolean) {
        val rInt = radius.roundToInt().coerceAtLeast(1)
        val minX = max(0, (cx - radius).toInt())
        val maxX = min(width - 1, (cx + radius).toInt())
        val minY = max(0, (cy - radius).toInt())
        val maxY = min(height - 1, (cy + radius).toInt())
        val rSq = radius * radius
        val targetVal = if (isRestore) 255.toByte() else 0.toByte()

        for (y in minY..maxY) {
            val row = y * width
            val dy = y - cy
            val dySq = dy * dy
            for (x in minX..maxX) {
                val dx = x - cx
                if (dx * dx + dySq <= rSq) {
                    currentMask[row + x] = targetVal
                }
            }
        }
    }

    private fun applySmartCenter(cx: Float, cy: Float, radius: Float, isRestore: Boolean) {
        val rInt = radius.roundToInt().coerceAtLeast(1)
        val minX = max(0, (cx - radius).toInt())
        val maxX = min(width - 1, (cx + radius).toInt())
        val minY = max(0, (cy - radius).toInt())
        val maxY = min(height - 1, (cy + radius).toInt())
        val rSq = radius * radius

        val centerIdxX = cx.roundToInt().coerceIn(0, width - 1)
        val centerIdxY = cy.roundToInt().coerceIn(0, height - 1)

        // Find local maximum gradient within brush window
        var localMaxGrad = 0f
        for (y in minY..maxY) {
            val row = y * width
            for (x in minX..maxX) {
                val g = gradients[row + x]
                if (g > localMaxGrad) localMaxGrad = g
            }
        }

        // If very low contrast throughout, fall back to smooth circle
        if (localMaxGrad < 0.12f) {
            applyManualCenter(cx, cy, radius, isRestore)
            return
        }

        // Edge threshold: snaps to strong physical edges without crossing
        val edgeThreshold = max(0.11f, localMaxGrad * 0.48f)
        val targetVal = if (isRestore) 255.toByte() else 0.toByte()

        val boxW = maxX - minX + 1
        val boxH = maxY - minY + 1
        val totalBox = boxW * boxH

        val visited = BooleanArray(totalBox)
        val queue = IntArray(totalBox)
        var head = 0
        var tail = 0

        val startLocal = (centerIdxY - minY) * boxW + (centerIdxX - minX)
        visited[startLocal] = true
        queue[tail++] = (centerIdxY shl 16) or centerIdxX

        while (head < tail) {
            val packed = queue[head++]
            val px = packed and 0xFFFF
            val py = (packed ushr 16) and 0xFFFF

            val dx = px - cx
            val dy = py - cy
            if (dx * dx + dy * dy <= rSq) {
                currentMask[py * width + px] = targetVal
            }

            // 4-connected neighbors
            val nxList = intArrayOf(px - 1, px + 1, px, px)
            val nyList = intArrayOf(py, py, py - 1, py + 1)

            for (k in 0 until 4) {
                val nx = nxList[k]
                val ny = nyList[k]

                if (nx in minX..maxX && ny in minY..maxY) {
                    val nLocal = (ny - minY) * boxW + (nx - minX)
                    if (!visited[nLocal]) {
                        visited[nLocal] = true
                        val ndx = nx - cx
                        val ndy = ny - cy
                        val inCircle = ndx * ndx + ndy * ndy <= rSq

                        val nGrad = gradients[ny * width + nx]
                        if (nGrad >= edgeThreshold) {
                            // Boundary pixel: include in target but DO NOT expand through it
                            if (inCircle) {
                                currentMask[ny * width + nx] = targetVal
                            }
                        } else {
                            if (inCircle) {
                                queue[tail++] = (ny shl 16) or nx
                            }
                        }
                    }
                }
            }
        }
    }

    private var overlayVersion = 0

    /**
     * Exports full-resolution uncropped cutout overlay PNG (with transparent background)
     * so Flutter can display it directly on top of the ghosted background image.
     */
    fun exportOverlayPng(context: Context): String {
        val pixels = IntArray(width * height)
        for (i in 0 until width * height) {
            val alpha = currentMask[i].toInt() and 0xFF
            val rgb = rgbPixels[i] and 0x00FFFFFF
            pixels[i] = (alpha shl 24) or rgb
        }

        val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        overlayVersion++
        val file = File(context.cacheDir, "refine_overlay_${sessionId}_${overlayVersion}.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()

        // Clean up files older than the last 2 versions
        if (overlayVersion > 2) {
            val oldFile = File(context.cacheDir, "refine_overlay_${sessionId}_${overlayVersion - 2}.png")
            if (oldFile.exists()) {
                oldFile.delete()
            }
        }
        return file.absolutePath
    }

    fun cleanup(context: Context) {
        try {
            val prefix = "refine_overlay_${sessionId}_"
            context.cacheDir.listFiles()?.forEach { f ->
                if (f.name.startsWith(prefix) || f.name == "refine_overlay_${sessionId}.png") {
                    f.delete()
                }
            }
        } catch (_: Exception) {}
    }

    /**
     * Finalizes the refinement session: applies feathering/smoothing, crops to
     * tight bounding box with padding, and writes the final sticker cutout PNG.
     */
    fun finishAndExportCropPng(context: Context): Map<String, Any> {
        // 1. Convert current mask to IntArray for feathering
        val maskInts = IntArray(width * height)
        for (i in 0 until width * height) {
            val a = currentMask[i].toInt() and 0xFF
            maskInts[i] = (a shl 24) or (a shl 16) or (a shl 8) or a
        }

        // 2. Feather & anti-alias alpha
        val feathered = featherAndSmoothAlpha(maskInts, width, height, radius = 1)

        // 3. Find opaque bounds
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var opaqueCount = 0

        val cutoutPixels = IntArray(width * height)
        for (y in 0 until height) {
            val row = y * width
            for (x in 0 until width) {
                val idx = row + x
                val alpha = (feathered[idx] shr 24) and 0xFF
                if (alpha > 24) {
                    opaqueCount++
                    if (x < minX) minX = x
                    if (y < minY) minY = y
                    if (x > maxX) maxX = x
                    if (y > maxY) maxY = y
                }
                cutoutPixels[idx] = (alpha shl 24) or (rgbPixels[idx] and 0x00FFFFFF)
            }
        }

        if (opaqueCount < 10) {
            throw IllegalStateException("Sticker cannot be completely empty. Restore some parts or reset.")
        }

        val pad = 4
        val cropMinX = max(0, minX - pad)
        val cropMinY = max(0, minY - pad)
        val cropMaxX = min(width - 1, maxX + pad)
        val cropMaxY = min(height - 1, maxY + pad)
        val cropW = cropMaxX - cropMinX + 1
        val cropH = cropMaxY - cropMinY + 1

        val cutoutBitmap = Bitmap.createBitmap(cutoutPixels, width, height, Bitmap.Config.ARGB_8888)
        val cropped = Bitmap.createBitmap(cutoutBitmap, cropMinX, cropMinY, cropW, cropH)
        if (cropped != cutoutBitmap) {
            cutoutBitmap.recycle()
        }

        val destFile = File(context.cacheDir, "cutout_refined_${UUID.randomUUID()}.png")
        destFile.parentFile?.mkdirs()
        FileOutputStream(destFile).use { out ->
            cropped.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        cropped.recycle()

        return mapOf(
            "path" to destFile.absolutePath,
            "width" to cropW,
            "height" to cropH,
            "minX" to cropMinX,
            "minY" to cropMinY
        )
    }

    private fun featherAndSmoothAlpha(mask: IntArray, width: Int, height: Int, radius: Int = 1): IntArray {
        val total = width * height
        val temp = FloatArray(total)
        val smoothed = IntArray(total)

        val weights = floatArrayOf(0.27901f, 0.44198f, 0.27901f) // radius = 1 Gaussian

        for (y in 0 until height) {
            val row = y * width
            for (x in 0 until width) {
                var sum = 0f
                for (k in -1..1) {
                    val nx = (x + k).coerceIn(0, width - 1)
                    val a = ((mask[row + nx] shr 24) and 0xFF).toFloat()
                    sum += a * weights[k + 1]
                }
                temp[row + x] = sum
            }
        }

        for (x in 0 until width) {
            for (y in 0 until height) {
                var sum = 0f
                for (k in -1..1) {
                    val ny = (y + k).coerceIn(0, height - 1)
                    sum += temp[ny * width + x] * weights[k + 1]
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

    companion object {
        fun computeSobelGradients(rgbPixels: IntArray, width: Int, height: Int): FloatArray {
            val total = width * height
            val lum = FloatArray(total)
            for (i in 0 until total) {
                val c = rgbPixels[i]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                lum[i] = 0.299f * r + 0.587f * g + 0.114f * b
            }

            val grads = FloatArray(total)
            for (y in 1 until height - 1) {
                val rowPrev = (y - 1) * width
                val rowCurr = y * width
                val rowNext = (y + 1) * width
                for (x in 1 until width - 1) {
                    val p00 = lum[rowPrev + x - 1]
                    val p01 = lum[rowPrev + x]
                    val p02 = lum[rowPrev + x + 1]

                    val p10 = lum[rowCurr + x - 1]
                    val p12 = lum[rowCurr + x + 1]

                    val p20 = lum[rowNext + x - 1]
                    val p21 = lum[rowNext + x]
                    val p22 = lum[rowNext + x + 1]

                    val gx = (p02 + 2f * p12 + p22) - (p00 + 2f * p10 + p20)
                    val gy = (p20 + 2f * p21 + p22) - (p00 + 2f * p01 + p02)
                    val mag = sqrt(gx * gx + gy * gy) / 1442.22f
                    grads[rowCurr + x] = mag.coerceIn(0.0f, 1.0f)
                }
            }
            return grads
        }
    }
}

object RefineSessionManager {
    private var activeSession: RefineSession? = null

    fun setSession(session: RefineSession) {
        activeSession = session
    }

    fun getSession(): RefineSession? = activeSession

    fun getSession(sessionId: String): RefineSession? {
        val s = activeSession
        return if (s != null && s.sessionId == sessionId) s else null
    }

    fun clearSession(sessionId: String? = null, context: Context? = null) {
        val s = activeSession
        if (s != null && (sessionId == null || s.sessionId == sessionId)) {
            if (context != null) {
                s.cleanup(context)
            }
            activeSession = null
        }
    }

    suspend fun getOrCreateSession(
        context: Context,
        imagePath: String?
    ): RefineSession = withContext(Dispatchers.Default) {
        val existing = activeSession
        if (existing != null && (imagePath == null || existing.originalImagePath == imagePath || existing.workingImagePath == imagePath)) {
            return@withContext existing
        }
        if (imagePath != null) {
            // Run cutout to compute and initialize the AI model's selection
            IsnetSegmenter.removeBackground(context, imagePath)
            val newlyCreated = activeSession
            if (newlyCreated != null) return@withContext newlyCreated
        }
        existing ?: throw IllegalStateException("Could not initialize refine session for image.")
    }
}
