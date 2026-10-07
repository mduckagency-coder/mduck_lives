import "dart:async";
import "dart:math";
import "package:flutter/material.dart";
import "avatar_picker_sheet.dart";
import "data/island_repository.dart";
import "widgets/cropped_media.dart";
import "../../core/media/media_cache.dart";

const _milestones = [80000, 150000, 250000, 350000, 500000, 800000, 1000000];

int _tierFor(int diamonds) => _milestones.where((m) => diamonds >= m).length;

// Fundo escuro (no tom do app) enquanto o fundo real da ilha carrega.
const _fallbackGradient = DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A0B2E), Color(0xFF0A0114)],
    ),
  ),
);

class _IslandPageData {
  final IslandBackground? background;
  final List<IslandSlot> slots;
  final List<IslandResident> residents;
  final IslandLastMonthChampion? lastMonthChampion;
  final bool testMode;
  final IslandAvatarOption? defaultAvatar;
  final String defaultAvatarDebug;

  const _IslandPageData({
    required this.background,
    required this.slots,
    required this.residents,
    required this.lastMonthChampion,
    required this.testMode,
    required this.defaultAvatar,
    required this.defaultAvatarDebug,
  });
}

const _monthNames = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

/// "2026-09" -> "Setembro/2026"
String _periodLabel(String period) {
  final parts = period.split("-");
  final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (month == null || month < 1 || month > 12) return period;
  return "${_monthNames[month - 1]}/${parts[0]}";
}

/// Busca tudo da ilha. Sem [period] e a ilha ao vivo do mes atual: ao
/// terminar, guarda o resultado em [_lastData] e ja comeca a baixar fundo e
/// avatares, pra quando a aba abrir estar tudo pronto. Com [period]
/// ("AAAA-MM"), e a ilha como ficou no fechamento daquele mes.
Future<_IslandPageData> _loadIslandData(BuildContext? context, {String? period}) async {
  final repository = IslandRepository();
  final results = await Future.wait([
    repository.fetchBackground(),
    repository.fetchSlots(),
    repository.fetchResidents(periodKey: period),
    repository.fetchTopOfLastMonth(beforePeriod: period),
    repository.fetchTestMode(),
    repository.fetchDefaultAvatar(),
    repository.debugDefaultAvatarStatus(),
  ]);
  final data = _IslandPageData(
    background: results[0] as IslandBackground?,
    slots: results[1] as List<IslandSlot>,
    residents: results[2] as List<IslandResident>,
    lastMonthChampion: results[3] as IslandLastMonthChampion?,
    testMode: results[4] as bool,
    defaultAvatar: results[5] as IslandAvatarOption?,
    defaultAvatarDebug: results[6] as String,
  );
  if (period == null) _lastData = data;
  if (context != null && context.mounted) _warmMedia(context, data);
  return data;
}

_IslandPageData? _lastData;
Future<_IslandPageData>? _prefetch;

void _warmMedia(BuildContext context, _IslandPageData data) {
  final urls = <String?>[
    data.background?.mediaUrl,
    data.defaultAvatar?.mediaUrl,
    data.lastMonthChampion?.avatarMediaUrl,
    data.lastMonthChampion?.avatarUrl,
    for (final r in data.residents) ...[r.avatarMediaUrl, r.profileAvatarUrl],
  ];
  for (final url in urls.whereType<String>().where((u) => u.isNotEmpty).toSet()) {
    if (isVideoUrl(url)) {
      MediaCache.download(url);
    } else {
      precacheImage(MediaCacheImage(url), context, onError: (_, _) {});
    }
  }
}

class IlhaTopDuckersContent extends StatefulWidget {
  const IlhaTopDuckersContent({super.key});

  /// Chamado pelo AppShell ao abrir o app: carrega a ilha em segundo plano
  /// enquanto o streamer esta na Home.
  static void prefetch(BuildContext context) {
    _prefetch ??= _loadIslandData(context).catchError((Object error) {
      _prefetch = null;
      throw error;
    });
  }

  @override
  State<IlhaTopDuckersContent> createState() => _IlhaTopDuckersContentState();
}

class _IlhaTopDuckersContentState extends State<IlhaTopDuckersContent> {
  late Future<_IslandPageData> _future;

  // A ilha so aparece quando o fundo ja esta na tela, pra nao piscar uma cor
  // solida antes. Se o fundo demorar demais, mostra assim mesmo.
  bool _backgroundReady = false;
  Timer? _backgroundTimeout;

  void _markBackgroundReady() {
    _backgroundTimeout?.cancel();
    if (mounted && !_backgroundReady) setState(() => _backgroundReady = true);
  }

  @override
  void dispose() {
    _backgroundTimeout?.cancel();
    super.dispose();
  }

  /// null = ilha ao vivo do mes atual; "AAAA-MM" = como ficou aquele mes.
  String? _period;
  List<String> _closedPeriods = const [];

  @override
  void initState() {
    super.initState();
    _backgroundTimeout = Timer(const Duration(seconds: 6), _markBackgroundReady);
    // Usa o que ja foi carregado em segundo plano; nas proximas visitas mostra
    // na hora o ultimo resultado e atualiza por baixo.
    _future = _prefetch ?? _loadIslandData(context);
    _prefetch = null;
    _loadClosedPeriods();
  }

  Future<void> _loadClosedPeriods() async {
    try {
      final periods = await IslandRepository().fetchClosedPeriods();
      if (mounted) setState(() => _closedPeriods = periods);
    } catch (_) {
      // sem historico: o seletor de mes simplesmente nao aparece
    }
  }

  Future<void> _refresh() async {
    final future = _loadIslandData(context, period: _period);
    setState(() => _future = future);
    await future;
  }

  void _selectPeriod(String? period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _future = _loadIslandData(context, period: period);
    });
  }

  void _openPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        Widget option(String? period, String title, String subtitle) => ListTile(
              onTap: () {
                Navigator.of(sheetContext).pop();
                _selectPeriod(period);
              },
              leading: Text(period == null ? "🔴" : "📅", style: const TextStyle(fontSize: 20)),
              title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              trailing: Icon(
                period == _period ? Icons.radio_button_checked : Icons.radio_button_off,
                color: const Color(0xFFB026FF),
              ),
            );

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.6),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              children: [
                const Center(
                  child: Text(
                    "Ver a ilha de qual mês?",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                option(null, "Este mês (ao vivo)", "Posições atualizando durante o mês"),
                for (final p in _closedPeriods) option(p, _periodLabel(p), "Resultado final do mês"),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAvatarPicker() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AvatarPickerSheet(),
    );
    if (changed == true && mounted) _refresh();
  }

  void _showResidentDetails(BuildContext context, IslandResident resident, IslandAvatarOption? defaultAvatar) {
    const fallbackDuck = Center(child: Text("🦆", style: TextStyle(fontSize: 34)));
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvatarFrame(
                  size: 96,
                  mediaUrl: resident.avatarMediaUrl,
                  displayShape: resident.displayShape,
                  borderColor: Colors.white,
                  muted: resident.muted,
                  volume: resident.volume,
                  loopVideo: resident.loopVideo,
                  cropScale: resident.cropScale,
                  cropOffsetX: resident.cropOffsetX,
                  cropOffsetY: resident.cropOffsetY,
                  defaultAvatar: defaultAvatar,
                  fallback: fallbackDuck,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text("#${resident.rank}", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(resident.displayName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    Text("${resident.diamonds} 💎", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_IslandPageData>(
      future: _future,
      initialData: _lastData,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Nao foi possivel carregar a ilha.\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        // O banner do campeao do mes passado e desenhado primeiro (fica atras
        // de todo mundo), mesmo que o admin tenha dado um z_index alto pra ele.
        int layer(IslandSlot s) => s.isLastMonth ? -1 << 20 : s.zIndex;
        final sortedSlots = [...data.slots]..sort((a, b) => layer(a).compareTo(layer(b)));
        final singleBySlot = <String, IslandResident>{
          for (final r in data.residents.where((r) => r.rank <= 10)) r.slotKey: r,
        };
        final areaResidents = data.residents.where((r) => r.rank > 10).toList();
        final isEmpty = data.residents.isEmpty && data.lastMonthChampion == null;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text("🏝️ Ilha Top", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  // Seletor de mes na mesma linha do titulo, pra nao roubar
                  // altura da ilha (os slots sao posicionados em % da altura).
                  if (_closedPeriods.isNotEmpty)
                    _PeriodChip(
                      period: _period,
                      loading: snapshot.connectionState == ConnectionState.waiting,
                      onTap: _openPeriodPicker,
                    )
                  else
                    Text("${data.residents.length} nessa ilha", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  if (data.testMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.6)),
                      ),
                      child: const Text("🧪 MODO TESTE", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  _AvatarPickerButton(onTap: _openAvatarPicker),
                ],
              ),
            ),
            if (data.defaultAvatar == null)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Text(
                  "🔧 avatar padrão: ${data.defaultAvatarDebug}",
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const Positioned.fill(child: _fallbackGradient),
                        if (data.background != null)
                          Positioned.fill(
                            child: CroppedMedia(
                              mediaUrl: data.background!.mediaUrl,
                              muted: data.background!.muted,
                              volume: data.background!.volume,
                              loopVideo: data.background!.loopVideo,
                              cropScale: data.background!.cropScale,
                              cropOffsetX: data.background!.cropOffsetX,
                              cropOffsetY: data.background!.cropOffsetY,
                              fit: BoxFit.fitWidth,
                              fallback: _fallbackGradient,
                              onReady: _markBackgroundReady,
                            ),
                          ),
                        if (isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                "Ainda ninguem chegou aqui este mes.\nBata 80 mil diamantes pra aparecer na ilha!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        else
                          for (final slot in sortedSlots)
                            if (slot.isLastMonth)
                              if (data.lastMonthChampion != null)
                                _LastMonthSlot(
                                  slot: slot,
                                  champion: data.lastMonthChampion!,
                                  areaWidth: w,
                                  areaHeight: h,
                                  defaultAvatar: data.defaultAvatar,
                                )
                              else
                                const SizedBox.shrink()
                            else if (slot.isArea)
                              _AreaSlot(
                                slot: slot,
                                residents: areaResidents,
                                totalWidth: w,
                                totalHeight: h,
                                defaultAvatar: data.defaultAvatar,
                                onTapResident: (r) => _showResidentDetails(context, r, data.defaultAvatar),
                              )
                            else if (singleBySlot[slot.slotKey] != null)
                              _FixedSlotAvatar(
                                slot: slot,
                                resident: singleBySlot[slot.slotKey]!,
                                areaWidth: w,
                                areaHeight: h,
                                defaultAvatar: data.defaultAvatar,
                                onTap: () => _showResidentDetails(context, singleBySlot[slot.slotKey]!, data.defaultAvatar),
                              ),
                        // Vendo um mes passado: deixa claro na propria ilha e
                        // oferece voltar pro mes atual.
                        if (_period != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.75),
                                shape: const StadiumBorder(side: BorderSide(color: Color(0xFFFFD700))),
                                child: InkWell(
                                  customBorder: const StadiumBorder(),
                                  onTap: () => _selectPeriod(null),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "📅 Resultado final de ${_periodLabel(_period!)}\n",
                                            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                                          ),
                                          const TextSpan(
                                            text: "Toque para voltar ao mês atual",
                                            style: TextStyle(color: Colors.white70, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!_backgroundReady && data.background != null)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Botao compacto ao lado do titulo: mostra qual mes esta na tela ("Ao vivo"
/// ou "Set/2026") e abre o seletor. Fica dourado vendo um mes passado.
class _PeriodChip extends StatelessWidget {
  final String? period;
  final bool loading;
  final VoidCallback onTap;

  const _PeriodChip({required this.period, required this.loading, required this.onTap});

  static const _short = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];

  String _shortLabel(String p) {
    final parts = p.split("-");
    final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (m == null || m < 1 || m > 12) return p;
    return "${_short[m - 1]}/${parts[0]}";
  }

  @override
  Widget build(BuildContext context) {
    final isPast = period != null;
    final color = isPast ? const Color(0xFFFFD700) : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
        decoration: BoxDecoration(
          color: isPast ? const Color(0xFFFFD700).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5))
            else
              Text(isPast ? "📅" : "🔴", style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Text(
              isPast ? _shortLabel(period!) : "Ao vivo",
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.arrow_drop_down, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Botao que abre o seletor de avatar.
class _AvatarPickerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AvatarPickerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF7A0BD4).withOpacity(0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB026FF).withOpacity(0.6)),
        ),
        child: const Text("Escolher Avatar", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Moldura do avatar respeitando o display_shape configurado no admin:
/// circulo (padrao/compatibilidade com avatares antigos), quadrado (cantos
/// levemente arredondados) ou nenhum (sem moldura, sem clip, sem fundo —
/// so a midia com a propria transparencia). Sem `color` na decoration de
/// proposito: um fundo solido atras da midia esconderia a transparencia
/// real de PNGs/GIFs/WebPs configurados no admin.
class _AvatarFrame extends StatelessWidget {
  final double size;
  final String? mediaUrl;
  final String? displayShape;
  final Color borderColor;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final Widget fallback;
  final IslandAvatarOption? defaultAvatar;

  const _AvatarFrame({
    required this.size,
    required this.mediaUrl,
    required this.displayShape,
    required this.borderColor,
    this.muted = true,
    this.volume = 0,
    this.loopVideo = true,
    this.cropScale = 1,
    this.cropOffsetX = 0,
    this.cropOffsetY = 0,
    required this.fallback,
    this.defaultAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // ninguem escolheu avatar ainda: cai no avatar marcado como padrao no
    // admin (se existir) antes de recorrer ao emoji de pato.
    final useDefault = (mediaUrl == null || mediaUrl!.isEmpty) && defaultAvatar != null;
    final effectiveUrl = useDefault ? defaultAvatar!.mediaUrl : mediaUrl;
    final effectiveShape = useDefault ? defaultAvatar!.displayShape : displayShape;
    final effectiveMuted = useDefault ? defaultAvatar!.muted : muted;
    final effectiveVolume = useDefault ? defaultAvatar!.volume : volume;
    final effectiveLoop = useDefault ? defaultAvatar!.loopVideo : loopVideo;
    final effectiveCropScale = useDefault ? defaultAvatar!.cropScale : cropScale;
    final effectiveCropOffsetX = useDefault ? defaultAvatar!.cropOffsetX : cropOffsetX;
    final effectiveCropOffsetY = useDefault ? defaultAvatar!.cropOffsetY : cropOffsetY;

    // "sem nada": mostra a midia inteira, sem o zoom/recorte configurado no
    // admin (esse crop foi pensado pra preencher um circulo/quadrado sem
    // sobra, aqui e o oposto — a ideia e nao cortar nada) e sem forcar
    // preenchimento do quadrado do slot (contain em vez de cover).
    if (effectiveShape == "none") {
      final media = effectiveUrl == null || effectiveUrl.isEmpty
          ? fallback
          : CroppedMedia(
              mediaUrl: effectiveUrl,
              muted: effectiveMuted,
              volume: effectiveVolume,
              loopVideo: effectiveLoop,
              fit: BoxFit.contain,
              fallback: fallback,
            );
      return SizedBox(width: size, height: size, child: media);
    }

    final media = effectiveUrl == null || effectiveUrl.isEmpty
        ? fallback
        : CroppedMedia(
            mediaUrl: effectiveUrl,
            muted: effectiveMuted,
            volume: effectiveVolume,
            loopVideo: effectiveLoop,
            cropScale: effectiveCropScale,
            cropOffsetX: effectiveCropOffsetX,
            cropOffsetY: effectiveCropOffsetY,
            fallback: fallback,
          );

    final isSquare = effectiveShape == "square";
    final radius = isSquare ? size * 0.18 : size / 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: borderColor.withOpacity(0.45), blurRadius: 6)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 2).clamp(0, radius)),
        child: media,
      ),
    );
  }
}

class _FixedSlotAvatar extends StatelessWidget {
  final IslandSlot slot;
  final IslandResident resident;
  final double areaWidth;
  final double areaHeight;
  final VoidCallback onTap;
  final IslandAvatarOption? defaultAvatar;

  const _FixedSlotAvatar({
    required this.slot,
    required this.resident,
    required this.areaWidth,
    required this.areaHeight,
    required this.onTap,
    this.defaultAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (slot.posX / 100) * areaWidth,
      top: (slot.posY / 100) * areaHeight,
      child: GestureDetector(
        onTap: onTap,
        child: _ResidentBubble(resident: resident, size: 64 * slot.scale, defaultAvatar: defaultAvatar),
      ),
    );
  }
}

/// top_11_plus e uma AREA (nao um ponto fixo): distribui todo mundo em wrap
/// dentro do retangulo configurado, encolhendo de scale ate min_scale
/// conforme a quantidade de streamers aumenta.
class _AreaSlot extends StatelessWidget {
  final IslandSlot slot;
  final List<IslandResident> residents;
  final double totalWidth;
  final double totalHeight;
  final void Function(IslandResident) onTapResident;
  final IslandAvatarOption? defaultAvatar;

  const _AreaSlot({
    required this.slot,
    required this.residents,
    required this.totalWidth,
    required this.totalHeight,
    required this.onTapResident,
    this.defaultAvatar,
  });

  @override
  Widget build(BuildContext context) {
    if (residents.isEmpty) return const SizedBox.shrink();

    final areaW = (slot.areaWidth / 100) * totalWidth;
    final areaH = (slot.areaHeight / 100) * totalHeight;
    final baseMax = 64 * slot.scale;
    final baseMin = 64 * slot.minScale;

    double avatarSize = baseMax;
    if (areaW > 0 && areaH > 0) {
      final estimated = sqrt((areaW * areaH) / max(residents.length, 1));
      avatarSize = estimated.clamp(baseMin, baseMax);
    }

    return Positioned(
      left: (slot.posX / 100) * totalWidth,
      top: (slot.posY / 100) * totalHeight,
      width: areaW > 0 ? areaW : null,
      height: areaH > 0 ? areaH : null,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in residents)
              GestureDetector(
                onTap: () => onTapResident(r),
                child: _ResidentBubble(resident: r, size: avatarSize, defaultAvatar: defaultAvatar),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slot especial e incondicional: so mostra foto + nome + diamantes do
/// campeao do mes fechado anterior, sem rotulo nenhum (isso e so pro admin).
class _LastMonthSlot extends StatelessWidget {
  final IslandSlot slot;
  final IslandLastMonthChampion champion;
  final double areaWidth;
  final double areaHeight;
  final IslandAvatarOption? defaultAvatar;

  const _LastMonthSlot({
    required this.slot,
    required this.champion,
    required this.areaWidth,
    required this.areaHeight,
    this.defaultAvatar,
  });

  /// 34414 -> "34.414"
  static String _formatDiamonds(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(".");
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  // Tamanho do quadro interno do banner "TOP 1 DO MES PASSADO" no fundo atual,
  // em % da ilha, contando a partir da posicao do slot configurada no admin.
  // Se o admin preencher largura/altura de area pro slot, vale o do admin.
  static const _defaultBoxWidthPct = 14.0;
  static const _defaultBoxHeightPct = 11.2;

  @override
  Widget build(BuildContext context) {
    final boxW = (slot.areaWidth > 0 ? slot.areaWidth : _defaultBoxWidthPct) / 100 * areaWidth;
    final boxH = (slot.areaHeight > 0 ? slot.areaHeight : _defaultBoxHeightPct) / 100 * areaHeight;
    final hasPhoto = champion.avatarUrl != null && champion.avatarUrl!.isNotEmpty;
    const photoPlaceholder = ColoredBox(
      color: Color(0xFF2A1B5E),
      child: FittedBox(child: Icon(Icons.person, color: Colors.white70)),
    );

    Widget label(String text) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        );

    // Tudo dentro de uma caixa do tamanho do quadro: o conteudo encolhe pra
    // caber e nunca sai pra fora do banner.
    return Positioned(
      left: (slot.posX / 100) * areaWidth,
      top: (slot.posY / 100) * areaHeight,
      width: boxW,
      height: boxH,
      child: Column(
        children: [
          label(champion.displayName),
          const SizedBox(height: 3),
          // foto do campeao (sem o avatar/pato), com borda dourada.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5), blurRadius: 8)],
                  ),
                  child: ClipOval(
                    child: hasPhoto
                        ? Image(image: MediaCacheImage(champion.avatarUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => photoPlaceholder,
                          )
                        : photoPlaceholder,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          label("${_formatDiamonds(champion.diamonds)} 💎"),
        ],
      ),
    );
  }
}

class _ResidentBubble extends StatelessWidget {
  final IslandResident resident;
  final double size;
  final IslandAvatarOption? defaultAvatar;

  const _ResidentBubble({required this.resident, required this.size, this.defaultAvatar});

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(resident.diamonds);
    final avatarUrl = resident.avatarMediaUrl;
    final photoUrl = resident.profileAvatarUrl;
    const fallbackDuck = Center(child: Text("🦆", style: TextStyle(fontSize: 26)));
    final photoSize = (size * 0.32).clamp(14.0, 24.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // avatar escolhido pelo streamer, em loop — e o foco visual
          // principal, respeitando o formato configurado no admin.
          _AvatarFrame(
            size: size,
            mediaUrl: avatarUrl,
            displayShape: resident.displayShape,
            borderColor: Colors.white,
            muted: resident.muted,
            volume: resident.volume,
            loopVideo: resident.loopVideo,
            cropScale: resident.cropScale,
            cropOffsetX: resident.cropOffsetX,
            cropOffsetY: resident.cropOffsetY,
            defaultAvatar: defaultAvatar,
            fallback: fallbackDuck,
          ),
          // nome sobreposto na base do avatar, com espaco pra estourar a
          // largura da bolha (Clip.none no Stack) e cortar menos o nick.
          Positioned(
            left: -size * 0.4,
            right: -size * 0.4,
            bottom: size * 0.08,
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: size * 1.8),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  resident.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          // fotinho do streamer (bem pequena) so pra identificar quem e por
          // tras do avatar — o avatar continua sendo o destaque.
          Positioned(
            top: -3,
            left: -3,
            child: Container(
              width: photoSize,
              height: photoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black87,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: ClipOval(
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person, size: photoSize * 0.6, color: Colors.white70)
                    : Image(image: MediaCacheImage(photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Icon(Icons.person, size: photoSize * 0.6, color: Colors.white70),
                      ),
              ),
            ),
          ),
          if (tier > 0)
            Positioned(
              bottom: -2,
              right: -4,
              child: Row(
                children: List.generate(tier.clamp(0, 4), (i) => const Text("✨", style: TextStyle(fontSize: 10))),
              ),
            ),
        ],
      ),
    );
  }
}
