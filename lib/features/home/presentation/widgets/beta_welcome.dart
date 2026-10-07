import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../settings/data/settings_repository.dart";
import "../../../settings/settings_info_pages.dart";

/// Boas-vindas da versao Beta, ao entrar na Home. Aparece uma vez por versao
/// (a versao vem do painel: Configuracoes do Aplicativo > Versao e
/// Atualizacoes). Mudou a versao no painel, aparece de novo para todos.
/// Titulo e texto podem ser trocados em Textos do Aplicativo.
bool _checking = false;

Future<void> maybeShowBetaWelcome(BuildContext context) async {
  if (_checking) return;
  _checking = true;
  try {
    final config = await SettingsRepository().fetchConfig();
    final version = config.versionLabel;
    if (!version.toLowerCase().contains("beta") && config.text("welcome_text").isEmpty) return;
    final key = "beta_welcome_seen_$version";
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BetaWelcomeDialog(config: config, version: version),
    );
    await prefs.setBool(key, true);
  } catch (_) {
    // sem internet ou sem armazenamento: tenta de novo na proxima vez
  } finally {
    _checking = false;
  }
}

class _BetaWelcomeDialog extends StatelessWidget {
  final AppConfig config;
  final String version;
  const _BetaWelcomeDialog({required this.config, required this.version});

  static const _lilac = Color(0xFFC084FC);

  Widget _point(String emoji, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final custom = config.text("welcome_text");
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1786), Color(0xFF221262), Color(0xFF142050)]),
          border: Border.all(color: _lilac.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: const Color(0xFF7A2BE2).withValues(alpha: 0.35), blurRadius: 30)],
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text("🦆", textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Text(
              config.text("welcome_title", "Boas-vindas ao MDuck Lives!"),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFC94D).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Text("Versão $version", style: const TextStyle(color: Color(0xFFFFC94D), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            if (custom.isNotEmpty)
              Text(custom, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45))
            else ...[
              _point("🚧", "Esta é uma versão Beta: o app ainda está em construção e vai melhorar a cada atualização."),
              _point("📊", "Alguns números podem ter atraso ou ser corrigidos pela equipe. A data da última atualização aparece na Home."),
              _point("💬", "Achou algo estranho ou teve uma ideia? Conte pra gente em Configurações > Reportar um problema ou Enviar sugestão."),
              _point("📖", "Na Central de Informações você entende como cada área do app funciona."),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7A2BE2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Vamos lá!", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            TextButton(
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(MaterialPageRoute(builder: (_) => HelpPage(config: config)));
              },
              child: const Text("Ver Central de Informações", style: TextStyle(color: _lilac)),
            ),
          ]),
        ),
      ),
    );
  }
}
