import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/academia/ui/academy_blocks.dart";
import "package:mduck_lives/features/academia/ui/academy_theme.dart";

/// Previas da aula Baú, Portal e Sacola (migracao 0111).
///   flutter test --update-goldens test/academia_aula02_test.dart
Future<void> _fonts() async {
  const dir = r"C:\src\flutter\bin\cache\artifacts\material_fonts";
  final roboto = FontLoader("Roboto");
  for (final f in ["roboto-regular.ttf", "roboto-medium.ttf", "roboto-bold.ttf", "roboto-black.ttf"]) {
    roboto.addFont(Future.value(ByteData.view(File("$dir/$f").readAsBytesSync().buffer)));
  }
  await roboto.load();
  final icons = FontLoader("MaterialIcons")..addFont(Future.value(ByteData.view(File("$dir\/materialicons-regular.otf").readAsBytesSync().buffer)));
  await icons.load();
}

String _between(String s, String a, String b) {
  final i = s.indexOf(a) + a.length;
  return s.substring(i, s.indexOf(b, i));
}

List<Map<String, dynamic>> _blocks() {
  final sql = File(r"C:\Users\gisel\mduck_web_adm\supabase\migrations\0111_academia_aula02_bau_portal_sacola.sql").readAsStringSync();
  final menu = jsonDecode(_between(sql, r"$m$", r"$m$::jsonb"));
  final chat = jsonDecode(_between(sql, r"$c$", r"$c$::jsonb"));
  return [
    for (final b in jsonDecode(_between(sql, "v_blocks := \$json\$", r"$json$::jsonb")) as List)
      {...Map<String, dynamic>.from(b as Map), if (b["type"] == "live_menu") "items": menu, if (b["type"] == "live_menu") "chat": chat},
  ];
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

  testWidgets("menu", (t) async {
    await size(t, 700);
    final b = _blocks();
    final menu = b.firstWhere((x) => x["type"] == "live_menu");
    await t.pumpWidget(_page([menu]));
    await wait(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula02_1_live.png"));
    await t.tap(find.byIcon(Icons.more_horiz));
    await wait(t, 600);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula02_2_menu.png"));
  });

  testWidgets("telas", (t) async {
    await size(t, 4200);
    final b = _blocks().where((x) => x["type"] == "tiktok_sheet" || x["type"] == "compare").toList();
    await t.pumpWidget(_page(b.take(5).toList()));
    await t.tap(find.text("BAÚ").first);
    await t.tap(find.text("Enviar").first);
    await wait(t, 4500);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula02_3_telas.png"));
  });

  testWidgets("espectador", (t) async {
    await size(t, 700);
    final sql = File(r"C:\Users\gisel\mduck_web_adm\supabase\migrations\0113_aula02_espectador_so_bau.sql").readAsStringSync();
    final v = Map<String, dynamic>.from(jsonDecode(_between(sql, r"b || $v$", r"$v$::jsonb")) as Map);
    v["type"] = "viewer_view";
    v["title"] = "Onde o espectador encontra";
    v["host"] = "Lucas Martins";
    await t.pumpWidget(_page([v]));
    await wait(t, 400);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula02_5_espectador.png"));
  });

  testWidgets("sacola", (t) async {
    await size(t, 2400);
    final b = _blocks().where((x) => x["type"] == "tiktok_sheet").toList();
    await t.pumpWidget(_page(b.sublist(4)));
    await wait(t, 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/aula02_4_sacola.png"));
  });
}

