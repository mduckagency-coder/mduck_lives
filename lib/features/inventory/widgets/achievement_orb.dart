import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "../data/achievements_repository.dart";
import "mduck_diamond.dart";
import "trail_icon.dart";

const _lilac = Color(0xFFC084FC);

/// Simbolo de uma conquista (icon_key do painel). Sem icone definido, deriva
/// da regra: diamantes -> diamante; horas -> relogio; dias -> calendario;
/// historico -> coroa; consistencia -> louros.
String achievementSymbolKey(Achievement a) {
  if (a.iconKey != null && a.iconKey!.isNotEmpty) return a.iconKey!;
  return switch (a.ruleType) {
    "month_diamonds" => "diamond",
    "total_diamonds" => "crown",
    "consecutive_months_diamonds" => "laurel",
    "month_hours" || "total_hours" => "clock",
    "month_days" => "calendar",
    "month_combo" => "crown",
    _ => "star",
  };
}

DiamondTier _tierForValue(double v) {
  if (v >= 150000) return DiamondTier.lendario;
  if (v >= 80000) return DiamondTier.grande;
  if (v >= 40000) return DiamondTier.marco;
  return DiamondTier.normal;
}

/// Esfera 3D da conquista (mesma linguagem da Trilha): aro metalico, vidro
/// roxo com luz, simbolo luminoso e reflexo. Bloqueada = vidro cinza.
/// Se o painel enviou uma arte propria, ela aparece dentro da esfera.
class AchievementOrb extends StatelessWidget {
  final Achievement achievement;
  final double size;
  final bool locked;
  final bool hidden;
  final bool glow;

  const AchievementOrb({super.key, required this.achievement, this.size = 68, this.locked = false, this.hidden = false, this.glow = true});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final gold = a.trailStage == "grande_marco" || a.trailStage == "merito" || a.family == "grande_marco" || a.family == "merito";
    final key = achievementSymbolKey(a);

    final colors = hidden
        ? const [Color(0xFFE9ECF5), Color(0xFFB5BBCC), Color(0xFF7F879C)]
        : locked
            ? const [Color(0xFFD9DDE8), Color(0xFF8E95A8), Color(0xFF555C70)]
            : gold
                ? const [Color(0xFFFFE7A3), Color(0xFFB45CFF), Color(0xFF4A0F94)]
                : const [Color(0xFFE6D2FF), Color(0xFF9B5CFF), Color(0xFF3B0A86)];

    Widget symbol;
    if (hidden) {
      symbol = Text("?", style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: size * 0.44, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Color(0x55000000), blurRadius: 4)]));
    } else if (a.imageUrl != null && !locked) {
      symbol = ClipOval(child: Image(image: MediaCacheImage(a.imageUrl!), width: size * 0.86, height: size * 0.86, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()));
    } else if (key == "diamond") {
      symbol = MDuckDiamond(size: size * 0.6, tier: _tierForValue(a.threshold), animate: !locked && size >= 60);
      if (locked) symbol = Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF9AA0B2), BlendMode.saturation), child: symbol));
    } else {
      symbol = TrailSymbol(iconKey: key, locked: locked, gold: gold && !locked, size: size * 0.53);
    }

    return SizedBox.square(
      dimension: size * 1.12,
      child: Stack(alignment: Alignment.center, children: [
        if (glow && !locked && !hidden)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: (gold ? const Color(0xFFFFC94D) : _lilac).withValues(alpha: 0.6), blurRadius: size * 0.32, spreadRadius: 1)]),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: locked || hidden
                  ? const [Color(0xFFFFFFFF), Color(0xFFB9BECC)]
                  : gold
                      ? const [Color(0xFFFFF6D6), Color(0xFFFFC94D), Color(0xFFB07A1E)]
                      : const [Color(0xFFFFFFFF), Color(0xFFE2CCFF), Color(0xFF9B5CFF)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: size * 0.12, offset: Offset(0, size * 0.07))],
          ),
        ),
        Container(
          width: size * 0.9,
          height: size * 0.9,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: const Alignment(-0.35, -0.45), radius: 0.95, colors: colors)),
        ),
        symbol,
        Positioned(
          top: size * 0.19,
          left: size * 0.29,
          child: Container(
            width: size * 0.38,
            height: size * 0.17,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0)]),
            ),
          ),
        ),
      ]),
    );
  }
}
