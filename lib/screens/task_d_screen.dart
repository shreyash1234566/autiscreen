import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/task_config.dart';
import '../models/session.dart';

/// TASK D — Bubble Popping (90 s)
/// 10 bubbles float around the screen. Child touches them.
/// All touches recorded as BubbleTouchEvent (hitBubble true/false).
class TaskDScreen extends StatefulWidget {
  final void Function(List<BubbleTouchEvent> events) onComplete;

  const TaskDScreen({super.key, required this.onComplete});

  @override
  State<TaskDScreen> createState() => _TaskDScreenState();
}

class _Bubble {
  final String id;
  double x; // 0..1 (relative to screen)
  double y;
  final double radius; // logical px
  final Color color;
  double dx; // velocity per tick
  double dy;
  bool popped = false;
  double popScale = 1.0;

  _Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.dx,
    required this.dy,
  });
}

class _TaskDScreenState extends State<TaskDScreen> {
  final _rng = math.Random();
  final List<_Bubble> _bubbles = [];
  final List<BubbleTouchEvent> _events = [];

  int _remaining = TaskConfig.taskDDurationSeconds;
  Timer? _countdown;
  Timer? _physics;

  static const _tickMs = 40; // ~25 fps physics
  static const _bubbleColors = [
    Color(0xFF64B5F6), Color(0xFF81C784), Color(0xFFFFD54F),
    Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF4DD0E1),
    Color(0xFFF06292), Color(0xFFA5D6A7), Color(0xFFFFCC02),
    Color(0xFF80CBC4),
  ];

  @override
  void initState() {
    super.initState();
    _spawnBubbles();
    _startCountdown();
    _startPhysics();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _physics?.cancel();
    super.dispose();
  }

  void _spawnBubbles() {
    for (int i = 0; i < TaskConfig.taskDBubbleCount; i++) {
      _bubbles.add(_makeBubble(i.toString()));
    }
  }

  _Bubble _makeBubble(String id) {
    final r = 28.0 + _rng.nextDouble() * 24;
    final speed = 0.003 + _rng.nextDouble() * 0.003;
    final angle = _rng.nextDouble() * math.pi * 2;
    return _Bubble(
      id: id,
      x: 0.1 + _rng.nextDouble() * 0.8,
      y: 0.1 + _rng.nextDouble() * 0.8,
      radius: r,
      color: _bubbleColors[_rng.nextInt(_bubbleColors.length)],
      dx: math.cos(angle) * speed,
      dy: math.sin(angle) * speed,
    );
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _physics?.cancel();
        widget.onComplete(List.from(_events));
      }
    });
  }

  void _startPhysics() {
    _physics = Timer.periodic(Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() {
        for (final b in _bubbles) {
          if (b.popped) continue;
          b.x += b.dx;
          b.y += b.dy;
          // Bounce off edges
          if (b.x < 0.05 || b.x > 0.95) b.dx = -b.dx;
          if (b.y < 0.08 || b.y > 0.92) b.dy = -b.dy;
          b.x = b.x.clamp(0.05, 0.95);
          b.y = b.y.clamp(0.08, 0.92);
        }
      });
    });
  }

  void _onTap(TapDownDetails details, Size screenSize) {
    final tx = details.localPosition.dx / screenSize.width;
    final ty = details.localPosition.dy / screenSize.height;
    bool hit = false;

    for (final b in _bubbles) {
      if (b.popped) continue;
      final bx = b.x * screenSize.width;
      final by = b.y * screenSize.height;
      final dist = math.sqrt(
        math.pow(details.localPosition.dx - bx, 2) +
        math.pow(details.localPosition.dy - by, 2),
      );
      if (dist <= b.radius) {
        hit = true;
        b.popped = true;
        // Respawn after 500 ms
        final id = b.id;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          final idx = _bubbles.indexWhere((e) => e.id == id);
          if (idx != -1) {
            setState(() {
              _bubbles[idx] = _makeBubble(id);
            });
          }
        });
        break;
      }
    }

    _events.add(BubbleTouchEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      screenX: tx,
      screenY: ty,
      hitBubble: hit,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final size =
                Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onTapDown: (d) => _onTap(d, size),
              child: Stack(
                children: [
                  // Starfield background
                  const _Starfield(),

                  // HUD
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: _HUD(
                      remaining: _remaining,
                      total: TaskConfig.taskDDurationSeconds,
                      pops: _events.where((e) => e.hitBubble).length,
                    ),
                  ),

                  // Bubbles
                  ..._bubbles.map((b) {
                    if (b.popped) return const SizedBox.shrink();
                    return Positioned(
                      left: b.x * size.width - b.radius,
                      top: b.y * size.height - b.radius,
                      child: _BubbleWidget(bubble: b),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Bubble widget ────────────────────────────────────────────────────────────
class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;
  const _BubbleWidget({super.key, required this.bubble});

  @override
  Widget build(BuildContext context) {
    final d = bubble.radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _BubblePainter(bubble.color),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  const _BubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    // Outer glow
    final glow = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, r * 1.2, glow);

    // Bubble body (radial gradient)
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Colors.white.withOpacity(0.55), color.withOpacity(0.75)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, body);

    // Rim
    final rim = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r - 1, rim);

    // Highlight
    final hi = Paint()..color = Colors.white.withOpacity(0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.65, r * 0.45), width: r * 0.4, height: r * 0.25),
      hi,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}

// ─── Starfield background ─────────────────────────────────────────────────────
class _Starfield extends StatelessWidget {
  const _Starfield();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _StarPainter extends CustomPainter {
  static final _rng = math.Random(42);
  static final _stars = List.generate(
    60,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.5);
    for (final s in _stars) {
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 1.5, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}

// ─── HUD ──────────────────────────────────────────────────────────────────────
class _HUD extends StatelessWidget {
  final int remaining;
  final int total;
  final int pops;
  const _HUD({required this.remaining, required this.total, required this.pops});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bubble_chart_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Text('$pops',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: remaining / total,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${remaining}s',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
