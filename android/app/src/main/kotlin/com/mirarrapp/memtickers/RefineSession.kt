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

    // Perceptual macro color gradients [0, 1] precomputed for fast edge snapping
    val gradients: FloatArray = computeMacroGradients(rgbPixels, width, height)

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

        val rClamped = radius.coerceIn(4f, 150f)

        if (isSmart) {
            applySmartStroke(points, rClamped, isRestore)
        } else {
            applyManualStroke(points, rClamped, isRestore)
        }

        return true
    }

    private fun applyManualStroke(
        points: List<Pair<Float, Float>>,
        radius: Float,
        isRestore: Boolean
    ) {
        val targetVal = if (isRestore) 255.toByte() else 0.toByte()
        val dense = interpolatePoints(points, max(2.0f, radius * 0.35f))
        val rSq = radius * radius

        for (pt in dense) {
            val cx = pt.first
            val cy = pt.second
            val minX = max(0, (cx - radius).toInt())
            val maxX = min(width - 1, (cx + radius).toInt())
            val minY = max(0, (cy - radius).toInt())
            val maxY = min(height - 1, (cy + radius).toInt())

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
    }

    private fun applySmartStroke(
        points: List<Pair<Float, Float>>,
        radius: Float,
        isRestore: Boolean
    ) {
        val targetVal = if (isRestore) 255.toByte() else 0.toByte()
        val dense = interpolatePoints(points, stepSize = 2.0f)
        if (dense.isEmpty()) return

        val reach = (radius * 1.30f).roundToInt()
        var minX = width - 1
        var maxX = 0
        var minY = height - 1
        var maxY = 0

        for (pt in dense) {
            val ix = pt.first.toInt()
            val iy = pt.second.toInt()
            if (ix < minX) minX = ix
            if (ix > maxX) maxX = ix
            if (iy < minY) minY = iy
            if (iy > maxY) maxY = iy
        }

        minX = max(0, minX - reach)
        maxX = min(width - 1, maxX + reach)
        minY = max(0, minY - reach)
        maxY = min(height - 1, maxY + reach)

        // Sample color characteristics along the user's stroke
        var sumR = 0L
        var sumG = 0L
        var sumB = 0L
        val count = dense.size
        for (pt in dense) {
            val px = pt.first.roundToInt().coerceIn(0, width - 1)
            val py = pt.second.roundToInt().coerceIn(0, height - 1)
            val c = rgbPixels[py * width + px]
            sumR += (c shr 16) and 0xFF
            sumG += (c shr 8) and 0xFF
            sumB += c and 0xFF
        }
        val avgR = (sumR / count).toInt()
        val avgG = (sumG / count).toInt()
        val avgB = (sumB / count).toInt()

        var maxStrokeVar = 0f
        for (pt in dense) {
            val px = pt.first.roundToInt().coerceIn(0, width - 1)
            val py = pt.second.roundToInt().coerceIn(0, height - 1)
            val c = rgbPixels[py * width + px]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            val d = colorDistance(r, g, b, avgR, avgG, avgB)
            if (d > maxStrokeVar) maxStrokeVar = d
        }

        // Adaptive color barrier: allows natural variations inside the stroked object (e.g. shadowed skin, buttons),
        // but blocks transitions into background colors.
        val colorBarrierThreshold = max(68.0f, min(145.0f, maxStrokeVar * 1.6f))
        val edgeThreshold = 0.15f

        val coreRadius = max(3.5f, radius * 0.40f)
        val coreRadiusSq = coreRadius * coreRadius
        val maxRadiusSq = (radius * 1.25f) * (radius * 1.25f)

        // Build stroke segments
        val segs = ArrayList<StrokeSegment>(max(1, points.size - 1))
        if (points.size == 1) {
            segs.add(StrokeSegment(points[0].first, points[0].second, points[0].first, points[0].second, reach.toFloat()))
        } else {
            for (i in 0 until points.size - 1) {
                segs.add(StrokeSegment(points[i].first, points[i].second, points[i + 1].first, points[i + 1].second, reach.toFloat()))
            }
        }

        for (y in minY..maxY) {
            val row = y * width
            for (x in minX..maxX) {
                var bestDistSq = Float.MAX_VALUE
                var bestProjX = x.toFloat()
                var bestProjY = y.toFloat()

                for (s in segs) {
                    if (x < s.minX || x > s.maxX || y < s.minY || y > s.maxY) continue
                    val (dSq, px, py) = s.project(x.toFloat(), y.toFloat())
                    if (dSq < bestDistSq) {
                        bestDistSq = dSq
                        bestProjX = px
                        bestProjY = py
                        if (dSq <= coreRadiusSq) break
                    }
                }

                // 1. Core zone: unconditionally marked (handles buttons, stitches, seams, skin creases)
                if (bestDistSq <= coreRadiusSq) {
                    currentMask[row + x] = targetVal
                    continue
                }

                // Outside outer reach
                if (bestDistSq > maxRadiusSq) continue

                // 2. Smart fringe zone: snap to the physical contour without bleeding across
                val refIx = bestProjX.roundToInt().coerceIn(0, width - 1)
                val refIy = bestProjY.roundToInt().coerceIn(0, height - 1)
                val refColor = rgbPixels[refIy * width + refIx]
                val refR = (refColor shr 16) and 0xFF
                val refG = (refColor shr 8) and 0xFF
                val refB = refColor and 0xFF

                val currColor = rgbPixels[row + x]
                val currR = (currColor shr 16) and 0xFF
                val currG = (currColor shr 8) and 0xFF
                val currB = currColor and 0xFF
                val currDelta = colorDistance(currR, currG, currB, refR, refG, refB)

                if (currDelta > colorBarrierThreshold * 1.30f) continue

                // Ray trace from core boundary toward (x, y)
                val dist = sqrt(bestDistSq)
                val steps = max(2, ((dist - coreRadius) / 2.0f).toInt())
                var crossedBoundary = false

                for (st in 1..steps) {
                    val t = (coreRadius + (dist - coreRadius) * (st.toFloat() / steps)) / dist
                    val sx = (bestProjX + (x - bestProjX) * t).roundToInt().coerceIn(0, width - 1)
                    val sy = (bestProjY + (y - bestProjY) * t).roundToInt().coerceIn(0, height - 1)
                    val sIdx = sy * width + sx

                    val grad = gradients[sIdx]
                    if (grad >= edgeThreshold) {
                        val sc = rgbPixels[sIdx]
                        val sr = (sc shr 16) and 0xFF
                        val sg = (sc shr 8) and 0xFF
                        val sb = sc and 0xFF
                        val sDelta = colorDistance(sr, sg, sb, refR, refG, refB)
                        if (sDelta >= colorBarrierThreshold * 0.70f) {
                            crossedBoundary = true
                            break
                        }
                    }
                }

                if (!crossedBoundary) {
                    currentMask[row + x] = targetVal
                }
            }
        }
    }

    private class StrokeSegment(val ax: Float, val ay: Float, val bx: Float, val by: Float, reach: Float) {
        val dx = bx - ax
        val dy = by - ay
        val lenSq = dx * dx + dy * dy
        val minX = min(ax, bx) - reach
        val maxX = max(ax, bx) + reach
        val minY = min(ay, by) - reach
        val maxY = max(ay, by) + reach

        fun project(px: Float, py: Float): Triple<Float, Float, Float> {
            if (lenSq < 1e-4f) {
                val ex = px - ax
                val ey = py - ay
                return Triple(ex * ex + ey * ey, ax, ay)
            }
            val t = (((px - ax) * dx + (py - ay) * dy) / lenSq).coerceIn(0f, 1f)
            val projX = ax + t * dx
            val projY = ay + t * dy
            val ex = px - projX
            val ey = py - projY
            return Triple(ex * ex + ey * ey, projX, projY)
        }
    }

    private fun interpolatePoints(points: List<Pair<Float, Float>>, stepSize: Float): List<Pair<Float, Float>> {
        if (points.isEmpty()) return emptyList()
        if (points.size == 1) return points

        val result = ArrayList<Pair<Float, Float>>()
        for (i in 0 until points.size - 1) {
            val p0 = points[i]
            val p1 = points[i + 1]
            val dx = p1.first - p0.first
            val dy = p1.second - p0.second
            val dist = sqrt(dx * dx + dy * dy)
            val steps = max(1, (dist / stepSize).roundToInt())

            for (s in 0 until steps) {
                val t = s.toFloat() / steps
                result.add(Pair(p0.first + dx * t, p0.second + dy * t))
            }
        }
        result.add(points.last())
        return result
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
        fun colorDistance(r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int): Float {
            val dr = r1 - r2
            val dg = g1 - g2
            val db = b1 - b2
            // Perceptually weighted Euclidean color distance
            return sqrt((2 * dr * dr + 4 * dg * dg + 3 * db * db).toFloat())
        }

        fun computeMacroGradients(rgbPixels: IntArray, width: Int, height: Int): FloatArray {
            val total = width * height
            val grads = FloatArray(total)

            // 1. Fast separable 5-tap Gaussian pre-smoothing: [1, 4, 6, 4, 1] / 16
            // Removes sensor noise, cloth weave, and pore textures while preserving macro object edges
            val tempR = IntArray(total)
            val tempG = IntArray(total)
            val tempB = IntArray(total)

            val smoothR = IntArray(total)
            val smoothG = IntArray(total)
            val smoothB = IntArray(total)

            // Horizontal pass
            for (y in 0 until height) {
                val row = y * width
                for (x in 0 until width) {
                    val xm2 = (x - 2).coerceIn(0, width - 1)
                    val xm1 = (x - 1).coerceIn(0, width - 1)
                    val xp1 = (x + 1).coerceIn(0, width - 1)
                    val xp2 = (x + 2).coerceIn(0, width - 1)

                    val c0 = rgbPixels[row + xm2]
                    val c1 = rgbPixels[row + xm1]
                    val c2 = rgbPixels[row + x]
                    val c3 = rgbPixels[row + xp1]
                    val c4 = rgbPixels[row + xp2]

                    val r = (((c0 shr 16) and 0xFF) + (((c1 shr 16) and 0xFF) shl 2) + (((c2 shr 16) and 0xFF) * 6) + (((c3 shr 16) and 0xFF) shl 2) + ((c4 shr 16) and 0xFF)) shr 4
                    val g = (((c0 shr 8) and 0xFF) + (((c1 shr 8) and 0xFF) shl 2) + (((c2 shr 8) and 0xFF) * 6) + (((c3 shr 8) and 0xFF) shl 2) + ((c4 shr 8) and 0xFF)) shr 4
                    val b = ((c0 and 0xFF) + ((c1 and 0xFF) shl 2) + ((c2 and 0xFF) * 6) + ((c3 and 0xFF) shl 2) + (c4 and 0xFF)) shr 4

                    val idx = row + x
                    tempR[idx] = r
                    tempG[idx] = g
                    tempB[idx] = b
                }
            }

            // Vertical pass
            for (x in 0 until width) {
                for (y in 0 until height) {
                    val ym2 = (y - 2).coerceIn(0, height - 1) * width + x
                    val ym1 = (y - 1).coerceIn(0, height - 1) * width + x
                    val y0  = y * width + x
                    val yp1 = (y + 1).coerceIn(0, height - 1) * width + x
                    val yp2 = (y + 2).coerceIn(0, height - 1) * width + x

                    smoothR[y0] = (tempR[ym2] + (tempR[ym1] shl 2) + tempR[y0] * 6 + (tempR[yp1] shl 2) + tempR[yp2]) shr 4
                    smoothG[y0] = (tempG[ym2] + (tempG[ym1] shl 2) + tempG[y0] * 6 + (tempG[yp1] shl 2) + tempG[yp2]) shr 4
                    smoothB[y0] = (tempB[ym2] + (tempB[ym1] shl 2) + tempB[y0] * 6 + (tempB[yp1] shl 2) + tempB[yp2]) shr 4
                }
            }

            // 2. Central difference on smoothed color channels
            for (y in 1 until height - 1) {
                val rowPrev = (y - 1) * width
                val rowCurr = y * width
                val rowNext = (y + 1) * width

                for (x in 1 until width - 1) {
                    val idxL = rowCurr + x - 1
                    val idxR = rowCurr + x + 1
                    val idxU = rowPrev + x
                    val idxD = rowNext + x

                    val drX = smoothR[idxR] - smoothR[idxL]
                    val drY = smoothR[idxD] - smoothR[idxU]

                    val dgX = smoothG[idxR] - smoothG[idxL]
                    val dgY = smoothG[idxD] - smoothG[idxU]

                    val dbX = smoothB[idxR] - smoothB[idxL]
                    val dbY = smoothB[idxD] - smoothB[idxU]

                    val magX2 = 2 * drX * drX + 4 * dgX * dgX + 3 * dbX * dbX
                    val magY2 = 2 * drY * drY + 4 * dgY * dgY + 3 * dbY * dbY
                    val mag = sqrt((magX2 + magY2).toFloat()) / 765.0f
                    grads[rowCurr + x] = mag.coerceIn(0.0f, 1.0f)
                }
            }

            return grads
        }

        fun computeSobelGradients(rgbPixels: IntArray, width: Int, height: Int): FloatArray {
            return computeMacroGradients(rgbPixels, width, height)
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
