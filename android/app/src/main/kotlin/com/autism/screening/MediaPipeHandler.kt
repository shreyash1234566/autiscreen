package com.autism.screening

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Environment
import android.os.SystemClock
import android.util.Log
import android.util.Range
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.*

/**
 * MediaPipeHandler — wraps MediaPipe Face Landmarker (478-point mesh + irises)
 * and owns a CameraX ImageAnalysis + VideoCapture pipeline.
 *
 * Each Flutter task (A, B, C) calls start()/stop() independently and gets its
 * OWN separate MP4 file back — three tasks, three clips. Task D never touches
 * this class.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * HISTORY (two bugs found in this file, in order):
 *
 * BUG 1 (original, ~70 KB unusable clips):
 *   start() rebuilt the camera from scratch on every task AND told Flutter
 *   "recording started" the instant the method was called — before the
 *   async camera-provider listener had even fired, let alone before
 *   VideoRecordEvent.Start confirmed the encoder was producing frames. Each
 *   task's on-screen timer ran its full duration while native recording was
 *   still mid-bind, so the resulting file was just container overhead.
 *
 * BUG 2 (introduced while fixing Bug 1, Task B/C produced NO file at all):
 *   To avoid the rebind cost, a previous version of this file bound the
 *   camera ONCE and reused the same Recorder/VideoCapture for all three
 *   tasks via repeated prepareRecording() calls. This is documented as
 *   supported by the Recorder API in principle, but reusing a Recorder for
 *   a second recording is a known source of real failures — see e.g.
 *   "AssertionError: One-time media muxer creation has already occurred
 *   for recording" (dotnet/android-libraries#709) for the same underlying
 *   pattern. In practice, Task A's recording (fresh Recorder) worked; Task
 *   B's and C's (reused Recorder) silently produced no file.
 *
 * CURRENT FIX:
 *   Each task gets a genuinely NEW Recorder + VideoCapture (the standard,
 *   universally-documented CameraX pattern: unbindAll() then bind a fresh
 *   set of use cases) — this is what avoids Bug 2. Bug 1 is independently
 *   fixed by NOT resolving start() until VideoRecordEvent.Start has actually
 *   fired for that task's Recording, so Flutter's timer never gets ahead of
 *   the real camera/encoder state regardless of how long a given rebind
 *   takes on a given device.
 * ─────────────────────────────────────────────────────────────────────────
 */
class MediaPipeHandler(private val context: Context) {

    companion object {
        private const val TAG = "MediaPipeHandler"
        private const val MODEL_ASSET = "face_landmarker.task"
        private val LEFT_IRIS   = intArrayOf(468, 469, 470, 471, 472)
        private val RIGHT_IRIS  = intArrayOf(473, 474, 475, 476, 477)
        private const val L_EYE_OUTER  = 33
        private const val L_EYE_INNER  = 133
        private const val R_EYE_INNER  = 362
        private const val R_EYE_OUTER  = 263
        private const val L_EYE_UPPER  = 159
        private const val L_EYE_LOWER  = 145
        private const val R_EYE_UPPER  = 386
        private const val R_EYE_LOWER  = 374
        private const val NOSE_TIP     = 1
        private const val CHIN         = 152
        private const val FOREHEAD     = 10
    }

    private var faceLandmarker: FaceLandmarker? = null

    /**
     * Tracks the last timestamp passed to detectAsync(). FaceLandmarker
     * requires strictly increasing timestamps per call; this guards against
     * ties from SystemClock.uptimeMillis()'s millisecond resolution. Reset
     * on every start() since a new FaceLandmarker instance is built per task
     * (buildLandmarker() is called fresh each time) and doesn't carry state
     * from the previous task's timestamps.
     */
    private var lastDetectTimestampMs: Long = 0L
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor = Executors.newSingleThreadExecutor()
    private var sink: EventChannel.EventSink? = null
    private var isRunning = false

    // ── Video recording ────────────────────────────────────────────────────
    // videoCapture is intentionally re-created fresh in bindCamera() on every
    // start() call — see BUG 2 above for why it is NOT reused across tasks.
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var videoOutputFile: File? = null

    /** Fired once VideoRecordEvent.Start has actually been received for THIS task. */
    private var pendingStartCallback: ((Boolean) -> Unit)? = null

    /** Fired from VideoRecordEvent.Finalize for the CURRENT task's Recording only. */
    private var pendingStopCallback: ((String?) -> Unit)? = null

    fun setSink(s: EventChannel.EventSink?) { sink = s }

    // ─────────────────────────────────────────────────────────────────────────
    // start(callback) — ALWAYS does a fresh bind (new ImageAnalysis, new
    // Recorder, new VideoCapture) for every task. callback(true) fires only
    // once VideoRecordEvent.Start has actually been received for THIS task's
    // Recording. callback(false) on failure.
    // ─────────────────────────────────────────────────────────────────────────
    fun start(callback: (Boolean) -> Unit) {
        if (isRunning) { callback(true); return }
        isRunning = true
        lastDetectTimestampMs = 0L

        if (cameraExecutor.isShutdown) {
            cameraExecutor = Executors.newSingleThreadExecutor()
        }

        buildLandmarker()
        pendingStartCallback = callback
        bindCamera()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // stop(releaseCamera, callback) — stops gaze analysis + THIS task's
    // Recording, waits for VideoRecordEvent.Finalize, returns that task's own
    // file path. If [releaseCamera] is true (call this after the LAST
    // camera-using task, e.g. Task C), also fully unbinds the camera and
    // shuts down the analyzer executor. Otherwise the camera use cases stay
    // bound until the NEXT task's bindCamera() unbinds+rebinds them fresh.
    // ─────────────────────────────────────────────────────────────────────────
    fun stop(releaseCamera: Boolean, callback: (String?) -> Unit) {
        if (!isRunning) { callback(null); return }
        isRunning = false

        faceLandmarker?.close()
        faceLandmarker = null

        val rec = activeRecording
        if (rec == null) {
            Log.w(TAG, "stop() called with no active recording")
            if (releaseCamera) releaseCameraInternal()
            callback(null)
            return
        }

        pendingStopCallback = { path ->
            if (releaseCamera) releaseCameraInternal()
            callback(path)
        }
        rec.stop()   // → VideoRecordEvent.Finalize, handled in bindCamera()'s listener
    }

    // ── Camera binding — runs fresh on EVERY start() call ───────────────────
    private fun bindCamera() {
        val lifecycleOwner = context as? LifecycleOwner ?: run {
            Log.e(TAG, "context is not a LifecycleOwner")
            pendingStartCallback?.invoke(false)
            pendingStartCallback = null
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            if (!isRunning) {
                Log.w(TAG, "bindCamera listener fired after stop() — aborting")
                pendingStartCallback?.invoke(false)
                pendingStartCallback = null
                return@addListener
            }

            cameraProvider = cameraProviderFuture.get()

            // ── Use case 1: ImageAnalysis (MediaPipe gaze tracking) ──────
            val imageAnalysis = ImageAnalysis.Builder()
                .setResolutionSelector(
                    ResolutionSelector.Builder()
                        .setResolutionStrategy(
                            ResolutionStrategy(
                                Size(640, 480),
                                ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                            )
                        )
                        .build()
                )
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()

            // FIX (root cause of "exactly 8 frames every time, regardless of
            // task duration" — a fixed-count cap, not a time-based one):
            //
            // detectAsync() is documented (FaceLandmarker Java API) to
            // require STRICTLY monotonically increasing timestamps between
            // calls. SystemClock.uptimeMillis() has millisecond resolution
            // and is NOT guaranteed to differ between two consecutive
            // analyzer invocations — especially during the camera's initial
            // frame burst at session start, which is exactly when this kind
            // of tie is most likely. A documented MediaPipe behavior (real
            // GitHub issue, "Packet timestamp mismatch — mediapipe does not
            // recover") is that once this is violated, MediaPipe keeps
            // throwing on every subsequent call — it does not self-heal.
            //
            // imageProxy.close() sat AFTER the throwing call with no
            // try/finally, so every exception leaked that frame's camera
            // buffer permanently. With a small, fixed buffer pool, a handful
            // of leaked buffers exhausts it — and once the pool is empty,
            // the WHOLE capture session stalls (no more buffers for ANY
            // bound use case, including VideoCapture), until stop() forces
            // finalization at the end of the task. That's why frame count
            // is a constant (~8) independent of whether the task is 24s or
            // 104s: it's a buffer-count limit, not a time-based one.
            //
            // Fix: (1) guarantee close() always runs via try/finally, so a
            // single bad frame can never leak a buffer regardless of cause;
            // (2) guarantee the timestamp passed to detectAsync() is
            // strictly greater than the last one used, eliminating the most
            // likely trigger for the violation in the first place.
            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                try {
                    if (isRunning) {
                        val raw = SystemClock.uptimeMillis()
                        val tsMs = if (raw > lastDetectTimestampMs) raw else lastDetectTimestampMs + 1
                        lastDetectTimestampMs = tsMs
                        val mpImage = imageProxyToMPImage(imageProxy)
                        if (mpImage != null) {
                            try {
                                faceLandmarker?.detectAsync(mpImage, tsMs)
                            } catch (e: Exception) {
                                Log.e(TAG, "detectAsync threw, frame skipped (buffer still released): ${e.message}")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Analyzer frame processing failed, buffer still released: ${e.message}")
                } finally {
                    imageProxy.close()
                }
            }

            // ── Use case 2: VideoCapture — a FRESH Recorder every task ───
            //
            // setTargetFrameRate(): asks CameraX to hold a frame-rate floor
            // even under auto-exposure pressure in dim indoor lighting,
            // which can otherwise legitimately negotiate the sensor down to
            // a very low FPS. Verified against the current AndroidX API
            // surface (camera-video:1.4.0, already pinned in build.gradle;
            // method exists since 1.3.0-alpha06). Best-effort hint, not a
            // hard requirement — won't throw if unachievable.
            val recorder = Recorder.Builder()
                .setQualitySelector(QualitySelector.from(
                    Quality.SD,
                    FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
                ))
                .build()
            val vc = VideoCapture.Builder(recorder)
                .setTargetFrameRate(Range(20, 30))
                .build()
            videoCapture = vc

            // Standard CameraX pattern: unbind everything, then bind the
            // full fresh set together. This is what avoids BUG 2 (reusing a
            // Recorder across tasks) — every task gets its own Recorder.
            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                imageAnalysis,
                vc
            )

            startNewRecording()

        }, ContextCompat.getMainExecutor(context))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // startNewRecording() — starts the Recording on the VideoCapture that was
    // JUST freshly bound in bindCamera(), for this task only.
    // pendingStartCallback only resolves on VideoRecordEvent.Start — i.e. the
    // MethodChannel "startTracking" call genuinely blocks until frames are
    // actually being encoded.
    // ─────────────────────────────────────────────────────────────────────────
    private fun startNewRecording() {
        val vc = videoCapture ?: run {
            Log.e(TAG, "startNewRecording: no VideoCapture bound")
            pendingStartCallback?.invoke(false)
            pendingStartCallback = null
            return
        }

        val outputDir = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
            ?: context.filesDir
        val videoFile = File(outputDir, "session_${System.currentTimeMillis()}.mp4")
        videoOutputFile = videoFile

        val outputOptions = FileOutputOptions.Builder(videoFile).build()

        activeRecording = vc.output
            .prepareRecording(context, outputOptions)
            // No .withAudioEnabled() → audio OFF (screening needs video, not audio)
            .start(ContextCompat.getMainExecutor(context)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        Log.d(TAG, "Recording started: ${videoFile.name}")
                        pendingStartCallback?.invoke(true)
                        pendingStartCallback = null
                    }

                    // DIAGNOSTIC — fires roughly once/sec during an active
                    // recording. If durationMs climbs steadily while
                    // bytesRecorded barely moves (or stalls for multi-second
                    // gaps), the encoder is being starved of frames mid-
                    // recording — not just at start/stop. Check logcat for
                    // this tag during the next device run of Task A.
                    is VideoRecordEvent.Status -> {
                        val stats = event.recordingStats
                        val durationMs = stats.recordedDurationNanos / 1_000_000
                        Log.d(TAG, "Recording status: durationMs=$durationMs " +
                                "bytesRecorded=${stats.numBytesRecorded}")
                    }

                    is VideoRecordEvent.Pause ->
                        Log.w(TAG, "Recording PAUSED mid-task — likely lifecycle " +
                                "or capture-session interruption, not a normal event")

                    is VideoRecordEvent.Resume ->
                        Log.w(TAG, "Recording RESUMED after a pause")

                    is VideoRecordEvent.Finalize -> {
                        activeRecording = null
                        if (!event.hasError()) {
                            Log.d(TAG, "Recording finalised: ${videoFile.absolutePath} " +
                                    "(${videoFile.length() / 1024} KB)")
                            pendingStopCallback?.invoke(videoFile.absolutePath)
                        } else {
                            Log.e(TAG, "Recording error ${event.error}: ${event.cause?.message}")
                            pendingStopCallback?.invoke(null)
                        }
                        pendingStopCallback = null
                    }

                    else -> { /* unhandled event type — no action needed */ }
                }
            }
    }

    // ── Camera teardown — called once, after the LAST camera-using task ────
    private fun releaseCameraInternal() {
        cameraProvider?.unbindAll()
        cameraProvider = null
        videoCapture = null
        if (!cameraExecutor.isShutdown) cameraExecutor.shutdown()
        Log.d(TAG, "Camera released")
    }

    // ── MPImage conversion ─────────────────────────────────────────────────
    private fun imageProxyToMPImage(imageProxy: ImageProxy): com.google.mediapipe.framework.image.MPImage? {
        return try {
            val rawBitmap: Bitmap = imageProxy.toBitmap()
            val rotDeg = imageProxy.imageInfo.rotationDegrees.toFloat()
            val rotMatrix = Matrix().apply { postRotate(rotDeg) }
            val rotatedBitmap = Bitmap.createBitmap(rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, rotMatrix, true)
            val flipMatrix = Matrix().apply { postScale(-1f, 1f, rotatedBitmap.width / 2f, 0f) }
            val flippedBitmap = Bitmap.createBitmap(rotatedBitmap, 0, 0, rotatedBitmap.width, rotatedBitmap.height, flipMatrix, true)
            BitmapImageBuilder(flippedBitmap).build()
        } catch (e: Exception) {
            Log.e(TAG, "imageProxy → MPImage failed: ${e.message}")
            null
        }
    }

    // ── FaceLandmarker builder ─────────────────────────────────────────────
    private fun buildLandmarker() {
        try {
            val optionsBuilder = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET).build())
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setOutputFaceBlendshapes(false)
                .setResultListener { result: FaceLandmarkerResult, _: com.google.mediapipe.framework.image.MPImage ->
                    if (!isRunning) return@setResultListener
                    processFaceResult(result, SystemClock.uptimeMillis())
                }
                .setErrorListener { err: RuntimeException -> Log.e(TAG, "MediaPipe error: ${err.message}") }

            faceLandmarker = FaceLandmarker.createFromOptions(context, optionsBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build FaceLandmarker — model asset missing or corrupt: ${e.message}")
            faceLandmarker = null
        }
    }

    // ── Gaze computation ──────────────────────────────────────────────────
    private fun processFaceResult(result: FaceLandmarkerResult, timestampMs: Long) {
        if (result.faceLandmarks().isEmpty()) return
        val lm = result.faceLandmarks()[0]

        val leftIrisX  = LEFT_IRIS.map  { lm[it].x() }.average().toFloat()
        val leftIrisY  = LEFT_IRIS.map  { lm[it].y() }.average().toFloat()
        val rightIrisX = RIGHT_IRIS.map { lm[it].x() }.average().toFloat()
        val rightIrisY = RIGHT_IRIS.map { lm[it].y() }.average().toFloat()

        val leftEyeWidth  = abs(lm[L_EYE_INNER].x() - lm[L_EYE_OUTER].x())
        val rightEyeWidth = abs(lm[R_EYE_OUTER].x() - lm[R_EYE_INNER].x())

        val leftGazeNorm  = if (leftEyeWidth  > 0.001f) (leftIrisX  - lm[L_EYE_OUTER].x()) / leftEyeWidth  else 0.5f
        val rightGazeNorm = if (rightEyeWidth > 0.001f) (rightIrisX - lm[R_EYE_INNER].x()) / rightEyeWidth else 0.5f

        val gazeH = ((leftGazeNorm + rightGazeNorm) / 2f).coerceIn(0f, 1f)
        val gazeV = ((leftIrisY + rightIrisY) / 2f).coerceIn(0f, 1f)

        val leftVert  = dist(lm[L_EYE_UPPER], lm[L_EYE_LOWER])
        val rightVert = dist(lm[R_EYE_UPPER], lm[R_EYE_LOWER])
        val leftHoriz = dist(lm[L_EYE_OUTER], lm[L_EYE_INNER])
        val rightHoriz = dist(lm[R_EYE_OUTER], lm[R_EYE_INNER])
        val ear = if (leftHoriz + rightHoriz > 0.001f) (leftVert + rightVert) / (leftHoriz + rightHoriz) else 1.0f

        val eyeMidX     = (lm[L_EYE_OUTER].x() + lm[R_EYE_OUTER].x()) / 2f
        val yawApprox   = (lm[NOSE_TIP].x() - eyeMidX) * 200f
        val faceVMid    = (lm[FOREHEAD].y() + lm[CHIN].y()) / 2f
        val pitchApprox = (lm[NOSE_TIP].y() - faceVMid) * 200f

        val data: Map<String, Any> = mapOf(
            "timestamp_ms"  to timestampMs,
            "left_iris_x"   to leftIrisX.toDouble(),
            "left_iris_y"   to leftIrisY.toDouble(),
            "right_iris_x"  to rightIrisX.toDouble(),
            "right_iris_y"  to rightIrisY.toDouble(),
            "gaze_h"        to gazeH.toDouble(),
            "gaze_v"        to gazeV.toDouble(),
            "head_yaw"      to yawApprox.toDouble(),
            "head_pitch"    to pitchApprox.toDouble(),
            "blink_ear"     to ear.toDouble()
        )
        ContextCompat.getMainExecutor(context).execute { sink?.success(data) }
    }

    private fun dist(
        a: com.google.mediapipe.tasks.components.containers.NormalizedLandmark,
        b: com.google.mediapipe.tasks.components.containers.NormalizedLandmark
    ): Float {
        val dx = a.x() - b.x(); val dy = a.y() - b.y()
        return sqrt(dx * dx + dy * dy)
    }
}
