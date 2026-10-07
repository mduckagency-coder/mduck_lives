import "dart:async";

import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:video_player/video_player.dart";
import "../../../../core/media/media_cache.dart";
import "../../../shell/app_shell.dart";
import "../../../home/data/home_background_repository.dart";
import "../../data/max_activity_repository.dart";
import "../../data/max_daily_gate.dart";
import "../../data/max_messages.dart";
import "../../data/max_state_content_repository.dart";
import "../../domain/max_activity_calculator.dart";
import "../../domain/max_state.dart";

const _fallbackImageAsset = "assets/videos/LogoMduck.png";

class MaxIntroPage extends StatefulWidget {
  const MaxIntroPage({super.key});

  @override
  State<MaxIntroPage> createState() => _MaxIntroPageState();
}

class _MaxIntroPageState extends State<MaxIntroPage> with SingleTickerProviderStateMixin {
  final _activityRepository = MaxActivityRepository();
  final _contentRepository = MaxStateContentRepository();
  final SupabaseMaxMessageProvider _messageProvider = SupabaseMaxMessageProvider();
  final _dailyGate = MaxDailyGate();

  VideoPlayerController? _videoController;
  String? _imageUrl;
  String? _imageAsset;
  String _message = "";
  String? _streamerName;
  dynamic _agencyId;
  bool _imageFallbackAttempted = false;
  bool _navigated = false;
  bool _ready = false;

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // Ja busca o video de fundo da Home enquanto o streamer esta nesta tela.
    HomeBackgroundRepository.prefetch();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2, milliseconds: 200),
    )..repeat(reverse: true);
    _loadWithTimeout();
  }

  Future<void> _loadWithTimeout() async {
    try {
      await _load().timeout(const Duration(seconds: 12));
    } catch (_) {
      if (mounted) _goToHome();
    }
  }

  Future<void> _load() async {
    String streamerId;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final profile = await client
          .from("profiles")
          .select("id, display_name, agency_id")
          .eq("auth_user_id", userId)
          .single();
      streamerId = profile["id"] as String;
      _streamerName = (profile["display_name"] as String?)?.trim();
      // Desabilitado no painel (Max Entrada > Configuração): pula direto pra Home.
      if (!await _activityRepository.fetchEnabled(profile["agency_id"])) {
        _goToHome();
        return;
      }
    } catch (_) {
      // Sem streamer resolvido, nao da pra buscar atividade real - segue
      // direto pra Home.
      _goToHome();
      return;
    }

    // A tela do Max aparece toda vez que o app abre. O _dailyGate continua
    // guardando a ultima mensagem/estado pra nao repetir a mesma frase e pra
    // detectar o retorno de um periodo INATIVO/CAVEIRA.

    final data = await _activityRepository.fetchSnapshotForCurrentStreamer();
    _agencyId = data.agencyId;
    final now = DateTime.now();
    final state = calculateMaxState(data.snapshot, data.thresholds, now);
    final moment = calculateMonthMoment(now);
    final lastMessage = await _dailyGate.lastMessage(streamerId);
    final lastState = await _dailyGate.lastState(streamerId);

    final wasInactive = lastState == MaxState.inativo || lastState == MaxState.caveira;
    final isBackToActive = state == MaxState.regular || state == MaxState.constante;
    final isReturning = wasInactive && isBackToActive;

    var remoteMessage = await _messageProvider.fetchMessage(
      state: state,
      agencyId: data.agencyId?.toString(),
      lastMessage: lastMessage,
      moment: moment,
      isReturning: isReturning,
    );
    if (remoteMessage == null && state != MaxState.regular) {
      remoteMessage = await _messageProvider.fetchMessage(
        state: MaxState.regular,
        agencyId: data.agencyId?.toString(),
        lastMessage: lastMessage,
        moment: moment,
        isReturning: false,
      );
    }
    final message = remoteMessage ??
        LocalMaxMessageProvider().pickMessage(
          state: state == MaxState.regular ? state : MaxState.regular,
          moment: moment,
          lastMessage: lastMessage,
          isReturning: false,
        );

    var content = await _contentRepository.fetchContentFor(
      state,
      agencyId: data.agencyId,
    );
    if (content == null && state != MaxState.regular) {
      content = await _contentRepository.fetchContentFor(
        MaxState.regular,
        agencyId: data.agencyId,
      );
    }

    if (!mounted) return;

    await _dailyGate.markShownToday(streamerId, message: message, state: state);

    if (content != null && content.mediaType == MaxMediaType.image) {
      final imageUrl = content.mediaUrl;
      setState(() {
        _imageUrl = imageUrl;
        _message = message;
        _ready = true;
      });
      return;
    }

    await _initializeVideo(content, agencyId: data.agencyId);

    if (!mounted) return;
    setState(() {
      _message = message;
      _ready = true;
    });
  }

  Future<void> _handleImageError() async {
    if (_imageFallbackAttempted) return;
    _imageFallbackAttempted = true;
    final regular = await _contentRepository.fetchContentFor(
      MaxState.regular,
      agencyId: _agencyId,
    );
    if (!mounted) return;
    if (regular != null && regular.mediaType == MaxMediaType.image) {
      setState(() => _imageUrl = regular.mediaUrl);
      return;
    }
    setState(() => _imageUrl = null);
    await _initializeVideo(null, agencyId: _agencyId);
    if (mounted) setState(() {});
  }

  Future<void> _initializeVideo(MaxStateContent? content, {dynamic agencyId}) async {
    final sources = <String>[];
    MaxStateContent? regularContent;
    if (content?.mediaUrl != null) sources.add(content!.mediaUrl);
    if (content != null) {
      regularContent = await _contentRepository.fetchContentFor(
        MaxState.regular,
        agencyId: agencyId,
      );
      if (regularContent != null && regularContent.mediaType == MaxMediaType.video && regularContent.mediaUrl != content.mediaUrl) {
        sources.add(regularContent.mediaUrl);
      }
    }

    for (final source in sources) {
      // video em loop: toca do arquivo salvo (baixa uma vez so). Se demorar,
      // segue com a imagem e o download fica pronto para a proxima vez.
      final controller = await MediaCache.controller(source, wait: const Duration(seconds: 12));
      if (controller == null) continue;
      try {
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        controller.setLooping(true);
        // Animacao do pato sem som: o audio em loop gerava estalos/chiado.
        await controller.setVolume(0);
        await controller.play();
        _videoController = controller;
        return;
      } catch (_) {
        await controller.dispose();
      }
    }

    if (regularContent?.mediaType == MaxMediaType.image) {
      _imageUrl = regularContent!.mediaUrl;
      return;
    }

    _imageAsset = _fallbackImageAsset;
  }

  void _goToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildMedia() {
    if (_imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Image(image: MediaCacheImage(_imageUrl!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              unawaited(_handleImageError());
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      );
    }
    if (_imageAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Image.asset(_imageAsset!, fit: BoxFit.contain),
        ),
      );
    }

    final controller = _videoController;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 220,
        height: 220,
        child: controller != null && controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContinueButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = _glowController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.16 + glow * 0.18),
                blurRadius: 14 + glow * 10,
                spreadRadius: 1 + glow * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ElevatedButton(
        onPressed: _goToHome,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          "Avançar",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Mantem a imagem de carregamento enquanto busca o conteudo, em tela
      // cheia igual a tela anterior, pra parecer a mesma tela continuando.
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: Image(image: AssetImage("assets/splash/splash.jpg"), fit: BoxFit.cover),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMedia(),
                    const SizedBox(height: 16),
                    // Saudacao com o nome do streamer, acima da frase do Max.
                    if (_streamerName != null && _streamerName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                        child: Text(
                          "Olá, $_streamerName!",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC084FC),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildContinueButton(),
                  ],
                ),
              ),
      ),
    );
  }
}
