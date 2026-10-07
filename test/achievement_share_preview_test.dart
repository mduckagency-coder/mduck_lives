import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/inventory/data/achievements_repository.dart";
import "package:mduck_lives/features/inventory/widgets/achievement_widgets.dart";
import "package:mduck_lives/features/inventory/widgets/inventory_emblem_icon.dart";

/// Previa do card de compartilhamento e do emblema do menu.
/// Rodar: flutter test test/achievement_share_preview_test.dart --update-goldens
/// (nos testes o texto aparece como blocos -- serve pra conferir a composicao)
void main() {
  testWidgets("previa do card de compartilhamento", (tester) async {
    tester.view.physicalSize = const Size(760, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = Achievement(
      id: "x",
      code: "total_80k",
      title: "Primeiros 80K",
      description: "Sua história com a MDUCK somou 80.000 diamantes.",
      family: "marco",
      ruleType: "total_diamonds",
      threshold: 80000,
      months: 3,
      artKey: "marco_5",
      unlockedAt: DateTime(2026, 9, 14),
      seen: true,
      currentValue: 90000,
    );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        color: const Color(0xFF070D1A),
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 360, height: 640, child: AchievementShareCard(achievement: a, streamerName: "gidreams_")),
          const SizedBox(width: 40),
          const Column(children: [
            InventoryEmblemIcon(color: Color(0xFF7A0BD4), size: 120),
            SizedBox(height: 20),
            InventoryEmblemIcon(color: Colors.white60, size: 60),
            SizedBox(height: 20),
            InventoryEmblemIcon(color: Colors.white60, size: 22),
          ]),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/achievement_share_preview.png"));
  });
}
