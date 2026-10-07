import "dart:math" as math;

import "package:flutter/material.dart";

/// Pergaminho/mapa antigo desenhado em codigo (sem imagem): folha de papel
/// envelhecido entre dois rolos, uma trilha pontilhada de mapa terminando num
/// "X" e o selo de cera roxo da MDuck.
class ParchmentIcon extends StatelessWidget {
  final double size;
  const ParchmentIcon({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ParchmentPainter());
  }
}

class _ParchmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // leve inclinacao, como um pergaminho largado na areia
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.12);
    canvas.translate(-w / 2, -h / 2);

    // ---- folha ----
    final sheet = Path()
      ..moveTo(w * 0.20, h * 0.20)
      ..lineTo(w * 0.80, h * 0.20)
      // borda direita levemente ondulada
      ..quadraticBezierTo(w * 0.84, h * 0.50, w * 0.80, h * 0.80)
      ..lineTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.16, h * 0.50, w * 0.20, h * 0.20)
      ..close();
    canvas.drawShadow(sheet, Colors.black, 2, false);
    canvas.drawPath(
      sheet,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF0D2), Color(0xFFE9CF95), Color(0xFFD9B672)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      sheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..color = const Color(0xFF9C7238),
    );

    // ---- trilha de mapa pontilhada + X ----
    final trail = Path()
      ..moveTo(w * 0.30, h * 0.66)
      ..quadraticBezierTo(w * 0.34, h * 0.42, w * 0.48, h * 0.50)
      ..quadraticBezierTo(w * 0.60, h * 0.57, w * 0.62, h * 0.36);
    final dash = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in trail.computeMetrics()) {
      for (double d = 0; d < metric.length; d += w * 0.09) {
        canvas.drawPath(metric.extractPath(d, math.min(d + w * 0.04, metric.length)), dash);
      }
    }
    final x = Paint()
      ..color = const Color(0xFFC0392B)
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    final cx = w * 0.64, cy = h * 0.33, r = w * 0.055;
    canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), x);
    canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), x);

    // ---- rolos (em cima e embaixo) ----
    void roll(double top) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, top, w * 0.76, h * 0.12),
        Radius.circular(h * 0.06),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE2BE7C), Color(0xFFB5843F), Color(0xFF7E5524)],
          ).createShader(rect.outerRect),
      );
      // pontas de madeira
      final knob = Paint()..color = const Color(0xFF5A3A1A);
      canvas.drawCircle(Offset(w * 0.12, top + h * 0.06), h * 0.055, knob);
      canvas.drawCircle(Offset(w * 0.88, top + h * 0.06), h * 0.055, knob);
    }

    roll(h * 0.14);
    roll(h * 0.74);

    // ---- selo de cera MDuck ----
    final sealCenter = Offset(w * 0.70, h * 0.66);
    final sealR = w * 0.12;
    canvas.drawCircle(sealCenter, sealR, Paint()..color = const Color(0xFF5B0699));
    canvas.drawCircle(
      sealCenter,
      sealR * 0.72,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)])
            .createShader(Rect.fromCircle(center: sealCenter, radius: sealR)),
    );
    final m = TextPainter(
      text: TextSpan(
        text: "M",
        style: TextStyle(color: const Color(0xFFF3E3FF), fontSize: sealR * 1.0, fontWeight: FontWeight.w900, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    m.paint(canvas, sealCenter - Offset(m.width / 2, m.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
