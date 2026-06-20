package com.autism.screening

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Environment
import android.os.SystemClock
import android.util.Log
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
 * BUG FIXED HERE (was: ~70 KB / unusable clips):
 *
 *   Previously, start() called startCamera() on EVERY task, which did:
 *     unbindAll() → bindToLifecycle(fresh ImageAnalysis, fresh VideoCapture)
 *   on every single call — a full camera teardown + hardware re-init on the
 *   2nd and 3rd cycles (Task B, Task C). Camera session teardown/rebind on
 *   real Android hardware is slow and not guaranteed to settle quickly; the
 *   Recorder's first frames after a rebind are frequently dropped or delayed.
 *   Combined with `result.success(null)` being returned to Flutter the
 *   INSTANT start() was called — before the async camera-provider listener
 *   had even fired, let alone before VideoRecordEvent.Start confirmed the
 *   encoder was actually producing frames — Flutter's task timer/TTS sequence
 *   would run its full duration while native recording was still mid-rebind,
 *   stop() would fire, and the resulting file was just container overhead
 *   plus at most a couple of frames: ~70 KB, "extremely short and unusable."
 *
 *   FIX:
 *     • The camera (ImageAnalysis + VideoCapture) is bound EXACTLY ONCE, on
 *       the first start() call. Tasks B and C reuse the already-bound
 *       VideoCapture/Recorder — no unbindAll(), no rebind, no teardown.
 *     • start() does not resolve until VideoRecordEvent.Start has actually
 *       fired for that task's Recording — Flutter's "startTracking" only
 *       returns once recording is verifiably rolling.
 *     • stop() starts a fresh Recording boundary by calling .stop() on the
 *       CURRENT task's Recording and waits for VideoRecordEvent.Finalize —
 *       returning a path that belongs to THAT task only.
 *     • The camera is only unbound once, after Task C, via releaseCamera().
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
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor = Executors.newSingleThreadExecutor()
    private var sink: EventChannel.EventSink? = null
    private var isRunning = false

    // ── Video recording ────────────────────────────────────────────────────
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var videoOutputFile: File? = null

    /** True once the camera + VideoCapture use cases have been bound for this session. */
    private var cameraBound = false

    /** Fired once, from the camera-bind listener OR immediately if already bound. */
    private var pendingStartCallback: ((Boolean) -> Unit)? = null

    /** Fired from VideoRecordEvent.Finalize for the CURRENT task's Recording only. */
    private var pendingStopCallback: ((String?) -> Unit)? = null

    fun setSink(s: EventChannel.EventSink?) { sink = s }

    // ─────────────────────────────────────────────────────────────────────────
    // start(callback) — callback(true) fires only once VideoRecordEvent.Start
    // has actually been received for THIS task's Recording (not just once the
    // method was invoked). callback(false) on failure.
    // ─────────────────────────────────────────────────────────────────────────
    fun start(callback: (Boolean) -> Unit) {
        if (isRunning) { callback(true); return }
        isRunning = true

        if (cameraExecutor.isShutdown) {
            cameraExecutor = Executors.newSingleThreadExecutor()
        }

        buildLandmarker()
        pendingStartCallback = callback

        if (!cameraBound) {
            // First task: bind the camera once, then start the first Recording.
            bindCamera()
        } else {
            // Subsequent tasks: camera already bound — just start a NEW
            // Recording on the existing VideoCapture. No rebind.
            startNewRecording()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // stop(releaseCamera, callback) — stops gaze analysis + THIS task's
    // Recording, waits for VideoRecordEvent.Finalize, returns that task's own
    // file path. If [releaseCamera] is true (call this after the LAST
    // camera-using task, e.g. Task C), also unbinds the camera afterwards.
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
        rec.stop()   // → VideoRecordEvent.Finalize, handled in startNewRecording()
    }

    // ── Camera binding (runs exactly once per session) ─────────────────────
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

            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                if (isRunning) {
                    val tsMs = SystemClock.uptimeMillis()
                    val mpImage = imageProxyToMPImage(imageProxy)
                    if (mpImage != null) faceLandmarker?.detectAsync(mpImage, tsMs)
                }
                imageProxy.close()
            }

            // ── Use case 2: VideoCapture (bound ONCE, reused for all 3 tasks) ──
            val recorder = Recorder.Builder()
                .setQualitySelector(QualitySelector.from(
                    Quality.SD,
                    FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
                ))
                .build()
            val vc = VideoCapture.withOutput(recorder)
            videoCapture = vc

            // unbindAll() here is safe & necessary the FIRST time only — there is
            // nothing else bound yet. This is never called again after this point
            // for the lifetime of the session, so there is no rebind cycle.
            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                imageAnalysis,
                vc
            )
            cameraBound = true

            startNewRecording()

        }, ContextCompat.getMainExecutor(context))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // startNewRecording() — starts a fresh Recording on the EXISTING,
    // already-bound VideoCapture/Recorder. Called once per task (no rebind).
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

                    else -> { /* Status / Pause events — no action needed */ }
                }
            }
    }

    // ── Camera teardown — called once, after the LAST camera-using task ────
    private fun releaseCameraInternal() {
        cameraProvider?.unbindAll()
        cameraProvider = null
        videoCapture = null
        cameraBound = false
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
