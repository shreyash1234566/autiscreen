import 'package:json_annotation/json_annotation.dart';

part 'session.g.dart';

// Gaze data point collected at ~30 fps by MediaPipe
@JsonSerializable(fieldRename: FieldRename.snake)
class GazeDataPoint {
  final int timestampMs;
  final double gazeRatioHorizontal; // 0=full-left  1=full-right  0.5=center
  final double gazeRatioVertical;
  final double headYawDegrees;
  final double headPitchDegrees;
  final double blinkEar; // Eye Aspect Ratio

  const GazeDataPoint({
    required this.timestampMs,
    required this.gazeRatioHorizontal,
    required this.gazeRatioVertical,
    required this.headYawDegrees,
    required this.headPitchDegrees,
    required this.blinkEar,
  });

  factory GazeDataPoint.fromJson(Map<String, dynamic> json) =>
      _$GazeDataPointFromJson(json);
  Map<String, dynamic> toJson() => _$GazeDataPointToJson(this);
}

// Name-response trial result
@JsonSerializable(fieldRename: FieldRename.snake)
class NameTrialResult {
  final int trialNumber; // 1, 2, or 3
  final int nameCalledAtMs;
  final bool responseDetected;
  final double? responseLatencyMs; // null if no response
  final double headYawAtCall;
  final double headYawAtResponse;

  const NameTrialResult({
    required this.trialNumber,
    required this.nameCalledAtMs,
    required this.responseDetected,
    this.responseLatencyMs,
    required this.headYawAtCall,
    required this.headYawAtResponse,
  });

  factory NameTrialResult.fromJson(Map<String, dynamic> json) =>
      _$NameTrialResultFromJson(json);
  Map<String, dynamic> toJson() => _$NameTrialResultToJson(this);
}

// Bubble touch event for Task D
@JsonSerializable(fieldRename: FieldRename.snake)
class BubbleTouchEvent {
  final int timestampMs;
  final double screenX; // 0-1 normalised
  final double screenY;
  final bool hitBubble;

  const BubbleTouchEvent({
    required this.timestampMs,
    required this.screenX,
    required this.screenY,
    required this.hitBubble,
  });

  factory BubbleTouchEvent.fromJson(Map<String, dynamic> json) =>
      _$BubbleTouchEventFromJson(json);
  Map<String, dynamic> toJson() => _$BubbleTouchEventToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class SessionData {
  final String sessionId;
  final String childId;
  final DateTime startedAt;
  final String videoPath; // local encrypted path pre-upload
  final List<GazeDataPoint> gazeTaskA; // social preference gaze
  final List<GazeDataPoint> gazeTaskB; // name response gaze
  final List<NameTrialResult> nameTrials;
  final List<GazeDataPoint> gazeTaskC; // imitation gaze
  final List<BubbleTouchEvent> bubbleEvents;
  final int questionnaireScore;
  final String questionnaireType; // 'mchat_r' or 'indt_asd'
  final Map<String, int> questionnaireAnswers;

  const SessionData({
    required this.sessionId,
    required this.childId,
    required this.startedAt,
    required this.videoPath,
    required this.gazeTaskA,
    required this.gazeTaskB,
    required this.nameTrials,
    required this.gazeTaskC,
    required this.bubbleEvents,
    required this.questionnaireScore,
    required this.questionnaireType,
    required this.questionnaireAnswers,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) =>
      _$SessionDataFromJson(json);
  Map<String, dynamic> toJson() => _$SessionDataToJson(this);
}
