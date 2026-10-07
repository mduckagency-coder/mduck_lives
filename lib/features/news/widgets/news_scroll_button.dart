import "dart:async";

import "package:flutter/material.dart";
import "../data/agency_news_repository.dart";
import "news_sheet.dart";
import "parchment_icon.dart";

/// Botao flutuante do pergaminho na Home: abre NOVIDADES e mostra um selinho
/// com quantas novidades ainda nao foram lidas. Atualiza sozinho ao voltar
/// pro app e a cada poucos minutos.
class NewsScrollButton extends StatefulWidget {
  const NewsScrollButton({super.key});

  @override
  State<NewsScrollButton> createState() => _NewsScrollButtonState();
}

class _NewsScrollButtonState extends State<NewsScrollButton> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _repository = AgencyNewsRepository();
  int _unread = 0;
  Timer? _refreshTimer;

  // leve "respiracao" so quando ha novidade nao lida
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final items = await _repository.fetch();
      if (!mounted) return;
      _setUnread(items.where((n) => !n.isRead).length);
    } catch (_) {
      // tabela/funcao ainda nao criada no banco: pergaminho sem selinho
    }
  }

  void _setUnread(int count) {
    setState(() => _unread = count);
    if (count > 0) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  Future<void> _open() async {
    await showNewsSheet(context, onAllRead: () => _setUnread(0));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _unread > 0 ? "Novidades da agência, $_unread não lidas" : "Novidades da agência",
      child: GestureDetector(
        onTap: _open,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Transform.scale(scale: 1 + t * 0.06, child: child);
          },
          child: SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(color: const Color(0xFFD9B672).withValues(alpha: 0.85), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Center(child: ParchmentIcon(size: 38)),
                ),
                if (_unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB026FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _unread > 9 ? "9+" : "$_unread",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
