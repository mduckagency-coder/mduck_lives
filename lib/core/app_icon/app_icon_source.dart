import "package:supabase_flutter/supabase_flutter.dart";

/// Fonte oficial usada no processo de gerar uma nova versao do app.
///
/// O painel salva a URL publica em `app_settings.value`, usando a chave
/// `app_icon_default` por agencia. Este contrato nao e chamado durante o uso
/// normal do app: o icone instalado continua sendo o asset nativo atual ate
/// que a imagem seja incorporada em um novo build.
class AppIconSource {
  static const settingKey = "app_icon_default";
  static const storageBucket = "app_settings_media";

  final SupabaseClient _client;

  AppIconSource({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<String?> fetchCurrentUrl() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final profile = await _client
          .from("profiles")
          .select("agency_id")
          .eq("auth_user_id", userId)
          .single();
      final agencyId = profile["agency_id"];

      final rows = await _client
          .from("app_settings")
          .select("value")
          .eq("agency_id", agencyId)
          .eq("key", settingKey)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      final value = (list.first as Map<String, dynamic>)["value"];
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }
}