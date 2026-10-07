import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SplashMedia {
  final String mediaType;
  final String mediaUrl;
  final bool muted;
  final double volume;

  const SplashMedia({
    required this.mediaType,
    required this.mediaUrl,
    required this.muted,
    required this.volume,
  });
}

class SplashRepository {
  SupabaseClient? _client;

  SupabaseClient get _clientInstance {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  Future<SplashMedia?> fetchLoadingMedia() async {
    try {
      final authUserId = _clientInstance.auth.currentUser?.id;
      if (authUserId == null) {
        debugPrint("[Carregamento] sem usuario logado - pulando video");
        return null;
      }

      final profile = await _clientInstance
          .from("profiles")
          .select("agency_id")
          .eq("auth_user_id", authUserId)
          .single();
      final agencyId = profile["agency_id"];

      final row = await _clientInstance
          .rpc(
            "app_pick_splash_media",
            params: {"p_agency_id": agencyId, "p_kind": "loading"},
          )
          .maybeSingle();

      debugPrint("[Carregamento] agencia=$agencyId resposta=$row");
      if (row == null) return null;
      final url = row["media_url"];
      final type = row["media_type"];
      if (url is! String || url.isEmpty || type is! String) {
        debugPrint("[Carregamento] nenhum video ativo cadastrado no site");
        return null;
      }

      return SplashMedia(
        mediaType: type.toLowerCase(),
        mediaUrl: url,
        muted: row["muted"] == true,
        volume: (row["volume"] as num?)?.toDouble() ?? 1,
      );
    } catch (error) {
      debugPrint("[Carregamento] erro ao buscar midia: $error");
      return null;
    }
  }
}
