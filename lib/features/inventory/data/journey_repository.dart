import "package:supabase_flutter/supabase_flutter.dart";
import "art_slots.dart";

/// Meta adaptativa (journey_recommended_milestone, migration 0096). Toda a
/// regra fica no banco; o app so mostra. O modo e interno (nunca exibido).
class JourneyGoal {
  final String mode; // start | build | comeback | steady
  final double recommended;
  final double currentTarget;
  final double? comebackTarget;
  final double? stretchTarget;
  final double? horizon;
  final String label;
  final String message;
  final String afterLabel;
  final String horizonLabel;
  final double current;

  const JourneyGoal({
    required this.mode,
    required this.recommended,
    required this.currentTarget,
    this.comebackTarget,
    this.stretchTarget,
    this.horizon,
    required this.label,
    required this.message,
    required this.afterLabel,
    required this.horizonLabel,
    required this.current,
  });

  double get progress => recommended <= 0 ? 0 : (current / recommended).clamp(0, 1).toDouble();

  static JourneyGoal? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    double? d(String k) => (m[k] as num?)?.toDouble();
    return JourneyGoal(
      mode: m["mode"] as String? ?? "build",
      recommended: d("recommended") ?? 0,
      currentTarget: d("current_target") ?? 0,
      comebackTarget: d("comeback_target"),
      stretchTarget: d("stretch_target"),
      horizon: d("horizon"),
      label: m["label"] as String? ?? "Seu próximo marco",
      message: m["message"] as String? ?? "",
      afterLabel: m["after_label"] as String? ?? "Depois",
      horizonLabel: m["horizon_label"] as String? ?? "Grande horizonte",
      current: d("current") ?? 0,
    );
  }
}


/// Indicador de Constancia (journey_constancy, migration 0097): automatico,
/// considera dias e horas do mes, ritmo, comparacao com o mes anterior e
/// dias sem live. state: forte | evolucao | estavel | retomando | alerta.
class Constancy {
  final String state;
  final String label;
  final String message;
  final double intensity; // 0..1 (tamanho/brilho da chama)
  final int? daysSinceLastLive;

  const Constancy({required this.state, required this.label, required this.message, required this.intensity, this.daysSinceLastLive});

  static Constancy? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return Constancy(
      state: m["state"] as String? ?? "estavel",
      label: m["label"] as String? ?? "",
      message: m["message"] as String? ?? "",
      intensity: (m["intensity"] as num?)?.toDouble() ?? 0.5,
      daysSinceLastLive: (m["days_since_last_live"] as num?)?.toInt(),
    );
  }
}

/// Primeiros 90 dias apos o acesso ao app (journey_onboarding, 0097).
class Onboarding {
  final int day;
  final int total;
  final String phaseTitle;
  final List<String> tips;
  const Onboarding({required this.day, required this.total, required this.phaseTitle, required this.tips});

  double get progress => total <= 0 ? 0 : (day / total).clamp(0, 1).toDouble();

  static Onboarding? fromMap(Object? raw) {
    if (raw is! Map || raw["active"] != true) return null;
    final m = Map<String, dynamic>.from(raw);
    return Onboarding(
      day: (m["day"] as num?)?.toInt() ?? 1,
      total: (m["total"] as num?)?.toInt() ?? 90,
      phaseTitle: m["phase_title"] as String? ?? "",
      tips: [for (final t in (m["tips"] as List? ?? const [])) t.toString()],
    );
  }
}

/// Resumo da Jornada do streamer logado (app_my_journey, migrations 0095-0097):
/// estagio/brasao, conquistas, metas profissionais do mes (22 dias / 100 h /
/// 80K -- nunca reduzidas), constancia, primeiros 90 dias e recordes.
class JourneySummary {
  final String name;
  final String? avatarUrl;
  final String stageName;
  final String? stageDescription;
  final String crestKey;
  final String? crestImageUrl;
  final int unlocked;
  final int total;
  final double currentDiamonds;
  final double currentDays;
  final double currentHours;
  final double daysTarget;
  final double hoursTarget;
  final double diamondTarget;
  final double totalHours;
  final double recordValue;
  final String? recordPeriod;
  final Constancy? constancy;
  final Onboarding? onboarding;
  final JourneyGoal? goal;

  const JourneySummary({
    required this.name,
    this.avatarUrl,
    required this.stageName,
    this.stageDescription,
    required this.crestKey,
    this.crestImageUrl,
    required this.unlocked,
    required this.total,
    required this.currentDiamonds,
    required this.currentDays,
    required this.currentHours,
    required this.daysTarget,
    required this.hoursTarget,
    required this.diamondTarget,
    required this.totalHours,
    required this.recordValue,
    this.recordPeriod,
    this.constancy,
    this.onboarding,
    this.goal,
  });

  factory JourneySummary.fromMap(Map<String, dynamic> m) {
    double d(String k, [double def = 0]) => (m[k] as num?)?.toDouble() ?? def;
    String? s(String k) => (m[k] as String?)?.trim().isEmpty ?? true ? null : (m[k] as String).trim();
    return JourneySummary(
      name: s("name") ?? "",
      avatarUrl: s("avatar_url"),
      stageName: s("stage_name") ?? "Primeiros Passos",
      stageDescription: s("stage_description"),
      crestKey: s("crest_key") ?? "prata",
      crestImageUrl: s("crest_image_url"),
      unlocked: (m["unlocked"] as num?)?.toInt() ?? 0,
      total: (m["total"] as num?)?.toInt() ?? 0,
      currentDiamonds: d("current_diamonds"),
      currentDays: d("current_days"),
      currentHours: d("current_hours"),
      daysTarget: d("days_target", 22),
      hoursTarget: d("hours_target", 100),
      diamondTarget: d("diamond_target", 80000),
      totalHours: d("total_hours"),
      recordValue: d("record_value"),
      recordPeriod: s("record_period"),
      constancy: Constancy.fromMap(m["constancy"]),
      onboarding: Onboarding.fromMap(m["onboarding"]),
      goal: JourneyGoal.fromMap(m["goal"]),
    );
  }
}

/// Um degrau dos Marcos do Mes (escada configuravel no painel) com o estado
/// do streamer no mes e a arte do mes, se o painel enviou.
class MonthMilestone {
  final String id;
  final double value;
  final String title;
  final int importance; // 1 (bonito) ... 8 (extremamente especial)
  final bool reached;
  final DateTime? unlockedAt;
  final bool seen;
  /// Arte classica (padrao do marco) e comemorativa (do mes), com as areas
  /// detectadas (circulo da foto e placa). Sem arte: o app usa o cartao padrao.
  final String? classicUrl;
  final ArtSlots? classicSlots;
  final String? specialUrl;
  final ArtSlots? specialSlots;
  final String? specialLabel;
  final bool isHighest;
  final String periodKey;
  final double currentDiamonds;

  const MonthMilestone({
    required this.id,
    required this.value,
    required this.title,
    required this.importance,
    required this.reached,
    this.unlockedAt,
    required this.seen,
    this.classicUrl,
    this.classicSlots,
    this.specialUrl,
    this.specialSlots,
    this.specialLabel,
    required this.isHighest,
    required this.periodKey,
    required this.currentDiamonds,
  });

  factory MonthMilestone.fromMap(Map<String, dynamic> m) => MonthMilestone(
        id: m["milestone_id"] as String,
        value: (m["value"] as num?)?.toDouble() ?? 0,
        title: (m["title"] as String?)?.trim().isNotEmpty == true ? (m["title"] as String).trim() : "",
        importance: (m["importance"] as num?)?.toInt() ?? 1,
        reached: m["reached"] == true,
        unlockedAt: DateTime.tryParse(m["unlocked_at"] as String? ?? "")?.toLocal(),
        seen: m["seen"] as bool? ?? true,
        classicUrl: _url(m["classic_url"] ?? m["art_url"]),
        classicSlots: ArtSlots.fromJson(m["classic_slots"]),
        specialUrl: _url(m["special_url"]),
        specialSlots: ArtSlots.fromJson(m["special_slots"]),
        specialLabel: (m["special_label"] as String?)?.trim().isEmpty ?? true ? null : (m["special_label"] as String).trim(),
        isHighest: m["is_highest"] == true,
        periodKey: m["period_key"] as String? ?? "",
        currentDiamonds: (m["current_diamonds"] as num?)?.toDouble() ?? 0,
      );

  static String? _url(Object? v) => v is String && v.isNotEmpty ? v : null;

  bool get hasArt => classicUrl != null || specialUrl != null;
}

class JourneyRepository {
  final _client = Supabase.instance.client;

  /// So a Constancia (leve, pra Home).
  Future<Constancy?> fetchConstancy() async => Constancy.fromMap(await _client.rpc("app_my_constancy"));

  Future<JourneySummary?> fetchSummary() async {
    final res = await _client.rpc("app_my_journey");
    if (res is! Map) return null;
    return JourneySummary.fromMap(Map<String, dynamic>.from(res));
  }

  Future<List<MonthMilestone>> fetchMonthMilestones({String? period}) async {
    final rows = await _client.rpc("app_my_month_milestones", params: {"p_period": period});
    return [for (final r in (rows as List)) MonthMilestone.fromMap(r as Map<String, dynamic>)];
  }

  /// Maior marco de cada mes (linha do tempo da Jornada).
  Future<List<({String period, double value, String title, int importance, DateTime? at})>> fetchMilestoneHistory() async {
    final rows = await _client.rpc("app_my_milestone_history");
    return [
      for (final r in rows as List)
        (
          period: r["period_key"] as String? ?? "",
          value: (r["value"] as num?)?.toDouble() ?? 0,
          title: r["title"] as String? ?? "",
          importance: (r["importance"] as num?)?.toInt() ?? 1,
          at: DateTime.tryParse(r["unlocked_at"] as String? ?? "")?.toLocal(),
        ),
    ];
  }

  /// Titulo e subtitulo da Jornada (editaveis no painel).
  Future<({String title, String subtitle})> fetchJourneyTexts() async {
    final res = await _client.rpc("app_journey_texts");
    final m = res is Map ? res : const {};
    return (
      title: (m["title"] as String?) ?? "Sua jornada na MDuck",
      subtitle: (m["subtitle"] as String?) ?? "Um registro dos momentos que marcaram sua trajetória.",
    );
  }

  Future<void> markMonthSeen(List<String> milestoneIds) async {
    if (milestoneIds.isEmpty) return;
    await _client.rpc("app_mark_month_milestones_seen", params: {"p_milestone_ids": milestoneIds});
  }
}
