import "dart:io";
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:gal/gal.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

/// Compartilhamento de imagem do app (usado pelo Ranking e pelas
/// Conquistas): menu com TikTok em destaque, Instagram, WhatsApp, salvar na
/// galeria e o menu nativo do celular.
///
/// No Android abre o app escolhido direto (canal nativo "mduck/share" em
/// MainActivity.kt); no iPhone cai no menu de compartilhar do sistema.
class ImageShareMenu {
  ImageShareMenu._();

  static const _channel = MethodChannel("mduck/share");
  static const _tiktok = ["com.zhiliaoapp.musically", "com.ss.android.ugc.trill", "com.zhiliaoapp.musically.go"];

  /// Gera o PNG de um RepaintBoundary (em alta resolucao, bom pra Stories).
  static Future<Uint8List> capture(GlobalKey boundaryKey, {double pixelRatio = 3}) async {
    final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Abre o menu de compartilhar. [capture] gera a imagem na hora da escolha;
  /// [text] vai como legenda; [title] e o titulo do menu.
  static Future<void> show(
    BuildContext context, {
    required Future<Uint8List> Function() capture,
    required String text,
    String title = "Compartilhar",
    String fileName = "mduck_agency.png",
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    void message(String m) => messenger?.showSnackBar(SnackBar(content: Text(m)));

    Future<String> writeFile() async {
      final bytes = await capture();
      final dir = Directory("${(await getTemporaryDirectory()).path}/share_plus");
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes);
      return file.path;
    }

    Future<void> toApp(String appName, List<String> packages) async {
      try {
        final path = await writeFile();
        if (Platform.isAndroid) {
          final opened = await _channel.invokeMethod<bool>("shareImageToApp", {"path": path, "packages": packages, "text": text});
          if (opened != true) message("$appName não está instalado neste celular.");
          return;
        }
        await Share.shareXFiles([XFile(path)], text: text);
      } catch (e) {
        message("Não foi possível compartilhar: $e");
      }
    }

    Future<void> toSystem() async {
      try {
        await Share.shareXFiles([XFile(await writeFile())], text: text);
      } catch (e) {
        message("Não foi possível compartilhar: $e");
      }
    }

    Future<void> save() async {
      try {
        if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
          message("Permita o acesso à galeria para salvar a imagem.");
          return;
        }
        await Gal.putImageBytes(await capture(), album: "MDuck", name: "mduck_${DateTime.now().millisecondsSinceEpoch}");
        message("Imagem salva na galeria! ✅");
      } catch (e) {
        message("Não foi possível salvar: $e");
      }
    }

    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        void pick(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return _ShareMenu(
          title: title,
          onTikTok: () => pick(() => toApp("TikTok", _tiktok)),
          onInstagram: () => pick(() => toApp("Instagram", const ["com.instagram.android"])),
          onWhatsApp: () => pick(() => toApp("WhatsApp", const ["com.whatsapp", "com.whatsapp.w4b"])),
          onSave: () => pick(save),
          onMore: () => pick(toSystem),
        );
      },
    );
  }
}

class _ShareMenu extends StatelessWidget {
  final String title;
  final VoidCallback onTikTok;
  final VoidCallback onInstagram;
  final VoidCallback onWhatsApp;
  final VoidCallback onSave;
  final VoidCallback onMore;

  const _ShareMenu({
    required this.title,
    required this.onTikTok,
    required this.onInstagram,
    required this.onWhatsApp,
    required this.onSave,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTikTok,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF25F4EE), width: 1.5),
                  ),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.music_note, color: Color(0xFFFE2C55), size: 24),
                  SizedBox(width: 10),
                  Text("Postar no TikTok", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ShareOption(label: "Instagram", icon: Icons.camera_alt, gradient: const [Color(0xFFFEDA75), Color(0xFFD62976), Color(0xFF4F5BD5)], onTap: onInstagram),
              _ShareOption(label: "WhatsApp", icon: Icons.chat, gradient: const [Color(0xFF25D366), Color(0xFF128C7E)], onTap: onWhatsApp),
              _ShareOption(label: "Salvar imagem", icon: Icons.download, gradient: const [Color(0xFFB026FF), Color(0xFF7A0BD4)], onTap: onSave),
              _ShareOption(label: "Mais opções", icon: Icons.more_horiz, gradient: const [Color(0xFF4A4060), Color(0xFF2A2240)], onTap: onMore),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ShareOption({required this.label, required this.icon, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}
