import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../../core/media/media_cache.dart";

/// Video de fundo da Home escolhido pro streamer agora (site > Configuracao
/// Animacao APP > Background Home).
class HomeBackground {
  final String id;
  final String videoUrl;

  /// 'video' (som do proprio video) | 'default' (video mudo + audio padrao)
  /// | 'mute' (sem som).
  final String audioMode;
  final double volume;

  /// Audio padrao da Home, quando [audioMode] == 'default'.
  final String? defaultAudioUrl;
  final double defaultAudioVolume;

  /// 'normal' ou 'inactivity' (streamer ha mais de 7 dias sem live -- quem
  /// decide e a funcao home_pick_background no banco).
  final String category;

  /// Texto configurado no site pra aparecer sobre o video (inatividade).
  final String? overlayText;

  const HomeBackground({
    required this.id,
    required this.videoUrl,
    required this.audioMode,
    required this.volume,
    this.defaultAudioUrl,
    this.defaultAudioVolume = 1,
    this.category = "normal",
    this.overlayText,
  });

  bool get isInactivity => category == "inactivity";

  /// Volume do proprio video.
  double get videoVolume => audioMode == "video" ? volume.clamp(0, 1) : 0;

  bool get usesDefaultAudio => audioMode == "default" && defaultAudioUrl != null;
}

class HomeBackgroundRepository {
  final _client = Supabase.instance.client;

  static Future<HomeBackground?>? _prefetched;

  /// Chamado na tela do Max (antes da Home): ja descobre o video do horario e
  /// comeca a baixar, pra quando o streamer tocar em "Avançar" ele ja tocar.
  static void prefetch() {
    _prefetched ??= HomeBackgroundRepository().fetchCurrent().then((background) {
      if (background != null) MediaCache.download(background.videoUrl);
      return background;
    });
  }

  /// Resultado do [prefetch], se houver (usado uma vez so).
  static Future<HomeBackground?>? takePrefetched() {
    final pending = _prefetched;
    _prefetched = null;
    return pending;
  }

  /// A regra de horario e o sorteio do dia ficam no banco
  /// (home_pick_background): o mesmo streamer recebe sempre o mesmo video
  /// naquela faixa de horario durante o dia. Devolve null se a agencia
  /// ainda nao cadastrou nenhum video (o app usa o video padrao embutido).
  Future<HomeBackground?> fetchCurrent() async {
    try {
      final authUserId = _client.auth.currentUser?.id;
      if (authUserId == null) return null;
      final profile = await _client.from("profiles").select("id, agency_id").eq("auth_user_id", authUserId).single();
      final agencyId = profile["agency_id"];

      final row = await _client
          .rpc("home_pick_background", params: {"p_agency_id": agencyId, "p_streamer_id": profile["id"]})
          .maybeSingle();
      final url = row?["media_url"];
      debugPrint("[Background Home] escolhido: ${row?["label"]} | categoria=${row?["category"]} | texto=${row?["overlay_text"]}");
      if (row == null || url is! String || url.isEmpty) return null;

      final audioMode = row["audio_mode"] as String? ?? "video";
      String? defaultUrl;
      double defaultVolume = 1;
      if (audioMode == "default") {
        final setting = await _client
            .from("app_settings")
            .select("value")
            .eq("agency_id", agencyId)
            .eq("key", "home_default_audio")
            .maybeSingle();
        final value = setting?["value"];
        if (value is Map) {
          final u = value["url"] as String?;
          defaultUrl = u == null || u.isEmpty ? null : u;
          defaultVolume = (value["volume"] as num?)?.toDouble() ?? 1;
        }
      }

      return HomeBackground(
        id: row["id"] as String,
        videoUrl: url,
        audioMode: audioMode,
        volume: (row["volume"] as num?)?.toDouble() ?? 1,
        defaultAudioUrl: defaultUrl,
        defaultAudioVolume: defaultVolume,
        category: row["category"] as String? ?? "normal",
        overlayText: (row["overlay_text"] as String?)?.trim(),
      );
    } catch (error) {
      debugPrint("[Background Home] usando o video padrao: $error");
      return null;
    }
  }
}
