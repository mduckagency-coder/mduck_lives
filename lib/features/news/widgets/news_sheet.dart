import "dart:math" as math;
import "package:mduck_lives/core/media/media_cache.dart";

import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../data/agency_news_repository.dart";

const _ink = Color(0xFF3E2A14);
const _inkSoft = Color(0xFF7A5A33);
const _gold = Color(0xFFB08A4E);
const _purple = Color(0xFF7A0BD4);

const _months = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];

/// Abre NOVIDADES como um pergaminho que desenrola do centro da tela.
/// [onAllRead] e chamado quando as novidades exibidas sao marcadas como lidas.
Future<void> showNewsSheet(BuildContext context, {VoidCallback? onAllRead}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar novidades",
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => _NewsScroll(onAllRead: onAllRead),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SizeTransition(sizeFactor: curved, axisAlignment: 0, child: child),
      );
    },
  );
}

class _NewsScroll extends StatefulWidget {
  final VoidCallback? onAllRead;
  const _NewsScroll({this.onAllRead});

  @override
  State<_NewsScroll> createState() => _NewsScrollState();
}

class _NewsScrollState extends State<_NewsScroll> {
  final _repository = AgencyNewsRepository();
  List<AgencyNews>? _items;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _limit = newsPageSize;
  Object? _error;

  /// Ids que estavam nao lidos quando a tela abriu: continuam com o selo
  /// "Nova" durante esta visita, mesmo depois de marcados como lidos.
  final Set<String> _newThisVisit = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.fetch(limit: _limit);
      if (!mounted) return;
      final unread = items.where((n) => !n.isRead).map((n) => n.id).toList();
      _newThisVisit.addAll(unread);
      setState(() {
        _items = items;
        _hasMore = items.length >= _limit;
        _error = null;
      });
      if (unread.isNotEmpty) {
        await _repository.markRead(unread);
        widget.onAllRead?.call();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _limit += newsPageSize;
    });
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.startsWith("http") ? url : "https://$url");
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o link.")));
    }
  }

  String _date(DateTime d) => "${d.day.toString().padLeft(2, "0")} ${_months[d.month - 1]} · ${d.year}";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: size.height * 0.86),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // papel
                  Positioned.fill(
                    top: 14,
                    bottom: 14,
                    child: CustomPaint(painter: _PaperPainter()),
                  ),
                  // rolos
                  const Positioned(left: -6, right: -6, top: 0, child: _Roll()),
                  const Positioned(left: -6, right: -6, bottom: 0, child: _Roll()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
                    child: Column(
                      children: [
                        _header(context),
                        const SizedBox(height: 10),
                        Expanded(child: _content()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    Widget ornament() => Expanded(
          child: Container(
            height: 1.4,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, _gold, Colors.transparent]),
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        const SizedBox(width: 40),
        ornament(),
        const Text("NOVIDADES",
            style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4)),
        ornament(),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: "Fechar",
            icon: const Icon(Icons.close_rounded, color: _inkSoft),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ]),
      const Text("da MDUCK Agency", style: TextStyle(color: _inkSoft, fontSize: 12, fontStyle: FontStyle.italic)),
    ]);
  }

  Widget _content() {
    if (_error != null && _items == null) {
      return const Center(
        child: Text("Não foi possível carregar as novidades agora.", textAlign: TextAlign.center, style: TextStyle(color: _inkSoft)),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator(color: _gold));
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Nenhuma novidade por enquanto.\nQuando a agência publicar algo, aparece aqui. 🏝️",
            textAlign: TextAlign.center,
            style: TextStyle(color: _inkSoft, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    // Prioriza o mes atual; o resto fica em "Anteriores".
    final now = DateTime.now();
    final thisMonth = items.where((n) => n.publishedAt.year == now.year && n.publishedAt.month == now.month).toList();
    final older = items.where((n) => !thisMonth.contains(n)).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (thisMonth.isNotEmpty) ...[
          _sectionLabel("Este mês"),
          for (var i = 0; i < thisMonth.length; i++) ...[
            if (i > 0) const _Divider(),
            _newsItem(thisMonth[i]),
          ],
        ],
        if (older.isNotEmpty) ...[
          _sectionLabel("Anteriores"),
          for (var i = 0; i < older.length; i++) ...[
            if (i > 0) const _Divider(),
            _newsItem(older[i]),
          ],
        ],
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
                  : TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.history, color: _inkSoft, size: 18),
                      label: const Text("Ver anteriores", style: TextStyle(color: _inkSoft, fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
      );

  Widget _newsItem(AgencyNews n) {
    final isNew = _newThisVisit.contains(n.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_date(n.publishedAt), style: const TextStyle(color: _inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
            if (isNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(8)),
                child: const Text("NOVA", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text(n.title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
          if (n.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(image: MediaCacheImage(n.imageUrl!),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(n.body, style: const TextStyle(color: _ink, fontSize: 15, height: 1.45)),
          if (n.linkUrl != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openLink(n.linkUrl!),
              icon: const Icon(Icons.open_in_new, size: 16, color: _purple),
              label: Text(n.linkLabel ?? "Saiba mais", style: const TextStyle(color: _purple, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _purple),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Separador entre novidades: linha fina com um losango no meio.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(child: Container(height: 1, color: _gold.withValues(alpha: 0.45)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        line(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text("✦", style: TextStyle(color: _gold, fontSize: 10)),
        ),
        line(),
      ]),
    );
  }
}

/// Rolo de madeira do pergaminho (em cima e embaixo).
class _Roll extends StatelessWidget {
  const _Roll();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(children: [
        _knob(),
        Expanded(
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEBCB8B), Color(0xFFC0904A), Color(0xFF8A5F2A)],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
            ),
          ),
        ),
        _knob(),
      ]),
    );
  }

  Widget _knob() => Container(
        width: 14,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF5A3A1A),
          borderRadius: BorderRadius.circular(7),
        ),
      );
}

/// Papel envelhecido: gradiente quente, borda escurecida e uma rosa dos
/// ventos bem clarinha no canto (detalhe de mapa, sem atrapalhar a leitura).
class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paper = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(
      paper,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8EBCB), Color(0xFFF3E1B6), Color(0xFFEBD39E)],
        ).createShader(rect),
    );
    // borda envelhecida
    canvas.drawRRect(
      paper,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, const Color(0xFF9C7238).withValues(alpha: 0.28)],
          stops: const [0.72, 1],
        ).createShader(rect),
    );

    // rosa dos ventos (marca d'agua)
    final c = Offset(size.width - 54, size.height - 64);
    final faint = Paint()
      ..color = const Color(0xFF9C7238).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, 34, faint);
    canvas.drawCircle(c, 26, faint);
    final fill = Paint()..color = const Color(0xFF9C7238).withValues(alpha: 0.13);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tip = c + Offset(math.cos(a), math.sin(a)) * 40;
      final l = c + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * 7;
      final r = c + Offset(math.cos(a - math.pi / 2), math.sin(a - math.pi / 2)) * 7;
      canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(l.dx, l.dy)..lineTo(r.dx, r.dy)..close(), fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
