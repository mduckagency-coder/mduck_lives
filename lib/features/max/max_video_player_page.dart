import "dart:async";
import "package:flutter/material.dart";
import "package:video_player/video_player.dart";
import "package:youtube_player_flutter/youtube_player_flutter.dart";
import "data/max_lessons_repository.dart";

/// Player travado: o streamer so pode dar play, pause ou reassistir.
/// Sem barra de progresso arrastavel e sem avancar/voltar.
class MaxVideoPlayerPage extends StatefulWidget {
  final MaxLesson lesson;
  const MaxVideoPlayerPage({super.key, required this.lesson});

  @override
  State<MaxVideoPlayerPage> createState() => _MaxVideoPlayerPageState();
}

class _MaxVideoPlayerPageState extends State<MaxVideoPlayerPage> {
  static const _purple = Color(0xFFB026FF);
  static const _purpleDark = Color(0xFF7A0BD4);
  static const _bg = Color(0xFF1A0B2E);

  late bool _isYoutube;
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  StreamSubscription<YoutubePlayerValue>? _ytSub;
  bool _ready = false;
  bool _ended = false;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isYoutube = widget.lesson.videoSource == "youtube";
    if (_isYoutube) {
      final videoId = YoutubePlayerController.convertUrlToId(widget.lesson.videoUrl) ?? widget.lesson.videoUrl;
      final controller = YoutubePlayerController.fromVideoId(videoId: videoId, autoPlay: false);
      _youtubeController = controller;
      _ytSub = controller.stream.listen(_onYoutubeTick);
      _ready = true;
    } else {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.lesson.videoUrl));
      _videoController = controller;
      controller.addListener(_onVideoTick);
      controller.initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      });
    }
  }

  void _onYoutubeTick(YoutubePlayerValue value) {
    final ended = value.playerState == PlayerState.ended;
    final playing = value.playerState == PlayerState.playing;
    if (ended != _ended || playing != _playing) {
      setState(() {
        _ended = ended;
        _playing = playing;
      });
    }
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final ended = c.value.duration > Duration.zero && c.value.position >= c.value.duration;
    final playing = c.value.isPlaying;
    if (ended != _ended || playing != _playing) {
      setState(() {
        _ended = ended;
        _playing = playing;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _ytSub?.cancel();
    _youtubeController?.close();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isYoutube) {
      final c = _youtubeController!;
      _playing ? c.pauseVideo() : c.playVideo();
    } else {
      final c = _videoController!;
      c.value.isPlaying ? c.pause() : c.play();
      setState(() => _playing = c.value.isPlaying);
    }
  }

  void _rewatch() {
    if (_isYoutube) {
      final c = _youtubeController!;
      c.seekTo(seconds: 0, allowSeekAhead: true);
      c.playVideo();
    } else {
      _videoController!
        ..seekTo(Duration.zero)
        ..play();
    }
    setState(() {
      _ended = false;
      _playing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.lesson.title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: _buildPlayerArea()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tag(_categoryLabel(widget.lesson.category), _purple),
                        _tag(_levelLabel(widget.lesson.level), const Color(0xFFFFD700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.lesson.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (widget.lesson.description != null && widget.lesson.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(widget.lesson.description!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _categoryLabel(String c) {
    switch (c) {
      case "batalha":
        return "Batalha";
      case "musico":
        return "Musica";
      case "games":
        return "Games";
      default:
        return "Geral";
    }
  }

  String _levelLabel(String l) {
    switch (l) {
      case "veterano":
        return "Veterano";
      case "pro":
        return "Avancado";
      default:
        return "Iniciante";
    }
  }

  Widget _buildPlayerArea() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Nao foi possivel carregar o video.\n$_error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }

    if (_isYoutube) {
      return Container(
        color: Colors.black,
        child: YoutubePlayer(
          controller: _youtubeController!,
          aspectRatio: 16 / 9,
          builder: (context, player, controller) {
            return Stack(alignment: Alignment.center, fit: StackFit.expand, children: [player, _controlsOverlay()]);
          },
        ),
      );
    }

    if (!_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
          _controlsOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: _videoController!.value.duration.inMilliseconds == 0
                  ? 0
                  : _videoController!.value.position.inMilliseconds / _videoController!.value.duration.inMilliseconds,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_ended)
                _controlButton(icon: Icons.replay, label: "Assistir novamente", onTap: _rewatch)
              else if (!_playing)
                _controlButton(icon: Icons.play_arrow, onTap: _togglePlayPause),
              if (!_ended && _playing)
                Positioned(
                  bottom: 12,
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                      child: const Icon(Icons.pause, color: Colors.white, size: 22),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, String? label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_purple, _purpleDark]),
              boxShadow: [BoxShadow(color: _purple.withOpacity(0.6), blurRadius: 16, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          if (label != null) ...[
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
