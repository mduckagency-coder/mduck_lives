import "package:flutter/material.dart";

/// Dado 3D desenhado em codigo, nas cores da MDuck: faces roxas com pontos
/// brancos (5 na frente, 1 em cima, 2 na lateral) e um leve brilho dourado.
class DiceIcon extends StatelessWidget {
  final double size;
  const DiceIcon({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _DicePainter());
  }
}

class _DicePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final d = s * 0.22; // profundidade (deslocamento da face de cima/lateral)
    final front = Rect.fromLTWH(s * 0.06, s * 0.06 + d, s * 0.70, s * 0.70);

    // face de cima
    final top = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + d, front.top - d)
      ..lineTo(front.right + d, front.top - d)
      ..lineTo(front.right, front.top)
      ..close();
    // face lateral
    final side = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + d, front.top - d)
      ..lineTo(front.right + d, front.bottom - d)
      ..lineTo(front.right, front.bottom)
      ..close();

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE6C36A).withValues(alpha: 0.8);

    canvas.drawPath(top, Paint()..color = const Color(0xFFC06BFF));
    canvas.drawPath(side, Paint()..color = const Color(0xFF55058F));
    final frontRRect = RRect.fromRectAndRadius(front, Radius.circular(s * 0.10));
    canvas.drawRRect(
      frontRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA43BF5), Color(0xFF7A0BD4)],
        ).createShader(front),
    );
    canvas.drawPath(top, edge);
    canvas.drawPath(side, edge);
    canvas.drawRRect(frontRRect, edge);

    final pip = Paint()..color = Colors.white;
    final r = s * 0.058;
    // frente: 5
    final fx = front.left, fy = front.top, fw = front.width;
    for (final p in const [Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.5, 0.5), Offset(0.27, 0.73), Offset(0.73, 0.73)]) {
      canvas.drawCircle(Offset(fx + fw * p.dx, fy + fw * p.dy), r, pip);
    }
    // cima: 1 (centro da face, achatado)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(front.center.dx + d / 2, front.top - d / 2), width: r * 2.2, height: r * 1.1),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    // lateral: 2
    for (final t in const [0.3, 0.7]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(front.right + d * (1 - t) * 0.9 + d * 0.05, front.top - d * (1 - t) + front.height * t),
          width: r * 1.1,
          height: r * 1.9,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
