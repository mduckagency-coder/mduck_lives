import "package:supabase_flutter/supabase_flutter.dart";

/// Categorias das CONQUISTAS (historico permanente), na ordem do app.
/// Familias antigas (primeira/marco) ficaram desativadas no painel.
const achievementFamilies = [
  (key: "mensal", title: "Diamantes", subtitle: "A primeira vez que você alcançou cada marco"),
  (key: "grande_marco", title: "Meses completos", subtitle: "Dias, horas e resultado no mesmo mês"),
  (key: "consistencia", title: "Constância", subtitle: "Meses seguidos no mesmo nível"),
  (key: "dias", title: "Frequência", subtitle: "Meses de dedicação profissional"),
  (key: "horas", title: "Horas", subtitle: "Horas ao vivo acumuladas na sua trajetória"),
  (key: "merito", title: "Programa de Mérito", subtitle: "Reconhecimento dos grandes resultados"),
  (key: "marco", title: "Marcos da sua história", subtitle: "Diamantes somados em todos os meses"),
  (key: "primeira", title: "Primeiros passos", subtitle: "O começo da sua história"),
];

/// Uma conquista (painel > Inventario > Conquistas) com o estado do
/// streamer logado. O desbloqueio e automatico no banco (migrations 0091/0095).
class Achievement {
  final String id;
  final String code;
  final String title;
  final String description;
  final String family;
  final String ruleType;
  final double threshold;
  final int months; // so pras de consistencia
  final int comboDays; // so pra month_combo
  final int comboHours; // so pra month_combo
  final String? artKey;
  final String? imageUrl;
  final String? trailStage;
  final int trailOrder;
  final String? iconKey;
  final DateTime? unlockedAt;
  final double? valueAtUnlock;
  final bool seen;
  final double currentValue;

  const Achievement({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.family,
    required this.ruleType,
    required this.threshold,
    required this.months,
    this.comboDays = 0,
    this.comboHours = 0,
    this.artKey,
    this.imageUrl,
    this.trailStage,
    this.trailOrder = 0,
    this.iconKey,
    this.unlockedAt,
    this.valueAtUnlock,
    required this.seen,
    required this.currentValue,
  });

  bool get unlocked => unlockedAt != null;

  /// Alvo e valor atual na mesma unidade da regra (pra barra de progresso).
  double get target => ruleType == "consecutive_months_diamonds" ? months.toDouble() : threshold;
  double get progress => target <= 0 ? 0 : (currentValue / target).clamp(0, 1).toDouble();

  factory Achievement.fromMap(Map<String, dynamic> m) {
    final config = m["config"];
    int cfg(String k, int d) => config is Map ? (config[k] as num?)?.toInt() ?? d : d;
    return Achievement(
      id: m["id"] as String,
      code: m["code"] as String? ?? "",
      title: m["title"] as String? ?? "",
      description: m["description"] as String? ?? "",
      family: m["family"] as String? ?? "marco",
      ruleType: m["rule_type"] as String? ?? "",
      threshold: (m["threshold"] as num?)?.toDouble() ?? 0,
      months: cfg("months", 3),
      comboDays: cfg("days", 0),
      comboHours: cfg("hours", 0),
      artKey: m["art_key"] as String?,
      imageUrl: (m["image_url"] as String?)?.isEmpty ?? true ? null : m["image_url"] as String,
      trailStage: m["trail_stage"] as String?,
      trailOrder: (m["trail_order"] as num?)?.toInt() ?? 0,
      iconKey: m["icon_key"] as String?,
      unlockedAt: DateTime.tryParse(m["unlocked_at"] as String? ?? "")?.toLocal(),
      valueAtUnlock: (m["value_at_unlock"] as num?)?.toDouble(),
      seen: m["seen"] as bool? ?? true,
      currentValue: (m["current_value"] as num?)?.toDouble() ?? 0,
    );
  }
}

class AchievementsRepository {
  final _client = Supabase.instance.client;

  /// Recalcula (reforco) e devolve todas as conquistas ativas com o estado.
  Future<List<Achievement>> fetch() async {
    final rows = await _client.rpc("app_my_achievements");
    return [for (final r in (rows as List)) Achievement.fromMap(r as Map<String, dynamic>)];
  }

  Future<void> markSeen(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.rpc("app_mark_achievements_seen", params: {"p_ids": ids});
  }
}
