import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mduck_lives/features/academia/data/academy_models.dart";
import "package:mduck_lives/features/academia/data/academy_repository.dart";
import "package:mduck_lives/features/academia/ui/academy_home.dart";
import "package:mduck_lives/features/academia/ui/academy_lesson_page.dart";
import "package:mduck_lives/features/academia/ui/live_scenes.dart";

/// Previas da Academia com o conteudo inicial real (migracao 0102 do painel).
///   flutter test --update-goldens test/academia_preview_test.dart
Future<void> _fonts() async {
  const dir = r"C:\src\flutter\bin\cache\artifacts\material_fonts";
  final roboto = FontLoader("Roboto");
  for (final f in ["roboto-regular.ttf", "roboto-medium.ttf", "roboto-bold.ttf", "roboto-black.ttf"]) {
    roboto.addFont(Future.value(ByteData.view(File("$dir\\$f").readAsBytesSync().buffer)));
  }
  await roboto.load();
  final icons = FontLoader("MaterialIcons")..addFont(Future.value(ByteData.view(File("$dir\\materialicons-regular.otf").readAsBytesSync().buffer)));
  await icons.load();
}

Map<String, dynamic> _seed() {
  final sql = File(r"C:\Users\gisel\mduck_web_adm\supabase\migrations\0102_academia_conteudo_inicial.sql").readAsStringSync();
  final start = sql.indexOf(r"$json$") + 6;
  final end = sql.indexOf(r"$json$::jsonb");
  return jsonDecode(sql.substring(start, end)) as Map<String, dynamic>;
}

class _FakeRepo extends AcademyRepository {
  final Map<String, dynamic> seed;
  final String audience;
  const _FakeRepo(this.seed, this.audience);

  Map<String, dynamic> _lessonJson(Map l, int i) => {
        "id": l["slug"],
        "slug": l["slug"],
        "category_id": l["cat"],
        "subcategory": l["sub"],
        "title": l["title"],
        "subtitle": l["subtitle"],
        "summary": l["summary"],
        "audience": l["audience"],
        "level": l["level"],
        "featured": l["featured"] ?? false,
        "recommended": l["recommended"] ?? false,
        "start_here": l["start_here"] ?? false,
        "series_id": l["series"],
        "series_order": l["series_order"],
        "sort_order": l["order"] ?? 0,
        "duration_min": l["dur"],
        "tags": l["tags"] ?? [],
        "availability": l["slug"] == "x_em_breve_games_avancado" ? "em_breve" : "disponivel",
        "status": "publicado",
        "access": l["slug"] == "x_em_breve_games_avancado" ? "soon" : (i % 5 == 4 ? "locked" : "open"),
        "block_types": [for (final b in (l["blocks"] as List)) b["type"]],
        "progress_status": i == 1 ? "em_andamento" : (i == 0 || i == 9 ? "concluido" : null),
        "progress": i == 1 ? 0.4 : 0,
        "sources": l["sources"] ?? [],
        "blocks": l["blocks"],
      };

  @override
  Future<AcademyCatalog> fetchCatalog() async {
    final ls = seed["lessons"] as List;
    return AcademyCatalog.fromJson({
      "audience": audience,
      "categories": [for (final c in seed["categories"]) {...c, "id": c["slug"], "sort_order": c["order"]}],
      "series": [for (final s in seed["series"]) {...s, "id": s["slug"], "category_id": s["cat"], "sort_order": s["order"]}],
      "lessons": [for (var i = 0; i < ls.length; i++) _lessonJson(ls[i] as Map, i)],
    });
  }

  @override
  Future<AcademyLesson?> fetchLesson(String id) async {
    final ls = seed["lessons"] as List;
    final i = ls.indexWhere((l) => l["slug"] == id);
    return AcademyLesson.fromJson({..._lessonJson(ls[i] as Map, i), "info_status": "revisar"});
  }

  @override
  Future<void> track(String lessonId, String event, {double? progress, Map<String, dynamic>? quiz}) async {}
}

Widget _app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Roboto", brightness: Brightness.dark),
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(_fonts);
  final seed = _seed();

  testWidgets("academia_home", (tester) async {
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(AcademyHome(repo: _FakeRepo(seed, "games"))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/academia_home.png"));
  });

  testWidgets("academia_aula_batalha", (tester) async {
    tester.view.physicalSize = const Size(412, 4200);
    tester.view.devicePixelRatio = 1;
    final repo = _FakeRepo(seed, "batalhas");
    final cat = await repo.fetchCatalog();
    final l = cat.lessons.firstWhere((x) => x.isOpen && x.categoryId == "batalhas" && x.hasSimulation && x.hasQuiz);
    await tester.pumpWidget(_app(AcademyLessonPage(repo: repo, summary: l, category: cat.categoryOf(l))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/academia_aula_batalha.png"));
  });

  testWidgets("academia_aula_bloqueada", (tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    final repo = _FakeRepo(seed, "todos");
    final cat = await repo.fetchCatalog();
    final l = cat.lessons.firstWhere((x) => x.isLocked);
    await tester.pumpWidget(_app(AcademyLessonPage(repo: repo, summary: l, category: cat.categoryOf(l))));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/academia_aula_bloqueada.png"));
  });

  testWidgets("academia_simulacoes", (tester) async {
    tester.view.physicalSize = const Size(4 * 370, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(Container(
      color: const Color(0xFF0C1230),
      padding: const EdgeInsets.all(5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final s in ["batalha", "games", "musica", "conversa"])
          Padding(padding: const EdgeInsets.all(5), child: SizedBox(width: 355, child: LiveScene(scene: s))),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile("goldens/academia_simulacoes.png"));
  });
}
