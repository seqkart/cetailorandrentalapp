import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme_colors.dart';

/// Paints the brand ring: a running-stitch circle with a gap on the right,
/// so it reads as a "C". Used by both the splash and the loader.
///
/// * [progress]      0..1 – how much of the ring has been "sewn".
/// * [needleOpacity] 0..1 – the needle that travels with the stitching head.
/// * [highlight]     null, or 0..1 – position of a travelling glow (loader).
class StitchRingPainter extends CustomPainter {
  const StitchRingPainter({
    this.progress = 1.0,
    this.needleOpacity = 0.0,
    this.highlight,
    this.colors = kThreadColors,
  });

  final double progress;
  final double needleOpacity;
  final double? highlight;
  final List<Color> colors;

  static const double _startDeg = 40, _endDeg = 320;
  static const double _dash = 15 / 110, _gap = 10 / 110; // radians @ R=110

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.40;
    final stroke = radius * 0.06;

    final startRad = _startDeg * math.pi / 180;
    final endRad = _endDeg * math.pi / 180;
    final span = endRad - startRad;
    const step = _dash + _gap;
    final count = ((span + _gap) / step).floor();
    final head = startRad + span * progress.clamp(0.0, 1.0).toDouble();
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    for (var i = 0; i < count; i++) {
      final s = startRad + i * step;
      if (s >= head) break;
      final e = math.min(s + _dash, head);
      var color = colors[i % colors.length];
      if (highlight != null) {
        final pos = highlight! * count;
        var d = (i - pos).abs();
        d = math.min(d, count - d);
        final k = (1 - d / 4.5).clamp(0.0, 1.0).toDouble();
        color = color.withAlpha((255 * (0.28 + 0.72 * k)).round());
      }
      paint.color = color;
      // Canvas angles run clockwise; ours run counter-clockwise, so negate.
      canvas.drawArc(rect, -e, e - s, false, paint);
    }

    if (needleOpacity > 0) {
      final a = (255 * needleOpacity.clamp(0.0, 1.0)).round();
      final pos = center + Offset(math.cos(head), -math.sin(head)) * radius;
      final dir = Offset(-math.sin(head), -math.cos(head));
      final tip = pos + dir * (radius * 0.15);
      final tail = pos - dir * (radius * 0.47);

      // faint trailing thread
      final threadStart = math.max(startRad, head - 0.38);
      canvas.drawArc(
        rect, -head, head - threadStart, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 0.3
          ..color = kGold.withAlpha((a * 0.6).round()),
      );

      canvas.drawLine(
        tail, tip,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 0.6
          ..color = kIvory.withAlpha(a),
      );
      canvas.drawCircle(
        tail + dir * (radius * 0.06), stroke * 0.45,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.25
          ..color = kSplashBg.withAlpha(a),
      );
    }
  }

  @override
  bool shouldRepaint(StitchRingPainter old) =>
      old.progress != progress ||
      old.needleOpacity != needleOpacity ||
      old.highlight != highlight;
}
