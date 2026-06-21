package com.autism.screening

import android.os.Bundle
import android.view.WindowManager
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

    // FIX: Tasks A/B/C bind VideoCapture to THIS Activity's lifecycle. Task A
    // in particular is a 60-second passive viewing task with zero touch
    // input. If the device's screen times out mid-task, Android pauses the
    // Activity, and CameraX automatically stops every use case bound to that
    // lifecycle — including the in-progress recording — well before the
    // intended duration. FLAG_KEEP_SCREEN_ON is the standard, zero-downside
    // fix every camera-recording app uses for exactly this.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaHandler = MediaPipeHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // FIX: result.success() now fires only once
                    // VideoRecordEvent.Start has actually been received for
                    // this task's Recording — not the instant start() is
                    // invoked. This closes the async race that previously let
                    // a task's countdown timer run its full duration before
                    // the camera/recorder had genuinely started.
                    "startTracking" -> {
                        try {
                            mediaHandler.start { started ->
                                if (started) {
                                    result.success(null)
                                } else {
                                    result.error("START_FAILED",
                                        "Camera or recorder failed to start", null)
                                }
                            }
                        } catch (e: Exception) {
                            result.error("START_ERROR", e.message, null)
                        }
                    }

                    // releaseCamera=true is passed only after the LAST
                    // camera-using task (Task C) so the camera is unbound
                    // exactly once, after all three clips are captured.
                    "stopTracking" -> {
                        val releaseCamera = call.argument<Boolean>("releaseCamera") ?: false
                        mediaHandler.stop(releaseCamera) { videoPath ->
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
        // Always release the camera on app teardown, even if Task C never
        // finished cleanly (e.g. app killed mid-session).
        if (::mediaHandler.isInitialized) mediaHandler.stop(true) {}
    }
}
