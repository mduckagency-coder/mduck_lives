import "package:flutter/material.dart";

/// Icone do Inventario no menu inferior: um emblema/brasao da MDUCK com
/// fitas e a estrela ✦ (o mesmo simbolo da aba Conquistas). Desenhado em
/// codigo pra seguir a cor do menu (selecionado/nao selecionado), sem trofeu
/// (que ja e do Ranking) e sem mochila generica.
class InventoryEmblemIcon extends StatelessWidget {
  final Color color;
  final double size;
  const InventoryEmblemIcon({super.key, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _EmblemPainter(color));
}

class _EmblemPainter extends CustomPainter {
  final Color color;
  _EmblemPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..color = color;
    final cut = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());

    // fitas embaixo
    final ribbonL = Path()
      ..moveTo(s * 0.30, s * 0.62)
      ..lineTo(s * 0.18, s * 0.98)
      ..lineTo(s * 0.31, s * 0.90)
      ..lineTo(s * 0.40, s * 1.00)
      ..lineTo(s * 0.46, s * 0.70)
      ..close();
    final ribbonR = Path()
      ..moveTo(s * 0.70, s * 0.62)
      ..lineTo(s * 0.82, s * 0.98)
      ..lineTo(s * 0.69, s * 0.90)
      ..lineTo(s * 0.60, s * 1.00)
      ..lineTo(s * 0.54, s * 0.70)
      ..close();
    canvas.drawPath(ribbonL, fill);
    canvas.drawPath(ribbonR, fill);

    // medalhao (circulo com borda recortada)
    final c = Offset(s * 0.5, s * 0.40);
    canvas.drawCircle(c, s * 0.38, fill);
    canvas.drawCircle(c, s * 0.29, cut);
    canvas.drawCircle(c, s * 0.25, fill);

    // estrela ✦ recortada no centro
    final r = s * 0.17;
    final star = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.18, c.dy - r * 0.18, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.18, c.dy + r * 0.18, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.18, c.dy + r * 0.18, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.18, c.dy - r * 0.18, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(star, cut);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.color != color;
}
