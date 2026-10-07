import "package:supabase_flutter/supabase_flutter.dart";

/// Quantas novidades o pergaminho busca por vez (e quantas a mais o "Ver
/// anteriores" traz). O historico completo fica no painel web.
const newsPageSize = 15;

/// Uma novidade da agencia (painel web > Operacoes APP > Novidades Home).
class AgencyNews {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkLabel;
  final DateTime publishedAt;
  final bool isRead;

  const AgencyNews({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    this.linkLabel,
    required this.publishedAt,
    required this.isRead,
  });

  factory AgencyNews.fromMap(Map<String, dynamic> m) => AgencyNews(
        id: m["id"] as String,
        title: m["title"] as String? ?? "",
        body: m["body"] as String? ?? "",
        imageUrl: _clean(m["image_url"]),
        linkUrl: _clean(m["link_url"]),
        linkLabel: _clean(m["link_label"]),
        publishedAt: DateTime.tryParse(m["published_at"] as String? ?? "")?.toLocal() ?? DateTime.now(),
        isRead: m["is_read"] == true,
      );

  static String? _clean(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  AgencyNews markedRead() => AgencyNews(
        id: id,
        title: title,
        body: body,
        imageUrl: imageUrl,
        linkUrl: linkUrl,
        linkLabel: linkLabel,
        publishedAt: publishedAt,
        isRead: true,
      );
}

/// Novidades da agencia pro streamer logado. Quem decide o que ele pode ver
/// (publico, datas, ativo) e a funcao app_news_for_me no banco -- separado do
/// sino de notificacoes (streamer_notifications).
class AgencyNewsRepository {
  final _client = Supabase.instance.client;

  Future<List<AgencyNews>> fetch({int limit = newsPageSize}) async {
    final rows = await _client.rpc("app_news_for_me", params: {"p_limit": limit});
    return [for (final r in (rows as List)) AgencyNews.fromMap(r as Map<String, dynamic>)];
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.rpc("app_mark_news_read", params: {"p_news_ids": ids});
  }
}
