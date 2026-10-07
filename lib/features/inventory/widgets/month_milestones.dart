import "dart:math" as math;
import "package:mduck_lives/core/media/media_cache.dart";

import "dart:typed_data";
import "dart:ui" as ui;

import "package:flutter/foundation.dart" show compute;
import "package:flutter/material.dart";
import "package:flutter/services.dart" show NetworkAssetBundle;
import "package:image/image.dart" as img;
import "../data/art_slots.dart";
import "../../../core/share/image_share_menu.dart";
import "../data/journey_repository.dart";
import "achievement_widgets.dart" show compactNumber;
import "mduck_diamond.dart";

const _purple = Color(0xFF7A2BE2);
const _lilac = Color(0xFFC084FC);
const _gold = Color(0xFFFFC94D);
const _monthNames = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

String monthLabel(String periodKey, {bool capitalized = true}) {
  final parts = periodKey.split("-");
  if (parts.length != 2) return periodKey;
  final m = _monthNames[((int.tryParse(parts[1]) ?? 1) - 1).clamp(0, 11)];
  return "${capitalized ? m[0].toUpperCase() + m.substring(1) : m} de ${parts[0]}";
}

String _thousands(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(".");
    b.write(s[i]);
  }
  return b.toString();
}

String milestoneName(MonthMilestone m) => m.title.isNotEmpty ? m.title : compactNumber(m.value);

/// Titulo da arte pela importancia (configurada no painel).
String _artHeadline(int importance) {
  if (importance >= 7) return "MARCO LENDÁRIO DO MÊS";
  if (importance >= 5) return "MARCO RARO DO MÊS";
  if (importance == 4) return "GRANDE MARCO DO MÊS";
  return "CONQUISTA DO MÊS";
}

// ============================================================================
// Secao MARCOS DO MES (aba Trilha)
// ============================================================================

/// Maior marco do mes em destaque (com a arte) + colecao de todos os degraus
/// do mes. Toque em qualquer marco abre a conquista.
class MonthMilestonesSection extends StatelessWidget {
  final List<MonthMilestone> milestones;
  final String streamerName;
  final String? avatarUrl;

  const MonthMilestonesSection({super.key, required this.milestones, required this.streamerName, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();
    final period = milestones.first.periodKey;
    final reached = milestones.where((m) => m.reached).toList();
    final highest = reached.where((m) => m.isHighest).firstOrNull ?? (reached.isEmpty ? null : reached.last);
    final next = milestones.where((m) => !m.reached).firstOrNull;

    void open(MonthMilestone m) => showMilestoneViewer(context, milestones: milestones, initial: m, streamerName: streamerName, avatarUrl: avatarUrl);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Expanded(
          child: Text("Marcos do mês", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        ),
        Text(monthLabel(period), style: const TextStyle(color: Color(0xFFB9A7E8), fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      if (highest != null)
        _HighestCard(milestone: highest, streamerName: streamerName, avatarUrl: avatarUrl, onOpen: () => open(highest))
      else if (next != null)
        _FirstOfMonthCard(next: next),
      const SizedBox(height: 14),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: milestones.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _MilestoneToken(milestone: milestones[i], onTap: () => open(milestones[i])),
        ),
      ),
    ]);
  }
}

class _HighestCard extends StatelessWidget {
  final MonthMilestone milestone;
  final String streamerName;
  final String? avatarUrl;
  final VoidCallback onOpen;
  const _HighestCard({required this.milestone, required this.streamerName, this.avatarUrl, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B1260), Color(0xFF151A45)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (m.importance >= 4 ? _gold : _lilac).withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          // previa da arte (9:16), carregada so quando aparece
          SizedBox(
            width: 92,
            height: 164,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 360, height: 640, child: MilestoneArtCard(milestone: m, streamerName: streamerName, avatarUrl: avatarUrl))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("MAIOR MARCO DO MÊS", style: TextStyle(color: m.importance >= 4 ? _gold : _lilac, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
              const SizedBox(height: 6),
              Row(children: [
                MDuckDiamond(size: 34, tier: diamondTierForImportance(m.importance)),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(milestoneName(m), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1)),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text("${_thousands(m.currentDiamonds)} diamantes em ${monthLabel(m.periodKey, capitalized: false)}",
                  style: const TextStyle(color: Color(0xFFB9A7E8), fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _PillButton(label: "Ver conquista", filled: false, onTap: onOpen)),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillButton(
                    label: "Compartilhar",
                    filled: true,
                    onTap: () => showMilestoneViewer(context, milestones: [m], initial: m, streamerName: streamerName, avatarUrl: avatarUrl, shareNow: true),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FirstOfMonthCard extends StatelessWidget {
  final MonthMilestone next;
  const _FirstOfMonthCard({required this.next});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        MDuckDiamond(size: 44, tier: diamondTierForImportance(next.importance)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Seu primeiro marco do mês é ${milestoneName(next)}. Quando chegar, a arte para compartilhar aparece aqui.",
            style: const TextStyle(color: Color(0xFFD6CCF2), fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: filled ? const LinearGradient(colors: [Color(0xFFB45CFF), _purple]) : null,
          color: filled ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: filled ? Colors.transparent : Colors.white24),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _MilestoneToken extends StatelessWidget {
  final MonthMilestone milestone;
  final VoidCallback onTap;
  const _MilestoneToken({required this.milestone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final on = m.reached;
    final special = m.importance >= 4;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: on
                ? (special ? const [Color(0xFF5B1FB8), Color(0xFF241046)] : const [Color(0xFF3A2380), Color(0xFF1B1A45)])
                : [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? (m.isHighest ? (special ? _gold : _lilac) : _lilac.withValues(alpha: 0.45)) : Colors.white.withValues(alpha: 0.08),
            width: m.isHighest ? 2 : 1,
          ),
          boxShadow: on ? [BoxShadow(color: (special ? _gold : _purple).withValues(alpha: 0.28), blurRadius: 14)] : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Opacity(
            opacity: on ? 1 : 0.35,
            child: MDuckDiamond(size: 40, tier: diamondTierForImportance(m.importance), animate: on),
          ),
          Text(milestoneName(m), style: TextStyle(color: on ? Colors.white : Colors.white38, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(on ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 13, color: on ? (special ? _gold : _lilac) : Colors.white30),
            if (m.isHighest) ...[
              const SizedBox(width: 3),
              const Text("maior", style: TextStyle(color: _gold, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ============================================================================
// Visualizador + compartilhar
// ============================================================================

/// Abre a conquista do mes em tela cheia: a arte 9:16, "Compartilhar" e os
/// outros marcos batidos no mes. Compartilha a ARTE em 1080x1920.
Future<void> showMilestoneViewer(
  BuildContext context, {
  required List<MonthMilestone> milestones,
  required MonthMilestone initial,
  required String streamerName,
  String? avatarUrl,
  bool shareNow = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child)),
    pageBuilder: (_, _, _) => _MilestoneViewer(milestones: milestones, initial: initial, streamerName: streamerName, avatarUrl: avatarUrl, shareNow: shareNow),
  );
}

class _MilestoneViewer extends StatefulWidget {
  final List<MonthMilestone> milestones;
  final MonthMilestone initial;
  final String streamerName;
  final String? avatarUrl;
  final bool shareNow;
  const _MilestoneViewer({required this.milestones, required this.initial, required this.streamerName, this.avatarUrl, required this.shareNow});

  @override
  State<_MilestoneViewer> createState() => _MilestoneViewerState();
}

class _MilestoneViewerState extends State<_MilestoneViewer> {
  final _boundary = GlobalKey();
  late MonthMilestone _current = widget.initial;
  bool _special = true; // comemorativa quando houver; o streamer pode trocar

  @override
  void initState() {
    super.initState();
    if (widget.shareNow && widget.initial.reached) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(const Duration(milliseconds: 500), _share));
    }
  }

  Future<void> _share() async {
    if (!mounted) return;
    final m = _current;
    final box = _boundary.currentContext?.findRenderObject() as RenderBox?;
    final ratio = box == null || box.size.width <= 0 ? 3.0 : 1080 / box.size.width;
    await ImageShareMenu.show(
      context,
      capture: () => ImageShareMenu.capture(_boundary, pixelRatio: ratio),
      text: "Bati ${milestoneName(m)} em ${monthLabel(m.periodKey, capitalized: false)} na MDuck Agency! 🦆💜",
      title: "Compartilhar minha conquista",
      fileName: "conquista_${m.periodKey}_${m.value.round()}.png",
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _current;
    final reached = widget.milestones.where((x) => x.reached).toList();
    final size = MediaQuery.of(context).size;
    final artH = math.min(size.height * 0.68, (size.width - 48) * 16 / 9);
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28)),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                height: artH,
                width: artH * 9 / 16,
                child: RepaintBoundary(
                  key: _boundary,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(m.reached ? 0 : 20),
                    child: Stack(fit: StackFit.expand, children: [
                      FittedBox(fit: BoxFit.fill, child: SizedBox(width: 360, height: 640, child: MilestoneArtCard(milestone: m, streamerName: widget.streamerName, avatarUrl: widget.avatarUrl, useSpecial: _special))),
                      if (!m.reached)
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: Text("Bata ${milestoneName(m)} diamantes neste mês para liberar esta conquista.",
                              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.35)),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (m.specialUrl != null && m.classicUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final opt in [(false, "Arte Clássica"), (true, "Arte ${m.specialLabel ?? "Comemorativa"}")])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(opt.$2, style: TextStyle(color: _special == opt.$1 ? Colors.white : Colors.white70, fontWeight: FontWeight.w800)),
                      selected: _special == opt.$1,
                      selectedColor: _purple,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: BorderSide(color: _special == opt.$1 ? _lilac : Colors.white24),
                      onSelected: (_) => setState(() => _special = opt.$1),
                    ),
                  ),
              ]),
            ),
          if (reached.length > 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reached.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final x = reached[i];
                  final sel = x.id == m.id;
                  return ChoiceChip(
                    label: Text(milestoneName(x), style: TextStyle(color: sel ? Colors.white : Colors.white70, fontWeight: FontWeight.w800)),
                    selected: sel,
                    selectedColor: _purple,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(color: sel ? _lilac : Colors.white24),
                    onSelected: (_) => setState(() => _current = x),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: m.reached ? _share : null,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text("Compartilhar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// ARTE 9:16 (desenhada em 360x640; capturada em 1080x1920)
// ============================================================================

/// Arte do marco do mes pensada pra Stories/TikTok/WhatsApp.
/// Com arte enviada pelo painel (classica ou comemorativa do mes), o app
/// MONTA a arte de cada streamer sozinho: foto recortada em circulo na area
/// reservada, @ e mes na placa, e "MDuck Agency" no rodape. As areas vem do
/// painel (detectadas no upload) ou sao detectadas aqui mesmo, uma vez.
/// Sem arte: composicao desenhada, com raridade visual crescente.
/// Nunca quebra sem foto (usa a inicial do @).
class MilestoneArtCard extends StatelessWidget {
  final MonthMilestone milestone;
  final String streamerName;
  final String? avatarUrl;

  /// true = arte comemorativa do mes (quando existir); false = classica.
  final bool useSpecial;

  const MilestoneArtCard({super.key, required this.milestone, required this.streamerName, this.avatarUrl, this.useSpecial = true});

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final special = useSpecial && m.specialUrl != null;
    final url = special ? m.specialUrl : (m.classicUrl ?? m.specialUrl);
    final slots = special ? m.specialSlots : (m.classicUrl != null ? m.classicSlots : m.specialSlots);
    if (url != null) {
      return _ComposedArt(url: url, slots: slots, milestone: m, streamerName: streamerName, avatarUrl: avatarUrl, fallback: _designed(m));
    }
    return _designed(m);
  }

  Widget _designed(MonthMilestone m) {
    final imp = m.importance;
    final special = imp >= 4;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    // com foto + frase, o diamante encolhe um pouco pra caber tudo
    final gemSize = hasAvatar ? 92.0 + math.min(imp, 8) * 6 : 118.0 + math.min(imp, 8) * 8;
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _ArtBackgroundPainter(imp)),
      Column(children: [
        const SizedBox(height: 30),
        Image.asset("assets/videos/LogoMduck.png", height: 34, errorBuilder: (_, _, _) => const SizedBox(height: 34)),
        const SizedBox(height: 16),
        Text(_artHeadline(imp),
            style: TextStyle(color: special ? const Color(0xFFFFE08A) : const Color(0xFFE2D2FF), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4)),
        SizedBox(height: hasAvatar ? 6 : 22),
        MDuckDiamond(size: gemSize, tier: diamondTierForImportance(imp), animate: false),
        Transform.translate(
          offset: const Offset(0, -10),
          child: ShaderMask(
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: special ? const [Colors.white, Color(0xFFFFE08A)] : const [Colors.white, Color(0xFFE2C6FF)],
            ).createShader(r),
            child: Text(milestoneName(m),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 104,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -4,
                  shadows: [Shadow(color: (special ? _gold : _lilac).withValues(alpha: 0.8), blurRadius: 28)],
                )),
          ),
        ),
        const SizedBox(height: 4),
        if (hasAvatar) _CrystalAvatar(url: avatarUrl!, size: 92, special: special),
        // desbloqueada: comemoracao logo abaixo da foto
        if (m.reached) ...[
          SizedBox(height: hasAvatar ? 8 : 0),
          const Text("Parabéns por alcançar esse marco.",
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
        ],
        SizedBox(height: hasAvatar ? 10 : 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("@$streamerName", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "alcançou ${_thousands(m.value)} diamantes\nem ${monthLabel(m.periodKey, capitalized: false)}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE6DCFA), fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
        ),
        const Spacer(),
        Text("MDuck Agency", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 26),
      ]),
    ]);
  }
}

class _CrystalAvatar extends StatelessWidget {
  final String url;
  final double size;
  final bool special;
  const _CrystalAvatar({required this.url, required this.size, required this.special});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: special
              ? const [Color(0xFFFFF1B8), _gold, Color(0xFFB45CFF), Color(0xFFFFE08A), Color(0xFFFFF1B8)]
              : const [Colors.white, _lilac, _purple, Color(0xFFE9D5FF), Colors.white],
        ),
        boxShadow: [BoxShadow(color: (special ? _gold : _lilac).withValues(alpha: 0.7), blurRadius: size * 0.3)],
      ),
      child: ClipOval(
        child: Image(image: MediaCacheImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A1A8C))),
      ),
    );
  }
}

/// Cenario da arte: ceu roxo, brilho central, aurora (raros), raios (80K+),
/// estrelas, oceano turquesa, ilhas com palmeiras em silhueta, cristais nas
/// laterais e moldura (dourada a partir do grande marco).
class _ArtBackgroundPainter extends CustomPainter {
  final int imp;
  _ArtBackgroundPainter(this.imp);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final rnd = math.Random(imp * 31 + 7);
    final special = imp >= 4;
    final rect = Offset.zero & s;
    canvas.clipRect(rect);

    // ceu
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: switch (imp) {
            1 => const [Color(0xFF1A0B45), Color(0xFF3A1786), Color(0xFF241056)],
            2 => const [Color(0xFF190A44), Color(0xFF4A1A9E), Color(0xFF2A0E5E)],
            3 => const [Color(0xFF1C0848), Color(0xFF5E1BB0), Color(0xFF2E0B62)],
            4 => const [Color(0xFF14063A), Color(0xFF6A1FC8), Color(0xFF2A0A5C)],
            _ => const [Color(0xFF0E0430), Color(0xFF5A16B8), Color(0xFF1E0748)],
          },
        ).createShader(rect),
    );

    // aurora (raros)
    if (imp >= 5) {
      for (final a in [(0.18, const Color(0xFF2EE6D6)), (0.30, const Color(0xFFB45CFF))]) {
        final p = Path()..moveTo(-20, h * a.$1);
        p.cubicTo(w * 0.3, h * (a.$1 - 0.10), w * 0.6, h * (a.$1 + 0.08), w + 20, h * (a.$1 - 0.04));
        canvas.drawPath(p, Paint()
          ..color = a.$2.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 46
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
      }
    }

    // estrelas
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.7), rnd.nextDouble() * 1.4 + 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.3 + rnd.nextDouble() * 0.6));
    }

    // brilho central + raios
    final glowC = Offset(w / 2, h * 0.33);
    if (special) {
      final ray = Paint()..color = (imp >= 7 ? const Color(0xFFFFE08A) : const Color(0xFFE2C6FF)).withValues(alpha: imp >= 7 ? 0.13 : 0.08);
      final n = imp >= 7 ? 24 : 16;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n;
        canvas.drawPath(
          Path()
            ..moveTo(glowC.dx, glowC.dy)
            ..lineTo(glowC.dx + math.cos(a - 0.05) * h, glowC.dy + math.sin(a - 0.05) * h)
            ..lineTo(glowC.dx + math.cos(a + 0.05) * h, glowC.dy + math.sin(a + 0.05) * h)
            ..close(),
          ray,
        );
      }
    }
    canvas.drawCircle(glowC, w * 0.55, Paint()
      ..shader = RadialGradient(colors: [
        (imp >= 7 ? const Color(0xFFFFD36B) : const Color(0xFFB45CFF)).withValues(alpha: 0.55),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: glowC, radius: w * 0.55)));

    // oceano + reflexos
    final seaTop = h * 0.80;
    final sea = Rect.fromLTWH(0, seaTop, w, h - seaTop);
    canvas.drawRect(sea, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2EB7C9), Color(0xFF15457A), Color(0xFF0B1638)]).createShader(sea));
    for (var i = 0; i < 9; i++) {
      final y = seaTop + 8 + i * 12.0;
      final x = w * 0.5 + (rnd.nextDouble() - 0.5) * w * 0.6;
      canvas.drawLine(Offset(x - 18 + i, y), Offset(x + 18 - i, y), Paint()
        ..color = Colors.white.withValues(alpha: 0.35 - i * 0.03)
        ..strokeWidth = 1.4);
    }

    // ilhas em silhueta com palmeiras
    for (final isl in [(w * 0.12, 1.0), (w * 0.88, 0.85)]) {
      final c = Offset(isl.$1, seaTop + 2);
      final r = 46.0 * isl.$2;
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.6, height: r * 0.7), Paint()..color = const Color(0xFF1B0B45));
      for (final dx in [-0.25, 0.2]) {
        final base = c.translate(r * dx, -r * 0.18);
        final top = base.translate(r * 0.15, -r * 1.2);
        canvas.drawPath(
          Path()..moveTo(base.dx - 2, base.dy)..quadraticBezierTo(base.dx + r * 0.2, base.dy - r * 0.6, top.dx, top.dy)..lineTo(top.dx + 2.5, top.dy)..quadraticBezierTo(base.dx + r * 0.26, base.dy - r * 0.6, base.dx + 2, base.dy)..close(),
          Paint()..color = const Color(0xFF1B0B45),
        );
        for (final a in [-2.7, -2.1, -1.4, -0.8, -0.2]) {
          final end = top.translate(math.cos(a) * r * 0.7, math.sin(a) * r * 0.35 + r * 0.2);
          canvas.drawPath(
            Path()..moveTo(top.dx, top.dy)..quadraticBezierTo((top.dx + end.dx) / 2, top.dy - r * 0.2, end.dx, end.dy)..quadraticBezierTo((top.dx + end.dx) / 2, top.dy - r * 0.05, top.dx, top.dy)..close(),
            Paint()..color = const Color(0xFF1B0B45),
          );
        }
      }
    }

    // cristais nas laterais (40K+)
    if (imp >= 3) {
      for (final side in [-1.0, 1.0]) {
        final base = Offset(side < 0 ? 16 : w - 16, seaTop - 4);
        for (var k = 0; k < (imp >= 5 ? 4 : 2); k++) {
          final hh = 30.0 + k * 9 + imp * 1.5;
          canvas.save();
          canvas.translate(base.dx + side * -k * 10, base.dy);
          canvas.rotate(side * (0.18 - k * 0.08));
          final cr = Path()..moveTo(0, -hh)..lineTo(9, -hh * 0.6)..lineTo(7, 0)..lineTo(-7, 0)..lineTo(-9, -hh * 0.6)..close();
          canvas.drawPath(cr, Paint()..shader = const LinearGradient(colors: [Color(0xFFF3E6FF), Color(0xFFB45CFF), Color(0xFF3B0A86)]).createShader(cr.getBounds()));
          canvas.restore();
        }
        canvas.drawCircle(base.translate(0, -30), 40, Paint()
          ..color = _lilac.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
      }
    }

    // faiscas
    for (var i = 0; i < 10 + imp * 3; i++) {
      final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.78);
      final r = 2.0 + rnd.nextDouble() * (special ? 5 : 3);
      final p = Path();
      for (var j = 0; j < 8; j++) {
        final rr = j.isEven ? r : r * 0.25;
        final a = j * math.pi / 4;
        final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
        j == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), Paint()..color = (special && i.isEven ? const Color(0xFFFFE9B0) : Colors.white).withValues(alpha: 0.9));
    }

    // moldura
    final frame = RRect.fromRectAndRadius(rect.deflate(12), const Radius.circular(18));
    canvas.drawRRect(frame, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = special ? 2.2 : 1.2
      ..shader = LinearGradient(colors: special
              ? const [Color(0xFFFFF1B8), _gold, Color(0xFFB07A1E), _gold]
              : [Colors.white.withValues(alpha: 0.5), _lilac.withValues(alpha: 0.5)])
          .createShader(rect));
    if (special) {
      canvas.drawRRect(frame.deflate(6), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _gold.withValues(alpha: 0.5));
      for (final corner in [frame.outerRect.topLeft, frame.outerRect.topRight, frame.outerRect.bottomLeft, frame.outerRect.bottomRight]) {
        canvas.save();
        canvas.translate(corner.dx, corner.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(const Rect.fromLTWH(-6, -6, 12, 12), Paint()..shader = const LinearGradient(colors: [Color(0xFFFFF1B8), _gold]).createShader(const Rect.fromLTWH(-6, -6, 12, 12)));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArtBackgroundPainter old) => old.imp != imp;
}

// ============================================================================
// "Novo marco desbloqueado"
// ============================================================================

/// Aparece ao abrir a Jornada quando o streamer bateu um marco do mes que
/// ainda nao tinha visto. Mostra o maior, com a arte, [Ver conquista] e
/// [Compartilhar].
Future<void> showMonthMilestoneUnlocked(
  BuildContext context,
  MonthMilestone m, {
  required List<MonthMilestone> all,
  required String streamerName,
  String? avatarUrl,
  int moreCount = 0,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("NOVO MARCO DESBLOQUEADO",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: m.importance >= 4 ? _gold : _lilac, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.6)),
              if (moreCount > 0) ...[
                const SizedBox(height: 4),
                Text("e mais $moreCount ${moreCount == 1 ? "marco" : "marcos"} neste mês",
                    style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: math.min(MediaQuery.of(ctx).size.height * 0.56, 460),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: (m.importance >= 4 ? _gold : _purple).withValues(alpha: 0.5), blurRadius: 40)]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FittedBox(fit: BoxFit.fill, child: SizedBox(width: 360, height: 640, child: MilestoneArtCard(milestone: m, streamerName: streamerName, avatarUrl: avatarUrl))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: _PillButton(
                    label: "Ver conquista",
                    filled: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showMilestoneViewer(context, milestones: all, initial: m, streamerName: streamerName, avatarUrl: avatarUrl);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    label: "Compartilhar",
                    filled: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showMilestoneViewer(context, milestones: all, initial: m, streamerName: streamerName, avatarUrl: avatarUrl, shareNow: true);
                    },
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}

// ============================================================================
// Montagem automatica da arte enviada pelo painel
// ============================================================================

/// Apenas pra testes/previas: troca a rede por bytes locais.
Uint8List Function(String url)? milestoneArtTestBytes;

ImageProvider _artImage(String url) {
  final t = milestoneArtTestBytes;
  return t != null ? MemoryImage(t(url)) : MediaCacheImage(url);
}

/// Cache das areas detectadas por URL (deteccao roda uma vez por arte).
final Map<String, Future<({ArtSlots? slots, double aspect})>> _slotCache = {};

Future<({ArtSlots? slots, double aspect})> _resolveArt(String url) {
  return _slotCache.putIfAbsent(url, () async {
    final t = milestoneArtTestBytes;
    final bytes = t != null ? t(url) : (await NetworkAssetBundle(Uri.parse(url)).load(url)).buffer.asUint8List();
    return compute(_detectWithAspect, bytes);
  });
}

({ArtSlots? slots, double aspect}) _detectWithAspect(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  final aspect = decoded == null ? 2 / 3 : decoded.width / decoded.height;
  return (slots: detectArtSlots(bytes), aspect: aspect);
}

class _ComposedArt extends StatefulWidget {
  final String url;
  final ArtSlots? slots;
  final MonthMilestone milestone;
  final String streamerName;
  final String? avatarUrl;
  final Widget fallback;
  const _ComposedArt({required this.url, this.slots, required this.milestone, required this.streamerName, this.avatarUrl, required this.fallback});

  @override
  State<_ComposedArt> createState() => _ComposedArtState();
}

class _ComposedArtState extends State<_ComposedArt> {
  ArtSlots? _slots;
  double _aspect = 2 / 3;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _slots = widget.slots;
    _resolveArt(widget.url).then((r) {
      if (!mounted) return;
      setState(() {
        _slots ??= r.slots;
        _aspect = r.aspect;
        _ready = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(covariant _ComposedArt old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _ready = false;
      _slots = widget.slots;
      _resolveArt(widget.url).then((r) {
        if (!mounted) return;
        setState(() {
          _slots ??= r.slots;
          _aspect = r.aspect;
          _ready = true;
        });
      }).catchError((_) {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final W = box.maxWidth, H = box.maxHeight;
      // arte inteira (contain) sobre um fundo desfocado da propria arte (9:16)
      var aw = W, ah = W / _aspect;
      if (ah > H) {
        ah = H;
        aw = H * _aspect;
      }
      final ax = (W - aw) / 2, ay = (H - ah) / 2;
      final s = _slots;
      final m = widget.milestone;
      final month = monthLabel(m.periodKey).replaceFirst(" de ", " ");

      return Stack(fit: StackFit.expand, children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Image(image: _artImage(widget.url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF12052E))),
        ),
        Container(color: Colors.black.withValues(alpha: 0.25)),
        Positioned(
          left: ax,
          top: ay,
          width: aw,
          height: ah,
          child: Image(image: _artImage(widget.url), fit: BoxFit.fill, errorBuilder: (_, _, _) => widget.fallback),
        ),
        if (!_ready && s == null) const Center(child: CircularProgressIndicator(color: Colors.white54)),
        if (s != null) ...[
          // titulo acima do circulo (se houver espaco)
          if (s.cy * ah - s.r * aw > ah * 0.07)
            Positioned(
              left: ax,
              width: aw,
              top: ay + (s.cy * ah - s.r * aw) / 2 - aw * 0.03,
              child: Center(
                child: Text("MARCO DO MÊS ALCANÇADO",
                    style: TextStyle(color: Colors.white, fontSize: aw * 0.042, fontWeight: FontWeight.w900, letterSpacing: aw * 0.008, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])),
              ),
            ),
          // foto no circulo reservado
          Positioned(
            left: ax + (s.cx - s.r * 0.97) * aw,
            top: ay + s.cy * ah - s.r * 0.97 * aw,
            width: s.r * 2 * 0.97 * aw,
            height: s.r * 2 * 0.97 * aw,
            child: ClipOval(child: _photo(s.r * 2 * aw)),
          ),
          // desbloqueada: a arte vira comemoracao (bloqueada, o visualizador
          // mostra "Bata XK diamantes..." por cima)
          if (m.reached)
            Positioned(
              left: ax,
              width: aw,
              top: ay + s.cy * ah + s.r * aw + ah * 0.012,
              child: Center(
                child: Text("Parabéns por alcançar esse marco.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: aw * 0.042,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 8), Shadow(color: Colors.black87, blurRadius: 3)],
                    )),
              ),
            ),
          // @ e mes na placa (ou logo abaixo do circulo, se nao houver placa)
          Positioned(
            left: ax + (s.hasPlate ? s.px! * aw : aw * 0.12),
            width: s.hasPlate ? s.pw! * aw : aw * 0.76,
            top: ay + (s.hasPlate ? s.py! * ah : s.cy * ah + s.r * aw + ah * 0.02),
            height: s.hasPlate ? s.ph! * ah : ah * 0.1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: aw * 0.05, vertical: ah * 0.006),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("@${widget.streamerName}",
                        style: TextStyle(color: Colors.white, fontSize: aw * 0.075, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
                  Text(month, style: TextStyle(color: const Color(0xFFE2C6FF), fontSize: aw * 0.042, fontWeight: FontWeight.w800, letterSpacing: aw * 0.003)),
                ]),
              ),
            ),
          ),
          // assinatura
          Positioned(
            left: ax,
            width: aw,
            top: ay + (s.hasPlate ? ((s.py! + s.ph!) * ah + ah) / 2 : ah * 0.94) - aw * 0.03,
            child: Center(
              child: Text("MDuck Agency",
                  style: TextStyle(color: Colors.white, fontSize: aw * 0.045, fontWeight: FontWeight.w800, letterSpacing: aw * 0.002, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])),
            ),
          ),
        ],
      ]);
    });
  }

  Widget _photo(double size) {
    final url = widget.avatarUrl;
    final initial = widget.streamerName.isNotEmpty ? widget.streamerName[0].toUpperCase() : "M";
    final placeholder = Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB98CFF), _purple, Color(0xFF3B0A86)])),
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900)),
    );
    if (url == null || url.isEmpty) return placeholder;
    return Image(image: _artImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
  }
}
