package com.autism.screening

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var mediaHandler: MediaPipeHandler

    companion object {
        private const val METHOD_CHANNEL  = "autism_screening/mediapipe"
        private const val EVENT_CHANNEL   = "autism_screening/gaze_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaHandler = MediaPipeHandler(this)

        // ── Method channel: start / stop tracking ────────────────────────
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
                    "stopTracking" -> {
                        try {
                            mediaHandler.stop()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STOP_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Event channel: gaze data stream ──────────────────────────────
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
        if (::mediaHandler.isInitialized) mediaHandler.stop()
    }
}
