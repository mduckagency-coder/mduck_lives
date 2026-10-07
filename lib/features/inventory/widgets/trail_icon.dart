import "dart:math" as math;

import "package:flutter/material.dart";
import "mduck_diamond.dart";

/// Moldura do emblema por etapa da trilha.
enum EmblemFrame { silver, crystal, gold }

EmblemFrame emblemFrameForStage(String? stage) => switch (stage) {
      "resultados" => EmblemFrame.crystal,
      "grande_marco" || "merito" => EmblemFrame.gold,
      _ => EmblemFrame.silver,
    };

/// Emblema colecionavel de um ponto da Trilha: moldura metalica facetada,
/// disco de cristal e o simbolo do marco (achievements.icon_key, editavel no
/// painel). Todos na mesma linguagem, como pecas de uma colecao.
///
/// Simbolos: portal, steps, crystal, crystals, laurel, clock, hourglass,
/// flame, diamond, crown, plaque, live, calendar (outros -> estrela).
class TrailEmblem extends StatelessWidget {
  final String? iconKey;
  final EmblemFrame frame;
  final bool locked;
  final double size;
  final DiamondTier diamondTier;

  const TrailEmblem({
    super.key,
    required this.iconKey,
    this.frame = EmblemFrame.silver,
    this.locked = false,
    this.size = 72,
    this.diamondTier = DiamondTier.normal,
  });

  @override
  Widget build(BuildContext context) {
    final medal = CustomPaint(size: Size.square(size), painter: _MedalPainter(frame: frame, locked: locked));
    final inner = size * 0.56;
    Widget symbol;
    if (iconKey == "diamond") {
      symbol = MDuckDiamond(size: inner, tier: diamondTier, animate: !locked);
    } else {
      symbol = CustomPaint(size: Size.square(inner), painter: _SymbolPainter(iconKey ?? "", locked: locked, gold: frame == EmblemFrame.gold));
    }
    if (locked && iconKey == "diamond") {
      symbol = ColorFiltered(colorFilter: _grayscale, child: Opacity(opacity: 0.7, child: symbol));
    }
    return SizedBox.square(dimension: size, child: Stack(alignment: Alignment.center, children: [medal, symbol]));
  }

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// Compatibilidade: icone simples (usado fora da trilha).
class TrailIcon extends StatelessWidget {
  final String? iconKey;
  final Color color;
  final double size;
  const TrailIcon({super.key, required this.iconKey, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SymbolPainter(iconKey ?? "", locked: false, gold: false, tint: color));
}

class _MedalPainter extends CustomPainter {
  final EmblemFrame frame;
  final bool locked;
  _MedalPainter({required this.frame, required this.locked});

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;

    final metal = locked
        ? const [Color(0xFFE6E8EE), Color(0xFF9AA0AE), Color(0xFF5E6472), Color(0xFFC9CDD6)]
        : switch (frame) {
            EmblemFrame.silver => const [Color(0xFFFFFFFF), Color(0xFFC9CEDB), Color(0xFF7D8596), Color(0xFFE9ECF3)],
            EmblemFrame.crystal => const [Color(0xFFF7EBFF), Color(0xFFC79BFF), Color(0xFF7B3FD9), Color(0xFFE9D5FF)],
            EmblemFrame.gold => const [Color(0xFFFFF6D6), Color(0xFFFFD36B), Color(0xFFB07A1E), Color(0xFFFFE9A8)],
          };

    // sombra
    canvas.drawCircle(c.translate(0, r * 0.08), r * 0.92, Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12));

    // moldura facetada (12 lados)
    final ring = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final pt = Offset(c.dx + math.cos(a) * r * 0.96, c.dy + math.sin(a) * r * 0.96);
      i == 0 ? ring.moveTo(pt.dx, pt.dy) : ring.lineTo(pt.dx, pt.dy);
    }
    ring.close();
    canvas.drawPath(ring, Paint()..shader = SweepGradient(colors: [...metal, metal.first]).createShader(Rect.fromCircle(center: c, radius: r)));
    // bisel
    canvas.drawPath(ring, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..color = Colors.white.withValues(alpha: 0.6));

    // disco de cristal
    final disc = Rect.fromCircle(center: c, radius: r * 0.76);
    canvas.drawCircle(c, r * 0.78, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(
      c,
      r * 0.76,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.0,
          colors: locked
              ? const [Color(0xFF6A6F7D), Color(0xFF3B3F4B), Color(0xFF23262E)]
              : frame == EmblemFrame.gold
                  ? const [Color(0xFF8E4BFF), Color(0xFF4A1499), Color(0xFF1E0748)]
                  : const [Color(0xFF7C5CFF), Color(0xFF3A1A8C), Color(0xFF140B3A)],
        ).createShader(disc),
    );
    // reflexo de vidro
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-r * 0.15, -r * 0.42), width: r * 1.3, height: r * 0.7),
      Paint()..color = Colors.white.withValues(alpha: locked ? 0.06 : 0.12),
    );
    canvas.restore();
    canvas.drawCircle(c, r * 0.76, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = (locked ? Colors.white24 : const Color(0xFFE9D5FF)).withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant _MedalPainter old) => old.frame != frame || old.locked != locked;
}

/// Simbolos luminosos (gradiente claro + brilho) desenhados no disco.
class _SymbolPainter extends CustomPainter {
  final String key;
  final bool locked;
  final bool gold;
  final Color? tint;
  _SymbolPainter(this.key, {required this.locked, required this.gold, this.tint});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final rect = Offset.zero & s;
    final colors = tint != null
        ? [tint!, tint!]
        : locked
            ? const [Color(0xFFB8BDC9), Color(0xFF8A90A0)]
            : gold
                ? const [Color(0xFFFFF6D6), Color(0xFFFFC94D)]
                : const [Color(0xFFFFFFFF), Color(0xFFD9B8FF)];
    final fill = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(rect);
    final stroke = Paint()
      ..shader = fill.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = (gold ? const Color(0xFFFFC94D) : const Color(0xFFC084FC)).withValues(alpha: locked || tint != null ? 0 : 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08);
    final c = Offset(w / 2, w / 2);

    void both(Path p, {bool filled = true}) {
      canvas.drawPath(p, glow);
      canvas.drawPath(p, filled ? fill : stroke);
    }

    switch (key) {
      case "_":
        return; // ponto ainda na nevoa: so o disco
      case "portal":
        // portal de luz: anel eliptico + nucleo brilhante + faisca
        canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.62, height: w * 0.86), glow);
        canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.62, height: w * 0.86), stroke);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.36, height: w * 0.56),
          Paint()
            ..shader = RadialGradient(colors: [Colors.white, (locked ? Colors.grey : const Color(0xFFB45CFF)).withValues(alpha: 0.2)])
                .createShader(Rect.fromCenter(center: c, width: w * 0.36, height: w * 0.56)),
        );
        _star(canvas, c.translate(w * 0.30, -w * 0.32), w * 0.12, fill);
      case "steps":
        // degraus subindo + estrela no topo (constancia)
        for (var i = 0; i < 3; i++) {
          final hh = w * (0.22 + i * 0.18);
          both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * (0.12 + i * 0.27), w * 0.86 - hh, w * 0.22, hh), Radius.circular(w * 0.04))));
        }
        _star(canvas, Offset(w * 0.77, w * 0.14), w * 0.12, fill);
      case "crystal":
        both(_crystalPath(c.translate(0, w * 0.05), w * 0.30, w * 0.80));
        _star(canvas, Offset(w * 0.78, w * 0.20), w * 0.09, fill);
      case "crystals":
        both(_crystalPath(c.translate(-w * 0.22, w * 0.14), w * 0.17, w * 0.50));
        both(_crystalPath(c.translate(w * 0.22, w * 0.14), w * 0.17, w * 0.50));
        both(_crystalPath(c.translate(0, w * 0.04), w * 0.23, w * 0.80));
      case "laurel":
        // louros + cristal: marco especial de consistencia
        for (final side in [-1.0, 1.0]) {
          for (var i = 0; i < 5; i++) {
            final t = i / 4;
            final ang = math.pi * (0.55 + 0.6 * t);
            final px = c.dx + side * math.cos(ang) * -w * 0.40;
            final py = c.dy + math.sin(ang) * w * 0.36;
            canvas.save();
            canvas.translate(px, py);
            canvas.rotate(side * (0.9 - t * 1.5));
            final leaf = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: w * 0.09, height: w * 0.2));
            canvas.drawPath(leaf, glow);
            canvas.drawPath(leaf, fill);
            canvas.restore();
          }
        }
        both(_crystalPath(c.translate(0, w * 0.02), w * 0.2, w * 0.56));
      case "clock":
        canvas.drawCircle(c, w * 0.38, glow);
        canvas.drawCircle(c, w * 0.38, stroke);
        canvas.drawLine(c, Offset(c.dx, w * 0.24), stroke);
        canvas.drawLine(c, Offset(w * 0.70, w * 0.60), stroke);
        canvas.drawCircle(c, w * 0.06, fill);
      case "hourglass":
        final hg = Path()
          ..moveTo(w * 0.22, w * 0.10)
          ..lineTo(w * 0.78, w * 0.10)
          ..lineTo(w * 0.52, w * 0.5)
          ..lineTo(w * 0.78, w * 0.90)
          ..lineTo(w * 0.22, w * 0.90)
          ..lineTo(w * 0.48, w * 0.5)
          ..close();
        canvas.drawPath(hg, glow);
        canvas.drawPath(hg, stroke);
        both(Path()
          ..moveTo(w * 0.32, w * 0.84)
          ..lineTo(w * 0.68, w * 0.84)
          ..lineTo(w * 0.5, w * 0.62)
          ..close());
      case "flame":
        both(Path()
          ..moveTo(w * 0.5, w * 0.04)
          ..cubicTo(w * 0.78, w * 0.32, w * 0.92, w * 0.58, w * 0.74, w * 0.82)
          ..quadraticBezierTo(w * 0.5, w * 1.0, w * 0.26, w * 0.82)
          ..cubicTo(w * 0.1, w * 0.6, w * 0.3, w * 0.44, w * 0.38, w * 0.28)
          ..quadraticBezierTo(w * 0.46, w * 0.44, w * 0.5, w * 0.04)
          ..close());
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, w * 0.48)
            ..cubicTo(w * 0.66, w * 0.62, w * 0.66, w * 0.82, w * 0.5, w * 0.86)
            ..cubicTo(w * 0.34, w * 0.82, w * 0.36, w * 0.64, w * 0.5, w * 0.48)
            ..close(),
          Paint()..color = (locked ? const Color(0xFF5E6472) : const Color(0xFF7B22D6)).withValues(alpha: 0.75),
        );
      case "crown":
        both(Path()
          ..moveTo(w * 0.12, w * 0.76)
          ..lineTo(w * 0.08, w * 0.28)
          ..lineTo(w * 0.32, w * 0.50)
          ..lineTo(w * 0.5, w * 0.16)
          ..lineTo(w * 0.68, w * 0.50)
          ..lineTo(w * 0.92, w * 0.28)
          ..lineTo(w * 0.88, w * 0.76)
          ..close());
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, w * 0.80, w * 0.76, w * 0.1), Radius.circular(w * 0.03)), fill);
        for (final x in [0.08, 0.5, 0.92]) {
          canvas.drawCircle(Offset(w * x, w * (x == 0.5 ? 0.14 : 0.26)), w * 0.06, Paint()..color = const Color(0xFFB45CFF));
        }
      case "plaque":
        final shield = Path()
          ..moveTo(w * 0.16, w * 0.12)
          ..lineTo(w * 0.84, w * 0.12)
          ..lineTo(w * 0.84, w * 0.52)
          ..quadraticBezierTo(w * 0.84, w * 0.82, w * 0.5, w * 0.94)
          ..quadraticBezierTo(w * 0.16, w * 0.82, w * 0.16, w * 0.52)
          ..close();
        canvas.drawPath(shield, glow);
        canvas.drawPath(shield, stroke);
        _star(canvas, Offset(w * 0.5, w * 0.48), w * 0.2, fill);
      case "live":
        canvas.drawCircle(c, w * 0.12, fill);
        for (final rr in [0.27, 0.42]) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: w * rr), -0.75, 1.5, false, stroke);
          canvas.drawArc(Rect.fromCircle(center: c, radius: w * rr), math.pi - 0.75, 1.5, false, stroke);
        }
      case "calendar":
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, w * 0.2, w * 0.76, w * 0.68), Radius.circular(w * 0.1)), stroke);
        canvas.drawLine(Offset(w * 0.12, w * 0.42), Offset(w * 0.88, w * 0.42), stroke);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(w * (0.32 + i * 0.18), w * 0.63), w * 0.05, fill);
        }
      default:
        _star(canvas, c, w * 0.40, fill);
    }
  }

  Path _crystalPath(Offset c, double halfW, double hgt) => Path()
    ..moveTo(c.dx, c.dy - hgt / 2)
    ..lineTo(c.dx + halfW, c.dy - hgt * 0.18)
    ..lineTo(c.dx + halfW * 0.7, c.dy + hgt / 2)
    ..lineTo(c.dx - halfW * 0.7, c.dy + hgt / 2)
    ..lineTo(c.dx - halfW, c.dy - hgt * 0.18)
    ..close();

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.3;
      final a = i * math.pi / 4 - math.pi / 2;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) => old.key != key || old.locked != locked || old.gold != gold || old.tint != tint;
}

/// Simbolo do marco sozinho (sem moldura), pra usar em outros suportes
/// (ex.: a esfera 3D da trilha).
class TrailSymbol extends StatelessWidget {
  final String? iconKey;
  final bool locked;
  final bool gold;
  final double size;
  const TrailSymbol({super.key, required this.iconKey, this.locked = false, this.gold = false, this.size = 34});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SymbolPainter(iconKey ?? "", locked: locked, gold: gold));
}
