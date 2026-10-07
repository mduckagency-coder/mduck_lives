/// Niveis de evolucao do mes pelos diamantes (nao sao condicao pra ser
/// "profissional": sao degraus de progresso).
///   ate 79K  Ducker
///   80K+     Top Ducker
///   250K+    Ducker Elite
///   500K+    Ducker Lendario (ultimo nivel por enquanto)
library;

/// Marcos de diamantes do mes, em ordem.
const duckerMarcos = <double>[10000, 20000, 40000, 80000, 150000, 250000, 350000, 500000, 800000, 1000000, 1200000, 1600000];

enum DuckerLevel { ducker, topDucker, elite, lendario }

/// Marco que abre cada nivel (Ducker nao tem).
const _levelEntry = {
  DuckerLevel.topDucker: 80000.0,
  DuckerLevel.elite: 250000.0,
  DuckerLevel.lendario: 500000.0,
};

DuckerLevel duckerLevelFor(double diamonds) {
  if (diamonds >= 500000) return DuckerLevel.lendario;
  if (diamonds >= 250000) return DuckerLevel.elite;
  if (diamonds >= 80000) return DuckerLevel.topDucker;
  return DuckerLevel.ducker;
}

String duckerLevelName(DuckerLevel l) => switch (l) {
      DuckerLevel.ducker => "Ducker",
      DuckerLevel.topDucker => "Top Ducker",
      DuckerLevel.elite => "Ducker Elite",
      DuckerLevel.lendario => "Ducker Lendário",
    };

/// Maior marco ja alcancado (null antes dos 10K).
double? highestMarco(double diamonds) {
  double? best;
  for (final m in duckerMarcos) {
    if (diamonds >= m) best = m;
  }
  return best;
}

/// Proximo marco (null depois de 1,6M).
double? nextMarco(double diamonds) {
  for (final m in duckerMarcos) {
    if (diamonds < m) return m;
  }
  return null;
}

/// O marco alcancado e o que abre um nivel novo (80K, 250K, 500K)?
bool isLevelEntry(double marco) => _levelEntry.values.contains(marco);

/// Marco que abre o nivel (pra celebracao: "Voce alcancou 250K diamantes").
double? levelEntryValue(DuckerLevel l) => _levelEntry[l];

/// 10K, 150K, 1M.
String marcoLabel(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return "${m == m.roundToDouble() ? m.toInt() : m.toStringAsFixed(1).replaceAll(".", ",")}M";
  }
  return "${(v / 1000).round()}K";
}

/// Titulo e frase do cartao do mes (Jornada > Marcos do Mes).
({String title, String message}) duckerCardTexts(double diamonds) {
  final top = highestMarco(diamonds);
  final next = nextMarco(diamonds);
  final level = duckerLevelFor(diamonds);

  if (level == DuckerLevel.ducker) {
    // antes dos 80K: as metricas do Top Ducker como guia, sem cobranca
    return (
      title: "Referência Top Ducker",
      message: "Estas são as métricas de um Top Ducker profissional. Use como guia e evolua no seu ritmo.",
    );
  }
  final reached = top!;
  // 1M: marco extraordinario de 1 milhao
  if (reached == 1000000) {
    return (
      title: "DUCKER LENDÁRIO",
      message: "1.000.000 💎\n1 MILHÃO DE DIAMANTES ALCANÇADOS${next != null ? "\nSeu próximo marco: ${marcoLabel(next)} 💎" : ""}",
    );
  }
  final name = duckerLevelName(level);
  if (next == null) {
    return (title: name, message: "${marcoLabel(reached)} diamantes alcançados.\nVocê alcançou o maior marco do mês 💎");
  }
  final title = isLevelEntry(reached) ? "Você é um $name!" : name;
  return (
    title: title,
    message: "${marcoLabel(reached)} diamantes alcançados.\nSeu próximo marco: ${marcoLabel(next)} 💎",
  );
}
