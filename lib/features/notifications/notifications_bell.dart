import "package:flutter/material.dart";
import "../calendar/data/calendar_requests_repository.dart";

class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key});

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  final _repository = CalendarRequestsRepository();
  List<StreamerNotificationItem> _items = [];
  bool _loaded = false;

  static const _bg = Color(0xFF1A0B2E);
  static const _purple = Color(0xFFB026FF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.fetchNotifications();
      if (mounted) {
        setState(() {
          _items = items;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  int get _unreadCount => _items.where((n) => n.isUnread).length;

  Future<void> _markRead(StreamerNotificationItem item, StateSetter setSheetState) async {
    if (!item.isUnread) return;
    final idx = _items.indexWhere((n) => n.id == item.id);
    if (idx == -1) return;
    final updated = StreamerNotificationItem(
      id: item.id,
      type: item.type,
      subject: item.subject,
      message: item.message,
      readAt: DateTime.now(),
      createdAt: item.createdAt,
    );
    setState(() => _items[idx] = updated);
    setSheetState(() {});
    try {
      await _repository.markNotificationRead(item.id);
    } catch (_) {}
  }

  Color _colorFor(String type) {
    if (type.contains("aprov")) return Colors.greenAccent;
    if (type.contains("rejeit") || type.contains("recus")) return Colors.redAccent;
    return _purple;
  }

  IconData _iconFor(String type) {
    if (type.contains("aprov")) return Icons.check_circle;
    if (type.contains("rejeit") || type.contains("recus")) return Icons.cancel;
    if (type.contains("pedido")) return Icons.campaign;
    return Icons.info;
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("Notificacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Text("Nenhuma notificacao ainda.", style: TextStyle(color: Colors.white54)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final n = _items[i];
                            return ListTile(
                              onTap: () => _markRead(n, setSheetState),
                              leading: Icon(_iconFor(n.type), color: _colorFor(n.type)),
                              title: Text(
                                n.subject,
                                style: TextStyle(color: Colors.white, fontWeight: n.isUnread ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                              ),
                              subtitle: Text(n.message, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: n.isUnread
                                  ? Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _purple))
                                  : null,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white, size: 26),
          if (_loaded && _unreadCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black, width: 1)),
                child: Text(
                  _unreadCount > 9 ? "9+" : "$_unreadCount",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
