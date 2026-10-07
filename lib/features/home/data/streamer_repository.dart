import "package:supabase_flutter/supabase_flutter.dart";

import "../../ranking/data/ranking_rows_repository.dart";

class StreamerSummary {
  final String displayName;
  final String? avatarUrl;
  final String categoryName;
  final int daysLive;
  final int daysTarget;
  final double hoursLive;
  final double hoursTarget;
  final int diamonds;
  final int? rankingPosition;
  final int? hoursPosition;
  final int? categoryPosition;

  const StreamerSummary({
    required this.displayName,
    this.avatarUrl,
    required this.categoryName,
    required this.daysLive,
    required this.daysTarget,
    required this.hoursLive,
    required this.hoursTarget,
    required this.diamonds,
    this.rankingPosition,
    this.hoursPosition,
    this.categoryPosition,
  });
}

/// Posicao do streamer logado nos rankings da agencia (mes atual, dados ao vivo).
class StreamerPositions {
  final int? diamondPosition;
  final int? hoursPosition;
  final int? categoryPosition;
  final String categoryName;

  const StreamerPositions({
    this.diamondPosition,
    this.hoursPosition,
    this.categoryPosition,
    required this.categoryName,
  });
}

class StreamerRepository {
  final _client = Supabase.instance.client;

  /// Quando a equipe importou as metricas pela ultima vez (null se ainda
  /// nao houver importacao ou a migracao 0104 nao tiver sido rodada).
  Future<DateTime?> fetchMetricsUpdatedAt() async {
    try {
      final res = await _client.rpc("app_metrics_updated_at");
      return res == null ? null : DateTime.tryParse(res.toString())?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Acha o id do cadastro do streamer (profiles.id) a partir do usuario logado.
  Future<String> _resolveStreamerId() async {
    final authUserId = _client.auth.currentUser!.id;
    final profile = await _client
        .from("profiles")
        .select("id")
        .eq("auth_user_id", authUserId)
        .single();
    return profile["id"] as String;
  }

  Future<StreamerSummary> fetchCurrentStreamerSummary() async {
    final streamerId = await _resolveStreamerId();

    final profile = await _client
        .from("profiles")
        .select(
            "display_name, avatar_url, agency_id, category_id, custom_days_target, custom_hours_target, streamer_categories(name)")
        .eq("id", streamerId)
        .single();

    final stats = await _client
        .from("streamer_stats")
        .select("days_live, hours_live, diamonds")
        .eq("streamer_id", streamerId)
        .maybeSingle();

    final agencyId = profile["agency_id"];

    int daysTarget = (profile["custom_days_target"] as int?) ?? 22;
    double hoursTarget = ((profile["custom_hours_target"] as num?) ?? 100).toDouble();

    if (profile["custom_days_target"] == null) {
      final setting = await _client
          .from("app_settings")
          .select("value")
          .eq("agency_id", agencyId)
          .eq("key", "default_days_target")
          .maybeSingle();
      if (setting != null) daysTarget = (setting["value"] as num).toInt();
    }
    if (profile["custom_hours_target"] == null) {
      final setting = await _client
          .from("app_settings")
          .select("value")
          .eq("agency_id", agencyId)
          .eq("key", "default_hours_target")
          .maybeSingle();
      if (setting != null) hoursTarget = (setting["value"] as num).toDouble();
    }

    final categoryId = profile["category_id"];
    final positions = await _fetchPositions(
      agencyId: agencyId,
      streamerId: streamerId,
      categoryId: categoryId,
    );

    final categoryData = profile["streamer_categories"];
    final categoryName =
        (categoryData is Map ? categoryData["name"] as String? : null) ?? "";

    return StreamerSummary(
      displayName: profile["display_name"] as String? ?? "Ducker",
      avatarUrl: profile["avatar_url"] as String?,
      categoryName: categoryName,
      daysLive: (stats?["days_live"] as int?) ?? 0,
      daysTarget: daysTarget,
      hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
      hoursTarget: hoursTarget,
      diamonds: (stats?["diamonds"] as int?) ?? 0,
      rankingPosition: positions.diamondPosition,
      hoursPosition: positions.hoursPosition,
      categoryPosition: positions.categoryPosition,
    );
  }

  /// Posicoes do streamer logado nos rankings da agencia (diamantes, horas e
  /// diamantes dentro da propria categoria), sempre calculadas com os dados
  /// ao vivo do mes atual.
  Future<StreamerPositions> fetchCurrentPositions() async {
    final streamerId = await _resolveStreamerId();

    final profile = await _client
        .from("profiles")
        .select("agency_id, category_id, streamer_categories(name)")
        .eq("id", streamerId)
        .single();

    final agencyId = profile["agency_id"];
    final categoryId = profile["category_id"];

    final positions = await _fetchPositions(
      agencyId: agencyId,
      streamerId: streamerId,
      categoryId: categoryId,
    );

    final categoryData = profile["streamer_categories"];
    final categoryName =
        (categoryData is Map ? categoryData["name"] as String? : null) ?? "";

    return StreamerPositions(
      diamondPosition: positions.diamondPosition,
      hoursPosition: positions.hoursPosition,
      categoryPosition: positions.categoryPosition,
      categoryName: categoryName,
    );
  }

  Future<_Positions> _fetchPositions({
    required dynamic agencyId,
    required String streamerId,
    dynamic categoryId,
  }) async {
    // Fonte unica (servidor): ja respeita o periodo do ranking definido no painel.
    final board = await fetchRankingRows();
    final rows = board != null
        ? const []
        : await _client
            .from("profiles")
            .select("id, category_id, streamer_stats(diamonds, hours_live)")
            .eq("agency_id", agencyId)
            .eq("is_active", true);

    final list = board != null
        ? [
            for (final r in board.rows) <String, dynamic>{"id": r.id, "category_id": r.categoryId, "diamonds": r.diamonds, "hours_live": r.hours},
          ]
        : rows.map((r) {
      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      return {
        "id": r["id"],
        "category_id": r["category_id"],
        "diamonds": stats?["diamonds"] as int? ?? 0,
        "hours_live": (stats?["hours_live"] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    int? positionOf(List<Map<String, dynamic>> sorted) {
      final idx = sorted.indexWhere((r) => r["id"] == streamerId);
      return idx >= 0 ? idx + 1 : null;
    }

    // Quem esta zerado no mes nao tem posicao (igual ao Ranking Geral).
    final byDiamonds = list.where((r) => (r["diamonds"] as int) > 0).toList()
      ..sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));
    final byHours = list.where((r) => (r["hours_live"] as double) > 0).toList()
      ..sort((a, b) =>
          (b["hours_live"] as double).compareTo(a["hours_live"] as double));

    List<Map<String, dynamic>> byCategoryDiamonds = const [];
    if (categoryId != null) {
      byCategoryDiamonds = list.where((r) => r["category_id"] == categoryId && (r["diamonds"] as int) > 0).toList()
        ..sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));
    }

    return _Positions(
      diamondPosition: positionOf(byDiamonds),
      hoursPosition: positionOf(byHours),
      categoryPosition: positionOf(byCategoryDiamonds),
    );
  }
}

class _Positions {
  final int? diamondPosition;
  final int? hoursPosition;
  final int? categoryPosition;
  const _Positions({this.diamondPosition, this.hoursPosition, this.categoryPosition});
}
