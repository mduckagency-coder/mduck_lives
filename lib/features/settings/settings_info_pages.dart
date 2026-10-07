import "package:flutter/material.dart";
import "package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart";
import "package:url_launcher/url_launcher.dart";

import "data/settings_repository.dart";
import "settings_page.dart" show settingsBg, settingsCard, settingsLilac;

Scaffold _page(String title, List<Widget> children) => Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(backgroundColor: settingsBg, foregroundColor: Colors.white, title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );

Widget _paragraph(String text) =>
    Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5));

/// Configurações > Sobre a MDuck (texto editavel no painel).
class AboutPage extends StatelessWidget {
  final AppConfig config;
  const AboutPage({super.key, required this.config});

  @override
  Widget build(BuildContext context) => _page(config.text("about_title", "Sobre a MDuck"), [
        Center(child: Image.asset("assets/videos/LogoMduck_crop.png", width: 240)),
        const SizedBox(height: 16),
        // texto rico do painel (negrito, imagens, links...); sem ele, o texto simples
        if (config.text("about_html").isNotEmpty)
          HtmlWidget(
            config.text("about_html"),
            textStyle: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            customStylesBuilder: (e) => e.localName == "a" ? {"color": "#C084FC"} : null,
            onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          )
        else
          _paragraph(config.text("about_text")),
      ]);
}

/// Configurações > FAQ / Ajuda (+ contatos de suporte).
class HelpPage extends StatelessWidget {
  final AppConfig config;
  const HelpPage({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final faq = config.faq;
    final whatsapp = config.text("support_whatsapp").replaceAll(RegExp(r"[^0-9]"), "");
    final email = config.text("support_email");
    return _page("Central de Informações", [
      _paragraph(config.text("help_text")),
      const SizedBox(height: 14),
      const _ManagerContactCard(),
      const SizedBox(height: 16),
      if (faq.isEmpty)
        const Text("Nenhuma pergunta cadastrada ainda.", style: TextStyle(color: Colors.white38))
      else
        Container(
          decoration: BoxDecoration(color: settingsCard, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final item in faq)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: settingsLilac,
                  collapsedIconColor: Colors.white54,
                  title: Text(item.q, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedAlignment: Alignment.centerLeft,
                  children: [_paragraph(item.a)],
                ),
              ),
          ]),
        ),
      if (whatsapp.isNotEmpty || email.isNotEmpty) ...[
        const SizedBox(height: 22),
        const Text("FALE COM A GENTE",
            style: TextStyle(color: settingsLilac, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        _paragraph(config.text("support_text")),
        const SizedBox(height: 8),
        if (whatsapp.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_outlined, color: Colors.white),
            title: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
            subtitle: Text(config.text("support_whatsapp"), style: const TextStyle(color: Colors.white60)),
            onTap: () => launchUrl(Uri.parse("https://wa.me/$whatsapp"), mode: LaunchMode.externalApplication),
          ),
        if (email.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline, color: Colors.white),
            title: const Text("E-mail", style: TextStyle(color: Colors.white)),
            subtitle: Text(email, style: const TextStyle(color: Colors.white60)),
            onTap: () => launchUrl(Uri(scheme: "mailto", path: email)),
          ),
      ],
      if (config.text("info_version").isNotEmpty) ...[
        const SizedBox(height: 22),
        Text(config.text("info_version"), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    ]);
  }
}

/// "Falar com minha gestão": gestor responsavel do streamer (nome + WhatsApp).
/// Sem gestor definido ou sem WhatsApp cadastrado, o card nao aparece.
class _ManagerContactCard extends StatefulWidget {
  const _ManagerContactCard();

  @override
  State<_ManagerContactCard> createState() => _ManagerContactCardState();
}

class _ManagerContactCardState extends State<_ManagerContactCard> {
  late final Future<({String name, String whatsapp})?> _future = SettingsRepository().fetchMyManager();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String name, String whatsapp})?>(
      future: _future,
      builder: (context, snap) {
        final m = snap.data;
        if (m == null) return const SizedBox.shrink();
        final digits = m.whatsapp.replaceAll(RegExp(r"[^0-9]"), "");
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF2A1652), Color(0xFF1A1233)]),
            border: Border.all(color: settingsLilac.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.support_agent, color: settingsLilac, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Precisa conversar?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Text(m.name.isEmpty ? "Sua gestão" : "Sua gestão: ${m.name}", style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse("https://wa.me/$digits"), mode: LaunchMode.externalApplication),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25A35A), foregroundColor: Colors.white),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text("Falar com minha gestão"),
            ),
          ]),
        );
      },
    );
  }
}

/// Configurações > Informações do app.
class AppInfoPage extends StatefulWidget {
  final AppConfig config;
  const AppInfoPage({super.key, required this.config});

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  String _build = "...";

  @override
  void initState() {
    super.initState();
    SettingsRepository().installedVersion().then((v) {
      if (mounted) setState(() => _build = v);
    });
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.white60))),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return _page("Informações do app", [
      _paragraph(c.text("app_info_text")),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: settingsCard, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _row("Versão", c.versionLabel),
          if (c.lastUpdateLabel.isNotEmpty) _row("Última atualização", c.lastUpdateLabel),
          _row("Build instalado", _build),
          _row("Desenvolvido por", "MDuck Agency"),
        ]),
      ),
    ]);
  }
}
