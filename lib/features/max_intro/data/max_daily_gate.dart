import "package:shared_preferences/shared_preferences.dart";
import "../domain/max_state.dart";

/// Guarda localmente (por aparelho) a data em que a tela do Max foi exibida
/// pela ultima vez, qual foi a mensagem (pra nao repetir em seguida) e qual
/// era o estado do Max (pra detectar quando o streamer volta de um periodo
/// INATIVO/CAVEIRA). `wasShownToday` fica disponivel caso a regra de "uma vez
/// por dia" volte a ser usada.
class MaxDailyGate {
  String _dateKey(String streamerId) => "max_intro_last_shown_date_$streamerId";
  String _messageKey(String streamerId) => "max_intro_last_message_$streamerId";
  String _stateKey(String streamerId) => "max_intro_last_state_$streamerId";

  String _today() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<bool> wasShownToday(String streamerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dateKey(streamerId)) == _today();
  }

  Future<String?> lastMessage(String streamerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_messageKey(streamerId));
  }

  Future<MaxState?> lastState(String streamerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(streamerId));
    if (raw == null) return null;
    for (final s in MaxState.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  Future<void> markShownToday(
    String streamerId, {
    required String message,
    required MaxState state,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey(streamerId), _today());
    await prefs.setString(_messageKey(streamerId), message);
    await prefs.setString(_stateKey(streamerId), state.name);
  }
}
