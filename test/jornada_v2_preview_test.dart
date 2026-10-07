import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/inventory/data/achievements_repository.dart";
import "package:mduck_lives/features/inventory/data/journey_repository.dart";
import "package:mduck_lives/features/inventory/inventory_content.dart";
import "package:mduck_lives/features/inventory/data/ducker_level.dart";
import "package:mduck_lives/features/inventory/widgets/level_up_celebration.dart";
import "package:mduck_lives/features/inventory/widgets/constancy_flame.dart";
import "package:mduck_lives/features/inventory/widgets/journey_crest.dart";
import "package:mduck_lives/features/inventory/widgets/journey_type_icon.dart";
import "package:mduck_lives/features/inventory/widgets/mduck_diamond.dart";
import "package:mduck_lives/features/inventory/widgets/month_milestones.dart";
import "package:mduck_lives/features/inventory/widgets/trail_icon.dart";

/// Previas visuais da Jornada v2 com fontes reais (Roboto/MaterialIcons do
/// SDK). Gerar com:
///   flutter test --update-goldens test/jornada_v2_preview_test.dart
Future<void> _loadFonts() async {
  const dir = r"C:\src\flutter\bin\cache\artifacts\material_fonts";
  final roboto = FontLoader("Roboto");
  for (final f in ["roboto-regular.ttf", "roboto-medium.ttf", "roboto-bold.ttf", "roboto-black.ttf", "roboto-light.ttf"]) {
    final file = File("$dir\\$f");
    if (file.existsSync()) roboto.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await roboto.load();
  final icons = FontLoader("MaterialIcons")..addFont(Future.value(ByteData.view(File("$dir\\materialicons-regular.otf").readAsBytesSync().buffer)));
  await icons.load();
}

Achievement _a(String code, String title, String stage, int order, String icon,
        {bool done = false, double progress = 0, String rule = "month_days", double threshold = 100}) =>
    Achievement(
      id: code,
      code: code,
      title: title,
      description: "",
      family: "dias",
      ruleType: rule,
      threshold: threshold,
      months: 3,
      trailStage: stage,
      trailOrder: order,
      iconKey: icon,
      unlockedAt: done ? DateTime(2026, 9, 30) : null,
      seen: true,
      currentValue: progress * threshold,
    );

MonthMilestone _m(double v, String t, int imp, {bool reached = true, bool highest = false}) => MonthMilestone(
      id: t,
      value: v,
      title: t,
      importance: imp,
      reached: reached,
      seen: true,
      isHighest: highest,
      periodKey: "2026-10",
      currentDiamonds: 312450,
    );

Widget _app(Widget child, {Color bg = const Color(0xFF0C1230)}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Roboto"),
      home: Scaffold(backgroundColor: bg, body: child),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets("emblemas_brasoes_diamantes", (tester) async {
    tester.view.physicalSize = const Size(640, 520);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          JourneyCrest(crestKey: "prata", size: 130, animate: false),
          JourneyCrest(crestKey: "cristal", size: 130, animate: false),
          JourneyCrest(crestKey: "premium", size: 130, animate: false),
          JourneyCrest(crestKey: "merito", size: 130, animate: false),
        ]),
        const SizedBox(height: 16),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          MDuckDiamond(size: 70, animate: false),
          MDuckDiamond(size: 70, tier: DiamondTier.marco, animate: false),
          MDuckDiamond(size: 70, tier: DiamondTier.grande, animate: false),
          MDuckDiamond(size: 70, tier: DiamondTier.lendario, animate: false),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final k in ["portal", "steps", "crystal", "crystals", "laurel", "clock", "hourglass", "flame", "crown", "plaque"])
            TrailEmblem(iconKey: k, frame: k == "crown" || k == "plaque" ? EmblemFrame.gold : EmblemFrame.silver, size: 76),
          const TrailEmblem(iconKey: "diamond", frame: EmblemFrame.crystal, size: 76, diamondTier: DiamondTier.grande),
          const TrailEmblem(iconKey: "laurel", locked: true, size: 76),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 10, children: [
          for (final t in [("presente", 0xFFD65CFF), ("treinamento", 0xFF5B8CFF), ("recompensa", 0xFF9B5CFF), ("pix", 0xFF2EC4B6), ("campanha", 0xFFFF6FB5), ("suporte", 0xFF3FB6CF), ("evento", 0xFF7C5CFF), ("outros", 0xFF8E9AB8)])
            JourneyTypeIcon(category: t.$1, color: Color(t.$2), size: 56),
        ]),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v2_pecas.png"));
  });

  testWidgets("artes", (tester) async {
    tester.view.physicalSize = const Size(4 * 360 + 70, 640 + 20);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          for (final m in [_m(20000, "20K", 2), _m(80000, "80K", 4), _m(150000, "150K", 5), _m(350000, "350K", 6)]) ...[
            SizedBox(width: 360, height: 640, child: MilestoneArtCard(milestone: m, streamerName: "gidreams_")),
            const SizedBox(width: 10),
          ],
        ]),
      ),
      bg: Colors.black,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v2_artes.png"));
  });

  testWidgets("marcos_do_mes", (tester) async {
    tester.view.physicalSize = const Size(412, 420);
    tester.view.devicePixelRatio = 1;
    final ms = [
      _m(10000, "10K", 1),
      _m(20000, "20K", 2),
      _m(40000, "40K", 3),
      _m(80000, "80K", 4),
      _m(150000, "150K", 5),
      _m(250000, "250K", 5),
      _m(350000, "350K", 6, highest: true),
      _m(500000, "500K", 6, reached: false),
      _m(800000, "800K", 7, reached: false),
      _m(1000000, "1M", 7, reached: false),
      _m(1200000, "1,2M", 8, reached: false),
      _m(1600000, "1,6M", 8, reached: false),
    ];
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(16),
      child: MonthMilestonesSection(milestones: ms, streamerName: "gidreams_"),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v2_marcos.png"));
  });

  testWidgets("constancia", (tester) async {
    tester.view.physicalSize = const Size(412, 430);
    tester.view.devicePixelRatio = 1;
    const states = [
      ("forte", "Constância forte", "Você está no ritmo de um mês profissional.", 0.9),
      ("evolucao", "Em evolução", "Sua frequência está subindo em relação ao mês passado.", 0.6),
      ("estavel", "Ritmo estável", "Você está mantendo o ritmo. Rumo aos 22 dias e 100 horas.", 0.5),
      ("retomando", "Retomando", "Que bom te ver de volta! Mantenha as lives nos próximos dias.", 0.35),
      ("alerta", "Chama baixa", "Alguns dias sem live. Uma live hoje já reacende sua constância.", 0.15),
    ];
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        for (final s in states) ...[
          ConstancyChip(constancy: Constancy(state: s.$1, label: s.$2, message: s.$3, intensity: s.$4)),
          const SizedBox(height: 8),
        ],
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v4_constancia.png"));
  });

  test("goal parse", () {
    final g = JourneyGoal.fromMap({"mode": "comeback", "recommended": 80000, "current_target": 80000, "label": "Seu próximo marco", "message": "Vamos buscar os 80K novamente.", "current": 12000});
    expect(g!.recommended, 80000);
    expect(g.progress, closeTo(0.15, 0.001));
  });

  testWidgets("meta_do_mes_estados", (tester) async {
    tester.view.physicalSize = const Size(3 * 390 + 30, 2 * 400 + 30);
    tester.view.devicePixelRatio = 1;
    JourneySummary s(double d, double h, double dia) => JourneySummary(
          name: "gidreams_",
          stageName: "",
          crestKey: "prata",
          unlocked: 0,
          total: 0,
          currentDiamonds: dia,
          currentDays: d,
          currentHours: h,
          daysTarget: 22,
          hoursTarget: 100,
          diamondTarget: 80000,
          totalHours: 0,
          recordValue: 0,
        );
    final cases = [s(9, 31, 27000), s(17, 82, 96000), s(20, 95, 171000), s(23, 104, 262000), s(25, 130, 1040000), s(27, 140, 1650000)];
    await tester.pumpWidget(_app(Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in cases) SizedBox(width: 380, height: 390, child: MonthGoalCard(summary: c)),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v3_meta_do_mes.png"));
  });

  testWidgets("novo_nivel", (tester) async {
    tester.view.physicalSize = const Size(412, 560);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Center(
        child: TextButton(onPressed: () => showDuckerLevelUp(context, DuckerLevel.elite), child: const Text("abrir")),
      ),
    )));
    await tester.tap(find.text("abrir"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v3_novo_nivel.png"));
  });
}
