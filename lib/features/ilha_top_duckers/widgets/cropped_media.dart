import "package:flutter/material.dart";
import "package:video_player/video_player.dart";
import "../../../core/media/media_cache.dart";

bool isVideoUrl(String url) {
  final u = url.toLowerCase();
  return u.endsWith(".mp4") || u.endsWith(".mov") || u.endsWith(".webm");
}

/// Video ou imagem com o corte configurado no admin: crop_scale (1 = sem
/// zoom) e crop_offset_x/crop_offset_y (% de -50 a 50, deslocamento a partir
/// do centro). Usa mixWithOthers pra esse player nao ser pausado por outros
/// videos do app (aula do MAX) nem pausar eles — loop de fundo/avatar/mascote
/// precisa ficar isolado.
class CroppedMedia extends StatefulWidget {
  final String mediaUrl;
  final String? fallbackImageUrl;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final Widget fallback;
  final BoxFit fit;

  /// Avisado uma vez quando a midia ja esta na tela (ou falhou e caiu no
  /// fallback), pra quem usa poder esconder um carregamento por cima.
  final VoidCallback? onReady;

  const CroppedMedia({
    super.key,
    required this.mediaUrl,
    this.fallbackImageUrl,
    this.muted = true,
    this.volume = 0,
    this.loopVideo = true,
    this.cropScale = 1,
    this.cropOffsetX = 0,
    this.cropOffsetY = 0,
    this.fallback = const SizedBox.shrink(),
    this.fit = BoxFit.cover,
    this.onReady,
  });

  bool get isVideo => isVideoUrl(mediaUrl);

  @override
  State<CroppedMedia> createState() => _CroppedMediaState();
}

class _CroppedMediaState extends State<CroppedMedia> {
  VideoPlayerController? _videoController;

  bool _disposed = false;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaUrl.isNotEmpty && widget.isVideo) {
      _initVideo();
    } else if (widget.mediaUrl.isEmpty) {
      _notifyReady();
    }
  }

  void _notifyReady() {
    if (_readyNotified || widget.onReady == null) return;
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) widget.onReady!();
    });
  }

  /// Sempre toca do arquivo salvo no aparelho (baixado uma vez so). Video em
  /// loop direto da internet podia ser baixado de novo a cada volta.
  Future<void> _initVideo() async {
    final options = VideoPlayerOptions(mixWithOthers: true);
    final controller = await MediaCache.controller(widget.mediaUrl, options: options, wait: const Duration(minutes: 2));
    if (_disposed || controller == null) {
      await controller?.dispose();
      _notifyReady();
      return;
    }
    _videoController = controller;
    controller.setLooping(widget.loopVideo);
    controller.setVolume(widget.muted ? 0 : widget.volume.clamp(0, 1));
    controller.initialize().then((_) {
      if (mounted) {
        controller.play();
        setState(() {});
      }
      _notifyReady();
    }).catchError((_) {
      _notifyReady();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _videoController?.dispose();
    super.dispose();
  }

  Widget _crop(BoxConstraints constraints, Widget child) {
    final scale = widget.cropScale <= 0 ? 1.0 : widget.cropScale;
    return ClipRect(
      child: Align(
        alignment: Alignment(
          (widget.cropOffsetX / 50).clamp(-1, 1),
          (widget.cropOffsetY / 50).clamp(-1, 1),
        ),
        child: SizedBox(
          width: constraints.maxWidth * scale,
          height: constraints.maxHeight * scale,
          child: child,
        ),
      ),
    );
  }

  Widget _imageFallback() {
    final url = widget.fallbackImageUrl;
    if (url == null || url.isEmpty) return widget.fallback;
    return Image(image: MediaCacheImage(url), fit: widget.fit, errorBuilder: (_, __, ___) => widget.fallback);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl.isEmpty) return _imageFallback();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.isVideo) {
          final controller = _videoController;
          if (controller == null || !controller.value.isInitialized) return _imageFallback();
          return _crop(
            constraints,
            FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          );
        }

        return _crop(
          constraints,
          Image(image: MediaCacheImage(widget.mediaUrl),
            fit: widget.fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null || wasSynchronouslyLoaded) _notifyReady();
              return child;
            },
            errorBuilder: (context, error, stack) {
              _notifyReady();
              return _imageFallback();
            },
          ),
        );
      },
    );
  }
}
