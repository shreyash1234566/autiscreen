// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GazeDataPoint _$GazeDataPointFromJson(Map<String, dynamic> json) =>
    GazeDataPoint(
      timestampMs: (json['timestamp_ms'] as num).toInt(),
      gazeRatioHorizontal: (json['gaze_ratio_horizontal'] as num).toDouble(),
      gazeRatioVertical: (json['gaze_ratio_vertical'] as num).toDouble(),
      headYawDegrees: (json['head_yaw_degrees'] as num).toDouble(),
      headPitchDegrees: (json['head_pitch_degrees'] as num).toDouble(),
      blinkEar: (json['blink_ear'] as num).toDouble(),
    );

Map<String, dynamic> _$GazeDataPointToJson(GazeDataPoint instance) =>
    <String, dynamic>{
      'timestamp_ms': instance.timestampMs,
      'gaze_ratio_horizontal': instance.gazeRatioHorizontal,
      'gaze_ratio_vertical': instance.gazeRatioVertical,
      'head_yaw_degrees': instance.headYawDegrees,
      'head_pitch_degrees': instance.headPitchDegrees,
      'blink_ear': instance.blinkEar,
    };

NameTrialResult _$NameTrialResultFromJson(Map<String, dynamic> json) =>
    NameTrialResult(
      trialNumber: (json['trial_number'] as num).toInt(),
      nameCalledAtMs: (json['name_called_at_ms'] as num).toInt(),
      responseDetected: json['response_detected'] as bool,
      responseLatencyMs: (json['response_latency_ms'] as num?)?.toDouble(),
      headYawAtCall: (json['head_yaw_at_call'] as num).toDouble(),
      headYawAtResponse: (json['head_yaw_at_response'] as num).toDouble(),
    );

Map<String, dynamic> _$NameTrialResultToJson(NameTrialResult instance) =>
    <String, dynamic>{
      'trial_number': instance.trialNumber,
      'name_called_at_ms': instance.nameCalledAtMs,
      'response_detected': instance.responseDetected,
      'response_latency_ms': instance.responseLatencyMs,
      'head_yaw_at_call': instance.headYawAtCall,
      'head_yaw_at_response': instance.headYawAtResponse,
    };

BubbleTouchEvent _$BubbleTouchEventFromJson(Map<String, dynamic> json) =>
    BubbleTouchEvent(
      timestampMs: (json['timestamp_ms'] as num).toInt(),
      screenX: (json['screen_x'] as num).toDouble(),
      screenY: (json['screen_y'] as num).toDouble(),
      hitBubble: json['hit_bubble'] as bool,
    );

Map<String, dynamic> _$BubbleTouchEventToJson(BubbleTouchEvent instance) =>
    <String, dynamic>{
      'timestamp_ms': instance.timestampMs,
      'screen_x': instance.screenX,
      'screen_y': instance.screenY,
      'hit_bubble': instance.hitBubble,
    };

SessionData _$SessionDataFromJson(Map<String, dynamic> json) => SessionData(
      sessionId: json['session_id'] as String,
      childId: json['child_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      videoPath: json['video_path'] as String,
      gazeTaskA: (json['gaze_task_a'] as List<dynamic>)
          .map((e) => GazeDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      gazeTaskB: (json['gaze_task_b'] as List<dynamic>)
          .map((e) => GazeDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      nameTrials: (json['name_trials'] as List<dynamic>)
          .map((e) => NameTrialResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      gazeTaskC: (json['gaze_task_c'] as List<dynamic>)
          .map((e) => GazeDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      bubbleEvents: (json['bubble_events'] as List<dynamic>)
          .map((e) => BubbleTouchEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      questionnaireScore: (json['questionnaire_score'] as num).toInt(),
      questionnaireType: json['questionnaire_type'] as String,
      questionnaireAnswers:
          Map<String, int>.from(json['questionnaire_answers'] as Map),
    );

Map<String, dynamic> _$SessionDataToJson(SessionData instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'child_id': instance.childId,
      'started_at': instance.startedAt.toIso8601String(),
      'video_path': instance.videoPath,
      'gaze_task_a': instance.gazeTaskA,
      'gaze_task_b': instance.gazeTaskB,
      'name_trials': instance.nameTrials,
      'gaze_task_c': instance.gazeTaskC,
      'bubble_events': instance.bubbleEvents,
      'questionnaire_score': instance.questionnaireScore,
      'questionnaire_type': instance.questionnaireType,
      'questionnaire_answers': instance.questionnaireAnswers,
    };
