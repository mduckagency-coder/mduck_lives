import "package:flutter/material.dart";
import "data/calendar_repository.dart";
import "request_event_page.dart";

class CalendarContent extends StatefulWidget {
  const CalendarContent({super.key});

  @override
  State<CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends State<CalendarContent> {
  final _repository = CalendarRepository();
  late DateTime _month;
  DateTime? _selectedDay;
  EventTag? _selectedTag;
  late Future<CalendarMonthData> _future;

  static const _monthNames = [
    "Janeiro", "Fevereiro", "Marco", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
  ];
  static const _weekdayShort = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _future = _repository.fetchMonth(_month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
      _future = _repository.fetchMonth(_month);
    });
  }

  Color _tagColor(EventTag? tag) {
    switch (tag) {
      case EventTag.streamer:
        return const Color(0xFFB026FF);
      case EventTag.agencia:
        return const Color(0xFF6C4BD6);
      case EventTag.tiktok:
        return const Color(0xFFD84FE0);
      case EventTag.treinamento:
        return const Color(0xFF4B2E83);
      case null:
        return const Color(0xFF9B59F6);
    }
  }

  IconData _tagIcon(EventTag? tag) {
    switch (tag) {
      case EventTag.streamer:
        return Icons.person;
      case EventTag.agencia:
        return Icons.groups;
      case EventTag.tiktok:
        return Icons.music_note;
      case EventTag.treinamento:
        return Icons.school;
      case null:
        return Icons.apps;
    }
  }

  String _tagLabel(EventTag? tag, String streamerName) {
    switch (tag) {
      case EventTag.streamer:
        return "Eventos $streamerName";
      case EventTag.agencia:
        return "Eventos Agencia";
      case EventTag.tiktok:
        return "Campanhas TikTok";
      case EventTag.treinamento:
        return "Treinamentos Agencia";
      case null:
        return "Todos os eventos";
    }
  }

  String? _fmtTime(String? t) => (t != null && t.length >= 5) ? t.substring(0, 5) : t;

  void _showFilterMenu(String streamerName) {
    const options = <EventTag?>[null, EventTag.streamer, EventTag.agencia, EventTag.tiktok, EventTag.treinamento];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Filtrar eventos", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...options.map((tag) {
                final selected = _selectedTag == tag;
                final color = _tagColor(tag);
                return ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.2)),
                    child: Icon(_tagIcon(tag), color: color, size: 18),
                  ),
                  title: Text(
                    _tagLabel(tag, streamerName),
                    style: TextStyle(color: selected ? color : Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                  ),
                  trailing: selected ? Icon(Icons.check, color: color) : null,
                  onTap: () {
                    setState(() => _selectedTag = tag);
                    Navigator.of(context).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CalendarMonthData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Nao foi possivel carregar o calendario.\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        var tagFiltered = data.events;
        if (_selectedTag != null) {
          tagFiltered = tagFiltered.where((e) => e.tags.contains(_selectedTag)).toList();
        }

        List<CalendarEvent> displayed;
        String sectionTitle;
        if (_selectedDay != null) {
          final day = _selectedDay!;
          displayed = tagFiltered
              .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
              .toList();
          sectionTitle = "Eventos em ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}";
        } else {
          displayed = tagFiltered.where((e) => !e.date.isBefore(today)).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          sectionTitle = "Proximos Eventos";
        }

        return Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 4),
                _monthHeader(),
                const SizedBox(height: 8),
                _weekdayHeader(),
                _monthGrid(daysInMonth, today, data.events),
                const SizedBox(height: 12),
                _filterButton(data.streamerDisplayName),
                const SizedBox(height: 10),
                _sectionHeader(sectionTitle, _selectedDay != null),
                Expanded(child: _eventList(displayed)),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _newRequestButton(),
            ),
          ],
        );
      },
    );
  }

  Widget _newRequestButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestEventPage())),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]),
          boxShadow: [BoxShadow(color: const Color(0xFFB026FF).withOpacity(0.5), blurRadius: 14, spreadRadius: 1)],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _changeMonth(-1),
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A1B5E)),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          ),
        ),
        SizedBox(
          width: 170,
          child: Center(
            child: Text(
              "${_monthNames[_month.month - 1]} ${_month.year}".toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _changeMonth(1),
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A1B5E)),
            child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _weekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: _weekdayShort
            .map((w) => Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// Grade com o mes inteiro visivel de uma vez (sem precisar rolar entre os dias).
  Widget _monthGrid(int daysInMonth, DateTime today, List<CalendarEvent> allEvents) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalCells,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          if (index < firstWeekday) return const SizedBox.shrink();

          final day = index - firstWeekday + 1;
          final date = DateTime(_month.year, _month.month, day);
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final isSelected = _selectedDay != null &&
              _selectedDay!.year == date.year &&
              _selectedDay!.month == date.month &&
              _selectedDay!.day == date.day;
          final dayTags = allEvents
              .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
              .expand((e) => e.tags)
              .toSet();

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = isSelected ? null : date),
            child: Container(
              decoration: BoxDecoration(
                gradient: isToday ? const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]) : null,
                color: isToday ? null : (isSelected ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.03)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isSelected && !isToday) ? const Color(0xFFB026FF) : Colors.transparent,
                  width: 1.3,
                ),
                boxShadow: isToday
                    ? [BoxShadow(color: const Color(0xFFB026FF).withOpacity(0.5), blurRadius: 6, spreadRadius: 0.3)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$day",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dayTags.take(3).map((t) {
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _tagColor(t)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterButton(String streamerName) {
    final color = _tagColor(_selectedTag);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _showFilterMenu(streamerName),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.65)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 0.5)],
          ),
          child: Row(
            children: [
              Icon(_tagIcon(_selectedTag), color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tagLabel(_selectedTag, streamerName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool showClear) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (showClear)
            GestureDetector(
              onTap: () => setState(() => _selectedDay = null),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, color: Colors.white54, size: 14),
                  SizedBox(width: 2),
                  Text("limpar", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventCard(CalendarEvent event) {
    final primaryTag = event.tags.contains(EventTag.streamer)
        ? EventTag.streamer
        : event.tags.contains(EventTag.tiktok)
            ? EventTag.tiktok
            : event.tags.contains(EventTag.treinamento)
                ? EventTag.treinamento
                : EventTag.agencia;
    final barColor = _tagColor(primaryTag);
    final startTime = _fmtTime(event.startTime);
    final endTime = _fmtTime(event.endTime);
    final timeLabel = event.allDay
        ? "Dia todo"
        : [startTime, endTime].where((t) => t != null && t.isNotEmpty).join(" - ");

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        Text(
                          "${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    if (event.categoryName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: event.categoryColor)),
                          const SizedBox(width: 5),
                          Text(event.categoryName!, style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(timeLabel, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.white54),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(event.location!, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventList(List<CalendarEvent> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text("Nenhum evento neste periodo.", style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: events.length,
      itemBuilder: (context, index) => _eventCard(events[index]),
    );
  }
}
