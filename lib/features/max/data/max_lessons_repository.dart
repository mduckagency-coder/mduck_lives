import "package:supabase_flutter/supabase_flutter.dart";

class MaxLesson {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String level;
  final String coverImageUrl;
  final String videoSource;
  final String videoUrl;

  const MaxLesson({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.level,
    required this.coverImageUrl,
    required this.videoSource,
    required this.videoUrl,
  });

  factory MaxLesson.fromMap(Map<String, dynamic> m) => MaxLesson(
        id: m["id"] as String,
        title: m["title"] as String? ?? "Aula",
        description: m["description"] as String?,
        category: m["category"] as String? ?? "geral",
        level: m["level"] as String? ?? "iniciante",
        coverImageUrl: m["cover_image_url"] as String? ?? "",
        videoSource: m["video_source"] as String? ?? "upload",
        videoUrl: m["video_url"] as String? ?? "",
      );
}

/// Aulas do MAX cadastradas no site admin (Home Central > Configuracao
/// Animacao APP > MAX Aulas). RLS ja restringe o retorno as aulas ativas
/// da propria agencia do streamer logado.
class MaxLessonsRepository {
  final _client = Supabase.instance.client;

  Future<List<MaxLesson>> fetchLessons() async {
    final rows = await _client.from("max_lessons").select().order("created_at", ascending: false);
    return (rows as List).map((r) => MaxLesson.fromMap(r as Map<String, dynamic>)).toList();
  }
}
