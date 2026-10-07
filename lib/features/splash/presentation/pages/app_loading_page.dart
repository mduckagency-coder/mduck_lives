import "dart:async";

import "package:flutter/material.dart";
import "package:video_player/video_player.dart";
import "../../../../core/media/media_cache.dart";
import "../../data/splash_repository.dart";
import "../../../auth/presentation/pages/auth_gate.dart";

class AppLoadingPage extends StatefulWidget {
  const AppLoadingPage({super.key});

  @override
  State<AppLoadingPage> createState() => _AppLoadingPageState();
}

class _AppLoadingPageState extends State<AppLoadingPage> {
  final _repository = SplashRepository();
  Timer? _imageTimer;
  String? _imageUrl;
  VideoPlayerController? _videoController;
  bool _configurationLoaded = false;
  bool _imageLoaded = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final media = await _repository.fetchLoadingMedia().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;

      if (media?.mediaType == "video") {
        await _playLoadingVideo(media!);
        return;
      }

      // So troca a imagem do app pela do site depois que ela ja baixou;
      // senao a tela fica vazia no meio e parece que a imagem entra duas vezes.
      String? imageUrl = media?.mediaType == "image" ? media!.mediaUrl : null;
      if (imageUrl != null) {
        try {
          await precacheImage(MediaCacheImage(imageUrl), context)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          imageUrl = null;
        }
        if (!mounted) return;
      }

      setState(() {
        _imageUrl = imageUrl;
        _configurationLoaded = true;
      });
      _advanceWhenImageIsReady();
    } catch (_) {
      if (!mounted) return;
      setState(() => _configurationLoaded = true);
      _advanceWhenImageIsReady();
    }
  }

  Future<void> _playLoadingVideo(SplashMedia media) async {
    // So toca o video ja salvo no aparelho. Na primeira vez, mostra a imagem
    // e baixa o video em segundo plano para a proxima abertura (antes ele era
    // baixado da internet TODA vez que o app abria).
    final cached = await MediaCache.cachedFile(media.mediaUrl);
    if (cached == null) {
      MediaCache.download(media.mediaUrl);
      if (!mounted) return;
      setState(() => _configurationLoaded = true);
      _advanceWhenImageIsReady();
      return;
    }
    final controller = VideoPlayerController.file(cached);
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(media.muted ? 0 : media.volume.clamp(0, 1));
      controller.addListener(_onVideoChanged);
      _videoController = controller;
      setState(() => _configurationLoaded = true);
      await controller.play();
    } catch (error) {
      debugPrint("[Carregamento] video nao abriu (${media.mediaUrl}): $error");
      await controller.dispose();
      if (identical(_videoController, controller)) _videoController = null;
      if (!mounted) return;
      setState(() => _configurationLoaded = true);
      _advanceWhenImageIsReady();
    }
  }

  void _onVideoChanged() {
    final value = _videoController?.value;
    if (!mounted || value == null) return;
    if (value.hasError || value.isCompleted) {
      _goNext();
    }
  }

  void _onImageLoaded() {
    _imageLoaded = true;
    _advanceWhenImageIsReady();
  }

  void _advanceWhenImageIsReady() {
    if (!_configurationLoaded ||
        !_imageLoaded ||
        _navigated ||
        _imageTimer != null) {
      return;
    }
    _imageTimer = Timer(const Duration(milliseconds: 700), _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _imageTimer?.cancel();
    // Sem animacao de transicao: a proxima tela comeca com a mesma imagem,
    // entao a troca fica invisivel em vez de a imagem "entrar de novo".
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AuthGate(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final videoController = _videoController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: videoController != null && videoController.value.isInitialized
          ? Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoController.value.size.width,
                    height: videoController.value.size.height,
                    child: VideoPlayer(videoController),
                  ),
                ),
              ),
            )
          : imageUrl != null
          ? Image(image: MediaCacheImage(imageUrl),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null || wasSynchronouslyLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _onImageLoaded(),
                  );
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _imageUrl == null) return;
                  setState(() => _imageUrl = null);
                });
                return const SizedBox.expand();
              },
            )
          : Image.asset(
              "assets/splash/splash.jpg",
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null || wasSynchronouslyLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _onImageLoaded(),
                  );
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
            ),
    );
  }
}
