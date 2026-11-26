import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Transparent water highlights in the village artwork's 941 x 1672 space.
class WaterfallMotion extends StatefulWidget {
  const WaterfallMotion({super.key, required this.enabled});
  final bool enabled;
  @override
  State<WaterfallMotion> createState() => _WaterfallMotionState();
}

class _WaterfallMotionState extends State<WaterfallMotion>
    with TickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _bird = AnimationController(
    vsync: this, duration: const Duration(seconds: 27));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) { _flow.repeat(); _bird.repeat(); }
  }

  @override
  void didUpdateWidget(covariant WaterfallMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) { _flow.repeat(); _bird.repeat(); }
      else { _flow.stop(); _bird.stop(); }
    }
  }

  @override
  void dispose() { _flow.dispose(); _bird.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: widget.enabled ? RepaintBoundary(child: CustomPaint(
      painter: _WaterPainter(_flow, _bird))) : const SizedBox.shrink());
}

class _WaterPainter extends CustomPainter {
  _WaterPainter(this.flow, this.bird) : super(repaint: Listenable.merge([flow, bird]));
  final Animation<double> flow;
  final Animation<double> bird;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 941, size.height / 1672);
    _river(canvas);
    final water = Path()..moveTo(614, 1360)
      ..quadraticBezierTo(679, 1329, 760, 1334)
      ..quadraticBezierTo(731, 1382, 720, 1506)
      ..lineTo(588, 1503)
      ..quadraticBezierTo(588, 1411, 614, 1360)..close();
    canvas.save();
    canvas.clipPath(water);
    for (var i = 0; i < 32; i++) {
      final t = (flow.value + i * .173) % 1;
      final x = 603 + (i * 37 % 147) - 15 * t;
      final y = 1325 + 200 * t;
      final alpha = math.sin(t * math.pi) * .38;
      final paint = Paint()..color = const Color(0xFFDBFFFF).withValues(alpha: alpha)
        ..strokeWidth = 1.5 + i % 3..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12 + i % 17), paint);
    }
    canvas.restore();
    for (var i = 0; i < 4; i++) {
      final t = (flow.value + i / 4) % 1;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8
        ..color = const Color(0xFFCAFFFF).withValues(alpha: (1 - t) * .32);
      canvas.drawOval(Rect.fromCenter(center: const Offset(650, 1524),
        width: 75 + 170 * t, height: 8 + 28 * t), paint);
    }
    _drawBird(canvas);
    canvas.restore();
  }

  void _river(Canvas canvas) {
    // Follow the river around the banks; highlights never cross onto land.
    final river = Path()..moveTo(70, 1198)..lineTo(129, 1200)
      ..cubicTo(100, 1255, 94, 1300, 210, 1384)
      ..cubicTo(277, 1442, 320, 1468, 523, 1494)
      ..lineTo(570, 1538)..lineTo(746, 1540)
      ..lineTo(743, 1580)..lineTo(941, 1632)..lineTo(941, 1672)
      ..lineTo(654, 1672)..lineTo(418, 1558)
      ..cubicTo(180, 1480, 184, 1420, 20, 1335)
      ..lineTo(0, 1250)..lineTo(70, 1198)..close();
    canvas.save();
    canvas.clipPath(river);
    for (var i = 0; i < 55; i++) {
      final t = (flow.value + i * .137) % 1;
      final y = 1200 + (i * 59 % 470) + 18 * t;
      final x = (i * 127 % 941).toDouble() + 12 * t;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4
        ..color = const Color(0xFFBFFBFF).withValues(alpha: math.sin(t * math.pi) * .3);
      canvas.drawPath(Path()..moveTo(x, y)
        ..quadraticBezierTo(x + 10, y - 3, x + 26, y), paint);
    }
    canvas.restore();
  }

  void _drawBird(Canvas canvas) {
    // Six seconds perched, then a three-second flight to the next tree.
    const perches = [Offset(861, 917), Offset(374, 1080), Offset(35, 1060)];
    final clock = bird.value * 27;
    final leg = (clock / 9).floor().clamp(0, 2);
    final local = clock - leg * 9;
    final flying = local >= 6;
    final t = flying ? (local - 6) / 3 : 0.0;
    final from = perches[leg];
    final to = perches[(leg + 1) % perches.length];
    final eased = Curves.easeInOut.transform(t);
    final position = flying ? Offset.lerp(from, to, eased)! -
      Offset(0, math.sin(t * math.pi) * 125) : from;
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.scale(to.dx < from.dx ? -1 : 1, 1);
    final tail = Path()..moveTo(-10, -10)..lineTo(-29, -18)
      ..lineTo(-24, -5)..lineTo(-8, -3)..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFF1D70B8));
    if (!flying) {
      final feet = Paint()..color = const Color(0xFFE8AD50)..strokeWidth = 2;
      canvas.drawLine(const Offset(-3, -3), const Offset(-5, 2), feet);
      canvas.drawLine(const Offset(5, -3), const Offset(8, 2), feet);
    }
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -12), width: 29, height: 21),
      Paint()..color = const Color(0xFF40BFE7));
    canvas.drawOval(Rect.fromCenter(center: const Offset(4, -9), width: 19, height: 12),
      Paint()..color = const Color(0xFFFFE5A3));
    final flap = flying ? math.sin(local * math.pi * 8) : 0.0;
    final wing = Path()..moveTo(-7, -14)
      ..quadraticBezierTo(-24, flying ? -26 - flap * 16 : -8,
        flying ? -11 : -13, flying ? -34 - flap * 20 : -5)
      ..quadraticBezierTo(7, -10, -7, -14);
    canvas.drawPath(wing, Paint()..color = const Color(0xFF227BCC));
    canvas.drawCircle(const Offset(11, -21), 9, Paint()..color = const Color(0xFF50CCF0));
    canvas.drawPath(Path()..moveTo(18, -22)..lineTo(27, -19)
      ..lineTo(18, -17)..close(), Paint()..color = const Color(0xFFFFCA59));
    canvas.drawCircle(const Offset(14, -23), 2.3, Paint()..color = const Color(0xFF102540));
    canvas.drawCircle(const Offset(14.7, -23.7), .8, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterPainter oldDelegate) =>
    oldDelegate.flow != flow || oldDelegate.bird != bird;
}
