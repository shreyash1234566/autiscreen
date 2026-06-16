import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/task_config.dart';
import '../models/session.dart';
import '../services/mediapipe_service.dart';
import '../services/tts_service.dart';
import '../widgets/animated_character.dart';

/// TASK B — Name Response Test
/// 3 trials, 30-second inter-trial gaps, 3-second response window
class TaskBScreen extends StatefulWidget {
  final String childName;
  final String languageCode;
  final MediaPipeService mediaPipeService;
  final TtsService ttsService;
  final void Function(List<NameTrialResult> trials, List<GazeDataPoint> gazeData) onComplete;

  const TaskBScreen({
    super.key,
    required this.childName,
    required this.languageCode,
    required this.mediaPipeService,
    required this.ttsService,
    required this.onComplete,
  });

  @override
  State<TaskBScreen> createState() => _TaskBScreenState();
}

class _TaskBScreenState extends State<TaskBScreen> {
  int _currentTrial = 0;
  _Phase _phase = _Phase.gap;
  int _phaseSecondsLeft = 5; // initial countdown before first trial

  final List<NameTrialResult> _trialResults = [];
  final List<GazeDataPoint> _gazeBuffer = [];
  StreamSubscription<GazeDataPoint>? _gazeSub;

  Timer? _phaseTimer;
  bool _waitingForResponse = false;
  int? _nameCalledAtMs;
  double _headYawAtCall = 0;

  CharacterState _charState = CharacterState.idle;
  String _statusText = 'Get ready...';

  @override
  void initState() {
    super.initState();
    widget.mediaPipeService.startTracking();
    _gazeSub = widget.mediaPipeService.gazeStream?.listen((p) {
      _gazeBuffer.add(p);
    });
    _scheduleGap(seconds: 5);
  }

  void _scheduleGap({int seconds = TaskConfig.taskBInterTrialGapSeconds}) {
    setState(() {
      _phase = _Phase.gap;
      _phaseSecondsLeft = seconds;
      _charState = CharacterState.idle;
      _statusText = _currentTrial == 0
          ? 'Get ready...'
          : 'Trial ${_currentTrial} done. Waiting...';
    });

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _phaseSecondsLeft--);
      if (_phaseSecondsLeft <= 0) {
        t.cancel();
        if (_currentTrial < TaskConfig.taskBTrials) {
          _startTrial();
        } else {
          _finish();
        }
      }
    });
  }

  void _startTrial() {
    _currentTrial++;
    setState(() {
      _phase = _Phase.nameCalling;
      _statusText = 'Trial $_currentTrial of ${TaskConfig.taskBTrials}';
      _charState = CharacterState.talking;
    });

    // Record gaze snapshot at name-call moment
    final callGaze = _gazeBuffer.isNotEmpty ? _gazeBuffer.last : null;
    _headYawAtCall = callGaze?.headYawDegrees ?? 0;
    
    // CRITICAL FIX: Use the last received gaze point's timestamp as the reference
    // instead of wall-clock time, to align with the native uptime timestamps.
    _nameCalledAtMs = callGaze?.timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    widget.ttsService.callName(widget.childName, languageCode: widget.languageCode);

    // Open response window: 3 seconds
    _waitingForResponse = true;
    _phaseTimer = Timer(
      Duration(seconds: TaskConfig.taskBResponseWindowSeconds),
      _evaluateTrial,
    );
  }

  void _evaluateTrial() {
    if (!_waitingForResponse) return;
    _waitingForResponse = false;

    final responseMap = MediaPipeService.detectNameResponse(
      gazeData: _gazeBuffer,
      nameCalledAtMs: _nameCalledAtMs!,
    );

    final responseDetected = responseMap != null;
    final responseGaze = _gazeBuffer.isNotEmpty ? _gazeBuffer.last : null;
    final latencyMs = responseDetected
        ? (responseMap['latency_ms'] as num).toDouble()
        : null;

    _trialResults.add(NameTrialResult(
      trialNumber: _currentTrial,
      nameCalledAtMs: _nameCalledAtMs!,
      responseDetected: responseDetected,
      responseLatencyMs: latencyMs,
      headYawAtCall: _headYawAtCall,
      headYawAtResponse: responseGaze?.headYawDegrees ?? _headYawAtCall,
    ));

    setState(() {
      _charState = responseDetected ? CharacterState.happy : CharacterState.idle;
      _statusText = responseDetected ? '✓ Response detected!' : 'No response';
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_currentTrial < TaskConfig.taskBTrials) {
        _scheduleGap();
      } else {
        _finish();
      }
    });
  }

  void _finish() async {
    _gazeSub?.cancel();
    await widget.mediaPipeService.stopTracking();
    final gazeData = widget.mediaPipeService.consumeBuffer();
    widget.onComplete(_trialResults, gazeData);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _gazeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trial progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(TaskConfig.taskBTrials, (i) {
                final done = i < _trialResults.length;
                final responded = done ? _trialResults[i].responseDetected : false;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? (responded ? AppColors.riskLow : AppColors.riskHigh)
                        : AppColors.divider,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),
            AnimatedCharacter(state: _charState, size: 180),
            const SizedBox(height: 24),
            Text(_statusText,
                style: const TextStyle(fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (_phase == _Phase.gap)
              Text('$_phaseSecondsLeft s',
                  style: const TextStyle(fontSize: 36, color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

enum _Phase { gap, nameCalling }
