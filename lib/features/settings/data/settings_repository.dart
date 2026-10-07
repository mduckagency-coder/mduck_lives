import "dart:io";
import "dart:typed_data";

import "package:package_info_plus/package_info_plus.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/feature_flags.dart";

/// Textos e versao controlados pelo painel web (Configurações do Aplicativo).
/// Vem de app_get_config(): padroes do banco + o que a agencia salvou.
class AppConfig {
  final Map<String, dynamic> raw;
  const AppConfig(this.raw);

  String text(String key, [String fallback = ""]) {
    final v = raw[key];
    return v is String && v.trim().isNotEmpty ? v : fallback;
  }

  String get versionLabel => text("version_label", "1.0.0 Beta");

  /// "DD/MM/AAAA" (o banco guarda AAAA-MM-DD).
  String get lastUpdateLabel {
    final d = DateTime.tryParse(text("last_update"));
    if (d == null) return "";
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  List<({String q, String a})> get faq => [
        for (final item in (raw["faq"] as List? ?? const []))
          if (item is Map && (item["q"] ?? "").toString().trim().isNotEmpty)
            (q: item["q"].toString(), a: (item["a"] ?? "").toString()),
      ];
}

/// Dados da conta mostrados em Configurações > Perfil / Conta.
class MyAccount {
  final String? profileId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? email;
  final DateTime? joinedAt;
  final TikTokStatus tiktok;

  const MyAccount({
    required this.profileId,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.email,
    required this.joinedAt,
    required this.tiktok,
  });

  /// E-mail tecnico criado no primeiro login pelo TikTok: nao mostrar.
  bool get hasRealEmail => email != null && !email!.endsWith("@users.mduck.app");
}

class TikTokStatus {
  final bool connected;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  const TikTokStatus({required this.connected, this.displayName, this.username, this.avatarUrl});

  factory TikTokStatus.fromJson(Map<String, dynamic>? j) => TikTokStatus(
        connected: j?["connected"] == true,
        displayName: j?["display_name"] as String?,
        username: j?["username"] as String?,
        avatarUrl: j?["avatar_url"] as String?,
      );
}

/// Tipos do formulario "Reportar um problema" (mesmos codigos do banco).
const reportTypes = <(String, String)>[
  ("bug", "Bug ou erro"),
  ("dados", "Dados incorretos ou desatualizados"),
  ("imagem_conquista", "Problema com imagem ou conquista"),
  ("conta", "Problema na conta"),
  ("sugestao", "Sugestão"),
  ("outro", "Outro"),
];

class SettingsRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<AppConfig> fetchConfig() async {
    final res = await _db.rpc("app_get_config");
    return AppConfig(res is Map ? Map<String, dynamic>.from(res) : const {});
  }

  Future<MyAccount> fetchAccount() async {
    final user = _db.auth.currentUser;
    final profile = user == null
        ? null
        : await _db
            .from("profiles")
            .select("id, display_name, tiktok_username, avatar_url, joined_at")
            .eq("auth_user_id", user.id)
            .maybeSingle();
    TikTokStatus tiktok = const TikTokStatus(connected: false);
    try {
      final res = await _db.rpc("app_my_tiktok");
      if (res is Map) tiktok = TikTokStatus.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      // migracao 0099 ainda nao rodada: segue sem o status do TikTok
    }
    final username = (profile?["tiktok_username"] as String?)?.replaceFirst("@", "");
    return MyAccount(
      profileId: profile?["id"] as String?,
      name: (profile?["display_name"] as String?)?.trim().isNotEmpty == true
          ? profile!["display_name"] as String
          : (username ?? "Streamer"),
      username: username,
      avatarUrl: tiktok.avatarUrl ?? profile?["avatar_url"] as String?,
      email: user?.email,
      joinedAt: DateTime.tryParse(profile?["joined_at"]?.toString() ?? ""),
      tiktok: tiktok,
    );
  }

  /// Versao instalada de verdade (build), gravada junto do reporte.
  Future<String> installedVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return "${info.version}+${info.buildNumber}";
    } catch (_) {
      return "desconhecida";
    }
  }

  Future<void> submitReport({
    required String type,
    required String description,
    String? area,
    String? title,
    Uint8List? screenshot,
    String? screenshotExt,
    required String versionLabel,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception("Sessão expirada. Entre novamente.");
    String? path;
    if (screenshot != null) {
      final ext = (screenshotExt ?? "jpg").toLowerCase();
      path = "${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext";
      await _db.storage.from("app_reports").uploadBinary(
            path,
            screenshot,
            fileOptions: FileOptions(contentType: ext == "png" ? "image/png" : "image/jpeg"),
          );
    }
    final build = await installedVersion();
    final params = {
      "p_type": type,
      "p_description": description,
      "p_screenshot_path": path,
      "p_app_version": "$versionLabel ($build)",
      "p_platform": Platform.isIOS ? "ios" : (Platform.isAndroid ? "android" : Platform.operatingSystem),
    };
    try {
      await _db.rpc("app_submit_report", params: {...params, "p_area": area, "p_title": title});
    } on PostgrestException catch (e) {
      // migracao 0100 ainda nao rodada: envia sem area/titulo (vao na descricao)
      if (e.code != "PGRST202") rethrow;
      final extra = [if (title != null) "Ideia: $title", if (area != null) "Área: $area"].join("\n");
      await _db.rpc("app_submit_report", params: {
        ...params,
        "p_description": extra.isEmpty ? description : "$extra\n\n$description",
      });
    }
  }

  /// Gestor responsavel (Central de Informacoes > "Falar com minha gestao").
  /// null se nao houver gestor definido ou WhatsApp cadastrado.
  Future<({String name, String whatsapp})?> fetchMyManager() async {
    try {
      final res = await _db.rpc("app_my_manager");
      if (res is! Map) return null;
      final phone = (res["whatsapp"] as String? ?? "").trim();
      if (phone.replaceAll(RegExp(r"[^0-9]"), "").length < 8) return null;
      return (name: (res["name"] as String? ?? "").trim(), whatsapp: phone);
    } catch (_) {
      return null; // migracao 0103 ainda nao rodada
    }
  }

  Future<List<MyReport>> fetchMyReports() async {
    final rows = await _db.rpc("app_my_reports");
    return [for (final r in (rows as List)) MyReport.fromJson(Map<String, dynamic>.from(r as Map))];
  }
}

/// Um envio do proprio streamer (Configurações > Meus envios).
class MyReport {
  final String id;
  final String type;
  final String? area;
  final String? title;
  final String description;
  final String status;
  final String? reply;
  final DateTime createdAt;

  const MyReport({
    required this.id,
    required this.type,
    required this.area,
    required this.title,
    required this.description,
    required this.status,
    required this.reply,
    required this.createdAt,
  });

  factory MyReport.fromJson(Map<String, dynamic> j) => MyReport(
        id: j["id"] as String,
        type: j["type"] as String? ?? "outro",
        area: j["area"] as String?,
        title: j["title"] as String?,
        description: j["description"] as String? ?? "",
        status: j["status"] as String? ?? "novo",
        reply: j["reply"] as String?,
        createdAt: DateTime.tryParse(j["created_at"]?.toString() ?? "")?.toLocal() ?? DateTime.now(),
      );
}

/// Partes do app (pra saber onde aconteceu / sobre o que e a ideia).
const appAreas = <String>["Home", "Ranking", if (kIlhaTopEnabled) "Ilha Top", "Missões", "Calendário", "Jornada", "Academia", "Conta e login", "Outro"];
