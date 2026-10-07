import "package:supabase_flutter/supabase_flutter.dart";

/// Uma linha do ranking (numeros ja no periodo certo do mes).
class RankingRow {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? categoryId;
  final String? categoryName;
  final int diamonds;
  final double hours;
  final int battles;
  final int days;

  const RankingRow({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.categoryId,
    this.categoryName,
    required this.diamonds,
    required this.hours,
    required this.battles,
    required this.days,
  });

  factory RankingRow.fromJson(Map j) => RankingRow(
        id: j["id"] as String,
        displayName: (j["display_name"] as String?) ?? "Ducker",
        avatarUrl: j["avatar_url"] as String?,
        categoryId: j["category_id"] as String?,
        categoryName: j["category_name"] as String?,
        diamonds: (j["diamonds"] as num?)?.toInt() ?? 0,
        hours: (j["hours_live"] as num?)?.toDouble() ?? 0,
        battles: (j["battles"] as num?)?.toInt() ?? 0,
        days: (j["days_live"] as num?)?.toInt() ?? 0,
      );
}

class RankingRows {
  final String periodKey;

  /// periodo de cada ranking que nao usa o mes inteiro:
  /// "diamonds" (tambem Games e Musicos), "hours", "battles"
  final Map<String, (DateTime, DateTime)> windows;
  final List<RankingRow> rows;
  const RankingRows({required this.periodKey, required this.windows, required this.rows});

  /// "Período do ranking: 02/10 a 31/10" para o ranking [metric] quando o
  /// mes tem periodo personalizado no painel; null no padrao (mes inteiro).
  String? labelFor(String metric) {
    final w = windows[metric];
    if (w == null) return null;
    String f(DateTime d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}";
    return "Período do ranking: ${f(w.$1)} a ${f(w.$2)}";
  }
}

/// Numeros do ranking pelo servidor (app_ranking_rows, migracao 0105): mes
/// inteiro por padrao, ou o periodo definido no painel para aquele mes.
/// Devolve null se a funcao ainda nao existir (quem chama usa o jeito antigo).
Future<RankingRows?> fetchRankingRows([String? periodKey]) async {
  try {
    final res = await Supabase.instance.client.rpc("app_ranking_rows", params: {"p_period": periodKey});
    if (res is! Map) return null;
    final windows = <String, (DateTime, DateTime)>{};
    final raw = res["windows"];
    if (raw is Map) {
      for (final e in raw.entries) {
        final w = e.value;
        final s = DateTime.tryParse("${w is Map ? w["start_date"] : ""}");
        final t = DateTime.tryParse("${w is Map ? w["end_date"] : ""}");
        if (s != null && t != null) windows[e.key.toString()] = (s, t);
      }
    }
    return RankingRows(
      periodKey: res["period_key"] as String? ?? "",
      windows: windows,
      rows: [for (final r in (res["rows"] as List? ?? const [])) RankingRow.fromJson(r as Map)],
    );
  } catch (_) {
    return null;
  }
}
