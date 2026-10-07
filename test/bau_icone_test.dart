import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/academia/ui/academy_interactive.dart";

void main() {
  testWidgets("bau_icone", (t) async {
    t.view.physicalSize = const Size(700, 360);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TreasureChest(size: 220),
            TreasureChest(size: 220, portal: true),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/bau_icone.png"));
  });
}
