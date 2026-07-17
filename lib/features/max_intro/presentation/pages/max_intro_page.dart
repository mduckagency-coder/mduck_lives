import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:video_player/video_player.dart";
import "../../../home/presentation/pages/home_page.dart";

class MaxIntroPage extends StatefulWidget {
  const MaxIntroPage({super.key});

  @override
  State<MaxIntroPage> createState() => _MaxIntroPageState();
}

class _MaxIntroPageState extends State<MaxIntroPage> {
  late VideoPlayerController _controller;
  String _streamerNick = "";
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/videos/max_intro.mp4")
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
    _loadStreamerNick();
  }

  Future<void> _loadStreamerNick() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final profile = await client
          .from("profiles")
          .select("display_name, tiktok_username")
          .eq("id", userId)
          .single();
      if (mounted) {
        setState(() {
          _streamerNick = (profile["tiktok_username"] as String?) ??
              (profile["display_name"] as String?) ??
              "Ducker";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _streamerNick = "Ducker";
        });
      }
    }
  }

  void _goToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 220,
                height: 220,
                child: _controller.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _streamerNick.isEmpty
                    ? ""
                    : "Ola Streamer $_streamerNick, eu sou o Max e fico muito feliz em te ver por aqui!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _goToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Avancar!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
