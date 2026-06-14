import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
import '../constants/task_config.dart';
import '../models/session.dart';
import '../services/mediapipe_service.dart';

/// TASK A — Social Preference Test (60 s)
/// Left panel  = social content  (animated face)
/// Right panel = non-social content (geometric shapes)
/// MediaPipe records gaze throughout.
class TaskAScreen extends StatefulWidget {
  final MediaPipeService mediaPipeService;
  final void Function(List<GazeDataPoint> gaze) onComplete;

  const TaskAScreen({
    super.key,
    required this.mediaPipeService,
    required this.onComplete,
  });

  @override
  State<TaskAScreen> createState() => _TaskAScreenState();
}

class _TaskAScreenState extends State<TaskAScreen>
    with TickerProviderStateMixin {
  // Face animation
  late AnimationController _faceCtrl;
  late Animation<double> _facePulse;

  // Geometric shape rotation
  late AnimationController _geoCtrl;

  // Progress / countdown
  int _remainingSeconds = TaskConfig.taskADurationSeconds;
  Timer? _countdownTimer;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();

    _faceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _facePulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _faceCtrl, curve: Curves.easeInOut),
    );

    _geoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      _startTask();
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  void _startTask() {
    widget.mediaPipeService.startTracking();

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _finish();
      }
    });
  }

  void _finish() async {
    await widget.mediaPipeService.stopTracking();
    final gaze = widget.mediaPipeService.consumeBuffer();
    if (mounted) widget.onComplete(gaze);
  }

  @override
  void dispose() {
    _faceCtrl.dispose();
    _geoCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) return _permissionDeniedView();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── clinician HUD ─────────────────────────────────────────────
            _CliniciansHUD(
              label: 'Social Preference',
              remaining: _remainingSeconds,
              total: TaskConfig.taskADurationSeconds,
            ),

            // ── main split-screen ─────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // LEFT — social
                  Expanded(child: _SocialPanel(pulse: _facePulse)),
                  // thin divider
                  Container(width: 4, color: Colors.black),
                  // RIGHT — non-social
                  Expanded(child: _GeometricPanel(controller: _geoCtrl)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionDeniedView() => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 20),
                const Text(
                  'Camera permission is required for this task.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                    if (mounted) {
                      setState(() => _permissionDenied = false);
                      _requestPermissionAndStart();
                    }
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── Social Panel ──────────────────────────────────────────────────────────
class _SocialPanel extends StatelessWidget {
  final Animation<double> pulse;
  const _SocialPanel({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A237E),
      child: Center(
        child: ScaleTransition(
          scale: pulse,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_retouching_natural,
                    size: 90, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                '😊',
                style: TextStyle(fontSize: 48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Geometric Panel ──────────────────────────────────────────────────────
class _GeometricPanel extends StatelessWidget {
  final AnimationController controller;
  const _GeometricPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4A148C),
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => CustomPaint(
          painter: _GeometricPainter(controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GeometricPainter extends CustomPainter {
  final double t;
  _GeometricPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3;

    // Rotating squares
    for (int i = 0; i < 5; i++) {
      final angle = t * math.pi * 2 + i * math.pi / 5;
      final r = 30.0 + i * 22;
      paint.color = Colors.white.withOpacity(0.3 + i * 0.1);
      final rect = Rect.fromCenter(
          center: Offset(cx, cy), width: r * 2, height: r * 2);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.translate(-cx, -cy);
      canvas.drawRect(rect, paint);
      canvas.restore();
    }

    // Orbiting circle
    final orbitR = math.min(cx, cy) * 0.6;
    final circleX = cx + orbitR * math.cos(t * math.pi * 2);
    final circleY = cy + orbitR * math.sin(t * math.pi * 2);
    paint
      ..color = Colors.yellowAccent.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(circleX, circleY), 18, paint);
  }

  @override
  bool shouldRepaint(_GeometricPainter old) => old.t != t;
}

// ─── Clinician HUD ─────────────────────────────────────────────────────────
class _CliniciansHUD extends StatelessWidget {
  final String label;
  final int remaining;
  final int total;
  const _CliniciansHUD(
      {required this.label, required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = remaining / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.black87,
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${remaining}s',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
