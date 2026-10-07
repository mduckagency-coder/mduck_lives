import "dart:ui" show ImageFilter;
import "package:mduck_lives/core/media/media_cache.dart";

import "package:flutter/material.dart";
import "data/achievements_repository.dart";
import "data/inventory_repository.dart";
import "data/journey_repository.dart";
import "widgets/achievement_orb.dart";
import "widgets/achievement_widgets.dart";
import "widgets/journey_crest.dart";
import "widgets/journey_type_icon.dart";
import "widgets/mduck_diamond.dart";
import "widgets/month_milestones.dart";
import "widgets/constancy_flame.dart";
import "widgets/level_up_celebration.dart";
import "data/ducker_level.dart";
import "../home/data/streamer_repository.dart";

// Paleta da Jornada: roxo como destaque, lilas, azul profundo e branco.
// Dourado so em conquistas realmente especiais.
const _purple = Color(0xFF7A2BE2);
const _violet = Color(0xFF9B5CFF);
const _lilac = Color(0xFFC084FC);
const _lilacSoft = Color(0xFFD6CCF2);
const _gold = Color(0xFFFFC94D);
const _bgTop = Color(0xFF120A33);
const _bgMid = Color(0xFF0C1230);
const _bgBottom = Color(0xFF070A1C);

const _monthShort = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
const _monthLong = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];

/// JORNADA (no painel continua "Inventario"): a historia do streamer dentro
/// da MDuck Agency.
///   MARCOS DO MES metas profissionais do mes (22 dias / 100 h / 80K), Constancia,
///                 primeiros 90 dias e os marcos de diamantes com arte
///   CONQUISTAS    todas as conquistas automaticas, por familia
///   JORNADA MDUCK o que a MDuck Agency fez pelo streamer (registro da equipe)
/// Sem XP, niveis, moedas ou ranking. Tudo vem do historico real e a meta e
/// calculada no banco (migrations 0091/0095/0096/0097).
class InventoryContent extends StatefulWidget {
  const InventoryContent({super.key});

  @override
  State<InventoryContent> createState() => _InventoryContentState();
}

enum _Tab { marcos, conquistas, jornada }

class _InventoryContentState extends State<InventoryContent> {
  final _achievementsRepo = AchievementsRepository();
  final _journeyRepo = InventoryRepository();
  final _summaryRepo = JourneyRepository();

  _Tab _tab = _Tab.marcos;
  List<Achievement>? _achievements;
  JourneySummary? _summary;
  List<MonthMilestone> _month = const [];
  List<InventoryEntry>? _journey;
  List<({String period, double value, String title, int importance, DateTime? at})> _history = const [];
  static const _defaultTexts = (title: "Sua jornada na MDuck", subtitle: "Um registro dos momentos que marcaram sua trajetória.");
  ({String title, String subtitle}) _texts = _defaultTexts;
  String _streamerName = "";
  Object? _error;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final nameFuture = StreamerRepository().fetchCurrentStreamerSummary().then((s) => s.displayName).catchError((_) => "");
      // conquistas primeiro: app_my_achievements ja recalcula tudo no banco
      final achievements = await _achievementsRepo.fetch();
      final summaryFuture = _summaryRepo.fetchSummary().catchError((_) => null);
      final monthFuture = _summaryRepo.fetchMonthMilestones().catchError((_) => <MonthMilestone>[]);
      final journeyFuture = _journeyRepo.fetchEntries().catchError((_) => <InventoryEntry>[]);
      final historyFuture = _summaryRepo.fetchMilestoneHistory().catchError((_) => <({String period, double value, String title, int importance, DateTime? at})>[]);
      final textsFuture = _summaryRepo.fetchJourneyTexts().catchError((_) => _defaultTexts);
      final summary = await summaryFuture;
      final month = await monthFuture;
      final journey = await journeyFuture;
      final history = await historyFuture;
      final texts = await textsFuture;
      final name = await nameFuture;
      if (!mounted) return;
      setState(() {
        _achievements = achievements;
        _summary = summary;
        _month = month;
        _journey = journey;
        _history = history;
        _texts = texts;
        _streamerName = (summary?.name.isNotEmpty ?? false) ? summary!.name : name;
        _error = null;
      });
      _celebrateNew();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Novidades desde a ultima visita: maior marco do mes recem batido (com a
  /// arte) e conquistas novas. Marca como visto.
  Future<void> _celebrateNew() async {
    if (_celebrated) return;
    _celebrated = true;
    final fresh = (_achievements ?? []).where((a) => a.unlocked && !a.seen).toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    final freshMonth = _month.where((m) => m.reached && !m.seen).toList()..sort((a, b) => b.value.compareTo(a.value));
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (freshMonth.isNotEmpty) {
      await showMonthMilestoneUnlocked(context, freshMonth.first,
          all: _month, streamerName: _streamerName, avatarUrl: _summary?.avatarUrl, moreCount: freshMonth.length - 1);
      _summaryRepo.markMonthSeen([for (final m in freshMonth) m.id]).catchError((_) {});
    }
    if (!mounted) return;
    // mudanca de nivel (Top Ducker / Ducker Elite / Ducker Lendario): uma vez
    if (_summary != null) await maybeCelebrateDuckerLevel(context, _summary!.currentDiamonds);
    if (!mounted) return;
    if (fresh.isNotEmpty) {
      await showAchievementCelebration(context, fresh.first, streamerName: _streamerName, moreCount: fresh.length - 1);
      _achievementsRepo.markSeen([for (final a in fresh) a.id]).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgMid, _bgBottom]),
      ),
      child: RefreshIndicator(
        color: _violet,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          children: [
            _header(),
            const SizedBox(height: 18),
            _tabs(),
            const SizedBox(height: 22),
            if (_error != null && _achievements == null)
              _errorState()
            else if (_achievements == null)
              const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: _violet)))
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: switch (_tab) {
                  _Tab.marcos => KeyedSubtree(key: const ValueKey("m"), child: _marcos()),
                  _Tab.conquistas => KeyedSubtree(key: const ValueKey("c"), child: _conquistas()),
                  _Tab.jornada => KeyedSubtree(key: const ValueKey("j"), child: _jornada()),
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Topo: JORNADA + brasao atual (protagonista) + estagio + conquistas.
  Widget _header() {
    final s = _summary;
    final all = _achievements ?? const <Achievement>[];
    final unlocked = s?.unlocked ?? all.where((a) => a.unlocked).length;
    final total = s?.total ?? all.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Jornada", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1)),
      const SizedBox(height: 4),
      const Text("Sua história dentro da MDuck Agency", style: TextStyle(color: _lilacSoft, fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1786), Color(0xFF1C1150), Color(0xFF111A44)]),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _lilac.withValues(alpha: 0.35)),
          ),
          child: Stack(children: [
            Positioned(
              left: -30,
              top: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_violet.withValues(alpha: 0.45), Colors.transparent])),
              ),
            ),
            Row(children: [
              JourneyCrest(crestKey: s?.crestKey ?? "prata", imageUrl: s?.crestImageUrl, size: 116),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("SEU ESTÁGIO", style: TextStyle(color: _lilac, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                  const SizedBox(height: 4),
                  Text(s?.stageName ?? "Primeiros Passos",
                      style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.4)),
                  if (s?.stageDescription != null) ...[
                    const SizedBox(height: 5),
                    Text(s!.stageDescription!, style: const TextStyle(color: _lilacSoft, fontSize: 13, height: 1.3)),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const MDuckDiamond(size: 16, animate: false),
                      const SizedBox(width: 6),
                      Text("$unlocked de $total conquistas", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _tabs() {
    Widget tab(_Tab t, String label) {
      final selected = _tab == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [_violet, _purple]) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected ? [BoxShadow(color: _purple.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4))] : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(color: selected ? Colors.white : _lilacSoft.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        tab(_Tab.marcos, "Marcos do Mês"),
        tab(_Tab.conquistas, "Conquistas"),
        tab(_Tab.jornada, "Jornada"),
      ]),
    );
  }

  Widget _errorState() => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          const Text("Não foi possível carregar sua jornada agora.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          TextButton(onPressed: _load, child: const Text("Tentar de novo", style: TextStyle(color: _lilac))),
        ]),
      );

  // ==========================================================================
  // MARCOS DO MES
  // ==========================================================================
  Widget _marcos() {
    final s = _summary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (s?.onboarding != null) ...[_OnboardingCard(onboarding: s!.onboarding!, summary: s), const SizedBox(height: 18)],
      if (s != null) MonthGoalCard(summary: s),
      if (_month.isNotEmpty) ...[
        const SizedBox(height: 26),
        MonthMilestonesSection(milestones: _month, streamerName: _streamerName, avatarUrl: s?.avatarUrl),
      ],
    ]);
  }

  // ==========================================================================
  // CONQUISTAS
  // ==========================================================================
  Widget _conquistas() {
    final all = _achievements!;
    final unlocked = all.where((a) => a.unlocked).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_summary != null) ...[_RecordsCard(summary: _summary!), const SizedBox(height: 14)],
      _counter(unlocked, all.length),
      if (all.isEmpty)
        const Padding(
          padding: EdgeInsets.all(30),
          child: Text("As conquistas ainda estão sendo preparadas pela MDuck Agency.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        ),
      for (final f in achievementFamilies)
        if (all.any((a) => a.family == f.key)) _familySection(f.title, f.subtitle, all.where((a) => a.family == f.key).toList()),
    ]);
  }

  Widget _counter(int unlocked, int total) {
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2B1260), Color(0xFF151A45)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _lilac.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: pct, strokeWidth: 5, strokeCap: StrokeCap.round, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(_violet)),
            const MDuckDiamond(size: 28),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(children: [
                TextSpan(text: "$unlocked", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                TextSpan(text: " de $total", style: const TextStyle(color: _lilacSoft, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Text(
              unlocked == 0 ? "Sua primeira conquista está te esperando" : (unlocked == total ? "Você desbloqueou todas as conquistas!" : "conquistas na sua história"),
              style: const TextStyle(color: _lilacSoft, fontSize: 13),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _familySection(String title, String subtitle, List<Achievement> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(subtitle, style: const TextStyle(color: _lilacSoft, fontSize: 13)),
            ]),
          ),
          Text("${items.where((a) => a.unlocked).length}/${items.length}", style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.74),
          itemCount: items.length,
          itemBuilder: (context, i) => _AchievementTile(achievement: items[i], onTap: () => showAchievementDetails(context, items[i], streamerName: _streamerName)),
        ),
      ]),
    );
  }

  // ==========================================================================
  // JORNADA MDUCK
  // ==========================================================================
  /// Tudo que marcou a trajetoria, numa linha do tempo so: registros da
  /// equipe (presentes, premiacoes...), conquistas desbloqueadas e o maior
  /// marco de diamantes de cada mes. Mais recente primeiro, agrupado por mes.
  List<_TimelineItem> _timelineItems() {
    final items = <_TimelineItem>[];
    for (final e in _journey ?? const <InventoryEntry>[]) {
      final t = e.type;
      items.add(_TimelineItem(
        date: e.occurredAt,
        title: e.title,
        typeLabel: t.label,
        color: t.color,
        leading: e.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(image: ResizeImage(MediaCacheImage(e.imageUrl!), width: 144), width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => JourneyTypeIcon(category: e.category, color: t.color, size: 48)),
              )
            : JourneyTypeIcon(category: e.category, color: t.color, size: 48),
        onTap: () => _openJourneyDetails(e),
      ));
    }
    for (final a in _achievements ?? const <Achievement>[]) {
      if (!a.unlocked) continue;
      items.add(_TimelineItem(
        date: a.unlockedAt!,
        title: a.title,
        typeLabel: "Conquista",
        color: const Color(0xFFB45CFF),
        leading: AchievementOrb(achievement: a, size: 43, glow: false),
        onTap: () => showAchievementDetails(context, a, streamerName: _streamerName),
      ));
    }
    for (final h in _history) {
      final parts = h.period.split("-");
      // data no proprio mes do marco (independe do fuso do aparelho)
      final y = parts.length == 2 ? int.parse(parts[0]) : DateTime.now().year;
      final mo = parts.length == 2 ? int.parse(parts[1]) : DateTime.now().month;
      final at = h.at;
      final date = at != null && at.year == y && at.month == mo ? at : DateTime(y, mo + 1, 0, 12);
      items.add(_TimelineItem(
        date: date,
        title: "Marco de ${h.title.isNotEmpty ? h.title : compactNumber(h.value)} diamantes",
        typeLabel: "Marco do mês",
        color: h.value >= 80000 ? _gold : _violet,
        leading: SizedBox(width: 48, height: 48, child: Center(child: MDuckDiamond(size: 40, tier: diamondTierForImportance(h.importance), animate: false))),
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Widget _jornada() {
    final items = _timelineItems();
    // agrupa por mes/ano
    final groups = <String, List<_TimelineItem>>{};
    for (final it in items) {
      groups.putIfAbsent("${_monthLong[it.date.month - 1].toUpperCase()} ${it.date.year}", () => []).add(it);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_texts.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      const SizedBox(height: 4),
      Text(_texts.subtitle, style: const TextStyle(color: _lilacSoft, fontSize: 13.5, height: 1.35)),
      const SizedBox(height: 18),
      if (items.isNotEmpty)
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(g.key, style: const TextStyle(color: _lilac, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(children: [
              for (var i = 0; i < g.value.length; i++) _TimelineRow(item: g.value[i], showDivider: i < g.value.length - 1),
            ]),
          ),
          const SizedBox(height: 14),
        ],
      if (items.isEmpty)
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2B1260), Color(0xFF151A45)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lilac.withValues(alpha: 0.25)),
          ),
          child: const Column(children: [
            MDuckDiamond(size: 56),
            SizedBox(height: 12),
            Text("Sua jornada começa aqui", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text("Presentes, premiações, conquistas e marcos vão aparecer aqui, mês a mês.",
                textAlign: TextAlign.center, style: TextStyle(color: _lilacSoft, fontSize: 13.5, height: 1.4)),
          ]),
        )
    ]);
  }

  void _openJourneyDetails(InventoryEntry e) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Fechar",
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: child)),
      pageBuilder: (_, _, _) => _JourneyDetails(entry: e),
    );
  }
}

// ============================================================================
// Componentes
// ============================================================================

/// Cartao do mes: dias / horas / diamantes com os niveis de evolucao
/// (Ducker, Top Ducker, Ducker Elite, Ducker Lendario). Os niveis sao degraus
/// de progresso, nunca condicao pra ser "profissional". Constancia logo abaixo.
class MonthGoalCard extends StatelessWidget {
  final JourneySummary summary;
  const MonthGoalCard({super.key, required this.summary});

  static String _remaining(double v) {
    if (v <= 0) return "0";
    if (v >= 1000) return "${(v / 1000).ceil()}K";
    return v.ceil().toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final diamonds = s.currentDiamonds;
    final level = duckerLevelFor(diamonds);
    final next = nextMarco(diamonds);
    final top = highestMarco(diamonds);
    final texts = duckerCardTexts(diamonds);
    final lines = texts.message.split("\n");
    final legendary = top == 1000000; // 1 milhao: destaque dourado
    // ate os 80K a barra mira os 80K (referencia); depois, o proximo marco
    final beyond = level != DuckerLevel.ducker;
    final barTarget = beyond ? (next ?? duckerMarcos.last) : s.diamondTarget;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1786), Color(0xFF221262), Color(0xFF142050)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _lilac.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.3), blurRadius: 26, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(texts.title.toUpperCase(), style: const TextStyle(color: _lilac, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
        const SizedBox(height: 4),
        Text(
          lines.first,
          style: TextStyle(
            color: legendary ? _gold : (beyond ? Colors.white : _lilacSoft),
            fontSize: legendary ? 20 : (beyond ? 15 : 13),
            fontWeight: beyond ? FontWeight.w900 : FontWeight.w500,
            height: beyond ? 1.25 : 1.35,
          ),
        ),
        for (final l in lines.skip(1))
          Text(l, style: TextStyle(color: legendary && l.contains("MILHÃO") ? _gold : _lilacSoft, fontSize: 13, height: 1.35, fontWeight: legendary && l.contains("MILHÃO") ? FontWeight.w900 : FontWeight.w500)),
        const SizedBox(height: 16),
        _MetricRow(icon: Icons.calendar_month_rounded, label: "Dias de live", value: s.currentDays, target: s.daysTarget, format: (v) => v.round().toString()),
        const SizedBox(height: 12),
        _MetricRow(icon: Icons.schedule_rounded, label: "Horas ao vivo", value: s.currentHours, target: s.hoursTarget, format: (v) => v.floor().toString()),
        const SizedBox(height: 12),
        // depois dos 80K a barra recomeca rumo ao proximo marco; o selo
        // mostra o ultimo marco alcancado
        _MetricRow(
          diamond: true,
          label: "Diamantes",
          value: diamonds,
          target: barTarget,
          format: (v) => compactNumber(v),
          badge: beyond && top != null ? marcoLabel(top) : null,
        ),
        if (next != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            MDuckDiamond(size: 22, tier: diamondTierForValue(next), animate: false),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                beyond
                    ? TextSpan(children: [
                        TextSpan(text: "Faltam ${_remaining(next - diamonds)} para ", style: const TextStyle(color: _lilacSoft)),
                        TextSpan(text: marcoLabel(next), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ])
                    : TextSpan(children: [
                        const TextSpan(text: "Próximo degrau: ", style: TextStyle(color: _lilacSoft)),
                        TextSpan(text: marcoLabel(next), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        TextSpan(text: "  ·  faltam ${_remaining(next - diamonds)}", style: const TextStyle(color: _lilacSoft)),
                      ]),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ]),
        ],
        if (s.constancy != null) ...[
          const SizedBox(height: 14),
          ConstancyChip(constancy: s.constancy!, dark: false),
        ],
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData? icon;
  final bool diamond;
  final String label;
  final double value;
  final double target;
  final String Function(double) format;
  /// Selo pequeno ao lado do nome (ex.: "80K ✓" quando ja passou da referencia).
  final String? badge;
  const _MetricRow({this.icon, this.diamond = false, required this.label, required this.value, required this.target, required this.format, this.badge});

  @override
  Widget build(BuildContext context) {
    final done = target > 0 && value >= target;
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(
          width: 26,
          child: diamond ? const MDuckDiamond(size: 22, tier: DiamondTier.grande, animate: false) : Icon(icon, color: _lilac, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700))),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: _gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_rounded, color: _gold, size: 12),
                  const SizedBox(width: 2),
                  Text(badge!, style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
              ),
          ]),
        ),
        Text(format(value), style: TextStyle(color: done ? _gold : Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        Text(" / ${format(target)}", style: const TextStyle(color: _lilacSoft, fontSize: 14, fontWeight: FontWeight.w700)),
        if (done) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.check_circle_rounded, color: _gold, size: 18)),
      ]),
      const SizedBox(height: 6),
      _GlowBar(value: progress),
    ]);
  }
}

/// Primeiros 90 dias: desenvolvimento (dia atual, metricas do mes e
/// orientacoes da fase). Some depois do dia 90.
class _OnboardingCard extends StatelessWidget {
  final Onboarding onboarding;
  final JourneySummary summary;
  const _OnboardingCard({required this.onboarding, required this.summary});

  @override
  Widget build(BuildContext context) {
    final o = onboarding;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F3B5C), Color(0xFF16245A), Color(0xFF241046)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF5BD6F5).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: o.progress,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5BD6F5)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text("${o.day}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
                Text("de ${o.total}", style: const TextStyle(color: Color(0xFFBFEFFF), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("SEUS PRIMEIROS 90 DIAS", style: TextStyle(color: Color(0xFF8FE6FF), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              const SizedBox(height: 3),
              Text(o.phaseTitle, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 3),
              const Text("Tratar a live como profissão começa pela constância.", style: TextStyle(color: Color(0xFFBFD8F2), fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _MiniStat(label: "dias de live", value: summary.currentDays.round().toString()),
          _MiniStat(label: "horas", value: summary.currentHours.floor().toString()),
          _MiniStat(label: "diamantes", value: compactNumber(summary.currentDiamonds)),
        ]),
        const SizedBox(height: 14),
        for (final tip in o.tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: const Color(0xFF5BD6F5).withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF8FE6FF)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(tip, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Color(0xFFBFD8F2), fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Recordes da trajetoria (Conquistas): melhor mes e horas acumuladas.
class _RecordsCard extends StatelessWidget {
  final JourneySummary summary;
  const _RecordsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    Widget box(Widget leading, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2B1260), Color(0xFF151A45)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lilac.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                  Text(label, style: const TextStyle(color: _lilacSoft, fontSize: 11.5, height: 1.2)),
                ]),
              ),
            ]),
          ),
        );
    final period = s.recordPeriod;
    String periodLabel = "";
    if (period != null && period.contains("-")) {
      final parts = period.split("-");
      final m = int.tryParse(parts[1]) ?? 1;
      periodLabel = " em ${_monthShort[m - 1].toLowerCase()}/${parts[0]}";
    }
    return Row(children: [
      box(MDuckDiamond(size: 30, tier: diamondTierForValue(s.recordValue), animate: false), compactNumber(s.recordValue), "seu recorde no mês$periodLabel"),
      const SizedBox(width: 10),
      box(const Icon(Icons.schedule_rounded, color: _lilac, size: 28), "${s.totalHours.floor()}h", "horas ao vivo na sua trajetória"),
    ]);
  }
}

class _GlowBar extends StatelessWidget {
  final double value;
  const _GlowBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LayoutBuilder(builder: (context, box) {
        final fillW = (box.maxWidth * v).clamp(0.0, box.maxWidth);
        return SizedBox(
          height: 12,
          child: Stack(children: [
            Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6))),
            if (fillW > 0)
              Container(
                width: fillW < 12 ? 12 : fillW,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C5CFF), _lilac, Colors.white]),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: _lilac.withValues(alpha: 0.7), blurRadius: 10)],
                ),
              ),
          ]),
        );
      }),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _AchievementTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: a.unlocked ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B1260), Color(0xFF16163F)]) : null,
          color: a.unlocked ? null : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: a.unlocked ? _lilac.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.06)),
          boxShadow: a.unlocked ? [BoxShadow(color: _purple.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    colors: a.unlocked ? const [Color(0xFF4B1A93), Color(0xFF1B0B45)] : const [Color(0xFF2A2F45), Color(0xFF151827)],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (_, box) => Center(child: AchievementOrb(achievement: a, size: box.maxWidth * 0.62, locked: !a.unlocked)),
                ),
              ),
            ),
            if (!a.unlocked)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 14),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: a.unlocked ? Colors.white : Colors.white54, fontSize: 14, fontWeight: FontWeight.w800, height: 1.15)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: a.unlocked
                ? Row(children: [
                    const Icon(Icons.check_circle_rounded, color: _lilac, size: 14),
                    const SizedBox(width: 4),
                    Text("${a.unlockedAt!.day.toString().padLeft(2, "0")}/${a.unlockedAt!.month.toString().padLeft(2, "0")}/${a.unlockedAt!.year}",
                        style: const TextStyle(color: _lilac, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ])
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: a.progress, minHeight: 5, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Colors.white38)),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _TimelineItem {
  final DateTime date;
  final String title;
  final String typeLabel;
  final Color color;
  final Widget leading;
  final VoidCallback? onTap;
  const _TimelineItem({required this.date, required this.title, required this.typeLabel, required this.color, required this.leading, this.onTap});
}

/// Linha compacta da Jornada: data, miniatura (48px) ou icone do tipo,
/// titulo e o tipo na cor dele. A imagem grande so aparece nos detalhes.
class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  final bool showDivider;
  const _TimelineRow({required this.item, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final it = item;
    return InkWell(
      onTap: it.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))) : null,
        ),
        child: Row(children: [
          SizedBox(
            width: 38,
            child: Column(children: [
              Text(it.date.day.toString().padLeft(2, "0"), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(height: 2),
              Text(_monthShort[it.date.month - 1], style: TextStyle(color: it.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ]),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 48, height: 48, child: Center(child: it.leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 3),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(it.typeLabel, style: TextStyle(color: it.color, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
          if (it.onTap != null) const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
        ]),
      ),
    );
  }
}

/// Detalhe de um registro da Jornada MDUCK: imagem como protagonista, tipo,
/// data por extenso, descricao e quem registrou.
class _JourneyDetails extends StatelessWidget {
  final InventoryEntry entry;
  const _JourneyDetails({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = entry.type;
    final d = entry.occurredAt;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(18),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86, maxWidth: 520),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B1260), Color(0xFF121535)]),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: t.color.withValues(alpha: 0.5)),
              boxShadow: [BoxShadow(color: t.color.withValues(alpha: 0.35), blurRadius: 40)],
            ),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (entry.imageUrl != null)
                  Stack(children: [
                    Image(image: MediaCacheImage(entry.imageUrl!), width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 40)),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.4)),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ])
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
                    child: Row(children: [
                      JourneyTypeIcon(category: entry.category, color: t.color, size: 76),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: t.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.color.withValues(alpha: 0.6))),
                      child: Text(t.label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                    ),
                    const SizedBox(height: 10),
                    Text(entry.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.4)),
                    const SizedBox(height: 6),
                    Text("${d.day} de ${_monthLong[d.month - 1]} de ${d.year}", style: const TextStyle(color: _lilac, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (entry.description != null) ...[
                      const SizedBox(height: 16),
                      Text(entry.description!, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.5)),
                    ],
                    if (entry.amount != null) ...[
                      const SizedBox(height: 16),
                      Text(formatBrl(entry.amount!), style: const TextStyle(color: Color(0xFF7FF0D8), fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                    const SizedBox(height: 20),
                    Container(height: 1, color: Colors.white10),
                    const SizedBox(height: 14),
                    Row(children: [
                      const MDuckDiamond(size: 20, animate: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.responsible != null ? "Registrado por ${entry.responsible} · MDuck Agency" : "MDuck Agency",
                          style: const TextStyle(color: _lilacSoft, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
