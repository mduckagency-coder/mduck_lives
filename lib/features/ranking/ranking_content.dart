import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../home/data/streamer_repository.dart";
import "data/ranking_rows_repository.dart";

class _StreamerRow {
  final String displayName;
  final String? avatarUrl;
  final String? categoryName;
  final int diamonds;
  final double hoursLive;
  final int battles;
  _StreamerRow({
    required this.displayName,
    required this.avatarUrl,
    required this.categoryName,
    required this.diamonds,
    required this.hoursLive,
    required this.battles,
  });
}

class RankingContent extends StatefulWidget {
  final VoidCallback? onBack;
  const RankingContent({super.key, this.onBack});

  @override
  State<RankingContent> createState() => _RankingContentState();
}

class _RankingContentState extends State<RankingContent> {
  String _activeView = "diamonds";
  String _selectedPeriod = "atual";
  List<String> _availablePeriods = [];
  late Future<List<_StreamerRow>> _future;
  final _positionsRepository = StreamerRepository();
  StreamerPositions? _myPositions;

  static const _sideButtons = [
    ("diamonds", "Diamantes", Icons.diamond),
    ("horas", "Horas", Icons.access_time),
    ("batalhas", "Batalhas", null),
    ("jogos", "Games", Icons.sports_esports),
    ("musicos", "Musicos", Icons.music_note),
  ];

  @override
  void initState() {
    super.initState();
    _loadPeriods();
    _future = _load();
    _loadMyPositions();
  }

  Future<void> _loadMyPositions() async {
    try {
      final positions = await _positionsRepository.fetchCurrentPositions();
      if (mounted) setState(() => _myPositions = positions);
    } catch (_) {
      // streamer sem posicao calculavel ainda (sem stats) - ignora silenciosamente
    }
  }

  Future<void> _loadPeriods() async {
    final client = Supabase.instance.client;
    // meses fechados da agencia inteira (funcao do servidor: a tabela de
    // historico so deixa cada streamer ler a propria linha)
    try {
      final rows = await client.rpc("app_month_periods");
      final keys = <String>[for (final r in (rows as List)) r is String ? r : (r as Map).values.first as String];
      if (mounted) setState(() => _availablePeriods = keys);
    } catch (_) {
      // migracao 0100 ainda nao rodada: sem seletor de meses anteriores
    }
  }

  Future<List<_StreamerRow>> _load() async {
    final client = Supabase.instance.client;

    // Fonte unica (servidor): ja respeita o periodo definido no painel.
    final board = await fetchRankingRows(_selectedPeriod == "atual" ? null : _selectedPeriod);
    if (board != null) {
      return [
        for (final r in board.rows)
          _StreamerRow(
            displayName: r.displayName,
            avatarUrl: r.avatarUrl,
            categoryName: r.categoryName,
            diamonds: r.diamonds,
            hoursLive: r.hours,
            battles: r.battles,
          ),
      ];
    }

    if (_selectedPeriod == "atual") {
      final rows = await client
          .from("profiles")
          .select("id, display_name, avatar_url, streamer_categories(name), streamer_stats(diamonds, hours_live, battles)")
          .eq("is_active", true);
      return (rows as List).map((r) {
        final statsData = r["streamer_stats"];
        Map<String, dynamic>? stats;
        if (statsData is List && statsData.isNotEmpty) {
          stats = statsData.first as Map<String, dynamic>;
        } else if (statsData is Map) {
          stats = statsData as Map<String, dynamic>;
        }
        final catData = r["streamer_categories"];
        return _StreamerRow(
          displayName: r["display_name"] as String,
          avatarUrl: r["avatar_url"] as String?,
          categoryName: catData is Map ? catData["name"] as String? : null,
          diamonds: stats?["diamonds"] as int? ?? 0,
          hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
          battles: stats?["battles"] as int? ?? 0,
        );
      }).toList();
    } else {
      // resultado final do mes: todos da agencia (com ou sem login no app),
      // com a foto com que cada um terminou o mes
      final rows = await client.rpc("app_month_board", params: {"p_period": _selectedPeriod});
      return (rows as List).map((r) {
        return _StreamerRow(
          displayName: r["display_name"] as String? ?? "Ducker",
          avatarUrl: r["avatar_url"] as String?,
          categoryName: r["category_name"] as String?,
          diamonds: (r["diamonds"] as num?)?.toInt() ?? 0,
          hoursLive: (r["hours_live"] as num?)?.toDouble() ?? 0,
          battles: (r["battles"] as num?)?.toInt() ?? 0,
        );
      }).toList();
    }
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final options = ["atual", ..._availablePeriods];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text("Escolha o mes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
              ...options.map((p) {
                final selected = _selectedPeriod == p;
                return ListTile(
                  title: Text(_fullMonthLabel(p), style: TextStyle(color: selected ? const Color(0xFFB026FF) : Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  trailing: selected ? const Icon(Icons.check, color: Color(0xFFB026FF)) : null,
                  onTap: () {
                    _changePeriod(p);
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

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      _future = _load();
    });
  }

  /// Horas vem decimais da importacao (8.45 = 8h27) -> "8h27".
  /// Diamantes/batalhas com ponto de milhar -> "14.368".
  String _formatMetric(num value, String view) {
    if (view == "horas") {
      final totalMinutes = (value * 60).round();
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return m == 0 ? "${h}h" : "${h}h${m.toString().padLeft(2, "0")}";
    }
    final digits = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(".");
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  num _valueFor(_StreamerRow s, String view) {
    switch (view) {
      case "horas":
        return s.hoursLive;
      case "batalhas":
        return s.battles;
      default:
        return s.diamonds;
    }
  }

  List<_StreamerRow> _rankedFor(List<_StreamerRow> all, String view) {
    var list = all;
    if (view == "jogos") list = all.where((s) => s.categoryName == "Jogos").toList();
    if (view == "musicos") list = all.where((s) => s.categoryName == "Musica" || s.categoryName == "M\u00fasica").toList();
    final metric = (view == "jogos" || view == "musicos") ? "diamonds" : view;
    // Quem nao tem nada no periodo (ex.: ainda sem live no mes) nao entra.
    list = list.where((s) => _valueFor(s, metric) > 0).toList();
    list = List.of(list)..sort((a, b) => _valueFor(b, metric).compareTo(_valueFor(a, metric)));
    return list;
  }

  String _viewTitle(String view) {
    switch (view) {
      case "horas":
        return "Ranking de Horas";
      case "batalhas":
        return "Ranking de Batalhas";
      case "jogos":
        return "Top Games";
      case "musicos":
        return "Top Musicos";
      default:
        return "Ranking de Diamantes";
    }
  }

  static const _fullMonths = ["Janeiro", "Fevereiro", "Marco", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

  String _currentMonthName() => _fullMonths[DateTime.now().month - 1];

  String _fullMonthLabel(String period) {
    if (period == "atual") return _currentMonthName();
    final parts = period.split("-");
    if (parts.length == 2) {
      final monthIdx = int.tryParse(parts[1]);
      if (monthIdx != null && monthIdx >= 1 && monthIdx <= 12) return _fullMonths[monthIdx - 1];
    }
    return period;
  }

  String _periodLabel(String period) {
    if (period == "atual") return "Este mes";
    final parts = period.split("-");
    if (parts.length == 2) {
      const months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
      final monthIdx = int.tryParse(parts[1]);
      if (monthIdx != null && monthIdx >= 1 && monthIdx <= 12) {
        return months[monthIdx - 1] + "/" + parts[0].substring(2);
      }
    }
    return period;
  }

  Widget _crownPodiumSlot(_StreamerRow s, int place, String view) {
    final heights = {1: 0.0, 2: 14.0, 3: 22.0};
    final avatarSizes = {1: 44.0, 2: 34.0, 3: 30.0};
    final badgeColors = {1: const Color(0xFFFFD700), 2: const Color(0xFFC7CBD1), 3: const Color(0xFFE0A56F)};
    final value = _valueFor(s, (view == "jogos" || view == "musicos") ? "diamonds" : view);

    return Padding(
      padding: EdgeInsets.only(top: heights[place]!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place == 1) const Text("\ud83d\udc51", style: TextStyle(fontSize: 26)),
          if (place == 1) const SizedBox(height: 2),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSizes[place]! + 8,
                height: avatarSizes[place]! + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]),
                  boxShadow: [BoxShadow(color: const Color(0xFFB026FF).withOpacity(0.5), blurRadius: 14, spreadRadius: 1)],
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: avatarSizes[place]! / 2,
                  backgroundColor: Colors.white24,
                  backgroundImage: s.avatarUrl != null ? MediaCacheImage(s.avatarUrl!) : null,
                  child: s.avatarUrl == null ? Icon(Icons.person, color: Colors.white70, size: avatarSizes[place]! / 2) : null,
                ),
              ),
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColors[place], border: Border.all(color: const Color(0xFF1A0B2E), width: 2)),
                    child: Text(place.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 84,
            child: Text(s.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Text(_formatMetric(value, view), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  /// A posicao de categoria so deve aparecer na aba cuja categoria bate com
  /// a categoria real do streamer (ex: streamer de "Batalha" so ve a posicao
  /// de categoria na aba "Batalhas", nao em "Jogos" ou "Musicos").
  bool _categoryMatchesTab(String key, String categoryName) {
    final c = categoryName.toLowerCase();
    switch (key) {
      case "batalhas":
        return c.contains("batalh");
      case "jogos":
        return c.contains("jog");
      case "musicos":
        return c.contains("musi");
      default:
        return false;
    }
  }

  int? _positionFor(String key) {
    final positions = _myPositions;
    if (positions == null) return null;
    switch (key) {
      case "diamonds":
        return positions.diamondPosition;
      case "horas":
        return positions.hoursPosition;
      case "batalhas":
      case "jogos":
      case "musicos":
        return _categoryMatchesTab(key, positions.categoryName) ? positions.categoryPosition : null;
      default:
        return null;
    }
  }

  Widget _sideIconButton(String key, String label, IconData? icon) {
    final selected = _activeView == key;
    final size = selected ? 44.0 : 30.0;
    final iconSize = selected ? 22.0 : 14.0;
    final position = selected ? _positionFor(key) : null;
    return GestureDetector(
      onTap: () => setState(() => _activeView = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]) : null,
                color: selected ? null : Colors.white.withOpacity(0.06),
                border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
                boxShadow: selected ? [BoxShadow(color: const Color(0xFFB026FF).withOpacity(0.5), blurRadius: 8, spreadRadius: 0.5)] : null,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: selected ? Colors.white : Colors.white30, size: iconSize)
                    : Opacity(opacity: selected ? 1.0 : 0.3, child: Text("\ud83e\udd4a", style: TextStyle(fontSize: iconSize))),
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: selected ? Colors.white70 : Colors.white24, fontSize: selected ? 9 : 7), textAlign: TextAlign.center),
            if (position != null) ...[
              const SizedBox(height: 1),
              Text("#$position", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _restRow(_StreamerRow s, int place, String view) {
    final value = _valueFor(s, (view == "jogos" || view == "musicos") ? "diamonds" : view);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A1FB8), Color(0xFF3D0F73)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
            child: Text(place.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            backgroundImage: s.avatarUrl != null ? MediaCacheImage(s.avatarUrl!) : null,
            child: s.avatarUrl == null ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          Text(_formatMetric(value, view), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StreamerRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final ranked = _rankedFor(snapshot.data!, _activeView).take(10).toList();
        final top3 = ranked.take(3).toList();
        final rest = ranked.length > 3 ? ranked.sublist(3) : <_StreamerRow>[];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (_activeView != "diamonds") {
                              setState(() => _activeView = "diamonds");
                            } else {
                              widget.onBack?.call();
                            }
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A1B5E)),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _viewTitle(_activeView).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showMonthPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_fullMonthLabel(_selectedPeriod), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 3),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _sideButtons.map((b) => _sideIconButton(b.$1, b.$2, b.$3)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (top3.isEmpty)
                    const Expanded(child: Center(child: Text("Nenhum streamer nesse ranking ainda.", style: TextStyle(color: Colors.white54))))
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (top3.length > 1) _crownPodiumSlot(top3[1], 2, _activeView),
                          const SizedBox(width: 10),
                          _crownPodiumSlot(top3[0], 1, _activeView),
                          const SizedBox(width: 10),
                          if (top3.length > 2) _crownPodiumSlot(top3[2], 3, _activeView),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: rest.length,
                        itemBuilder: (context, index) => _restRow(rest[index], index + 4, _activeView),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ],
        );
      },
    );
  }

  Widget _simpleMonthLabel(String period) {
    final selected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => _changePeriod(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]) : null,
          color: selected ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _fullMonthLabel(period),
          style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _periodChip(String period) {
    final selected = _selectedPeriod == period;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _changePeriod(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [Color(0xFFB026FF), Color(0xFF7A0BD4)]) : null,
            color: selected ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.withOpacity(0.15)),
            boxShadow: selected ? [BoxShadow(color: const Color(0xFFB026FF).withOpacity(0.4), blurRadius: 8, spreadRadius: 0.5)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check, color: Colors.white, size: 13)),
              Text(_periodLabel(period), style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

















