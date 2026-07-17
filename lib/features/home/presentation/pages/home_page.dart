import "package:flutter/material.dart";
import "package:video_player/video_player.dart";
import "../../data/streamer_repository.dart";
import "../widgets/stat_card.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = StreamerRepository();
  late Future<StreamerSummary> _summaryFuture;
  late VideoPlayerController _videoController;
  int _bottomIndex = 3;

  static const _brandPurple = Color(0xFF7A0BD4);
  static const _milestones = [10000, 20000, 40000, 80000, 150000, 250000, 350000, 500000, 800000, 1000000];
  static const _topTierStart = 80000;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.fetchCurrentStreamerSummary();
    _videoController = VideoPlayerController.asset("assets/videos/manha.mp4");
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _videoController.setLooping(true);
      _videoController.play();
    }).catchError((error) {
      // ignore: avoid_print
      print("ERRO AO CARREGAR VIDEO DE FUNDO: $error");
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController.value.isInitialized)
            Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            )
          else
            Container(color: Colors.black),
          SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset("assets/videos/LogoMduck.png", height: 64, fit: BoxFit.contain),
                      const Spacer(),
                      const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<StreamerSummary>(
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
                        padding: const EdgeInsets.all(16),
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
                                    backgroundImage: summary.avatarUrl != null
                                        ? NetworkImage(summary.avatarUrl!)
                                        : null,
                                    child: summary.avatarUrl == null
                                        ? const Icon(Icons.person, color: Colors.white, size: 26)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "@${summary.displayName}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (summary.categoryName.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Text("\u2694\ufe0f", style: TextStyle(fontSize: 12)),
                                              const SizedBox(width: 4),
                                              Text(
                                                summary.categoryName,
                                                style: const TextStyle(
                                                  color: _brandPurple,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                                        style: const TextStyle(
                                          color: _brandPurple,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        "Posicao na agencia",
                                        style: TextStyle(color: Colors.white70, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                    valueText: "${summary.diamonds}",
                                    progress: summary.diamonds / _milestones.last,
                                    progressColor: _brandPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "\ud83d\udc51 PROGRESSO DUCKER",
                                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final barWidth = constraints.maxWidth;
                                      final n = _milestones.length;

                                      int reachedIndex = -1;
                                      for (int i = 0; i < n; i++) {
                                        if (summary.diamonds >= _milestones[i]) reachedIndex = i;
                                      }
                                      final prevValue = reachedIndex >= 0 ? _milestones[reachedIndex] : 0;
                                      final nextValue = reachedIndex + 1 < n ? _milestones[reachedIndex + 1] : _milestones[n - 1];
                                      final segmentFraction = nextValue == prevValue
                                          ? 1.0
                                          : ((summary.diamonds - prevValue) / (nextValue - prevValue)).clamp(0.0, 1.0);
                                      final trackFraction = ((reachedIndex + segmentFraction) / (n - 1)).clamp(0.0, 1.0);
                                      final fillWidth = barWidth * trackFraction;

                                      return SizedBox(
                                        height: 22,
                                        child: Stack(
                                          children: [
                                            Align(
                                              alignment: Alignment.center,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(height: 6, width: double.infinity, color: Colors.white24),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    height: 6,
                                                    width: fillWidth,
                                                    decoration: const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: List.generate(n, (i) {
                                                  final reached = i <= reachedIndex;
                                                  return Container(
                                                    width: 9,
                                                    height: 9,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: reached ? Colors.amber : Colors.white38,
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                            Positioned(
                                              left: (fillWidth - 7).clamp(0.0, barWidth - 15),
                                              top: 0,
                                              bottom: 0,
                                              child: Center(
                                                child: Container(
                                                  width: 15,
                                                  height: 15,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.amber,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: _milestones.map((m) {
                                      final highlight = m >= _topTierStart;
                                      final label = m >= 1000000 ? "${(m / 1000000).toStringAsFixed(0)}M" : "${(m / 1000).toStringAsFixed(0)}K";
                                      return Text(
                                        label,
                                        style: TextStyle(
                                          color: highlight ? Colors.amber : Colors.white54,
                                          fontSize: 10,
                                          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _BottomNav(
                  currentIndex: _bottomIndex,
                  onTap: (i) => setState(() => _bottomIndex = i),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _brandPurple = Color(0xFF7A0BD4);

  static const _items = [
    (Icons.emoji_events, "Ranking"),
    (Icons.assignment_turned_in, "Missoes"),
    (Icons.landscape, "Ilha Top"),
    (Icons.home, "Home"),
    (Icons.calendar_month, "Calendario"),
    (Icons.backpack, "Inventario"),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < _items.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _items[i].$1,
                    color: currentIndex == i ? _brandPurple : Colors.white60,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _items[i].$2,
                    style: TextStyle(
                      color: currentIndex == i ? _brandPurple : Colors.white60,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brandPurple,
                  ),
                  child: const Icon(Icons.pets, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 2),
                const Text("Max", style: TextStyle(color: Colors.white60, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


