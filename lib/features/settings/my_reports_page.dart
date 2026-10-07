import "package:flutter/material.dart";

import "data/settings_repository.dart";
import "settings_page.dart" show settingsBg, settingsCard, settingsLilac;

const _typeInfo = <String, (String, IconData)>{
  "bug": ("Bug ou erro", Icons.bug_report_outlined),
  "dados": ("Dados incorretos", Icons.query_stats),
  "imagem_conquista": ("Imagem ou conquista", Icons.image_not_supported_outlined),
  "conta": ("Problema na conta", Icons.manage_accounts_outlined),
  "sugestao": ("Sugestão", Icons.lightbulb_outline),
  "outro": ("Outro", Icons.more_horiz),
};

/// Como o status aparece pro streamer (linguagem simples).
const _statusInfo = <String, (String, Color)>{
  "novo": ("Recebido", Color(0xFF5BA8FF)),
  "em_analise": ("Em análise", Color(0xFFFFC94D)),
  "resolvido": ("Resolvido", Color(0xFF3DDC97)),
  "ignorado": ("Encerrado", Color(0xFF8E9AB8)),
  "duplicado": ("Já reportado", Color(0xFFC77DFF)),
};

/// Configurações > Meus envios: reportes e sugestoes do streamer, com o
/// andamento e a resposta da equipe.
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  late Future<List<MyReport>> _future = SettingsRepository().fetchMyReports();

  Future<void> _reload() async {
    final f = SettingsRepository().fetchMyReports();
    setState(() => _future = f);
    await f.catchError((_) => <MyReport>[]);
  }

  static String _date(DateTime d) =>
      "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(backgroundColor: settingsBg, foregroundColor: Colors.white, title: const Text("Meus envios")),
      body: FutureBuilder<List<MyReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: settingsLilac));
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("Não foi possível carregar seus envios.", style: TextStyle(color: Colors.white70)),
                TextButton(onPressed: _reload, child: const Text("Tentar de novo")),
              ]),
            );
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text("Você ainda não enviou nenhum reporte ou sugestão.",
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _card(MyReport r) {
    final (typeLabel, icon) = _typeInfo[r.type] ?? ("Outro", Icons.more_horiz);
    final (statusLabel, statusColor) = _statusInfo[r.status] ?? ("Recebido", const Color(0xFF5BA8FF));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: settingsCard, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: settingsLilac, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [typeLabel, if (r.area != null) r.area!].join(" · "),
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.6)),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        if (r.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(r.title!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
        if (r.description != r.title)
          Text(r.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.35)),
        const SizedBox(height: 8),
        Text("Enviado em ${_date(r.createdAt)}", style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        if (r.reply != null && r.reply!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: settingsLilac.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: settingsLilac.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Resposta da equipe MDuck",
                  style: TextStyle(color: settingsLilac, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(r.reply!, style: const TextStyle(color: Colors.white, height: 1.35)),
            ]),
          ),
        ],
      ]),
    );
  }
}
