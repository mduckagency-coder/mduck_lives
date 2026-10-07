import "dart:ui";

import "package:flutter/material.dart";
import "data/challenge_repository.dart";
import "games/tic_tac_toe_game.dart";
import "widgets/dice_icon.dart";

const _gold = Color(0xFFFFC94D);

/// Catalogo de jogos do dado: game_key (cadastrado no painel em Desafio >
/// Jogos) -> componente. Pra adicionar um jogo novo no futuro: criar o
/// componente (recebe onFinished) e registrar a chave aqui.
final Map<String, Widget Function(ValueChanged<ChallengeResult> onFinished)> challengeGames = {
  "tic_tac_toe": (onFinished) => TicTacToeGame(onFinished: onFinished),
};

/// Abre o jogo sobre a propria Home (fundo escurecido e desfocado). No fim
/// da partida mostra a Dica do Max. Nao aparece nenhum nome do recurso.
Future<void> showChallengeOverlay(BuildContext context, String gameKey) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Fechar",
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => _ChallengeOverlay(gameKey: gameKey),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * animation.value, sigmaY: 6 * animation.value),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

class _ChallengeOverlay extends StatefulWidget {
  final String gameKey;
  const _ChallengeOverlay({required this.gameKey});

  @override
  State<_ChallengeOverlay> createState() => _ChallengeOverlayState();
}

enum _Phase { playing, loadingTip, tip }

class _ChallengeOverlayState extends State<_ChallengeOverlay> {
  final _repository = ChallengeRepository();
  _Phase _phase = _Phase.playing;
  ChallengeResult? _result;
  ChallengeTip? _tip;
  int _round = 0; // muda a key do jogo pra "Jogar de novo" comecar do zero

  Future<void> _onFinished(ChallengeResult result) async {
    setState(() {
      _result = result;
      _phase = _Phase.loadingTip;
    });
    ChallengeTip? tip;
    try {
      tip = await _repository.finish(widget.gameKey, result);
    } catch (_) {
      // sem conexao/dica: termina normalmente, so sem a dica
    }
    if (!mounted) return;
    setState(() {
      _tip = tip;
      _phase = _Phase.tip;
    });
  }

  void _playAgain() => setState(() {
        _phase = _Phase.playing;
        _result = null;
        _tip = null;
        _round++;
      });

  String get _resultText => switch (_result) {
        ChallengeResult.win => "Você venceu! 🎉",
        ChallengeResult.loss => "O Max levou essa! 🦆",
        _ => "Deu velha!",
      };

  @override
  Widget build(BuildContext context) {
    final game = challengeGames[widget.gameKey];
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A0D4A), Color(0xFF14062A)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.4),
                  boxShadow: [BoxShadow(color: const Color(0xFFB026FF).withValues(alpha: 0.35), blurRadius: 30)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const DiceIcon(size: 28),
                      const Spacer(),
                      IconButton(
                        tooltip: "Fechar",
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ]),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _phase == _Phase.playing
                          ? (game == null
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text("Volte mais tarde 🎲", style: TextStyle(color: Colors.white70)),
                                )
                              : KeyedSubtree(key: ValueKey(_round), child: game(_onFinished)))
                          : _tipView(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tipView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_resultText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        if (_phase == _Phase.loadingTip)
          const Padding(
            padding: EdgeInsets.all(18),
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
          )
        else if (_tip != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withValues(alpha: 0.5)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("💡 Dica do Max", style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 8),
                Text(_tip!.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
              ]),
            ),
          ),
        if (_phase == _Phase.tip) ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _playAgain,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text("Jogar de novo"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A0BD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text("Fechar"),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
