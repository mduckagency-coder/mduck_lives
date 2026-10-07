import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "package:supabase_flutter/supabase_flutter.dart";

(String, Color) _computeStatus(Map<String, dynamic> m) {
  if (m["mission_status"] == "cancelada") return ("Cancelada", Colors.redAccent);
  final now = DateTime.now();
  final start = m["starts_at"] != null ? DateTime.parse(m["starts_at"]) : null;
  final end = m["ends_at"] != null ? DateTime.parse(m["ends_at"]) : null;
  if (start != null && now.isBefore(start)) return ("A comecar", Colors.blueAccent);
  if (end != null && now.isAfter(end)) return ("Encerrada", Colors.white54);
  return ("Ativa", Colors.greenAccent);
}

class MissoesPage extends StatefulWidget {
  const MissoesPage({super.key});

  @override
  State<MissoesPage> createState() => _MissoesPageState();
}

class _MissoesPageState extends State<MissoesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final authUserId = client.auth.currentUser!.id;
    final profile = await client.from("profiles").select("id").eq("auth_user_id", authUserId).single();
    final streamerId = profile["id"] as String;

    final stats = await client
        .from("streamer_stats")
        .select("days_live, hours_live, diamonds")
        .eq("streamer_id", streamerId)
        .maybeSingle();

    final currentDays = stats?["days_live"] as int? ?? 0;
    final currentHours = (stats?["hours_live"] as num?)?.toDouble() ?? 0;
    final currentDiamonds = stats?["diamonds"] as int? ?? 0;

    final assignments = await client
        .from("streamer_missions")
        .select(
            "mission_id, completed_at, missions(title, description, starts_at, ends_at, mission_status, requirement_days, requirement_hours, requirement_diamonds, reward_type, reward_detail, reward_image_url)")
        .eq("streamer_id", streamerId);

    final results = <Map<String, dynamic>>[];
    for (final a in (assignments as List)) {
      final mission = a["missions"];
      if (mission == null) continue;

      final reqDays = mission["requirement_days"] as int?;
      final reqHours = (mission["requirement_hours"] as num?)?.toDouble();
      final reqDiamonds = mission["requirement_diamonds"] as int?;

      final daysProgress = (reqDays != null && reqDays > 0) ? (currentDays / reqDays).clamp(0.0, 1.0) : null;
      final hoursProgress = (reqHours != null && reqHours > 0) ? (currentHours / reqHours).clamp(0.0, 1.0) : null;
      final diamondsProgress = (reqDiamonds != null && reqDiamonds > 0) ? (currentDiamonds / reqDiamonds).clamp(0.0, 1.0) : null;

      final allProgress = [daysProgress, hoursProgress, diamondsProgress].whereType<double>();
      final overallProgress = allProgress.isEmpty ? 0.0 : allProgress.reduce((a, b) => a < b ? a : b);

      var completedAt = a["completed_at"] as String?;
      if (overallProgress >= 1.0 && completedAt == null) {
        await client.from("streamer_missions").update({"completed_at": DateTime.now().toIso8601String()}).eq("streamer_id", streamerId).eq("mission_id", a["mission_id"]);
        completedAt = DateTime.now().toIso8601String();
      }

      results.add({
        "title": mission["title"],
        "description": mission["description"],
        "starts_at": mission["starts_at"],
        "ends_at": mission["ends_at"],
        "mission_status": mission["mission_status"],
        "reqDays": reqDays,
        "reqHours": reqHours,
        "reqDiamonds": reqDiamonds,
        "currentDays": currentDays,
        "currentHours": currentHours,
        "currentDiamonds": currentDiamonds,
        "daysProgress": daysProgress,
        "hoursProgress": hoursProgress,
        "diamondsProgress": diamondsProgress,
        "reward_type": mission["reward_type"],
        "reward_detail": mission["reward_detail"],
        "reward_image_url": mission["reward_image_url"],
        "completed": completedAt != null,
      });
    }
    return results;
  }

  Widget _progressRow(String label, double? progress, String valueText) {
    if (progress == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
              Text(valueText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.greenAccent : const Color(0xFF7A0BD4)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Missoes")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final missions = snapshot.data!;
          if (missions.isEmpty) {
            return const Center(child: Text("Nenhuma missao disponivel no momento.", style: TextStyle(color: Colors.white54)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final m = missions[index];
              final completed = m["completed"] as bool;
              final status = completed ? ("Concluida", Colors.greenAccent) : _computeStatus(m);
              final startText = m["starts_at"] != null ? DateTime.parse(m["starts_at"]).toLocal().toString().substring(0, 10) : null;
              final endText = m["ends_at"] != null ? DateTime.parse(m["ends_at"]).toLocal().toString().substring(0, 10) : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: completed ? Colors.greenAccent : Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(m["title"] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: status.$2.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (startText != null || endText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        (startText != null ? "Inicio: " + startText : "") + (endText != null ? "  Fim: " + endText : ""),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                    if ((m["description"] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(m["description"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    _progressRow("Dias", m["daysProgress"] as double?, "${m["currentDays"]}/${m["reqDays"]}"),
                    _progressRow("Horas", m["hoursProgress"] as double?, "${(m["currentHours"] as double).toStringAsFixed(0)}/${m["reqHours"]}"),
                    _progressRow("Diamantes", m["diamondsProgress"] as double?, "${m["currentDiamonds"]}/${m["reqDiamonds"]}"),
                    const SizedBox(height: 4),
                    if (m["reward_image_url"] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image(image: MediaCacheImage(m["reward_image_url"] as String), height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                    if (m["reward_type"] != null)
                      Text(
                        "Premio: " + m["reward_type"].toString() + ((m["reward_detail"] as String?)?.isNotEmpty == true ? " - " + m["reward_detail"] : ""),
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

