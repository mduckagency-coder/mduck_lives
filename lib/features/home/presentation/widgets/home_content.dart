import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "../../../inventory/data/journey_repository.dart";
import "../../../inventory/widgets/achievement_widgets.dart" show compactNumber;
import "../../../inventory/widgets/mduck_diamond.dart";
import "../../data/streamer_repository.dart";
import "beta_welcome.dart";
import "stat_card.dart";

/// Home: metas profissionais do mes (dias X/22, horas X/100, diamantes
/// X/80K), a chama da Constancia e os Marcos do Mes (diamantes).
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _repository = StreamerRepository();
  final _journey = JourneyRepository();
  late Future<StreamerSummary> _summaryFuture;
  List<MonthMilestone> _milestones = const [];
  DateTime? _metricsUpdatedAt;

  static const _brandPurple = Color(0xFF7A0BD4);

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.fetchCurrentStreamerSummary();
    _journey.fetchMonthMilestones().then((m) {
      if (mounted) setState(() => _milestones = m);
    }).catchError((_) {});
    _repository.fetchMetricsUpdatedAt().then((d) {
      if (mounted) setState(() => _metricsUpdatedAt = d);
    });
    // aviso de boas-vindas da versao Beta (uma vez por versao)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowBetaWelcome(context);
    });
  }

  /// "03/10/2026 às 14:20"
  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.day)}/${two(d.month)}/${d.year} às ${two(d.hour)}:${two(d.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StreamerSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Nao foi possivel carregar seus dados.\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final summary = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      backgroundImage: summary.avatarUrl != null ? MediaCacheImage(summary.avatarUrl!) : null,
                      child: summary.avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 26) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("@${summary.displayName}", style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          if (summary.categoryName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Text("\u2694\ufe0f", style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(summary.categoryName, style: const TextStyle(color: _brandPurple, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          summary.rankingPosition != null ? "#${summary.rankingPosition}" : "#-",
                          style: const TextStyle(color: _brandPurple, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Text("Posicao na agencia", style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.calendar_today,
                      iconColor: _brandPurple,
                      label: "DIAS",
                      valueText: "${summary.daysLive}/${summary.daysTarget}",
                      progress: summary.daysTarget == 0 ? 0 : summary.daysLive / summary.daysTarget,
                      progressColor: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      icon: Icons.access_time,
                      iconColor: Colors.orangeAccent,
                      label: "HORAS",
                      valueText: "${summary.hoursLive.toStringAsFixed(0)}/${summary.hoursTarget.toStringAsFixed(0)}",
                      progress: summary.hoursTarget == 0 ? 0 : summary.hoursLive / summary.hoursTarget,
                      progressColor: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      icon: Icons.diamond,
                      iconColor: _brandPurple,
                      label: "DIAMANTES",
                      valueText: "${compactNumber(summary.diamonds.toDouble())}/80K",
                      progress: (summary.diamonds / 80000).clamp(0.0, 1.0),
                      progressColor: _brandPurple,
                    ),
                  ),
                ],
              ),
              // a Constancia fica na parte de baixo da Home (HomeConstancyBar)
              const SizedBox(height: 8),
              _HomeMilestones(milestones: _milestones, diamonds: summary.diamonds.toDouble()),
              if (_metricsUpdatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Última atualização: ${_fmt(_metricsUpdatedAt!)}",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Marcos do Mes na Home: os diamantes do mes (10K ... 1,6M), brilhando os
/// ja batidos; o 80K em destaque (grande marco do mes).
class _HomeMilestones extends StatelessWidget {
  final List<MonthMilestone> milestones;
  final double diamonds;
  const _HomeMilestones({required this.milestones, required this.diamonds});

  @override
  Widget build(BuildContext context) {
    final next = milestones.where((m) => !m.reached).firstOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("MARCOS DO MÊS", style: TextStyle(color: Color(0xFFD6B8FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
          const Spacer(),
          if (next != null)
            Text("próximo: ${next.title.isNotEmpty ? next.title : compactNumber(next.value)}",
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        if (milestones.isEmpty)
          const SizedBox(height: 50, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final m = milestones[i];
                final big = m.value == 80000;
                return SizedBox(
                  width: 40,
                  child: Column(children: [
                    Opacity(
                      opacity: m.reached ? 1 : 0.35,
                      child: MDuckDiamond(size: 28, tier: diamondTierForImportance(m.importance), animate: m.reached),
                    ),
                    const SizedBox(height: 2),
                    Text(m.title.isNotEmpty ? m.title : compactNumber(m.value),
                        style: TextStyle(
                          color: m.reached ? Colors.white : (big ? const Color(0xFFFFD978) : Colors.white54),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        )),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}
