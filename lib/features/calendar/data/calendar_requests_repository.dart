import "package:supabase_flutter/supabase_flutter.dart";

enum RequestType { batalhaOficial, evento }

RequestType _parseRequestType(String? v) => v == "batalha_oficial" ? RequestType.batalhaOficial : RequestType.evento;

/// Fluxo de status de `calendar_requests`:
/// aguardando_analise -> (so batalha) buscando_oponente -> oponente_confirmado
/// -> aprovada/concluida, ou rejeitada/cancelada a qualquer momento.
enum RequestStatusCategory { pending, approved, rejected }

const _approvedStatuses = {"aprovada", "concluida"};
const _rejectedStatuses = {"rejeitada", "cancelada"};

/// Uma solicitacao feita pelo streamer (batalha oficial ou evento proprio).
/// Fica em analise ate a agencia aprovar ou recusar (`calendar_requests`).
class CalendarRequestItem {
  final String id;
  final RequestType type;
  final String? title;
  final String? description;
  final DateTime proposedDate;
  final String? proposedStartTime;
  final String? proposedEndTime;
  final int? battleRounds;
  final int? battleDiamondsEstimate;
  final String? battleOpponentType;
  final String? battleOpponentName;
  final String? battleScore;
  final bool needsBanner;
  final String status;
  final String? reviewNotes;
  final String? approvalMessage;
  final DateTime createdAt;

  const CalendarRequestItem({
    required this.id,
    required this.type,
    this.title,
    this.description,
    required this.proposedDate,
    this.proposedStartTime,
    this.proposedEndTime,
    this.battleRounds,
    this.battleDiamondsEstimate,
    this.battleOpponentType,
    this.battleOpponentName,
    this.battleScore,
    required this.needsBanner,
    required this.status,
    this.reviewNotes,
    this.approvalMessage,
    required this.createdAt,
  });

  RequestStatusCategory get statusCategory {
    if (_approvedStatuses.contains(status)) return RequestStatusCategory.approved;
    if (_rejectedStatuses.contains(status)) return RequestStatusCategory.rejected;
    return RequestStatusCategory.pending;
  }

  bool get isApproved => statusCategory == RequestStatusCategory.approved;
  bool get isRejected => statusCategory == RequestStatusCategory.rejected;
  bool get isPending => statusCategory == RequestStatusCategory.pending;

  String get statusLabel {
    switch (status) {
      case "aguardando_analise":
        return "Aguardando analise";
      case "buscando_oponente":
        return "Buscando oponente";
      case "oponente_confirmado":
        return "Oponente confirmado";
      case "aprovada":
        return "Aprovada";
      case "concluida":
        return "Concluida";
      case "rejeitada":
        return "Recusada";
      case "cancelada":
        return "Cancelada";
      default:
        return status;
    }
  }
}

/// Convite da agencia pedindo que o streamer preencha uma solicitacao
/// (`calendar_request_prompts`). O streamer ainda nao preencheu nada.
class RequestPromptItem {
  final String id;
  final RequestType type;
  final String message;
  final DateTime? suggestedDateStart;
  final DateTime? suggestedDateEnd;
  final DateTime createdAt;

  const RequestPromptItem({
    required this.id,
    required this.type,
    required this.message,
    this.suggestedDateStart,
    this.suggestedDateEnd,
    required this.createdAt,
  });
}

/// Alerta recebido pelo streamer (aprovacao, recusa, pedido da agencia etc).
class StreamerNotificationItem {
  final String id;
  final String type;
  final String subject;
  final String message;
  final DateTime? readAt;
  final DateTime createdAt;

  const StreamerNotificationItem({
    required this.id,
    required this.type,
    required this.subject,
    required this.message,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;
}

class CalendarRequestsRepository {
  final _client = Supabase.instance.client;

  Future<({String streamerId, String agencyId})> _context() async {
    final authUserId = _client.auth.currentUser!.id;
    final profile = await _client
        .from("profiles")
        .select("id, agency_id")
        .eq("auth_user_id", authUserId)
        .single();
    return (streamerId: profile["id"] as String, agencyId: profile["agency_id"] as String);
  }

  String _fmtDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> submitBattleRequest({
    required DateTime date,
    required String startTime,
    required int rounds,
    required int diamondsEstimate,
    required String opponentType,
    required bool needsBanner,
    String? fulfillsPromptId,
  }) async {
    final ctx = await _context();
    final inserted = await _client
        .from("calendar_requests")
        .insert({
          "agency_id": ctx.agencyId,
          "request_type": "batalha_oficial",
          "requested_by_streamer_id": ctx.streamerId,
          "proposed_date": _fmtDate(date),
          "proposed_start_time": startTime,
          "battle_rounds": rounds,
          "battle_diamonds_estimate": diamondsEstimate,
          "battle_opponent_type": opponentType,
          "needs_banner": needsBanner,
        })
        .select("id")
        .single();

    if (fulfillsPromptId != null) {
      await _client
          .from("calendar_request_prompts")
          .update({"status": "atendido", "fulfilled_request_id": inserted["id"]})
          .eq("id", fulfillsPromptId);
    }
  }

  Future<void> submitEventRequest({
    required DateTime date,
    required String startTime,
    String? endTime,
    required String title,
    String? description,
    required bool needsBanner,
    String? fulfillsPromptId,
  }) async {
    final ctx = await _context();
    final inserted = await _client
        .from("calendar_requests")
        .insert({
          "agency_id": ctx.agencyId,
          "request_type": "evento",
          "requested_by_streamer_id": ctx.streamerId,
          "title": title,
          "description": description,
          "proposed_date": _fmtDate(date),
          "proposed_start_time": startTime,
          "proposed_end_time": endTime,
          "needs_banner": needsBanner,
        })
        .select("id")
        .single();

    if (fulfillsPromptId != null) {
      await _client
          .from("calendar_request_prompts")
          .update({"status": "atendido", "fulfilled_request_id": inserted["id"]})
          .eq("id", fulfillsPromptId);
    }
  }

  Future<List<CalendarRequestItem>> fetchMyRequests() async {
    final ctx = await _context();
    final rows = await _client
        .from("calendar_requests")
        .select()
        .eq("requested_by_streamer_id", ctx.streamerId)
        .order("created_at", ascending: false);
    return (rows as List).map((r) => _mapRequest(r as Map<String, dynamic>)).toList();
  }

  CalendarRequestItem _mapRequest(Map<String, dynamic> r) {
    return CalendarRequestItem(
      id: r["id"] as String,
      type: _parseRequestType(r["request_type"] as String?),
      title: r["title"] as String?,
      description: r["description"] as String?,
      proposedDate: DateTime.parse(r["proposed_date"] as String),
      proposedStartTime: r["proposed_start_time"] as String?,
      proposedEndTime: r["proposed_end_time"] as String?,
      battleRounds: r["battle_rounds"] as int?,
      battleDiamondsEstimate: r["battle_diamonds_estimate"] as int?,
      battleOpponentType: r["battle_opponent_type"] as String?,
      battleOpponentName: r["battle_opponent_name"] as String?,
      battleScore: r["battle_score"] as String?,
      needsBanner: r["needs_banner"] as bool? ?? false,
      status: (r["status"] as String?) ?? "aguardando_analise",
      reviewNotes: r["review_notes"] as String?,
      approvalMessage: r["approval_message"] as String?,
      createdAt: DateTime.parse(r["created_at"] as String),
    );
  }

  Future<List<RequestPromptItem>> fetchPendingPrompts() async {
    final ctx = await _context();
    final rows = await _client
        .from("calendar_request_prompts")
        .select()
        .eq("streamer_id", ctx.streamerId)
        .eq("status", "pendente")
        .order("created_at", ascending: false);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return RequestPromptItem(
        id: m["id"] as String,
        type: _parseRequestType(m["request_type"] as String?),
        message: m["message"] as String? ?? "",
        suggestedDateStart:
            m["suggested_date_start"] != null ? DateTime.parse(m["suggested_date_start"] as String) : null,
        suggestedDateEnd: m["suggested_date_end"] != null ? DateTime.parse(m["suggested_date_end"] as String) : null,
        createdAt: DateTime.parse(m["created_at"] as String),
      );
    }).toList();
  }

  Future<List<StreamerNotificationItem>> fetchNotifications() async {
    final ctx = await _context();
    final rows = await _client
        .from("streamer_notifications")
        .select()
        .eq("streamer_id", ctx.streamerId)
        .order("created_at", ascending: false)
        .limit(50);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return StreamerNotificationItem(
        id: m["id"] as String,
        type: m["type"] as String? ?? "geral",
        subject: m["subject"] as String? ?? "",
        message: m["message"] as String? ?? "",
        readAt: m["read_at"] != null ? DateTime.parse(m["read_at"] as String) : null,
        createdAt: DateTime.parse(m["created_at"] as String),
      );
    }).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _client.from("streamer_notifications").update({"read_at": DateTime.now().toIso8601String()}).eq("id", id);
  }
}
