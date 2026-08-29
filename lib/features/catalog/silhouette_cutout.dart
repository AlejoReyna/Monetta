/// Drawn bag/watch silhouettes for the Formas rail and PLP sibling rail.
/// Monochrome cutouts, not product photos — they have to read at ~32px.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum SilhouetteCutoutKind { tote, crossbody, shoulder, cartera, reloj }

class SilhouetteCutout extends StatelessWidget {
  const SilhouetteCutout({
    required this.kind,
    this.size = 36,
    this.color = kInk,
    super.key,
  });

  final SilhouetteCutoutKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SilhouettePainter(kind: kind, color: color),
    );
  }
}

SilhouetteCutoutKind? silhouetteCutoutFor(String slug) {
  return switch (slug) {
    'tote' => SilhouetteCutoutKind.tote,
    'crossbody' => SilhouetteCutoutKind.crossbody,
    'shoulder' => SilhouetteCutoutKind.shoulder,
    'satchel' => SilhouetteCutoutKind.tote,
    'hobo' => SilhouetteCutoutKind.shoulder,
    'clutch' => SilhouetteCutoutKind.cartera,
    _ => null,
  };
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({required this.kind, required this.color});

  final SilhouetteCutoutKind kind;
  final Color color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _stroke;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case SilhouetteCutoutKind.tote:
        final body = Path()
          ..moveTo(w * 0.22, h * 0.32)
          ..lineTo(w * 0.16, h * 0.88)
          ..lineTo(w * 0.84, h * 0.88)
          ..lineTo(w * 0.78, h * 0.32)
          ..close();
        canvas.drawPath(body, p);
        canvas.drawArc(
          Rect.fromLTWH(w * 0.28, h * 0.12, w * 0.44, h * 0.36),
          3.14,
          3.14,
          false,
          p,
        );
      case SilhouetteCutoutKind.crossbody:
        final body = Path()
          ..moveTo(w * 0.28, h * 0.42)
          ..lineTo(w * 0.24, h * 0.86)
          ..lineTo(w * 0.76, h * 0.86)
          ..lineTo(w * 0.72, h * 0.42)
          ..close();
        canvas.drawPath(body, p);
        canvas.drawArc(
          Rect.fromLTWH(w * 0.34, h * 0.28, w * 0.32, h * 0.28),
          3.14,
          3.14,
          false,
          p,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.72),
          3.55,
          2.3,
          false,
          p,
        );
      case SilhouetteCutoutKind.shoulder:
        final body = Path()
          ..moveTo(w * 0.18, h * 0.46)
          ..quadraticBezierTo(w * 0.18, h * 0.88, w * 0.50, h * 0.88)
          ..quadraticBezierTo(w * 0.82, h * 0.88, w * 0.82, h * 0.46)
          ..close();
        canvas.drawPath(body, p);
        canvas.drawArc(
          Rect.fromLTWH(w * 0.22, h * 0.14, w * 0.56, h * 0.48),
          3.25,
          2.85,
          false,
          p,
        );
      case SilhouetteCutoutKind.cartera:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.32, w * 0.76, h * 0.46),
            Radius.circular(w * 0.04),
          ),
          p,
        );
        canvas.drawLine(
          Offset(w * 0.12, h * 0.48),
          Offset(w * 0.88, h * 0.48),
          p,
        );
      case SilhouetteCutoutKind.reloj:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.22, p);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.38, h * 0.08, w * 0.24, h * 0.20),
            Radius.circular(w * 0.04),
          ),
          p,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.38, h * 0.72, w * 0.24, h * 0.20),
            Radius.circular(w * 0.04),
          ),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
