import "dart:async";

import "package:flutter/material.dart";
import "package:video_player/video_player.dart";
import "../home/presentation/widgets/home_content.dart";
import "../home/presentation/widgets/home_constancy_bar.dart";
import "../missoes/missoes_content.dart";
import "../../core/feature_flags.dart";
import "../ilha_top_duckers/ilha_top_duckers_content.dart";
import "../ranking/ranking_content.dart";
import "../ranking/my_ranking_intro_screen.dart";
import "../calendar/calendar_content.dart";
import "../notifications/notifications_bell.dart";
import "../settings/settings_page.dart";
import "../academia/academy_tab.dart";
import "../inventory/inventory_content.dart";
import "../inventory/widgets/inventory_emblem_icon.dart";
import "../home/data/home_background_repository.dart";
import "../news/widgets/news_scroll_button.dart";
import "../challenge/widgets/dice_button.dart";
import "../../core/media/media_cache.dart";

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 3;
  bool _showGeneralRanking = false;
  /// Video de fundo da Home, sempre o configurado no site (Background Home).
  /// null enquanto carrega ou se a agencia nao cadastrou nenhum video.
  VideoPlayerController? _videoController;

  /// Audio padrao da Home tocando por cima de um video mudo (quando o video
  /// sorteado esta configurado com "Áudio padrão da Home" no site).
  VideoPlayerController? _audioController;
  String? _backgroundId;

  /// Texto configurado no site pra aparecer sobre o video de inatividade
  /// (streamer ha mais de 7 dias sem live). null nos videos normais.
  String? _overlayText;
  Timer? _backgroundCheck;
  bool _loadingBackground = false;
  final _backgroundRepository = HomeBackgroundRepository();

  bool get _onHome => _selectedIndex == 3;

  static const _brandPurple = Color(0xFF7A0BD4);

  static const _items = [
    (Icons.emoji_events, "Ranking"),
    (Icons.assignment_turned_in, "Missoes"),
    (Icons.landscape, "Ilha Top"),
    (Icons.home, "Home"),
    (Icons.calendar_month, "Calendario"),
    (Icons.backpack, "Jornada"),
  ];

  @override
  void initState() {
    super.initState();
    // Carrega a Ilha Top em segundo plano pra aba abrir sem espera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && kIlhaTopEnabled) IlhaTopDuckersContent.prefetch(context);
    });
    WidgetsBinding.instance.addObserver(this);
    _loadBackground();
    // Com o app aberto, confere de tempos em tempos se mudou a faixa de
    // horario (ex: 11:59 -> 12:00). Dentro da mesma faixa o sorteio do dia
    // devolve o mesmo video, entao nada muda na tela.
    _backgroundCheck = Timer.periodic(const Duration(minutes: 5), (_) => _loadBackground());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundCheck?.cancel();
    _videoController?.dispose();
    _audioController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePlayback();
      // Pode ter mudado a faixa de horario (ex: manha -> tarde) enquanto o
      // app estava fechado; dentro da mesma faixa o video do dia nao muda.
      _loadBackground();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _videoController?.pause();
      _audioController?.pause();
    }
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    _updatePlayback();
  }

  /// Video e som da Home so tocam com a aba Home aberta.
  void _updatePlayback() {
    if (_onHome) {
      _videoController?.play();
      _audioController?.play();
    } else {
      _videoController?.pause();
      _audioController?.pause();
    }
  }

  Future<void> _loadBackground() async {
    if (_loadingBackground) return;
    _loadingBackground = true;
    try {
      await _applyBackground();
    } finally {
      _loadingBackground = false;
      if (mounted && _backgroundId == null) setState(() {}); // tira o "carregando"
    }
  }

  Future<void> _applyBackground() async {
    final background = await (HomeBackgroundRepository.takePrefetched() ?? _backgroundRepository.fetchCurrent());
    if (!mounted || background == null) return;
    final overlay = background.isInactivity && (background.overlayText?.isNotEmpty ?? false) ? background.overlayText : null;
    if (background.id == _backgroundId) {
      // mesmo video: so atualiza o texto, caso tenha sido editado no site
      if (overlay != _overlayText) setState(() => _overlayText = overlay);
      return;
    }

    final options = VideoPlayerOptions(mixWithOthers: true);
    // video em loop: sempre do arquivo no aparelho (baixado uma vez so).
    // Enquanto baixa, continua o fundo atual.
    final video = await MediaCache.controller(background.videoUrl, options: options, wait: const Duration(minutes: 2));
    if (video == null || !mounted) {
      await video?.dispose();
      return;
    }

    VideoPlayerController? audio;
    try {
      await video.initialize();
      await video.setLooping(true);
      await video.setVolume(background.videoVolume);
      if (background.usesDefaultAudio) {
        audio = await MediaCache.controller(background.defaultAudioUrl!, options: options);
        if (audio == null) throw Exception("audio padrao nao baixou");
        await audio.initialize();
        await audio.setLooping(true);
        await audio.setVolume(background.defaultAudioVolume.clamp(0, 1));
      }
    } catch (error) {
      debugPrint("[Background Home] video do site nao abriu, mantendo o atual: $error");
      await video.dispose();
      await audio?.dispose();
      return;
    }
    if (!mounted) {
      await video.dispose();
      await audio?.dispose();
      return;
    }

    final oldVideo = _videoController;
    final oldAudio = _audioController;
    setState(() {
      _videoController = video;
      _audioController = audio;
      _backgroundId = background.id;
      _overlayText = overlay;
    });
    _updatePlayback();
    await oldVideo?.dispose();
    await oldAudio?.dispose();
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _showGeneralRanking
            ? RankingContent(onBack: () => setState(() => _showGeneralRanking = false))
            : MyRankingIntroScreen(onViewGeneralRanking: () => setState(() => _showGeneralRanking = true));
      case 1:
        return const MissoesContent();
      case 2:
        return const IlhaTopDuckersContent();
      case 3:
        return const HomeContent();
      case 4:
        return const CalendarContent();
      case 5:
        return const InventoryContent();
      case 6:
        return const AcademyTab();
      default:
        return Center(
          child: Text(_items[_selectedIndex].$2 + " - em construcao", style: const TextStyle(color: Colors.white70)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_onHome && _videoController != null && _videoController!.value.isInitialized)
            Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            )
          else if (_onHome)
            // Enquanto o video do site carrega (ou se nao houver nenhum
            // cadastrado): fundo escuro no tom do app.
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0B2E), Color(0xFF0A0114)],
                ),
              ),
              child: _loadingBackground
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox.expand(),
            )
          else
            Container(color: Colors.black),
          SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // logo sem as bordas transparentes: maior, com a barra na mesma altura (80)
                      SizedBox(
                        height: 80,
                        child: Center(child: Image.asset("assets/videos/LogoMduck_crop.png", height: 56, fit: BoxFit.contain)),
                      ),
                      const Spacer(),
                      const NotificationsBell(),
                      const SizedBox(width: 14),
                      const SettingsButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildBody()),
                      // Pequenas descobertas da Home, no canto inferior direito
                      // da area da ilha, acima do menu:
                      //   dado       -> jogo rapido + Dica do Max (some se nao
                      //                 houver jogo ativo no painel)
                      //   pergaminho -> NOVIDADES da agencia (nao e o sino)
                      if (_onHome)
                        const Positioned(
                          left: 14,
                          right: 14,
                          bottom: 26,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // lado a lado (e nao empilhados) pra nao subir em
                              // cima da mensagem de inatividade
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  DiceButton(),
                                  NewsScrollButton(),
                                ],
                              ),
                              SizedBox(height: 8),
                              // Chama da Constancia, logo acima do menu
                              HomeConstancyBar(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        if (kIlhaTopEnabled || _items[i].$2 != "Ilha Top")
                        GestureDetector(
                          onTap: () => _selectTab(i),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Jornada usa o emblema proprio da MDUCK (nao o trofeu, que e do Ranking)
                              _items[i].$2 == "Jornada"
                                  ? InventoryEmblemIcon(color: _selectedIndex == i ? _brandPurple : Colors.white60)
                                  : Icon(_items[i].$1, color: _selectedIndex == i ? _brandPurple : Colors.white60, size: 22),
                              const SizedBox(height: 2),
                              Text(_items[i].$2, style: TextStyle(color: _selectedIndex == i ? _brandPurple : Colors.white60, fontSize: 9)),
                            ],
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _selectTab(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _brandPurple,
                                border: _selectedIndex == 6 ? Border.all(color: Colors.white, width: 1.5) : null,
                              ),
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(height: 2),
                            Text("Academia", style: TextStyle(color: _selectedIndex == 6 ? _brandPurple : Colors.white60, fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Estado de inatividade: texto do site sobre a ilha (sem o pato),
          // na parte de baixo, acima do menu.
          if (_onHome && _overlayText != null)
            Align(
              alignment: const Alignment(0, 0.62),
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFB026FF).withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      _overlayText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}




