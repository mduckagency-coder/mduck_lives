import "max_state.dart";

/// Retrato da atividade do streamer no mes atual, montado a partir do que
/// existe hoje no Supabase (`streamer_stats`). `lastLiveAt` e
/// `currentStreakDays` podem nao existir ainda para todos os streamers -
/// nesse caso o calculo cai para o caminho "sem dado de ultima live"
/// (nunca INATIVO/CAVEIRA por invencao, so REGULAR/CONSTANTE).
class MaxActivitySnapshot {
  final int daysLiveThisMonth;
  final DateTime? lastLiveAt;
  final int? currentStreakDays;

  const MaxActivitySnapshot({
    required this.daysLiveThisMonth,
    this.lastLiveAt,
    this.currentStreakDays,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dias corridos desde a ultima live (por data, nao por horas), ou null se
/// nao houver esse dado ainda.
int? daysSinceLastLive(MaxActivitySnapshot snapshot, DateTime now) {
  final lastLive = snapshot.lastLiveAt;
  if (lastLive == null) return null;
  return _dateOnly(now).difference(_dateOnly(lastLive)).inDays;
}

/// Prioridade (conforme especificacao): inatividade sempre vence frequencia
/// boa; frequencia boa so conta quando nao ha inatividade relevante.
MaxState calculateMaxState(
  MaxActivitySnapshot snapshot,
  MaxThresholds thresholds,
  DateTime now,
) {
  final daysSince = daysSinceLastLive(snapshot, now);

  if (daysSince != null) {
    if (daysSince >= thresholds.caveiraMinDaysSinceLastLive) {
      return MaxState.caveira;
    }
    if (daysSince >= thresholds.inativoMinDaysSinceLastLive) {
      return MaxState.inativo;
    }
  }

  // Constante: sequencia de dias seguidos (quando esse dado existir) ou,
  // sem ele, a melhor aproximacao possivel com o que a importacao traz: fez
  // live ontem ou hoje E tem o minimo de dias com live no mes.
  final streak = snapshot.currentStreakDays;
  final liveRecently = daysSince != null && daysSince <= 1;
  final isConstante = (streak != null && streak >= thresholds.constanteMinStreakDays) ||
      (liveRecently && snapshot.daysLiveThisMonth >= thresholds.constanteMinDaysLive);
  if (isConstante) return MaxState.constante;

  return MaxState.regular;
}

MonthMoment calculateMonthMoment(DateTime now) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final third = daysInMonth / 3;
  if (now.day <= third) return MonthMoment.inicio;
  if (now.day <= third * 2) return MonthMoment.meio;
  return MonthMoment.fim;
}
