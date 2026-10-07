import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

enum EventTag { streamer, agencia, tiktok, treinamento }

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final bool allDay;
  final String? location;
  final String? meetingLink;
  final String? categoryName;
  final Color categoryColor;
  final Set<EventTag> tags;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    required this.allDay,
    this.location,
    this.meetingLink,
    this.categoryName,
    required this.categoryColor,
    required this.tags,
  });
}

class CalendarMonthData {
  final List<CalendarEvent> events;
  final String streamerDisplayName;
  const CalendarMonthData({required this.events, required this.streamerDisplayName});
}

/// Busca e classifica os eventos de calendario visiveis para o streamer logado.
///
/// So entram eventos com `show_in_app = true`. Um evento e "geral" (visivel
/// para toda a agencia) quando nao tem nenhum participante do tipo streamer
/// em `calendar_event_participants`; quando tem, so aparece para os
/// streamers que estao entre os participantes. As "etiquetas" pedidas pelo
/// usuario (evento do streamer / evento agencia / campanha tiktok /
/// treinamento) sao tags nao-exclusivas: um mesmo evento pode aparecer em
/// mais de um filtro (ex: um evento individual sobre TikTok e ao mesmo
/// tempo "meu" e "tiktok").
///
/// A visibilidade tambem e reforcada aqui no client (alem da RLS
/// `calendar_events_streamer_select`) porque, se existir alguma policy de
/// SELECT antiga/mais permissiva ainda ativa em `calendar_events`, o
/// Postgres combina policies com OR e a RLS nova sozinha pode nao restringir
/// nada.
class CalendarRepository {
  final _client = Supabase.instance.client;

  static const _trainingKeys = {
    "treinamento_agencia",
    "treinamento_games",
    "treinamento_plataforma",
    "workshop",
    "treinamento_agencia_app",
  };

  Future<CalendarMonthData> fetchMonth(DateTime month) async {
    final authUserId = _client.auth.currentUser!.id;
    final profile = await _client
        .from("profiles")
        .select("id, agency_id, display_name")
        .eq("auth_user_id", authUserId)
        .single();

    final streamerId = profile["id"] as String;
    final agencyId = profile["agency_id"];
    final displayName = profile["display_name"] as String? ?? "Voce";

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final rows = await _client
        .from("calendar_events")
        .select(
            "id, title, description, event_date, start_time, end_time, all_day, location, meeting_link, color_override, event_categories(name, color, key)")
        .eq("agency_id", agencyId)
        .eq("show_in_app", true)
        .gte("event_date", fmt(monthStart))
        .lte("event_date", fmt(monthEnd))
        .order("event_date");

    final eventIds = (rows as List).map((r) => r["id"] as String).toList();

    final streamerParticipantsByEvent = <String, Set<String>>{};
    if (eventIds.isNotEmpty) {
      final participantRows = await _client
          .from("calendar_event_participants")
          .select("event_id, streamer_id, participant_type")
          .inFilter("event_id", eventIds)
          .eq("participant_type", "streamer");
      for (final p in (participantRows as List)) {
        final sid = p["streamer_id"] as String?;
        if (sid == null) continue;
        final eid = p["event_id"] as String;
        streamerParticipantsByEvent.putIfAbsent(eid, () => {}).add(sid);
      }
    }

    final events = <CalendarEvent>[];
    for (final r in rows) {
      final id = r["id"] as String;
      final streamerParticipants = streamerParticipantsByEvent[id] ?? const <String>{};
      final isGeneral = streamerParticipants.isEmpty;
      final isMine = streamerParticipants.contains(streamerId);
      if (!isGeneral && !isMine) continue;

      final catData = r["event_categories"];
      final catMap = catData is Map ? catData : null;
      final key = catMap?["key"] as String?;
      final overrideHex = r["color_override"] as String?;
      final effectiveColorHex = (overrideHex != null && overrideHex.isNotEmpty) ? overrideHex : catMap?["color"] as String?;

      final tags = <EventTag>{};
      if (isMine) tags.add(EventTag.streamer);
      if (isGeneral) tags.add(EventTag.agencia);
      if ((key ?? "").contains("tiktok")) tags.add(EventTag.tiktok);
      if (_trainingKeys.contains(key)) tags.add(EventTag.treinamento);

      events.add(CalendarEvent(
        id: id,
        title: r["title"] as String? ?? "Evento",
        description: r["description"] as String?,
        date: DateTime.parse(r["event_date"] as String),
        startTime: r["start_time"] as String?,
        endTime: r["end_time"] as String?,
        allDay: r["all_day"] as bool? ?? false,
        location: r["location"] as String?,
        meetingLink: r["meeting_link"] as String?,
        categoryName: catMap?["name"] as String?,
        categoryColor: _parseColor(effectiveColorHex),
        tags: tags,
      ));
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    return CalendarMonthData(events: events, streamerDisplayName: displayName);
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF7F8C8D);
    var value = hex.replaceAll("#", "");
    if (value.length == 6) value = "FF$value";
    final parsed = int.tryParse(value, radix: 16);
    return parsed != null ? Color(parsed) : const Color(0xFF7F8C8D);
  }
}
