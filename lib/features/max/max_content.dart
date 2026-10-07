import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "data/max_lessons_repository.dart";
import "max_video_player_page.dart";

class MaxContent extends StatefulWidget {
  const MaxContent({super.key});

  @override
  State<MaxContent> createState() => _MaxContentState();
}

class _MaxContentState extends State<MaxContent> {
  final _repository = MaxLessonsRepository();
  late Future<List<MaxLesson>> _future;

  static const _purple = Color(0xFFB026FF);
  static const _purpleDark = Color(0xFF7A0BD4);

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchLessons();
  }

  String _categoryLabel(String c) {
    switch (c) {
      case "batalha":
        return "Batalha";
      case "musico":
        return "Musica";
      case "games":
        return "Games";
      default:
        return "Geral";
    }
  }

  IconData _categoryIcon(String c) {
    switch (c) {
      case "batalha":
        return Icons.sports_kabaddi;
      case "musico":
        return Icons.music_note;
      case "games":
        return Icons.sports_esports;
      default:
        return Icons.star;
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case "veterano":
        return "Veterano";
      case "pro":
        return "Avancado";
      default:
        return "Iniciante";
    }
  }

  Color _levelColor(String l) {
    switch (l) {
      case "veterano":
        return const Color(0xFF4FC3F7);
      case "pro":
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF69F0AE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text("MAX AULAS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: FutureBuilder<List<MaxLesson>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _purple));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Nao foi possivel carregar as aulas.\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }
              final lessons = snapshot.data ?? const [];
              if (lessons.isEmpty) {
                return const Center(child: Text("Nenhuma aula disponivel ainda.", style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: lessons.length,
                itemBuilder: (context, i) => _lessonCard(lessons[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _lessonCard(MaxLesson lesson) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.6), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.05), _purple.withOpacity(0.06)],
        ),
        boxShadow: [BoxShadow(color: _purple.withOpacity(0.18), blurRadius: 14, spreadRadius: 1)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaxVideoPlayerPage(lesson: lesson))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: lesson.coverImageUrl.isNotEmpty
                        ? Image(image: MediaCacheImage(lesson.coverImageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.white10,
                              child: const Icon(Icons.image_not_supported, color: Colors.white30, size: 32),
                            ),
                          )
                        : Container(color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white30, size: 40)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                      boxShadow: [BoxShadow(color: _purple.withOpacity(0.6), blurRadius: 12, spreadRadius: 1)],
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        lesson.description!,
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _badge(_categoryIcon(lesson.category), _categoryLabel(lesson.category), _purple),
                        _badge(null, _levelLabel(lesson.level), _levelColor(lesson.level)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData? icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
