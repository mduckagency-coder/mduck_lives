import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/inventory/data/journey_repository.dart";
import "package:mduck_lives/features/inventory/widgets/month_milestones.dart";

/// Previa da arte montada automaticamente (arte real do painel + foto).
///   flutter test --update-goldens test/arte_automatica_preview_test.dart
/// Usa a arte em test/fixtures/arte_10k.jpeg (se existir).
void main() {
  testWidgets("arte_automatica", (tester) async {
    final art = File("test/fixtures/arte_10k.jpeg");
    if (!art.existsSync()) return;
    const dir = r"C:\src\flutter\bin\cache\artifacts\material_fonts";
    final roboto = FontLoader("Roboto");
    for (final f in ["roboto-bold.ttf", "roboto-black.ttf"]) {
      roboto.addFont(Future.value(ByteData.view(File("$dir\\$f").readAsBytesSync().buffer)));
    }
    await roboto.load();

    final artBytes = art.readAsBytesSync();
    final avatarBytes = File("assets/icon/app_icon.png").readAsBytesSync();
    milestoneArtTestBytes = (url) => url == "avatar" ? avatarBytes : artBytes;

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    const m = MonthMilestone(
      id: "10k",
      value: 10000,
      title: "10K",
      importance: 1,
      reached: true,
      seen: true,
      isHighest: true,
      periodKey: "2026-10",
      currentDiamonds: 12000,
      classicUrl: "arte",
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: "Roboto"),
        home: const Material(child: SizedBox(width: 360, height: 640, child: MilestoneArtCard(milestone: m, streamerName: "gidreams_", avatarUrl: "avatar"))),
      ));
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      for (final e in find.byType(Image).evaluate()) {
        final w = e.widget as Image;
        await precacheImage(w.image, e);
      }
      await tester.pump();
    });
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/v5_arte_automatica.png"));
  });
}
