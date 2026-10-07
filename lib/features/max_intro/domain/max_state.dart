/// Os quatro estados visuais/comportamentais do Max, definidos pela
/// atividade real do streamer. Futuramente cada um tera sua propria
/// midia cadastrada pelo painel administrativo (ver MaxStateContentRepository).
enum MaxState { regular, constante, inativo, caveira }

/// Momento dentro do mes atual, usado apenas para variar mensagens de
/// REGULAR/CONSTANTE (a inatividade sempre tem prioridade sobre isso).
enum MonthMoment { inicio, meio, fim }

/// Limites que definem quando o Max muda de estado. Ficam agrupados aqui
/// para que, no futuro, o painel administrativo possa sobrescrever esses
/// valores (hoje eles vem de `app_settings`, com esses defaults).
class MaxThresholds {
  final int constanteMinDaysLive;
  final int constanteMinStreakDays;
  final int inativoMinDaysSinceLastLive;
  final int caveiraMinDaysSinceLastLive;

  const MaxThresholds({
    this.constanteMinDaysLive = 3,
    this.constanteMinStreakDays = 3,
    this.inativoMinDaysSinceLastLive = 3,
    this.caveiraMinDaysSinceLastLive = 10,
  });
}
