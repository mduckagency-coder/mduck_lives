import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/inventory/widgets/achievement_art.dart";

/// Gera uma folha com todas as artes de conquista (previa visual).
/// Rodar: flutter test test/achievement_art_preview_test.dart --update-goldens
void main() {
  testWidgets("previa das artes de conquista", (tester) async {
    const keys = [
      "marco_1", "marco_2", "marco_3", "marco_4", "marco_5", "marco_6", "marco_7", "marco_8",
      "mensal_1", "mensal_3", "mensal_5", "mensal_7",
      "consistencia_1", "consistencia_2", "consistencia_3",
      "horas_1", "horas_2", "horas_3", "horas_4",
      "dias_1", "dias_2", "dias_3",
    ];
    tester.view.physicalSize = const Size(1200, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: const Color(0xFF0E0718),
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in keys) SizedBox(width: 136, child: AchievementArt(artKey: k)),
              const SizedBox(width: 136, child: AchievementArt(artKey: "marco_5", locked: true)),
            ],
          ),
        ),
      ),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/achievement_art_preview.png"));
  });
}
