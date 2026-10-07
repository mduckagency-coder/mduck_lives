import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Resultado de uma partida, do ponto de vista do streamer.
enum ChallengeResult { win, loss, draw }

/// Dica do Max sorteada no fim da partida (painel web > Desafio > Dicas).
class ChallengeTip {
  final String id;
  final String text;
  const ChallengeTip(this.id, this.text);
}

/// Dado da Home: jogos ativos (challenge_games) e fim de partida
/// (app_challenge_finish registra a partida e sorteia a dica) -- migration
/// 0088 do painel.
class ChallengeRepository {
  final _client = Supabase.instance.client;

  static const _lastTipKey = "challenge_last_tip_id";

  /// game_keys ativos da agencia do streamer (RLS ja filtra agencia/ativo).
  Future<List<String>> fetchActiveGameKeys() async {
    final rows = await _client.from("challenge_games").select("game_key").eq("is_active", true).order("sort_order");
    return [for (final r in (rows as List)) r["game_key"] as String];
  }

  /// Registra a partida e devolve uma dica ativa (diferente da ultima que o
  /// streamer recebeu, quando houver outra). null se nao houver dica ativa.
  Future<ChallengeTip?> finish(String gameKey, ChallengeResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTip = prefs.getString(_lastTipKey);
    final rows = await _client.rpc("app_challenge_finish", params: {
      "p_game_key": gameKey,
      "p_result": result.name,
      "p_last_tip_id": lastTip,
    });
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    final tip = ChallengeTip(row["tip_id"] as String, row["tip_text"] as String);
    await prefs.setString(_lastTipKey, tip.id);
    return tip;
  }
}
