import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "../data/challenge_repository.dart";

const _purple = Color(0xFFB026FF);
const _gold = Color(0xFFFFC94D);

/// Jogo da Velha contra o sistema. O streamer e o X e comeca; o sistema e o O.
/// O sistema ganha quando pode, bloqueia quando precisa e as vezes "se
/// distrai" (jogada aleatoria) pra dar pra ganhar dele.
class TicTacToeGame extends StatefulWidget {
  final ValueChanged<ChallengeResult> onFinished;
  const TicTacToeGame({super.key, required this.onFinished});

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // linhas
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // colunas
    [0, 4, 8], [2, 4, 6], // diagonais
  ];

  final _random = Random();
  final List<String?> _board = List.filled(9, null);
  bool _systemThinking = false;
  bool _finished = false;
  List<int>? _winningLine;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<int>? _lineOf(String mark) {
    for (final l in _lines) {
      if (l.every((i) => _board[i] == mark)) return l;
    }
    return null;
  }

  int? _completing(String mark) {
    for (final l in _lines) {
      final marks = l.where((i) => _board[i] == mark).length;
      final empty = l.where((i) => _board[i] == null).toList();
      if (marks == 2 && empty.length == 1) return empty.first;
    }
    return null;
  }

  int _systemMove() {
    final free = [for (var i = 0; i < 9; i++) if (_board[i] == null) i];
    final win = _completing("O");
    if (win != null) return win;
    // ~25% das vezes "se distrai" e nao bloqueia: da pra ganhar
    if (_random.nextDouble() < 0.25) return free[_random.nextInt(free.length)];
    final block = _completing("X");
    if (block != null) return block;
    if (_board[4] == null) return 4;
    final corners = [0, 2, 6, 8].where((i) => _board[i] == null).toList();
    if (corners.isNotEmpty) return corners[_random.nextInt(corners.length)];
    return free[_random.nextInt(free.length)];
  }

  bool _checkEnd() {
    final x = _lineOf("X");
    final o = _lineOf("O");
    ChallengeResult? result;
    if (x != null) {
      _winningLine = x;
      result = ChallengeResult.win;
    } else if (o != null) {
      _winningLine = o;
      result = ChallengeResult.loss;
    } else if (_board.every((c) => c != null)) {
      result = ChallengeResult.draw;
    }
    if (result == null) return false;
    _finished = true;
    final r = result;
    // deixa a jogada final aparecer antes de seguir pra dica
    _timer = Timer(const Duration(milliseconds: 650), () => widget.onFinished(r));
    return true;
  }

  void _play(int i) {
    if (_finished || _systemThinking || _board[i] != null) return;
    setState(() => _board[i] = "X");
    if (_checkEnd()) {
      setState(() {});
      return;
    }
    setState(() => _systemThinking = true);
    _timer = Timer(Duration(milliseconds: 420 + _random.nextInt(320)), () {
      if (!mounted) return;
      setState(() {
        _board[_systemMove()] = "O";
        _systemThinking = false;
        _checkEnd();
      });
    });
  }

  String get _status {
    if (_finished) {
      if (_winningLine == null) return "Deu velha!";
      return _board[_winningLine!.first] == "X" ? "Você venceu! 🎉" : "O Max levou essa! 🦆";
    }
    return _systemThinking ? "Max está pensando..." : "Sua vez";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _status,
            key: ValueKey(_status),
            style: TextStyle(
              color: _systemThinking ? Colors.white60 : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (var i = 0; i < 9; i++) _cell(i)],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Você ", style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text("✕", style: TextStyle(color: _purple, fontSize: 14, fontWeight: FontWeight.w900)),
            Text("   ·   Max ", style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text("◯", style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _cell(int i) {
    final mark = _board[i];
    final highlighted = _winningLine?.contains(i) ?? false;
    final color = mark == "X" ? _purple : _gold;
    return GestureDetector(
      onTap: () => _play(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlighted ? color : Colors.white.withValues(alpha: 0.12), width: highlighted ? 2 : 1),
        ),
        child: Center(
          child: AnimatedScale(
            scale: mark == null ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Text(
              mark == "X" ? "✕" : (mark == "O" ? "◯" : ""),
              style: TextStyle(
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
