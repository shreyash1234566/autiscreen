import 'dart:async';
import 'package:flutter/services.dart';
import '../constants/task_config.dart';
import '../models/session.dart';

/// Communicates with the native Android MediaPipe Face Landmarker.
/// Native code lives in MediaPipeHandler.kt
class MediaPipeService {
  static const MethodChannel _channel =
      MethodChannel('autism_screening/mediapipe');
  static const EventChannel _gazeStream =
      EventChannel('autism_screening/gaze_stream');

  StreamController<GazeDataPoint>? _gazeController;
  Stream<GazeDataPoint>? _gazeStreamBroadcast;
  StreamSubscription? _nativeSub;

  bool _isRunning = false;
  final List<GazeDataPoint> _buffer = [];

  /// Absolute path of the MP4 recorded during the most recent tracking session.
  /// Populated by stopTracking(). Null if recording failed or hasn't run yet.
  String? lastVideoPath;

  Future<void> startTracking() async {
    if (_isRunning) return;
    _isRunning = true;
    _buffer.clear();

    _gazeController = StreamController<GazeDataPoint>.broadcast();
    _gazeStreamBroadcast = _gazeController!.stream;

    _nativeSub = _gazeStream.receiveBroadcastStream().listen((dynamic raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      final point = _parseGazePoint(map);
      _buffer.add(point);
      _gazeController?.add(point);
    });

    await _channel.invokeMethod('startTracking');
  }

  /// Stops tracking and waits for video recording to finalize.
  /// Returns the absolute path of the saved MP4, or null on error.
  /// Also stores the path in [lastVideoPath] for retrieval by the caller.
  Future<String?> stopTracking() async {
    if (!_isRunning) return lastVideoPath;
    _isRunning = false;
    // invokeMethod now returns String? — the video file path from Kotlin
    final path = await _channel.invokeMethod<String?>('stopTracking');
    lastVideoPath = path;
    await _nativeSub?.cancel();
    _gazeController?.close();
    return path;
  }

  List<GazeDataPoint> consumeBuffer() {
    final copy = List<GazeDataPoint>.from(_buffer);
    _buffer.clear();
    return copy;
  }

  List<GazeDataPoint> getBuffer() {
    return List<GazeDataPoint>.from(_buffer);
  }

  Stream<GazeDataPoint>? get gazeStream => _gazeStreamBroadcast;

  // ─────────────────────────────────────────────────────────────────────────
  // Parse raw map from native MediaPipe Face Landmarker.
  //
  // Fix: was recomputing gazeH as raw average of left_iris_x + right_iris_x,
  // which ignores eye-width variation and gives a different scale than the
  // threshold values calibrated from Perochon et al. 2023.
  //
  // Now uses gaze_h and gaze_v sent directly from Kotlin, which are computed
  // as the eye-width-normalised iris-to-eye-corner ratio — the correct quantity.
  //
  // Coordinate convention (after Kotlin-side front-camera horizontal flip):
  //   gaze_h < 0.5  →  looking at LEFT half of screen  (social content, Task A)
  //   gaze_h > 0.5  →  looking at RIGHT half of screen (non-social, Task A)
  // ─────────────────────────────────────────────────────────────────────────
  GazeDataPoint _parseGazePoint(Map<String, dynamic> map) {
    return GazeDataPoint(
      timestampMs:          (map['timestamp_ms'] as int),
      gazeRatioHorizontal:  (map['gaze_h']       as num).toDouble(),
      gazeRatioVertical:    (map['gaze_v']        as num).toDouble(),
      headYawDegrees:       (map['head_yaw']      as num).toDouble(),
      headPitchDegrees:     (map['head_pitch']    as num).toDouble(),
      blinkEar:             (map['blink_ear']     as num).toDouble(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL PREFERENCE RATIO
  // Source: Perochon et al. 2023, NEJM Evidence — Table 2
  // social_ratio = frames_looking_left / total_frames
  // Left half of screen = social content (character face)
  // Typical mean: 0.61 (SD 0.12)
  // ASD mean:     0.38 (SD 0.14)
  // ─────────────────────────────────────────────────────────────────────────
  static double computeSocialPreferenceRatio(List<GazeDataPoint> taskAGaze) {
    if (taskAGaze.isEmpty) return 0.5;
    final social = taskAGaze
        .where((p) => p.gazeRatioHorizontal < 0.5)
        .length;
    return social / taskAGaze.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAME RESPONSE DETECTION
  // Head yaw change > 15 degrees toward center within 3-second window
  // Source: Bradshaw et al. 2018, Autism Research
  // ─────────────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? detectNameResponse({
    required List<GazeDataPoint> gazeData,
    required int nameCalledAtMs,
  }) {
    const int windowMs = TaskConfig.taskBResponseWindowSeconds * 1000;
    final windowPoints = gazeData.where((p) =>
        p.timestampMs >= nameCalledAtMs &&
        p.timestampMs <= nameCalledAtMs + windowMs).toList();

    if (windowPoints.isEmpty) return null;

    final baselinePoints = gazeData.where((p) =>
        p.timestampMs >= nameCalledAtMs - 2000 &&
        p.timestampMs < nameCalledAtMs).toList();

    // If no baseline, use the first point in window as baseline
    final baselineYaw = baselinePoints.isNotEmpty
        ? baselinePoints.map((p) => p.headYawDegrees).reduce((a, b) => a + b) / baselinePoints.length
        : windowPoints.first.headYawDegrees;

    for (final p in windowPoints) {
      if ((p.headYawDegrees - baselineYaw).abs() > TaskConfig.headOrientationThresholdDegrees) {
        return {
          'latency_ms': p.timestampMs - nameCalledAtMs,
          'yaw_at_call': baselineYaw,
          'yaw_at_response': p.headYawDegrees,
        };
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLINK RATE (blinks per minute)
  // Eye Aspect Ratio threshold: 0.20 (Soukupová & Čech, 2016)
  // Typical: 15-20 bpm; ASD may differ
  // ─────────────────────────────────────────────────────────────────────────
  static double computeBlinkRate(List<GazeDataPoint> gazeData) {
    if (gazeData.length < 2) return 0;

    int blinkCount = 0;
    bool wasClosed = false;

    for (final p in gazeData) {
      final closed = p.blinkEar < TaskConfig.blinkEarThreshold;
      if (closed && !wasClosed) blinkCount++;
      wasClosed = closed;
    }

    final durationMs = gazeData.last.timestampMs - gazeData.first.timestampMs;
    final minutes = durationMs / 60000.0;
    return minutes > 0 ? blinkCount / minutes : 0;
  }
}
