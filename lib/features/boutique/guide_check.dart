/// Gold success mark from the purchase screen of the client guide.
///
/// Drawn in Flutter. The reference PNG is not shipped.
library;

import 'package:flutter/material.dart';

/// Caramel stroke from the guide reference (`#A8763E`).
const Color kGuideCheckColor = Color(0xFFA8763E);

class GuideSuccessMark extends StatelessWidget {
  const GuideSuccessMark({this.size = 88, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GuideCheckPainter(),
    );
  }
}

class _GuideCheckPainter extends CustomPainter {
  const _GuideCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = kGuideCheckColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inset = size.width * 0.08;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - inset, stroke);
    final check = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.70, size.height * 0.36);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
