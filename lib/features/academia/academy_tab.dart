import "package:flutter/material.dart";

import "../../core/media/media_cache.dart";
import "../max/data/max_lessons_repository.dart";
import "../max/max_video_player_page.dart";
import "ui/academy_home.dart";
import "ui/academy_theme.dart";

/// Aba "Academia" do app (antiga aba Max). Usa o player de video interno
/// (YouTube e arquivos) que ja existia no MAX Aulas.
class AcademyTab extends StatelessWidget {
  const AcademyTab({super.key});

  static bool _ready = false;

  static void _setupVideo() {
    if (_ready) return;
    _ready = true;
    academyImage = (url) => MediaCacheImage(url);
    academyVideoOpener = (context, {required url, required youtube, title}) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MaxVideoPlayerPage(
              lesson: MaxLesson(
                id: url,
                title: title ?? "Academia MDuck",
                category: "geral",
                level: "iniciante",
                coverImageUrl: "",
                videoSource: youtube ? "youtube" : "upload",
                videoUrl: url,
              ),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    _setupVideo();
    return const AcademyHome();
  }
}
