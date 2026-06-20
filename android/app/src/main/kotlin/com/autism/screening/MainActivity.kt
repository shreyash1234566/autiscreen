package com.autism.screening

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var mediaHandler: MediaPipeHandler

    companion object {
        private const val METHOD_CHANNEL = "autism_screening/mediapipe"
        private const val EVENT_CHANNEL  = "autism_screening/gaze_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaHandler = MediaPipeHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> {
                        try {
                            mediaHandler.start()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("START_ERROR", e.message, null)
                        }
                    }

                    // stopTracking now stops GAZE ANALYSIS ONLY — video keeps rolling.
                    // Returns null immediately (no path yet; use finalizeVideo after Task C).
                    "stopTracking" -> {
                        mediaHandler.stop { _ ->
                            result.success(null)
                        }
                    }

                    // finalizeVideo — called once after Task C.
                    // Stops and finalises the continuous A+B+C recording, then returns
                    // the absolute MP4 path (or null on error).
                    "finalizeVideo" -> {
                        mediaHandler.finalizeVideo { videoPath ->
                            result.success(videoPath)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mediaHandler.setSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    mediaHandler.setSink(null)
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        // Ensure video is properly finalised if the app is killed mid-session.
        if (::mediaHandler.isInitialized) mediaHandler.finalizeVideo { /* fire-and-forget */ }
    }
}
