import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/academia/ui/academy_blocks.dart";
import "package:mduck_lives/features/academia/ui/academy_theme.dart";

/// Previas da Aula 01 (Perfil, Liga e Galeria) com o conteudo da migracao 0107.
///   flutter test --update-goldens test/academia_aula01_test.dart
Future<void> _fonts() async {
  const dir = r"C:\src\flutter\bin\cache\artifacts\material_fonts";
  final roboto = FontLoader("Roboto");
  for (final f in ["roboto-regular.ttf", "roboto-medium.ttf", "roboto-bold.ttf", "roboto-black.ttf"]) {
    roboto.addFont(Future.value(ByteData.view(File("$dir\\$f").readAsBytesSync().buffer)));
  }
  final emoji = File(r"C:\Windows\Fonts\seguiemj.ttf");
  if (emoji.existsSync()) roboto.addFont(Future.value(ByteData.view(emoji.readAsBytesSync().buffer)));
  await roboto.load();
  final icons = FontLoader("MaterialIcons")..addFont(Future.value(ByteData.view(File("$dir\\materialicons-regular.otf").readAsBytesSync().buffer)));
  await icons.load();
}

List<Map<String, dynamic>> _blocks() {
  final sql = File(r"C:\Users\gisel\mduck_web_adm\supabase\migrations\0107_academia_aula01_perfil_galeria.sql").readAsStringSync();
  final start = sql.indexOf(r"$json$") + 6;
  final end = sql.indexOf(r"$json$::jsonb");
  return [for (final b in jsonDecode(sql.substring(start, end)) as List) Map<String, dynamic>.from(b as Map)];
}

Widget _page(List<Map<String, dynamic>> blocks) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: "Roboto")),
      home: Scaffold(
        backgroundColor: acBgMid,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < blocks.length; i++) ...[
              AcademyBlock(block: blocks[i], index: i, accent: const Color(0xFFA5B4FC)),
              const SizedBox(height: 24),
            ],
          ]),
        ),
      ),
    );

Future<void> wait(WidgetTester t, int ms) async {
  for (var e = 0; e < ms; e += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(_fonts);

  Future<void> size(WidgetTester t, double h) async {
    t.view.physicalSize = Size(412 * 2, h * 2);
    t.view.devicePixelRatio = 2;
  }

  testWidgets("aula01_batalha_e_perfil", (t) async {
    await size(t, 1500);
    final b = _blocks();
    await t.pumpWidget(_page([b[1]]));
    await wait(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_1_batalha.png"));
    await t.tap(find.textContaining("Lucas").first);
    await wait(t, 900);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_2_perfil.png"));
    await t.tap(find.textContaining("A1 · Nº 7"));
    await wait(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_3_explica_liga.png"));
  });

  testWidgets("aula01_liga", (t) async {
    await size(t, 900);
    final b = _blocks();
    await t.pumpWidget(_page([b[2]]));
    await t.tap(find.text("A"));
    await wait(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_4_liga.png"));
  });

  testWidgets("aula01_galeria", (t) async {
    await size(t, 1250);
    final b = _blocks();
    await t.pumpWidget(_page([b[3]]));
    await t.tap(find.text("Ver a Galeria sendo iluminada"));
    await wait(t, 1300);
    await wait(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_5_galeria_iluminando.png"));
    await wait(t, 2500);
    await wait(t, 700);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_6_galeria_iluminada.png"));
    await t.tap(find.text("TikTok Universe"));
    await wait(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_7_presente.png"));
  });

  testWidgets("aula01_final", (t) async {
    await size(t, 2600);
    final b = _blocks();
    await t.pumpWidget(_page(b.sublist(4)));
    await t.tap(find.text("Ver a disputa"));
    for (var i = 0; i < 5; i++) {
      await wait(t, 900);
    }
    await wait(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula01_8_final.png"));
  });
}
