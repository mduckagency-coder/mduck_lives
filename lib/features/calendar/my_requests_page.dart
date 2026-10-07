import "package:flutter/material.dart";
import "data/calendar_requests_repository.dart";

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _repository = CalendarRequestsRepository();
  late Future<List<CalendarRequestItem>> _future;

  static const _bg = Color(0xFF1A0B2E);
  static const _purple = Color(0xFFB026FF);

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchMyRequests();
  }

  Color _statusColor(CalendarRequestItem r) {
    if (r.isApproved) return Colors.greenAccent;
    if (r.isRejected) return Colors.redAccent;
    return Colors.amberAccent;
  }

  String _opponentLabel(String v) {
    switch (v) {
      case "agencia":
        return "Agencia";
      case "externo":
        return "Externo";
      default:
        return "Tanto faz";
    }
  }

  String? _fmtTime(String? t) => (t != null && t.length >= 5) ? t.substring(0, 5) : t;

  Widget _card(CalendarRequestItem r) {
    final color = _statusColor(r);
    final isBattle = r.type == RequestType.batalhaOficial;
    final title = isBattle ? "Batalha Oficial" : (r.title ?? "Meu Evento");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isBattle ? Icons.sports_kabaddi : Icons.celebration, color: _purple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(r.statusLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                "${r.proposedDate.day.toString().padLeft(2, '0')}/${r.proposedDate.month.toString().padLeft(2, '0')}/${r.proposedDate.year}",
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (r.proposedStartTime != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text(_fmtTime(r.proposedStartTime) ?? "", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ],
          ),
          if (isBattle) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                if (r.battleRounds != null)
                  Text("Melhor de ${r.battleRounds}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (r.battleDiamondsEstimate != null)
                  Text("~${r.battleDiamondsEstimate} diamantes", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (r.battleOpponentType != null)
                  Text("Oponente: ${_opponentLabel(r.battleOpponentType!)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (r.battleOpponentName != null && r.battleOpponentName!.isNotEmpty)
                  Text("Confirmado: ${r.battleOpponentName}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (r.battleScore != null && r.battleScore!.isNotEmpty)
                  Text("Resultado: ${r.battleScore}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
          if (r.description != null && r.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.description!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
          if (r.isRejected && r.reviewNotes != null && r.reviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text("Motivo: ${r.reviewNotes}", style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ),
          ],
          if (r.isApproved && r.approvalMessage != null && r.approvalMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text("Agencia: ${r.approvalMessage}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Minhas Solicitacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<CalendarRequestItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Erro ao carregar: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text("Voce ainda nao fez nenhuma solicitacao.", style: TextStyle(color: Colors.white54)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _card(items[i]),
          );
        },
      ),
    );
  }
}
