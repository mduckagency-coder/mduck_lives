import "dart:math";
import "package:supabase_flutter/supabase_flutter.dart";
import "../domain/max_state.dart";

/// Fonte das frases do Max para cada estado/momento do mes. Hoje so existe
/// uma implementacao local (`LocalMaxMessageProvider`), mas o app depende
/// dessa interface - nao da lista em si - para que trocar por uma fonte
/// vinda do Supabase (cadastrada pelo painel) seja so uma troca de
/// implementacao, sem mexer em quem consome.
abstract class MaxMessageProvider {
  /// Escolhe uma frase para `state`, evitando repetir `lastMessage` (a frase
  /// mostrada no dia anterior). `isReturning` sinaliza que o streamer estava
  /// INATIVO/CAVEIRA e voltou a ficar ativo hoje - nesse caso a fala usa o
  /// tom de "retorno" em vez do tom generico do estado atual. Para
  /// REGULAR/CONSTANTE (sem retorno), ocasionalmente mistura uma frase de
  /// momento do mes.
  String pickMessage({
    required MaxState state,
    required MonthMoment moment,
    String? lastMessage,
    bool isReturning = false,
  });
}

class SupabaseMaxMessageProvider implements MaxMessageProvider {
  final SupabaseClient _client;
  final Random _random;

  SupabaseMaxMessageProvider({SupabaseClient? client, Random? random})
      : _client = client ?? Supabase.instance.client,
        _random = random ?? Random();

  @override
  String pickMessage({
    required MaxState state,
    required MonthMoment moment,
    String? lastMessage,
    bool isReturning = false,
  }) {
    throw UnsupportedError("Use fetchMessage para buscar mensagens do Supabase.");
  }

  Future<String?> fetchMessage({
    required MaxState state,
    required String? agencyId,
    String? lastMessage,
    required MonthMoment moment,
    bool isReturning = false,
  }) async {
    try {
      final rows = await _client
          .from("max_state_messages")
          .select("message, category, sort_order")
          .eq("agency_id", agencyId!)
          .eq("state_key", state.name)
          .eq("is_active", true)
          .order("sort_order")
          .order("created_at");
      final allMessages = (rows as List)
          .whereType<Map>()
          .map((row) => _messageFrom(row))
          .whereType<String>()
          .where((message) => message.trim().isNotEmpty)
          .toList();

      final maps = (rows as List).whereType<Map>().toList();
      final categories = _categoryPriority(state, moment, isReturning);
      final candidates = <String>[];
      for (final category in categories) {
        candidates
          ..clear()
          ..addAll(maps
              .where((row) => (row["category"] as String? ?? "geral") == category)
              .map((row) => _messageFrom(row))
              .whereType<String>()
              .where((message) => message.trim().isNotEmpty));
        if (candidates.isNotEmpty) break;
      }

      if (candidates.isEmpty && allMessages.isEmpty) return null;
      final selectedMessages = candidates.isEmpty ? allMessages : candidates;
      final distinct = selectedMessages.toSet().toList();
      final alternatives = distinct.length > 1 && lastMessage != null
          ? distinct.where((message) => message != lastMessage).toList()
          : distinct;
      final pool = alternatives.isEmpty ? distinct : alternatives;
      return pool[_random.nextInt(pool.length)];
    } catch (_) {
      return null;
    }
  }

  static List<String> _categoryPriority(MaxState state, MonthMoment moment, bool isReturning) {
    if (isReturning) return const ["retorno", "geral"];
    if (state == MaxState.inativo || state == MaxState.caveira) {
      return const ["inatividade", "geral"];
    }
    final momentCategory = switch (moment) {
      MonthMoment.inicio => "inicio_mes",
      MonthMoment.meio => "meio_mes",
      MonthMoment.fim => "final_mes",
    };
    return [momentCategory, "frequencia", "geral"];
  }

  static String? _messageFrom(Map row) {
    final value = row["message"];
    return value?.toString();
  }
}

class LocalMaxMessageProvider implements MaxMessageProvider {
  final Random _random;

  LocalMaxMessageProvider({Random? random}) : _random = random ?? Random();

  static const Map<MaxState, List<String>> _byState = {
    MaxState.regular: [
      "Fala, Ducker.",
      "Bora ver como voce ta indo?",
      "Mais um dia por aqui, bora focar!",
      "Animado para as lives hoje?",
    ],
    MaxState.constante: [
      "Ta mantendo o ritmo das lives!",
      "Hoje e um dia perfeito para mais uma live.",
      "Que orgulho, voce ta firme nas lives, hein?",
      "Gostei da constancia, isso e muito importante!",
      "Bora fazer acontecer nas lives hoje?",
    ],
    MaxState.inativo: [
      "Voce deu uma sumida, hein.",
      "Poxa, voce nao vai abandonar as lives, ne?",
      "Hey! Tem que abrir sempre, bora animar!",
      "To esperando sua live!",
    ],
    MaxState.caveira: [
      "To aqui esperando voce abrir live!",
      "Ducker... voce nao pode me abandonar assim.",
      "Devo desistir de esperar voce abrir live?",
      "Ate que enfim voce apareceu, bora abrir live!",
    ],
  };

  /// So aparece no primeiro dia em que o streamer volta a ficar ativo depois
  /// de um periodo INATIVO/CAVEIRA - troca a fala generica do estado atual
  /// por esse tom de retorno.
  static const List<String> _retorno = [
    "Que bom que voce voltou!",
    "Olha quem apareceu!",
    "De volta ao ritmo? Bora abrir live?",
    "Nao pode desanimar, abre live!",
  ];

  static const Map<MonthMoment, List<String>> _byMoment = {
    MonthMoment.inicio: [
      "Vamos comecar o mes focados!",
      "Esse mes quero te ver no topo!",
      "To animado para esse mes.",
    ],
    MonthMoment.meio: [
      "Precisamos nos manter firmes esse mes!",
      "Precisamos focar em dias e horas!",
      "Bora que esse mes e incrivel!",
    ],
    MonthMoment.fim: [
      "Reta final, Ducker. Nao podemos desistir!",
      "Ultimos dias do mes. Bora focar nas metas.",
      "O mes ta acabando, vamos nos manter firmes.",
      "Poucos dias para fechar o mes, bora abrir live!",
    ],
  };

  /// So REGULAR/CONSTANTE recebem mensagens de momento do mes, e mesmo
  /// assim nao em todo dia - a inatividade (e o retorno dela) tem
  /// prioridade sobre qualquer mensagem generica de calendario.
  static const _monthMomentChance = 0.35;

  @override
  String pickMessage({
    required MaxState state,
    required MonthMoment moment,
    String? lastMessage,
    bool isReturning = false,
  }) {
    final allowsMonthMoment = state == MaxState.regular || state == MaxState.constante;

    final pool = <String>[
      if (isReturning && allowsMonthMoment) ..._retorno else ..._byState[state]!,
    ];
    if (!isReturning && allowsMonthMoment && _random.nextDouble() < _monthMomentChance) {
      pool.addAll(_byMoment[moment]!);
    }

    final withoutRepeat = pool.where((m) => m != lastMessage).toList();
    final finalPool = withoutRepeat.isEmpty ? pool : withoutRepeat;
    return finalPool[_random.nextInt(finalPool.length)];
  }
}
