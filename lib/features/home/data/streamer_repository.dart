import "package:supabase_flutter/supabase_flutter.dart";

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
  });
}

class StreamerRepository {
  final _client = Supabase.instance.client;

  Future<StreamerSummary> fetchCurrentStreamerSummary() async {
    final userId = _client.auth.currentUser!.id;

    final profile = await _client
        .from("profiles")
        .select(
            "display_name, avatar_url, agency_id, category_id, custom_days_target, custom_hours_target, streamer_categories(name)")
        .eq("id", userId)
        .single();

    final stats = await _client
        .from("streamer_stats")
        .select("days_live, hours_live, diamonds")
        .eq("streamer_id", userId)
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

    int? rankingPosition;
    final now = DateTime.now();
    final periodKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final ranking = await _client
        .from("rankings_snapshot")
        .select("position")
        .eq("agency_id", agencyId)
        .eq("scope_type", "global")
        .eq("metric", "diamonds")
        .eq("period_type", "monthly")
        .eq("period_key", periodKey)
        .eq("streamer_id", userId)
        .maybeSingle();
    if (ranking != null) rankingPosition = ranking["position"] as int?;

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
      rankingPosition: rankingPosition,
    );
  }
}
