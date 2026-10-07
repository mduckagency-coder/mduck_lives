import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../domain/max_activity_calculator.dart";
import "../domain/max_state.dart";

class MaxActivityRepository {
  final _client = Supabase.instance.client;

  /// Retorna o id (profiles.id) e a agencia do streamer logado.
  Future<({String streamerId, dynamic agencyId})> _resolveStreamer() async {
    final authUserId = _client.auth.currentUser!.id;
    final profile = await _client
        .from("profiles")
        .select("id, agency_id")
        .eq("auth_user_id", authUserId)
        .single();
    return (streamerId: profile["id"] as String, agencyId: profile["agency_id"]);
  }

  /// Le a atividade do mes atual em `streamer_stats`. `last_live_at` e
  /// `current_streak_days` sao colunas novas e podem ainda nao existir no
  /// banco (ou estar vazias) - nesse caso tratamos como "sem dado", nunca
  /// inventando uma data.
  ///
  /// A data da ultima live vem de `profiles.last_live_at`, que e a coluna que
  /// a Importacao TikTok grava (a mesma usada pelo Dashboard, CRM e pela
  /// inatividade do Background Home). Antes isso era lido so de
  /// streamer_stats, que nao tem a data -- e o streamer caia sempre em
  /// Regular.
  Future<MaxActivitySnapshot> fetchCurrentActivity(String streamerId) async {
    DateTime? lastLiveAt;
    int daysLive = 0;
    int? streak;

    try {
      final profile = await _client.from("profiles").select("last_live_at").eq("id", streamerId).maybeSingle();
      final raw = profile?["last_live_at"] as String?;
      if (raw != null) lastLiveAt = DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      // sem a data: segue sem ela (nunca inventa inatividade)
    }

    try {
      final stats = await _client.from("streamer_stats").select("days_live").eq("streamer_id", streamerId).maybeSingle();
      daysLive = (stats?["days_live"] as int?) ?? 0;
    } catch (_) {}

    // Colunas opcionais: usadas so se um dia existirem em streamer_stats.
    try {
      final extra = await _client
          .from("streamer_stats")
          .select("last_live_at, current_streak_days")
          .eq("streamer_id", streamerId)
          .maybeSingle();
      streak = extra?["current_streak_days"] as int?;
      final raw = extra?["last_live_at"] as String?;
      if (lastLiveAt == null && raw != null) lastLiveAt = DateTime.tryParse(raw)?.toLocal();
    } catch (_) {}

    debugPrint("[Max] ultima live=$lastLiveAt | dias de live no mes=$daysLive | sequencia=$streak");
    return MaxActivitySnapshot(daysLiveThisMonth: daysLive, lastLiveAt: lastLiveAt, currentStreakDays: streak);
  }

  /// Liga/desliga da tela do Max (painel > Max Entrada > Configuração).
  /// Sem configuracao = ligado.
  Future<bool> fetchEnabled(dynamic agencyId) async {
    try {
      final row = await _client
          .from("app_settings")
          .select("value")
          .eq("agency_id", agencyId)
          .eq("key", "max_intro_enabled")
          .maybeSingle();
      final value = row?["value"];
      return !(value == false || value == "false");
    } catch (_) {
      return true;
    }
  }

  Future<MaxThresholds> fetchThresholds(dynamic agencyId) async {
    const defaults = MaxThresholds();
    try {
      final rules = await _client.from("max_state_rules").select("*");
      final configured = _thresholdsFromRules(rules as List, agencyId);
      if (configured != null) return configured;
    } catch (_) {
      // Mantem compatibilidade com a configuracao antiga em app_settings.
    }

    try {
      final rows = await _client
          .from("app_settings")
          .select("key, value")
          .eq("agency_id", agencyId)
          .inFilter("key", [
        "max_constante_min_dias_live",
        "max_constante_min_dias_seguidos",
        "max_inativo_min_dias_sem_live",
        "max_caveira_min_dias_sem_live",
      ]);

      final values = <String, num>{
        for (final r in (rows as List)) r["key"] as String: r["value"] as num,
      };

      return MaxThresholds(
        constanteMinDaysLive:
            values["max_constante_min_dias_live"]?.toInt() ?? defaults.constanteMinDaysLive,
        constanteMinStreakDays:
            values["max_constante_min_dias_seguidos"]?.toInt() ?? defaults.constanteMinStreakDays,
        inativoMinDaysSinceLastLive:
            values["max_inativo_min_dias_sem_live"]?.toInt() ?? defaults.inativoMinDaysSinceLastLive,
        caveiraMinDaysSinceLastLive:
            values["max_caveira_min_dias_sem_live"]?.toInt() ?? defaults.caveiraMinDaysSinceLastLive,
      );
    } catch (_) {
      return defaults;
    }
  }

  MaxThresholds? _thresholdsFromRules(List rows, dynamic agencyId) {
    final matching = rows.whereType<Map>().where((row) {
      final rowAgency = row["agency_id"];
      final active = row["is_active"] != false && row["active"] != false;
      return active &&
          (rowAgency == null || agencyId == null || rowAgency.toString() == agencyId.toString());
    }).toList();
    if (matching.isEmpty) return null;

    Map? rowFor(String stateKey) => matching.cast<Map?>().firstWhere(
          (row) => row?["state_key"] == stateKey,
          orElse: () => null,
        );

    int? intValue(Map? row, String key) {
      final value = row?[key];
      return value is num ? value.toInt() : null;
    }

    int? extraInt(Map? row, String key) {
      final extra = row?["extra_config"];
      if (extra is Map && extra[key] is num) return (extra[key] as num).toInt();
      return null;
    }

    int? firstValue(List<String> keys, Map? row) {
      for (final key in keys) {
        final value = intValue(row, key) ?? extraInt(row, key);
        if (value != null) return value;
      }
      return null;
    }

    final constante = rowFor("constante");
    final inativo = rowFor("inativo");
    final caveira = rowFor("caveira");

    return MaxThresholds(
      constanteMinDaysLive: firstValue(["min_lives_this_month", "constante_min_days_live"], constante) ??
          3,
      constanteMinStreakDays: firstValue(["constante_min_streak_days", "min_streak_days"], constante) ??
          3,
      inativoMinDaysSinceLastLive: firstValue(["min_days_without_live", "inativo_min_days_since_last_live"], inativo) ??
          3,
      caveiraMinDaysSinceLastLive: firstValue(["min_days_without_live", "caveira_min_days_since_last_live"], caveira) ??
          10,
    );
  }

  Future<
      ({
        String streamerId,
        dynamic agencyId,
        MaxActivitySnapshot snapshot,
        MaxThresholds thresholds,
      })> fetchSnapshotForCurrentStreamer() async {
    final streamer = await _resolveStreamer();
    final snapshot = await fetchCurrentActivity(streamer.streamerId);
    final thresholds = await fetchThresholds(streamer.agencyId);
    return (
      streamerId: streamer.streamerId,
      agencyId: streamer.agencyId,
      snapshot: snapshot,
      thresholds: thresholds,
    );
  }
}
