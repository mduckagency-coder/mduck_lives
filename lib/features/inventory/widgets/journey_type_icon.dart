import "dart:math" as math;

import "package:flutter/material.dart";

/// Icone premium de um tipo da Jornada MDUCK (substitui os emojis):
/// ficha de cristal na cor do tipo com o simbolo em luz.
/// presente, treinamento, recompensa (Premiacao), pix, campanha, suporte,
/// evento, outros (+ legados conquista/reconhecimento).
class JourneyTypeIcon extends StatelessWidget {
  final String category;
  final Color color;
  final double size;
  const JourneyTypeIcon({super.key, required this.category, required this.color, this.size = 52});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _TypeIconPainter(category, color));
}

class _TypeIconPainter extends CustomPainter {
  final String category;
  final Color color;
  _TypeIconPainter(this.category, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect.deflate(w * 0.02), Radius.circular(w * 0.3));
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness((hsl.lightness + 0.18).clamp(0, 0.92)).toColor();
    final dark = hsl.withLightness((hsl.lightness - 0.32).clamp(0.08, 1)).toColor();

    // ficha de vidro
    canvas.drawRRect(rr.shift(Offset(0, w * 0.04)), Paint()
      ..color = dark.withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08));
    canvas.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, color, dark]).createShader(rect));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawOval(Rect.fromLTWH(-w * 0.2, -w * 0.45, w * 1.1, w * 0.8), Paint()..color = Colors.white.withValues(alpha: 0.22));
    canvas.restore();
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = Colors.white.withValues(alpha: 0.55));

    // simbolo
    final box = Rect.fromCenter(center: Offset(w / 2, w / 2), width: w * 0.58, height: w * 0.58);
    canvas.save();
    canvas.translate(box.left, box.top);
    _symbol(canvas, box.width);
    canvas.restore();
  }

  void _symbol(Canvas canvas, double u) {
    final fill = Paint()..color = Colors.white;
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(u * x, u * y);

    switch (category) {
      case "presente":
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.1, u * 0.42, u * 0.8, u * 0.52), Radius.circular(u * 0.06)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.04, u * 0.28, u * 0.92, u * 0.18), Radius.circular(u * 0.05)), fill);
        canvas.drawRect(Rect.fromLTWH(u * 0.44, u * 0.28, u * 0.12, u * 0.66), Paint()..color = color);
        canvas.drawOval(Rect.fromCenter(center: p(0.34, 0.18), width: u * 0.3, height: u * 0.2), stroke);
        canvas.drawOval(Rect.fromCenter(center: p(0.66, 0.18), width: u * 0.3, height: u * 0.2), stroke);
      case "treinamento":
        canvas.drawPath(Path()..moveTo(u * 0.5, u * 0.12)..lineTo(u * 1.0, u * 0.36)..lineTo(u * 0.5, u * 0.6)..lineTo(u * 0.0, u * 0.36)..close(), fill);
        canvas.drawPath(Path()..moveTo(u * 0.22, u * 0.48)..lineTo(u * 0.22, u * 0.74)..quadraticBezierTo(u * 0.5, u * 0.92, u * 0.78, u * 0.74)..lineTo(u * 0.78, u * 0.48)..lineTo(u * 0.5, u * 0.62)..close(), soft);
        canvas.drawLine(p(0.9, 0.4), p(0.9, 0.74), stroke);
        canvas.drawCircle(p(0.9, 0.8), u * 0.06, fill);
      case "recompensa":
        canvas.drawPath(Path()..moveTo(u * 0.28, u * 0.0)..lineTo(u * 0.42, u * 0.0)..lineTo(u * 0.56, u * 0.4)..lineTo(u * 0.42, u * 0.46)..close(), soft);
        canvas.drawPath(Path()..moveTo(u * 0.72, u * 0.0)..lineTo(u * 0.58, u * 0.0)..lineTo(u * 0.44, u * 0.4)..lineTo(u * 0.58, u * 0.46)..close(), soft);
        canvas.drawCircle(p(0.5, 0.66), u * 0.3, fill);
        _star(canvas, p(0.5, 0.66), u * 0.16, Paint()..color = color);
      case "pix":
        // moedas empilhadas + brilho (dinheiro recebido)
        for (var i = 0; i < 3; i++) {
          final y = u * (0.78 - i * 0.16);
          canvas.drawOval(Rect.fromCenter(center: Offset(u * 0.42, y), width: u * 0.66, height: u * 0.22), i == 2 ? fill : soft);
        }
        canvas.drawCircle(p(0.74, 0.34), u * 0.22, fill);
        final tp = TextPainter(
          text: TextSpan(text: "R\$", style: TextStyle(color: color, fontSize: u * 0.2, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p(0.74, 0.34) - Offset(tp.width / 2, tp.height / 2));
      case "campanha":
        canvas.drawCircle(p(0.46, 0.54), u * 0.4, stroke);
        canvas.drawCircle(p(0.46, 0.54), u * 0.22, stroke);
        canvas.drawCircle(p(0.46, 0.54), u * 0.07, fill);
        canvas.drawLine(p(0.46, 0.54), p(0.92, 0.08), stroke);
        canvas.drawPath(Path()..moveTo(u * 0.92, u * 0.08)..lineTo(u * 0.98, u * 0.26)..lineTo(u * 0.78, u * 0.12)..close(), fill);
      case "suporte":
        canvas.drawArc(Rect.fromLTWH(u * 0.1, u * 0.08, u * 0.8, u * 0.8), math.pi, math.pi, false, stroke);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.04, u * 0.44, u * 0.2, u * 0.32), Radius.circular(u * 0.08)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.76, u * 0.44, u * 0.2, u * 0.32), Radius.circular(u * 0.08)), fill);
        canvas.drawPath(Path()..moveTo(u * 0.86, u * 0.76)..quadraticBezierTo(u * 0.86, u * 0.96, u * 0.56, u * 0.96), stroke);
        canvas.drawCircle(p(0.52, 0.96), u * 0.07, fill);
      case "evento":
        final ticket = Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.02, u * 0.22, u * 0.96, u * 0.56), Radius.circular(u * 0.08)));
        final holes = Path()
          ..addOval(Rect.fromCircle(center: p(0.02, 0.5), radius: u * 0.1))
          ..addOval(Rect.fromCircle(center: p(0.98, 0.5), radius: u * 0.1));
        canvas.drawPath(Path.combine(PathOperation.difference, ticket, holes), fill);
        _star(canvas, p(0.5, 0.5), u * 0.17, Paint()..color = color);
      case "conquista":
        canvas.drawPath(Path()..moveTo(u * 0.2, u * 0.08)..lineTo(u * 0.8, u * 0.08)..quadraticBezierTo(u * 0.8, u * 0.62, u * 0.5, u * 0.64)..quadraticBezierTo(u * 0.2, u * 0.62, u * 0.2, u * 0.08)..close(), fill);
        canvas.drawRect(Rect.fromLTWH(u * 0.44, u * 0.62, u * 0.12, u * 0.18), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.26, u * 0.8, u * 0.48, u * 0.12), Radius.circular(u * 0.03)), fill);
      case "reconhecimento":
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          canvas.drawCircle(p(0.5 + math.cos(a) * 0.3, 0.42 + math.sin(a) * 0.3), u * 0.13, soft);
        }
        canvas.drawCircle(p(0.5, 0.42), u * 0.28, fill);
        _star(canvas, p(0.5, 0.42), u * 0.14, Paint()..color = color);
      case "evolucao":
        // barras crescendo + seta pra cima
        for (var i = 0; i < 3; i++) {
          final h = 0.28 + i * 0.22;
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(u * (0.06 + i * 0.3), u * (0.96 - h), u * 0.22, u * h), Radius.circular(u * 0.04)),
              i == 2 ? fill : soft);
        }
        canvas.drawLine(p(0.1, 0.5), p(0.72, 0.1), stroke);
        canvas.drawPath(Path()..moveTo(u * 0.82, u * 0.02)..lineTo(u * 0.78, u * 0.24)..lineTo(u * 0.6, u * 0.08)..close(), fill);
      case "objetivo":
        // bandeira fincada
        canvas.drawLine(p(0.22, 0.06), p(0.22, 0.96), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(u * 0.26, u * 0.08)
              ..quadraticBezierTo(u * 0.55, u * 0.0, u * 0.9, u * 0.12)
              ..lineTo(u * 0.9, u * 0.5)
              ..quadraticBezierTo(u * 0.55, u * 0.38, u * 0.26, u * 0.48)
              ..close(),
            fill);
        _star(canvas, p(0.58, 0.27), u * 0.1, Paint()..color = color);
        canvas.drawOval(Rect.fromCenter(center: p(0.3, 0.95), width: u * 0.5, height: u * 0.1), soft);
      default:
        // outros: caixa com brilho
        canvas.drawPath(Path()..moveTo(u * 0.5, u * 0.08)..lineTo(u * 0.94, u * 0.3)..lineTo(u * 0.5, u * 0.52)..lineTo(u * 0.06, u * 0.3)..close(), fill);
        canvas.drawPath(Path()..moveTo(u * 0.06, u * 0.34)..lineTo(u * 0.48, u * 0.56)..lineTo(u * 0.48, u * 0.98)..lineTo(u * 0.06, u * 0.76)..close(), soft);
        canvas.drawPath(Path()..moveTo(u * 0.94, u * 0.34)..lineTo(u * 0.52, u * 0.56)..lineTo(u * 0.52, u * 0.98)..lineTo(u * 0.94, u * 0.76)..close(), fill);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = i * math.pi / 5 - math.pi / 2;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _TypeIconPainter old) => old.category != category || old.color != color;
}
