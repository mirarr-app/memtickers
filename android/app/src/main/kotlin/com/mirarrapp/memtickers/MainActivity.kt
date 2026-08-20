package com.mirarrapp.memtickers

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mirarrapp.memtickers/cutout"
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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

                "dispose" -> {
                    IsnetSegmenter.close()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        IsnetSegmenter.close()
        super.onDestroy()
    }
}
