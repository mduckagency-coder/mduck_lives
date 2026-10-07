import "dart:math" as math;

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../data/ducker_level.dart";
import "mduck_diamond.dart";

const _gold = Color(0xFFFFC94D);
const _lilac = Color(0xFFC084FC);

/// Mostra "NOVO NIVEL DESBLOQUEADO" uma unica vez por nivel em cada mes,
/// so quando o nivel muda (Ducker -> Top Ducker -> Ducker Elite -> Ducker
/// Lendario). Marcos intermediarios nao passam por aqui.
Future<void> maybeCelebrateDuckerLevel(BuildContext context, double diamonds) async {
  final level = duckerLevelFor(diamonds);
  if (level == DuckerLevel.ducker) return;
  final now = DateTime.now();
  final key = "ducker_level_seen_${now.year}-${now.month.toString().padLeft(2, "0")}";
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(key) ?? 0) >= level.index) return;
  } catch (_) {
    return; // sem armazenamento local: nao arrisca repetir a celebracao
  }
  if (!context.mounted) return;
  await showDuckerLevelUp(context, level);
  await prefs.setInt(key, level.index);
}

Future<void> showDuckerLevelUp(BuildContext context, DuckerLevel level) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
    pageBuilder: (ctx, _, _) => _LevelUpCard(level: level),
  );
}

class _LevelUpCard extends StatefulWidget {
  final DuckerLevel level;
  const _LevelUpCard({required this.level});

  @override
  State<_LevelUpCard> createState() => _LevelUpCardState();
}

class _LevelUpCardState extends State<_LevelUpCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = levelEntryValue(widget.level) ?? 80000;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1786), Color(0xFF221262), Color(0xFF142050)]),
            border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.4),
            boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.25), blurRadius: 40)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("🎉 NOVO NÍVEL DESBLOQUEADO",
                textAlign: TextAlign.center,
                style: TextStyle(color: _lilac, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
            const SizedBox(height: 18),
            SizedBox(
              width: 130,
              height: 130,
              child: AnimatedBuilder(
                animation: _glow,
                builder: (_, child) => CustomPaint(painter: _RaysPainter(_glow.value), child: child),
                child: Center(child: MDuckDiamond(size: 74, tier: diamondTierForValue(entry))),
              ),
            ),
            const SizedBox(height: 16),
            Text(duckerLevelName(widget.level).toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _gold, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text("Você alcançou ${marcoLabel(entry)} diamantes.",
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF221262),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Continuar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Raios dourados girando atras do diamante.
class _RaysPainter extends CustomPainter {
  final double t;
  _RaysPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.35), Colors.transparent]).createShader(Rect.fromCircle(center: c, radius: r * 0.62)));
    final paint = Paint()..color = _gold.withValues(alpha: 0.16);
    for (var i = 0; i < 12; i++) {
      final a = t * math.pi * 2 / 6 + i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.09) * r, c.dy + math.sin(a - 0.09) * r)
        ..lineTo(c.dx + math.cos(a + 0.09) * r, c.dy + math.sin(a + 0.09) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t;
}
