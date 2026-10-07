import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "../challenge_overlay.dart";
import "../data/challenge_repository.dart";
import "dice_icon.dart";

/// Dado da Home: so o icone, sem nenhum texto (e uma descoberta). Aparece
/// apenas quando existe algum jogo ativo no painel; de tempos em tempos da
/// uma balancadinha sutil pra despertar curiosidade.
class DiceButton extends StatefulWidget {
  const DiceButton({super.key});

  @override
  State<DiceButton> createState() => _DiceButtonState();
}

class _DiceButtonState extends State<DiceButton> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _repository = ChallengeRepository();
  final _random = Random();
  List<String> _games = const [];
  Timer? _wobbleTimer;
  Timer? _refreshTimer;

  late final AnimationController _wobble = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
    _wobbleTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (_games.isNotEmpty && mounted) _wobble.forward(from: 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wobbleTimer?.cancel();
    _refreshTimer?.cancel();
    _wobble.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final keys = await _repository.fetchActiveGameKeys();
      // so jogos que esta versao do app sabe abrir
      final supported = keys.where(challengeGames.containsKey).toList();
      if (mounted) setState(() => _games = supported);
    } catch (_) {
      // tabelas ainda nao criadas / sem conexao: dado fica escondido
      if (mounted) setState(() => _games = const []);
    }
  }

  void _open() {
    if (_games.isEmpty) return;
    showChallengeOverlay(context, _games[_random.nextInt(_games.length)]);
  }

  @override
  Widget build(BuildContext context) {
    if (_games.isEmpty) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: "Dado",
      child: GestureDetector(
        onTap: _open,
        child: AnimatedBuilder(
          animation: _wobble,
          builder: (context, child) {
            // balancadinha que amortece: sin com decaimento
            final t = _wobble.value;
            final angle = sin(t * pi * 4) * 0.18 * (1 - t);
            return Transform.rotate(angle: angle, child: child);
          },
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 10, bottom: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(color: const Color(0xFFD9B672).withValues(alpha: 0.85), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Center(child: DiceIcon(size: 30)),
          ),
        ),
      ),
    );
  }
}
