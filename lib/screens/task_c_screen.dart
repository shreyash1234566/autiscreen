import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/task_config.dart';
import '../models/session.dart';
import '../services/mediapipe_service.dart';
import '../services/tts_service.dart';

/// TASK C — Imitation Test
/// Shows 3 actions (clap / wave / point). TTS announces each action.
/// MediaPipe records gaze during the 5-second imitation window.
class TaskCScreen extends StatefulWidget {
  final String languageCode;
  final MediaPipeService mediaPipeService;
  final TtsService ttsService;
  final void Function(List<GazeDataPoint> gaze) onComplete;

  const TaskCScreen({
    super.key,
    required this.languageCode,
    required this.mediaPipeService,
    required this.ttsService,
    required this.onComplete,
  });

  @override
  State<TaskCScreen> createState() => _TaskCScreenState();
}

// ─── Action descriptor ──────────────────────────────────────────────────────
class _Action {
  final String labelEn;
  final String labelHi;
  final IconData icon;
  final Color color;
  const _Action(this.labelEn, this.labelHi, this.icon, this.color);
}

const _actions = [
  _Action('Clap!',      'ताली बजाओ!',    Icons.back_hand_rounded,    Color(0xFF1565C0)),
  _Action('Wave!',      'हाथ हिलाओ!',    Icons.waving_hand_rounded,  Color(0xFF2E7D32)),
  _Action('Point up!',  'ऊपर इशारा करो!', Icons.ads_click_rounded,    Color(0xFF6A1B9A)),
];

// ─── State ───────────────────────────────────────────────────────────────────
class _TaskCScreenState extends State<TaskCScreen>
    with SingleTickerProviderStateMixin {
  int _actionIdx = 0;
  // 'demo'    = show action (2 s)
  // 'imitate' = child imitates (wait window)
  // 'done'    = all actions finished
  String _phase = 'demo';
  int _countdown = TaskConfig.taskCWaitAfterActionSeconds;

  Timer? _timer;

  bool get _isHi => widget.languageCode == 'hi';

  @override
  void initState() {
    super.initState();
    widget.mediaPipeService.startTracking();
    _runAction();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Announce action via TTS then move to imitation window
  void _runAction() async {
    if (!mounted) return;
    setState(() => _phase = 'demo');

    final a = _actions[_actionIdx];
    await widget.ttsService.speak(
      _isHi ? a.labelHi : a.labelEn,
      languageCode: widget.languageCode,
    );

    // 2-second demo pause
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _startImitateCountdown();
  }

  void _startImitateCountdown() {
    setState(() {
      _phase = 'imitate';
      _countdown = TaskConfig.taskCWaitAfterActionSeconds;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _nextOrFinish();
      }
    });
  }

  void _nextOrFinish() {
    if (_actionIdx < _actions.length - 1) {
      setState(() => _actionIdx++);
      _runAction();
    } else {
      _finish();
    }
  }

  void _finish() async {
    await widget.mediaPipeService.stopTracking();
    final gaze = widget.mediaPipeService.consumeBuffer();
    if (mounted) widget.onComplete(gaze);
  }

  @override
  Widget build(BuildContext context) {
    final a = _actions[_actionIdx];
    final label = _isHi ? a.labelHi : a.labelEn;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── progress dots ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_actions.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: i == _actionIdx ? 28 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: i <= _actionIdx
                          ? AppColors.primary
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),

            // ── main card ────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Phase label
                    Text(
                      _phase == 'demo'
                          ? (_isHi ? 'देखो और सीखो' : 'Watch carefully')
                          : (_isHi ? 'अब तुम करो!' : 'Now you do it!'),
                      style: TextStyle(
                        fontSize: 16,
                        color: _phase == 'imitate'
                            ? AppColors.riskLow
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Big animated icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(
                            _phase == 'imitate' ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                        border: _phase == 'imitate'
                            ? Border.all(color: a.color, width: 3)
                            : null,
                      ),
                      child: Icon(a.icon, size: 100, color: a.color),
                    ),
                    const SizedBox(height: 28),

                    // Action label
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: a.color,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Countdown (only during imitate phase)
                    if (_phase == 'imitate')
                      _CountdownRing(
                        value: _countdown /
                            TaskConfig.taskCWaitAfterActionSeconds,
                        label: '$_countdown',
                        color: a.color,
                      ),
                  ],
                ),
              ),
            ),

            // ── action indicator ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                '${_isHi ? "क्रिया" : "Action"} ${_actionIdx + 1} / ${_actions.length}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown ring widget ───────────────────────────────────────────────────
class _CountdownRing extends StatelessWidget {
  final double value; // 0..1
  final String label;
  final Color color;

  const _CountdownRing(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}
