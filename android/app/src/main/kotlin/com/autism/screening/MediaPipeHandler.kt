package com.autism.screening

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker.FaceLandmarkerOptions
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import kotlin.math.*

/**
 * MediaPipeHandler — wraps MediaPipe Face Landmarker (478-point mesh + irises)
 * and owns a CameraX ImageAnalysis pipeline that feeds frames in real-time.
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
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private var sink: EventChannel.EventSink? = null
    private var isRunning = false

    fun setSink(s: EventChannel.EventSink?) { sink = s }

    fun start() {
        if (isRunning) return
        isRunning = true
        buildLandmarker()
        startCamera()
        Log.d(TAG, "MediaPipeHandler started")
    }

    fun stop() {
        isRunning = false
        cameraProvider?.unbindAll()
        cameraProvider = null
        faceLandmarker?.close()
        faceLandmarker = null
        cameraExecutor.shutdown()
        Log.d(TAG, "MediaPipeHandler stopped")
    }

    private fun startCamera() {
        val lifecycleOwner = context as? LifecycleOwner ?: run {
            Log.e(TAG, "context is not a LifecycleOwner")
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

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
                    if (mpImage != null) {
                        faceLandmarker?.detectAsync(mpImage, tsMs)
                    }
                }
                imageProxy.close()
            }

            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                imageAnalysis
            )
        }, ContextCompat.getMainExecutor(context))
    }

    private fun imageProxyToMPImage(imageProxy: ImageProxy): com.google.mediapipe.framework.image.MPImage? {
        return try {
            val rawBitmap: Bitmap = imageProxy.toBitmap()
            val rotDeg = imageProxy.imageInfo.rotationDegrees.toFloat()
            val rotMatrix = Matrix().apply { postRotate(rotDeg) }
            val rotatedBitmap = Bitmap.createBitmap(
                rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, rotMatrix, true
            )

            val flipMatrix = Matrix().apply {
                postScale(-1f, 1f, rotatedBitmap.width / 2f, 0f)
            }
            val flippedBitmap = Bitmap.createBitmap(
                rotatedBitmap, 0, 0,
                rotatedBitmap.width, rotatedBitmap.height,
                flipMatrix, true
            )

            BitmapImageBuilder(flippedBitmap).build()
        } catch (e: Exception) {
            Log.e(TAG, "imageProxy → MPImage failed: ${e.message}")
            null
        }
    }

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
            // App continues without gaze tracking; all tasks still function
        }
    }

    private fun processFaceResult(
        result: FaceLandmarkerResult,
        timestampMs: Long
    ) {
        if (result.faceLandmarks().isEmpty()) return
        val lm = result.faceLandmarks()[0]

        val leftIrisX  = LEFT_IRIS.map  { lm[it].x() }.average().toFloat()
        val leftIrisY  = LEFT_IRIS.map  { lm[it].y() }.average().toFloat()
        val rightIrisX = RIGHT_IRIS.map { lm[it].x() }.average().toFloat()
        val rightIrisY = RIGHT_IRIS.map { lm[it].y() }.average().toFloat()

        val leftEyeWidth  = abs(lm[L_EYE_INNER].x() - lm[L_EYE_OUTER].x())
        val rightEyeWidth = abs(lm[R_EYE_OUTER].x() - lm[R_EYE_INNER].x())

        val leftGazeNorm = if (leftEyeWidth > 0.001f)
            (leftIrisX - lm[L_EYE_OUTER].x()) / leftEyeWidth else 0.5f
        val rightGazeNorm = if (rightEyeWidth > 0.001f)
            (rightIrisX - lm[R_EYE_INNER].x()) / rightEyeWidth else 0.5f

        val gazeH = ((leftGazeNorm + rightGazeNorm) / 2f).coerceIn(0f, 1f)
        val gazeV = ((leftIrisY + rightIrisY) / 2f).coerceIn(0f, 1f)

        val leftVert  = dist(lm[L_EYE_UPPER], lm[L_EYE_LOWER])
        val rightVert = dist(lm[R_EYE_UPPER], lm[R_EYE_LOWER])
        val leftHoriz = dist(lm[L_EYE_OUTER], lm[L_EYE_INNER])
        val rightHoriz = dist(lm[R_EYE_OUTER], lm[R_EYE_INNER])
        val ear = if (leftHoriz + rightHoriz > 0.001f)
            (leftVert + rightVert) / (leftHoriz + rightHoriz) else 1.0f

        val eyeMidX   = (lm[L_EYE_OUTER].x() + lm[R_EYE_OUTER].x()) / 2f
        val yawApprox = (lm[NOSE_TIP].x() - eyeMidX) * 200f
        val faceVMid  = (lm[FOREHEAD].y() + lm[CHIN].y()) / 2f
        val pitchApprox = (lm[NOSE_TIP].y() - faceVMid) * 200f

        val data: Map<String, Any> = mapOf(
            "timestamp_ms"   to timestampMs,
            "left_iris_x"    to leftIrisX.toDouble(),
            "left_iris_y"    to leftIrisY.toDouble(),
            "right_iris_x"   to rightIrisX.toDouble(),
            "right_iris_y"   to rightIrisY.toDouble(),
            "gaze_h"         to gazeH.toDouble(),
            "gaze_v"         to gazeV.toDouble(),
            "head_yaw"       to yawApprox.toDouble(),
            "head_pitch"     to pitchApprox.toDouble(),
            "blink_ear"      to ear.toDouble()
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
