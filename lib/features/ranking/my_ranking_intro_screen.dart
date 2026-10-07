import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/share/image_share_menu.dart";
import "data/ranking_rows_repository.dart";

const _monthNames = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

/// 12345 -> "12.345"
String _formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? "-" : "");
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(".");
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 12.5 -> "12,5h" / 11.0 -> "11h"
String _formatHours(double hours) {
  // 8.45 (decimal da importacao) = 8h27, igual ao Ranking Geral.
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return m == 0 ? "${h}h" : "${h}h${m.toString().padLeft(2, "0")}";
}

/// Ate que posicao um ranking conta como destaque no cartao.
const _topLimit = 10;

typedef _StatsRow = ({String id, String? category, int diamonds, double hours, int battles});

/// Um dos rankings do Ranking Geral (Diamantes, Horas, Batalhas, Games,
/// Musicos) com o valor e a posicao do streamer nele.
class _RankingHighlight {
  final String key;
  final String name; // "Horas"
  final String emoji;
  final String value; // "12,5h"
  final String valueLabel; // "horas de live no mês"
  final String rankLabel; // "em horas"
  final int rank;

  /// Diamantes sempre pode; os outros so quando esta no Top 10.
  bool get canHighlight => key == "diamonds" || (rank > 0 && rank <= _topLimit);

  const _RankingHighlight({
    required this.key,
    required this.name,
    required this.emoji,
    required this.value,
    required this.valueLabel,
    required this.rankLabel,
    required this.rank,
  });
}

/// Titulo e frase do cartao conforme o ranking em destaque e a posicao.
({String title, String subtitle}) _messageFor(_RankingHighlight h) {
  final rank = h.rank;
  final isDiamonds = h.key == "diamonds";
  if (rank <= 0) {
    return (title: "Bora começar! 🚀", subtitle: "Faça sua primeira live do mês pra entrar no ranking.");
  }
  if (rank == 1) {
    return isDiamonds
        ? (title: "Topo da agência! 👑", subtitle: "Ninguém fez mais diamantes que você este mês.")
        : (title: "1º lugar em ${h.name}! 👑", subtitle: "Você lidera o ranking de ${h.name} da agência.");
  }
  if (rank >= 2 && rank <= 3) {
    return isDiamonds
        ? (title: "No pódio! 🏆", subtitle: "Você está entre os 3 maiores da agência.")
        : (title: "Pódio em ${h.name}! 🏆", subtitle: "Você está entre os 3 melhores em ${h.name} da agência.");
  }
  if (rank >= 4 && rank <= 10) {
    return (
      title: isDiamonds ? "Top 10 da agência! 🔥" : "Top 10 em ${h.name}! 🔥",
      subtitle: "Seu esforço está aparecendo. Bora pra cima!",
    );
  }
  return (title: "Mandou bem! 🚀", subtitle: "Cada live te deixa mais perto do topo.");
}

class MyRankingIntroScreen extends StatefulWidget {
  final VoidCallback onViewGeneralRanking;
  const MyRankingIntroScreen({super.key, required this.onViewGeneralRanking});

  @override
  State<MyRankingIntroScreen> createState() => _MyRankingIntroScreenState();
}

class _MyRankingIntroScreenState extends State<MyRankingIntroScreen> {
  final GlobalKey _shareKey = GlobalKey();
  bool _loading = true;
  String? _displayName;
  String? _photoUrl;

  /// Posicao do streamer em cada ranking do Ranking Geral (diamantes primeiro).
  List<_RankingHighlight> _highlights = const [];
  int _selected = 0;

  _RankingHighlight? get _current => _highlights.isEmpty ? null : _highlights[_selected];

  /// Rankings (alem de diamantes) em que o streamer esta no Top 10.
  List<_RankingHighlight> get _extraTops => _highlights.skip(1).where((h) => h.canHighlight).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final myProfile = await client
        .from("profiles")
        .select("id, display_name, avatar_url")
        .eq("auth_user_id", userId)
        .maybeSingle();

    if (myProfile == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final myId = myProfile["id"] as String;

    // Mesma consulta e mesmas regras de ordenacao do Ranking Geral
    // (ranking_content.dart), pra posicao bater com o que aparece la.
    // Fonte unica (servidor): ja respeita o periodo definido no painel.
    final board = await fetchRankingRows();
    final allStats = board != null
        ? const []
        : await client
            .from("profiles")
            .select("id, streamer_categories(name), streamer_stats(diamonds, hours_live, battles)")
            .eq("is_active", true);

    final rows = board != null
        ? [
            for (final r in board.rows)
              (id: r.id, category: r.categoryName, diamonds: r.diamonds, hours: r.hours, battles: r.battles),
          ]
        : allStats.map<_StatsRow>((r) {
      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      final catData = r["streamer_categories"];
      return (
        id: r["id"] as String,
        category: catData is Map ? catData["name"] as String? : null,
        diamonds: stats?["diamonds"] as int? ?? 0,
        hours: (stats?["hours_live"] as num?)?.toDouble() ?? 0.0,
        battles: stats?["battles"] as int? ?? 0,
      );
    }).toList();

    final me = rows.where((r) => r.id == myId).firstOrNull;
    final highlights = <_RankingHighlight>[];
    if (me != null) {
      // Sem nada no mes = sem posicao (0), igual ao Ranking Geral, que nao
      // lista quem esta zerado.
      int positionIn(List<_StatsRow> list, num Function(_StatsRow) metric) {
        if (metric(me) <= 0) return 0;
        final sorted = List.of(list.where((r) => metric(r) > 0))..sort((a, b) => metric(b).compareTo(metric(a)));
        return sorted.indexWhere((r) => r.id == myId) + 1;
      }

      bool isGames(String? c) => c == "Jogos";
      bool isMusic(String? c) => c == "Musica" || c == "Música";

      highlights.add(_RankingHighlight(
        key: "diamonds",
        name: "Diamantes",
        emoji: "💎",
        value: _formatThousands(me.diamonds),
        valueLabel: "diamantes no mês",
        rankLabel: "em diamantes",
        rank: positionIn(rows, (r) => r.diamonds),
      ));

      // Todos os rankings entram na lista (pra pessoa ver a posicao em cada
      // um); so os do Top 10 podem ir pro cartao (ver canHighlight).
      highlights.add(_RankingHighlight(
        key: "horas",
        name: "Horas",
        emoji: "⏱️",
        value: _formatHours(me.hours),
        valueLabel: "de live no mês",
        rankLabel: "em horas",
        rank: positionIn(rows, (r) => r.hours),
      ));

      highlights.add(_RankingHighlight(
        key: "batalhas",
        name: "Batalhas",
        emoji: "⚔️",
        value: _formatThousands(me.battles),
        valueLabel: "batalhas no mês",
        rankLabel: "em batalhas",
        rank: positionIn(rows, (r) => r.battles),
      ));

      // Games/Musicos so existem pra quem e dessa categoria.
      if (isGames(me.category)) {
        highlights.add(_RankingHighlight(
          key: "jogos",
          name: "Games",
          emoji: "🎮",
          value: _formatThousands(me.diamonds),
          valueLabel: "diamantes no mês",
          rankLabel: "entre os Games",
          rank: positionIn(rows.where((r) => isGames(r.category)).toList(), (r) => r.diamonds),
        ));
      }

      if (isMusic(me.category)) {
        highlights.add(_RankingHighlight(
          key: "musicos",
          name: "Músicos",
          emoji: "🎵",
          value: _formatThousands(me.diamonds),
          valueLabel: "diamantes no mês",
          rankLabel: "entre os Músicos",
          rank: positionIn(rows.where((r) => isMusic(r.category)).toList(), (r) => r.diamonds),
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _displayName = myProfile["display_name"] as String?;
      _photoUrl = myProfile["avatar_url"] as String?;
      _highlights = highlights;
      _selected = 0;
      _loading = false;
    });
  }

  /// Lista pra escolher qual ranking vai em destaque no cartao.
  void _openHighlightPicker() {
    if (_highlights.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "O que mostrar no cartão?",
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Rankings em que você está no Top 10 podem ir para o cartão.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _highlights.length; i++)
                Opacity(
                  opacity: _highlights[i].canHighlight ? 1 : 0.45,
                  child: ListTile(
                    onTap: _highlights[i].canHighlight
                        ? () {
                            Navigator.of(sheetContext).pop();
                            setState(() => _selected = i);
                          }
                        : null,
                    leading: Text(_highlights[i].emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(_highlights[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _highlights[i].canHighlight
                          ? "${_highlights[i].value} ${_highlights[i].valueLabel}"
                          : "🔒 Chegue ao Top 10 para destacar",
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _highlights[i].rank > 0 ? "#${_highlights[i].rank}" : "-",
                          style: TextStyle(
                            color: _highlights[i].rank > 0 && _highlights[i].rank <= 3 ? const Color(0xFFFFD700) : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          i == _selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: const Color(0xFFB026FF),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _shareText =>
      "Meu mês na MDUCK Agency: ${_current!.value} ${_current!.valueLabel}${_current!.rank > 0 ? " e #${_current!.rank} ${_current!.rankLabel}" : ""}! ${_current!.emoji}🦆";

  /// Mesmo menu de compartilhar usado pelas Conquistas (core/share).
  void _openShareMenu() {
    ImageShareMenu.show(
      context,
      title: "Compartilhar meu resultado",
      capture: () => ImageShareMenu.capture(_shareKey),
      text: _shareText,
      fileName: "meu_ranking_mduck.png",
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFF1A0B2E), body: Center(child: CircularProgressIndicator()));
    }
    if (_displayName == null || _current == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A0B2E),
        body: Center(
          child: ElevatedButton(
            onPressed: widget.onViewGeneralRanking,
            child: const Text("Ver Ranking Geral"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0114),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    // formato vertical, igual aos stories do TikTok/Instagram
                    aspectRatio: 9 / 16,
                    child: RepaintBoundary(
                      key: _shareKey,
                      child: _RankingCard(
                        displayName: _displayName!,
                        photoUrl: _photoUrl,
                        highlight: _current!,
                        onTapStats: _openHighlightPicker,
                      ),
                    ),
                  ),
                ),
              ),
              // Fora do cartao (nao sai na imagem). Fica sempre visivel; em
              // dourado quando ha outro Top 10 pra mostrar.
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final extras = _extraTops;
                final hasExtras = extras.isNotEmpty;
                return TextButton.icon(
                  onPressed: _openHighlightPicker,
                  icon: Icon(Icons.swap_horiz, color: hasExtras ? const Color(0xFFFFD700) : Colors.white70),
                  label: Text(
                    hasExtras
                        ? "🔥 Top 10 em ${extras.map((h) => h.name).join(", ")}! Trocar o que aparece no cartão"
                        : "Trocar o que aparece no cartão",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: hasExtras ? const Color(0xFFFFD700) : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: hasExtras ? const Color(0xFFFFD700) : Colors.white70,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  icon: Icons.share,
                  label: "Compartilhar ou salvar",
                  busy: false,
                  onPressed: _openShareMenu,
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  icon: Icons.leaderboard,
                  label: "Ver ranking geral da agência",
                  busy: false,
                  onPressed: widget.onViewGeneralRanking,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O cartao que vira imagem: foto do streamer, o valor do ranking em
/// destaque (diamantes por padrao) e a posicao nele.
class _RankingCard extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final _RankingHighlight highlight;

  /// Toque nos quadros de numeros: troca o ranking em destaque.
  final VoidCallback? onTapStats;

  const _RankingCard({
    required this.displayName,
    required this.photoUrl,
    required this.highlight,
    this.onTapStats,
  });

  @override
  Widget build(BuildContext context) {
    final message = _messageFor(highlight);
    final rank = highlight.rank;
    final month = _monthNames[DateTime.now().month - 1];

    return LayoutBuilder(
      builder: (context, constraints) {
        // tudo proporcional a largura do cartao, pra imagem sair igual em
        // qualquer tamanho de tela
        final u = constraints.maxWidth / 100;
        return ClipRRect(
          borderRadius: BorderRadius.circular(5 * u),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0650), Color(0xFF12022A), Color(0xFF0A0114)],
              ),
            ),
            child: Stack(
              children: [
                // brilho roxo atras do avatar
                Positioned(
                  left: -20 * u,
                  right: -20 * u,
                  top: 30 * u,
                  height: 110 * u,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [const Color(0xFFB026FF).withValues(alpha: 0.45), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7 * u, vertical: 7 * u),
                  child: Column(
                    children: [
                      Image.asset("assets/splash/logo_mduck_recortado.png", width: 58 * u, fit: BoxFit.contain),
                      SizedBox(height: 1 * u),
                      Text(
                        "Meu mês de $month",
                        style: TextStyle(color: Colors.white60, fontSize: 4 * u, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 1 * u),
                      Text(
                        message.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 8 * u, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 1.5 * u),
                      Text(
                        message.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 4 * u),
                      ),
                      Expanded(
                        child: Center(
                          child: _StreamerPhoto(displayName: displayName, photoUrl: photoUrl, unit: u),
                        ),
                      ),
                      Text(
                        "@$displayName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 6 * u, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4 * u),
                      GestureDetector(
                        onTap: onTapStats,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatBox(
                                unit: u,
                                icon: highlight.emoji,
                                value: highlight.value,
                                label: highlight.valueLabel,
                              ),
                            ),
                            SizedBox(width: 3 * u),
                            Expanded(
                              child: _StatBox(
                                unit: u,
                                icon: "🏆",
                                value: rank > 0 ? "#$rank" : "-",
                                label: highlight.rankLabel,
                                highlight: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4 * u),
                      Text(
                        "MDUCK Agency",
                        style: TextStyle(color: const Color(0xFFB98CFF), fontSize: 3.5 * u, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Foto do streamer em destaque no centro do cartao (antes era o avatar da
/// Ilha Top, que esta desligada).
class _StreamerPhoto extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final double unit;

  const _StreamerPhoto({required this.displayName, required this.photoUrl, required this.unit});

  @override
  Widget build(BuildContext context) {
    final size = 54 * unit;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(1.4 * unit),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD700), Color(0xFFB026FF)]),
        boxShadow: [BoxShadow(color: const Color(0xFFB026FF).withValues(alpha: 0.55), blurRadius: 10 * unit)],
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image(image: MediaCacheImage(photoUrl!), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7A0BD4), Color(0xFF2A1B5E)]),
        ),
        alignment: Alignment.center,
        child: Text(
          displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : "🦆",
          style: TextStyle(color: Colors.white, fontSize: 22 * unit, fontWeight: FontWeight.w900),
        ),
      );
}

class _StatBox extends StatelessWidget {
  final double unit;
  final String icon;
  final String value;
  final String label;
  final bool highlight;

  const _StatBox({
    required this.unit,
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final u = unit;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 3.5 * u, horizontal: 2 * u),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4 * u),
        border: Border.all(
          color: highlight ? const Color(0xFFFFD700).withValues(alpha: 0.7) : const Color(0xFFB026FF).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: TextStyle(fontSize: 6 * u)),
          SizedBox(height: 1 * u),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? const Color(0xFFFFD700) : Colors.white,
                fontSize: 8 * u,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(label, style: TextStyle(color: Colors.white60, fontSize: 3.3 * u)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 18);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    const padding = EdgeInsets.symmetric(vertical: 14);
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7A0BD4),
          foregroundColor: Colors.white,
          padding: padding,
          shape: shape,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: iconWidget,
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFFB026FF).withValues(alpha: 0.12),
        side: const BorderSide(color: Color(0xFFB026FF), width: 1.5),
        padding: padding,
        shape: shape,
      ),
    );
  }
}

/// Menu de compartilhar: TikTok em destaque, depois Instagram, WhatsApp,
/// salvar na galeria e o menu completo do celular.
