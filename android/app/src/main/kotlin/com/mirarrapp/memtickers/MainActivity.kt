package com.mirarrapp.memtickers

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val CUTOUT_CHANNEL = "com.mirarrapp.memtickers/cutout"
    private val AUTOTAG_CHANNEL = "com.mirarrapp.memtickers/autotag"
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cutout / Segmentation Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CUTOUT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isModelReady" -> {
                    result.success(IsnetSegmenter.isLoaded)
                }

                "ensureModel" -> {
                    mainScope.launch {
                        try {
                            IsnetSegmenter.ensureLoaded(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOAD_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "cutout" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val outputPath = call.argument<String>("outputPath")
                    if (imagePath == null) {
                        result.error("INVALID_ARGUMENT", "imagePath is required", null)
                        return@setMethodCallHandler
                    }

                    mainScope.launch {
                        try {
                            val resultPath = withContext(Dispatchers.Default) {
                                IsnetSegmenter.removeBackground(applicationContext, imagePath, outputPath)
                            }
                            result.success(resultPath)
                        } catch (e: IllegalStateException) {
                            result.error("SEGMENTATION_ERROR", e.message, e.stackTraceToString())
                        } catch (e: Exception) {
                            result.error("CUTOUT_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "hasRefineSession" -> {
                    result.success(RefineSessionManager.getSession() != null)
                }

                "startRefineSession" -> {
                    val imagePath = call.argument<String>("imagePath")
                    mainScope.launch {
                        try {
                            val session = withContext(Dispatchers.Default) {
                                RefineSessionManager.getOrCreateSession(applicationContext, imagePath)
                            }
                            val overlayPath = withContext(Dispatchers.Default) {
                                session.exportOverlayPng(applicationContext)
                            }
                            result.success(mapOf(
                                "sessionId" to session.sessionId,
                                "width" to session.width,
                                "height" to session.height,
                                "workingImagePath" to session.workingImagePath,
                                "overlayPath" to overlayPath,
                                "canUndo" to session.canUndo,
                                "canRedo" to session.canRedo
                            ))
                        } catch (e: Exception) {
                            result.error("REFINE_START_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "applyRefineStroke" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val rawPoints = call.argument<List<Double>>("points") ?: emptyList()
                    val radius = (call.argument<Double>("radius") ?: 25.0).toFloat()
                    val isRestore = call.argument<Boolean>("isRestore") ?: true
                    val isSmart = call.argument<Boolean>("isSmart") ?: true

                    val session = RefineSessionManager.getSession(sessionId ?: "")
                        ?: RefineSessionManager.getSession()
                    if (session == null) {
                        result.error("SESSION_NOT_FOUND", "No active refine session for id $sessionId", null)
                        return@setMethodCallHandler
                    }

                    mainScope.launch {
                        try {
                            val points = ArrayList<Pair<Float, Float>>(rawPoints.size / 2)
                            for (i in 0 until rawPoints.size step 2) {
                                if (i + 1 < rawPoints.size) {
                                    points.add(Pair(rawPoints[i].toFloat(), rawPoints[i + 1].toFloat()))
                                }
                            }

                            withContext(Dispatchers.Default) {
                                session.applyStroke(points, radius, isRestore, isSmart)
                            }

                            val overlayPath = withContext(Dispatchers.Default) {
                                session.exportOverlayPng(applicationContext)
                            }

                            result.success(mapOf(
                                "overlayPath" to overlayPath,
                                "canUndo" to session.canUndo,
                                "canRedo" to session.canRedo
                            ))
                        } catch (e: Exception) {
                            result.error("STROKE_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "undoRefineStroke" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val session = RefineSessionManager.getSession(sessionId ?: "")
                        ?: RefineSessionManager.getSession()
                    if (session == null) {
                        result.error("SESSION_NOT_FOUND", "No active refine session for id $sessionId", null)
                        return@setMethodCallHandler
                    }
                    mainScope.launch {
                        try {
                            val didUndo = withContext(Dispatchers.Default) { session.undo() }
                            val overlayPath = if (didUndo) {
                                withContext(Dispatchers.Default) { session.exportOverlayPng(applicationContext) }
                            } else null
                            result.success(mapOf(
                                "success" to didUndo,
                                "overlayPath" to overlayPath,
                                "canUndo" to session.canUndo,
                                "canRedo" to session.canRedo
                            ))
                        } catch (e: Exception) {
                            result.error("UNDO_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "redoRefineStroke" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val session = RefineSessionManager.getSession(sessionId ?: "")
                        ?: RefineSessionManager.getSession()
                    if (session == null) {
                        result.error("SESSION_NOT_FOUND", "No active refine session for id $sessionId", null)
                        return@setMethodCallHandler
                    }
                    mainScope.launch {
                        try {
                            val didRedo = withContext(Dispatchers.Default) { session.redo() }
                            val overlayPath = if (didRedo) {
                                withContext(Dispatchers.Default) { session.exportOverlayPng(applicationContext) }
                            } else null
                            result.success(mapOf(
                                "success" to didRedo,
                                "overlayPath" to overlayPath,
                                "canUndo" to session.canUndo,
                                "canRedo" to session.canRedo
                            ))
                        } catch (e: Exception) {
                            result.error("REDO_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "resetRefine" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val session = RefineSessionManager.getSession(sessionId ?: "")
                        ?: RefineSessionManager.getSession()
                    if (session == null) {
                        result.error("SESSION_NOT_FOUND", "No active refine session for id $sessionId", null)
                        return@setMethodCallHandler
                    }
                    mainScope.launch {
                        try {
                            withContext(Dispatchers.Default) { session.resetToOriginal() }
                            val overlayPath = withContext(Dispatchers.Default) {
                                session.exportOverlayPng(applicationContext)
                            }
                            result.success(mapOf(
                                "success" to true,
                                "overlayPath" to overlayPath,
                                "canUndo" to session.canUndo,
                                "canRedo" to session.canRedo
                            ))
                        } catch (e: Exception) {
                            result.error("RESET_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "finishRefineSession" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val session = RefineSessionManager.getSession(sessionId ?: "")
                        ?: RefineSessionManager.getSession()
                    if (session == null) {
                        result.error("SESSION_NOT_FOUND", "No active refine session for id $sessionId", null)
                        return@setMethodCallHandler
                    }
                    mainScope.launch {
                        try {
                            val cropResult = withContext(Dispatchers.Default) {
                                session.finishAndExportCropPng(applicationContext)
                            }
                            result.success(cropResult)
                        } catch (e: Exception) {
                            result.error("FINISH_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "disposeRefineSession" -> {
                    val sessionId = call.argument<String>("sessionId")
                    RefineSessionManager.clearSession(sessionId, applicationContext)
                    result.success(null)
                }

                "dispose" -> {
                    RefineSessionManager.clearSession(null, applicationContext)
                    IsnetSegmenter.close()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // AutoTagging Channel (MobileCLIP-S0)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOTAG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isModelReady" -> {
                    result.success(AutoTagger.isLoaded)
                }

                "ensureModel" -> {
                    mainScope.launch {
                        try {
                            AutoTagger.ensureLoaded(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOAD_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "predictTags" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val topK = call.argument<Int>("topK") ?: 5
                    val minConfidence = (call.argument<Double>("minConfidence") ?: 0.18).toFloat()

                    if (imagePath == null) {
                        result.error("INVALID_ARGUMENT", "imagePath is required", null)
                        return@setMethodCallHandler
                    }

                    mainScope.launch {
                        try {
                            val tags = withContext(Dispatchers.Default) {
                                AutoTagger.predictTags(
                                    applicationContext,
                                    imagePath,
                                    topK,
                                    minConfidence
                                )
                            }
                            result.success(tags)
                        } catch (e: Exception) {
                            result.error("TAGGER_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                }

                "dispose" -> {
                    AutoTagger.close()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        mainScope.cancel()
        IsnetSegmenter.close()
        AutoTagger.close()
        super.onDestroy()
    }
}
