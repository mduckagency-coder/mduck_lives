import "dart:math" as math;

import "package:flutter/material.dart";
import "../data/journey_repository.dart";

/// Chama da Constancia (animada, leve). Muda com o estado calculado no banco:
///   forte     -> chama grande roxa/laranja, viva
///   evolucao  -> chama media com faiscas subindo
///   estavel   -> chama media
///   retomando -> broto verde com uma chaminha nascendo
///   alerta    -> chama pequena e apagada
class ConstancyFlame extends StatefulWidget {
  final String state;
  final double intensity;
  final double size;
  const ConstancyFlame({super.key, required this.state, this.intensity = 0.5, this.size = 44});

  @override
  State<ConstancyFlame> createState() => _ConstancyFlameState();
}

class _ConstancyFlameState extends State<ConstancyFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: _FlamePainter(widget.state, widget.intensity, _c.value)),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final String state;
  final double intensity;
  final double t;
  _FlamePainter(this.state, this.intensity, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final flicker = math.sin(t * math.pi * 2) * 0.05 + math.sin(t * math.pi * 6) * 0.025;

    if (state == "retomando") {
      _sprout(canvas, w);
      _flame(canvas, Offset(w * 0.5, w * 0.52), w * 0.32 * (1 + flicker), const [Color(0xFFFFF3C4), Color(0xFFFFB347), Color(0xFFB45CFF)], 0.9);
      return;
    }

    final (scale, colors, alpha) = switch (state) {
      "forte" => (0.5 + 0.5 * intensity.clamp(0.6, 1), const [Color(0xFFFFFBE6), Color(0xFFFFB347), Color(0xFFFF5FA2), Color(0xFF9B5CFF)], 1.0),
      "evolucao" => (0.82, const [Color(0xFFFFF6D6), Color(0xFFFFA94D), Color(0xFFFF6FB5), Color(0xFF9B5CFF)], 1.0),
      "alerta" => (0.55, const [Color(0xFFF1E7DA), Color(0xFFC9A27E), Color(0xFF8E7C9C), Color(0xFF5E5A70)], 0.75),
      _ => (0.72, const [Color(0xFFFFF6D6), Color(0xFFFFB347), Color(0xFFE05CB8), Color(0xFF7A2BE2)], 1.0),
    };

    // brilho
    canvas.drawCircle(Offset(w * 0.5, w * 0.62), w * 0.42 * scale, Paint()
      ..color = colors[2].withValues(alpha: state == "alerta" ? 0.15 : 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.16));
    _flame(canvas, Offset(w * 0.5, w * 0.9), w * 0.82 * scale * (1 + flicker), colors, alpha);

    // faiscas (evolucao/forte)
    if (state == "evolucao" || state == "forte") {
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3) % 1.0;
        final x = w * (0.32 + i * 0.18) + math.sin((p + i) * 6) * w * 0.05;
        final y = w * (0.45 - p * 0.42);
        canvas.drawCircle(Offset(x, y), w * 0.035 * (1 - p), Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 1 - p));
      }
    }
  }

  /// Chama em gota: camadas do roxo (fora) ao branco (nucleo).
  void _flame(Canvas canvas, Offset base, double h, List<Color> colors, double alpha) {
    final layers = [(1.0, colors.length > 3 ? colors[3] : colors[2]), (0.78, colors[2]), (0.56, colors[1]), (0.32, colors[0])];
    for (final l in layers) {
      final hh = h * l.$1;
      final ww = hh * 0.62;
      final tip = base.translate(math.sin(t * math.pi * 2) * ww * 0.06, -hh);
      final p = Path()
        ..moveTo(base.dx, base.dy)
        ..cubicTo(base.dx - ww * 0.75, base.dy - hh * 0.05, base.dx - ww * 0.55, base.dy - hh * 0.6, tip.dx, tip.dy)
        ..cubicTo(base.dx + ww * 0.55, base.dy - hh * 0.6, base.dx + ww * 0.75, base.dy - hh * 0.05, base.dx, base.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = l.$2.withValues(alpha: alpha));
    }
  }

  void _sprout(Canvas canvas, double w) {
    final stem = Paint()
      ..color = const Color(0xFF3FA65E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, w * 0.95), Offset(w * 0.5, w * 0.58), stem);
    for (final side in [-1.0, 1.0]) {
      final leaf = Path()
        ..moveTo(w * 0.5, w * 0.78)
        ..quadraticBezierTo(w * (0.5 + side * 0.36), w * 0.62, w * (0.5 + side * 0.4), w * 0.78)
        ..quadraticBezierTo(w * (0.5 + side * 0.2), w * 0.86, w * 0.5, w * 0.78)
        ..close();
      canvas.drawPath(leaf, Paint()..shader = const LinearGradient(colors: [Color(0xFF9BE36A), Color(0xFF2E8B57)]).createShader(leaf.getBounds()));
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) => old.t != t || old.state != state || old.intensity != intensity;
}

/// Chip discreto da Constancia: chama + estado + frase curta.
class ConstancyChip extends StatelessWidget {
  final Constancy constancy;
  final bool dark;
  const ConstancyChip({super.key, required this.constancy, this.dark = true});

  @override
  Widget build(BuildContext context) {
    final c = constancy;
    final accent = switch (c.state) {
      "forte" => const Color(0xFFFF8FC8),
      "evolucao" => const Color(0xFFFFB86B),
      "retomando" => const Color(0xFF8FE08A),
      "alerta" => const Color(0xFFB9B1C9),
      _ => const Color(0xFFC084FC),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        ConstancyFlame(state: c.state, intensity: c.intensity, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text("CONSTÂNCIA  ", style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
              Flexible(child: Text(c.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 2),
            Text(c.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}
