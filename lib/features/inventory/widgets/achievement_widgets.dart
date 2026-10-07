import "dart:math" as math;

import "package:flutter/material.dart";
import "../../../core/share/image_share_menu.dart";
import "../data/achievements_repository.dart";
import "achievement_orb.dart";

// Destaque da Jornada: lilas (dourado so nas artes realmente especiais).
const _gold = Color(0xFFC084FC);
const _ink = Color(0xFF0E0A2A);

const _months = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

String achievementDate(DateTime d) => "${d.day} de ${_months[d.month - 1]} de ${d.year}";

/// 102345 -> "102K" ; 1200000 -> "1,2M" ; 60 -> "60"
String compactNumber(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return "${m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1).replaceAll(".", ",")}M";
  }
  if (v >= 1000) return "${(v / 1000).floor()}K";
  return v.round().toString();
}

/// Texto da condicao de uma conquista ("80.000 diamantes somados" etc).
String achievementCondition(Achievement a) {
  final t = compactNumber(a.threshold);
  switch (a.ruleType) {
    case "total_diamonds":
      return "Somar $t diamantes na sua história";
    case "month_diamonds":
      return "Fechar um mês com $t diamantes";
    case "consecutive_months_diamonds":
      return "${a.months} meses seguidos acima de $t diamantes";
    case "month_hours":
      return "Fazer $t horas de live em um mês";
    case "total_hours":
      return "Somar $t horas de live";
    case "month_days":
      return "Fazer live em $t dias do mesmo mês";
    case "month_combo":
      return "$t diamantes + ${a.comboDays} dias + ${a.comboHours}h no mesmo mês";
    default:
      return a.description;
  }
}

String _progressLabel(Achievement a) {
  final unit = switch (a.ruleType) {
    "consecutive_months_diamonds" => " meses",
    "month_hours" || "total_hours" => "h",
    "month_days" => " dias",
    _ => "",
  };
  return "${compactNumber(a.currentValue)}$unit / ${compactNumber(a.target)}$unit";
}

// ============================================================================
// Detalhe da conquista
// ============================================================================
Future<void> showAchievementDetails(BuildContext context, Achievement a, {required String streamerName}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AchievementDetails(achievement: a, streamerName: streamerName),
  );
}

class _AchievementDetails extends StatelessWidget {
  final Achievement achievement;
  final String streamerName;
  const _AchievementDetails({required this.achievement, required this.streamerName});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1240),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: a.unlocked ? _gold.withValues(alpha: 0.55) : Colors.white12),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            AchievementOrb(achievement: a, size: 150, locked: !a.unlocked),
            const SizedBox(height: 18),
            _StatusChip(unlocked: a.unlocked),
            const SizedBox(height: 10),
            Text(a.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(a.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
            const SizedBox(height: 16),
            if (a.unlocked)
              Text("Desbloqueada em ${achievementDate(a.unlockedAt!)}",
                  style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w700))
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("COMO CONQUISTAR", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(achievementCondition(a), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: a.progress,
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF9B5CFF)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("${_progressLabel(a)}  ·  ${(a.progress * 100).round()}%", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
            ],
            if (a.unlocked) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showAchievementShareCard(context, a, streamerName: streamerName),
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text("Compartilhar conquista", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xFF1B0B45),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool unlocked;
  const _StatusChip({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? _gold : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(unlocked ? Icons.verified : Icons.lock_outline, size: 14, color: color),
        const SizedBox(width: 6),
        Text(unlocked ? "DESBLOQUEADA" : "BLOQUEADA",
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ]),
    );
  }
}

// ============================================================================
// Card de compartilhamento (formato Stories 9:16)
// ============================================================================
Future<void> showAchievementShareCard(BuildContext context, Achievement a, {required String streamerName}) {
  final key = GlobalKey();
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: RepaintBoundary(key: key, child: AchievementShareCard(achievement: a, streamerName: streamerName)),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Fechar"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              // mesmo menu de compartilhar do Ranking (core/share)
              onPressed: () => ImageShareMenu.show(
                dialogContext,
                title: "Compartilhar conquista",
                capture: () => ImageShareMenu.capture(key),
                text: "Conquista desbloqueada na MDuck Agency: ${a.title}! 💎🦆",
                fileName: "conquista_${a.code}.png",
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text("Compartilhar", style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF1B0B45),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ]),
      ]),
    ),
  );
}

/// Arte publica da conquista: so o que e da conquista (nada interno).
class AchievementShareCard extends StatelessWidget {
  final Achievement achievement;
  final String streamerName;
  const AchievementShareCard({super.key, required this.achievement, required this.streamerName});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return LayoutBuilder(builder: (context, c) {
      final u = c.maxWidth / 100;
      return ClipRRect(
        borderRadius: BorderRadius.circular(5 * u),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A1786), Color(0xFF1C1150), _ink],
            ),
          ),
          child: Stack(children: [
            // brilho dourado atras da arte
            Positioned(
              left: -20 * u,
              right: -20 * u,
              top: 32 * u,
              height: 110 * u,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [_gold.withValues(alpha: 0.28), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * u, 9 * u, 8 * u, 8 * u),
              child: Column(children: [
                Image.asset("assets/splash/logo_mduck_recortado.png", width: 42 * u, fit: BoxFit.contain),
                SizedBox(height: 6 * u),
                Text("CONQUISTA DESBLOQUEADA",
                    style: TextStyle(color: _gold, fontSize: 4.2 * u, fontWeight: FontWeight.w900, letterSpacing: 0.8 * u)),
                SizedBox(height: 6 * u),
                AchievementOrb(achievement: a, size: 62 * u),
                SizedBox(height: 7 * u),
                Text(a.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 9 * u, fontWeight: FontWeight.w900, height: 1.05)),
                SizedBox(height: 3 * u),
                Text("“${a.description}”",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 4.2 * u, fontStyle: FontStyle.italic, height: 1.35)),
                const Spacer(),
                Text("@$streamerName", style: TextStyle(color: Colors.white, fontSize: 5.5 * u, fontWeight: FontWeight.w800)),
                SizedBox(height: 1.5 * u),
                if (a.unlockedAt != null)
                  Text(achievementDate(a.unlockedAt!), style: TextStyle(color: Colors.white54, fontSize: 3.6 * u)),
                SizedBox(height: 3 * u),
                Text("MDuck Agency", style: TextStyle(color: const Color(0xFFD6CCF2), fontSize: 3.6 * u, fontWeight: FontWeight.w800, letterSpacing: 0.5 * u)),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

// ============================================================================
// Celebracao do desbloqueio (curta, sem confete, sem som)
// ============================================================================
Future<void> showAchievementCelebration(
  BuildContext context,
  Achievement a, {
  required String streamerName,
  int moreCount = 0,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => _Celebration(achievement: a, streamerName: streamerName, moreCount: moreCount),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)), child: child),
    ),
  );
}

class _Celebration extends StatefulWidget {
  final Achievement achievement;
  final String streamerName;
  final int moreCount;
  const _Celebration({required this.achievement, required this.streamerName, required this.moreCount});

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  // raios de luz girando bem devagar atras da arte
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("CONQUISTA DESBLOQUEADA",
                  style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3)),
              const SizedBox(height: 22),
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(alignment: Alignment.center, children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) => Transform.rotate(
                      angle: _spin.value * 2 * math.pi,
                      child: CustomPaint(size: const Size(240, 240), painter: _RaysPainter()),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: Center(child: AchievementOrb(achievement: a, size: 170)),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(a.title.toUpperCase(),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(a.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
              if (widget.moreCount > 0) ...[
                const SizedBox(height: 8),
                Text("+ ${widget.moreCount} ${widget.moreCount == 1 ? "outra conquista" : "outras conquistas"} desbloqueada${widget.moreCount == 1 ? "" : "s"}",
                    style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  onPressed: () => showAchievementShareCard(context, a, streamerName: widget.streamerName),
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text("Compartilhar conquista", style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xFF1B0B45),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Ver conquista", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.09) * r, c.dy + math.sin(a - 0.09) * r)
        ..lineTo(c.dx + math.cos(a + 0.09) * r, c.dy + math.sin(a + 0.09) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
