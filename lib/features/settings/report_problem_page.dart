import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "data/settings_repository.dart";
import "my_reports_page.dart";
import "settings_page.dart" show settingsBg, settingsCard, settingsLilac, settingsPurple;

const _red = Color(0xFFFF6B81);
const _gold = Color(0xFFFFC94D);

/// Configurações > Reportar um problema.
/// Nome, @, conta, data/hora, versao e status sao gravados pelo sistema.
class ReportProblemPage extends StatefulWidget {
  final AppConfig config;
  const ReportProblemPage({super.key, required this.config});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

/// Tipos de problema (a sugestao tem tela propria).
const _problemTypes = <(String, String, IconData)>[
  ("bug", "Bug ou erro", Icons.bug_report_outlined),
  ("dados", "Dados incorretos", Icons.query_stats),
  ("imagem_conquista", "Imagem ou conquista", Icons.image_not_supported_outlined),
  ("conta", "Problema na conta", Icons.manage_accounts_outlined),
  ("outro", "Outro", Icons.more_horiz),
];

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _description = TextEditingController();
  String? _type;
  String? _area;
  final _shot = ScreenshotController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _description.text.trim();
    if (_type == null) return setState(() => _error = "Escolha o que aconteceu.");
    if (text.length < 10) return setState(() => _error = "Conte um pouco mais do que aconteceu.");
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await SettingsRepository().submitReport(
        type: _type!,
        area: _area,
        description: text,
        screenshot: _shot.bytes,
        screenshotExt: _shot.ext,
        versionLabel: widget.config.versionLabel,
      );
      if (mounted) await showSentSheet(context, widget.config.text("report_success", "Recebemos seu reporte. Obrigado!"));
    } catch (_) {
      if (mounted) setState(() => _error = "Não foi possível enviar agora. Verifique sua internet e tente de novo.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: "Reportar um problema",
      children: [
        _Hero(
          icon: Icons.build_circle_outlined,
          colors: const [Color(0xFF5B1A3A), Color(0xFF2A1652)],
          accent: _red,
          title: "Algo não está certo?",
          text: widget.config.text("report_intro", "Conte o que aconteceu. Nós já registramos sua conta, a data e a versão do app."),
        ),
        const StepTitle(number: 1, text: "O que aconteceu?"),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            for (final (code, label, icon) in _problemTypes)
              _TypeTile(
                icon: icon,
                label: label,
                selected: _type == code,
                accent: _red,
                onTap: _sending ? null : () => setState(() => _type = code),
              ),
          ],
        ),
        const StepTitle(number: 2, text: "Em qual parte do app?", optional: true),
        AreaChips(selected: _area, enabled: !_sending, onSelected: (a) => setState(() => _area = a)),
        const StepTitle(number: 3, text: "Conte os detalhes"),
        DarkTextField(
          controller: _description,
          enabled: !_sending,
          minLines: 5,
          maxLength: 2000,
          hint: "O que você estava fazendo?\nO que aconteceu?\nO que você esperava que acontecesse?",
        ),
        const StepTitle(number: 4, text: "Print da tela", optional: true),
        ScreenshotPicker(controller: _shot, enabled: !_sending, onChanged: () => setState(() {}), onError: (e) => setState(() => _error = e)),
        const SizedBox(height: 16),
        const _AutoInfoNote(),
        if (_error != null) ErrorText(_error!),
        const SizedBox(height: 16),
        SendButton(sending: _sending, onPressed: _send, label: "Enviar reporte"),
      ],
    );
  }
}

/// Configurações > Enviar sugestão (tela propria, focada na ideia).
class SuggestionPage extends StatefulWidget {
  final AppConfig config;
  const SuggestionPage({super.key, required this.config});

  @override
  State<SuggestionPage> createState() => _SuggestionPageState();
}

class _SuggestionPageState extends State<SuggestionPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _area;
  final _image = ScreenshotController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final text = _description.text.trim();
    if (title.length < 4) return setState(() => _error = "Escreva sua ideia em uma frase.");
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await SettingsRepository().submitReport(
        type: "sugestao",
        title: title,
        area: _area,
        description: text.isEmpty ? title : text,
        screenshot: _image.bytes,
        screenshotExt: _image.ext,
        versionLabel: widget.config.versionLabel,
      );
      if (mounted) await showSentSheet(context, "Ideia recebida! A equipe MDuck lê todas as sugestões.");
    } catch (_) {
      if (mounted) setState(() => _error = "Não foi possível enviar agora. Verifique sua internet e tente de novo.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: "Enviar sugestão",
      children: [
        const _Hero(
          icon: Icons.lightbulb_outline,
          colors: [Color(0xFF4A3510), Color(0xFF2A1652)],
          accent: _gold,
          title: "Tem uma ideia?",
          text: "Sugestões ajudam a MDuck a construir um app cada vez melhor para você. Pode ser algo novo ou uma melhoria.",
        ),
        const StepTitle(number: 1, text: "Sua ideia em uma frase"),
        DarkTextField(controller: _title, enabled: !_sending, maxLength: 90, hint: "Ex.: Mostrar meu histórico de horas por semana"),
        const StepTitle(number: 2, text: "Sobre qual parte do app?", optional: true),
        AreaChips(selected: _area, enabled: !_sending, onSelected: (a) => setState(() => _area = a), accent: _gold, extra: "Algo novo"),
        const StepTitle(number: 3, text: "Conte mais", optional: true),
        DarkTextField(
          controller: _description,
          enabled: !_sending,
          minLines: 4,
          maxLength: 2000,
          hint: "Como funcionaria? Por que ajudaria você nas lives?",
        ),
        const StepTitle(number: 4, text: "Imagem de referência", optional: true),
        ScreenshotPicker(controller: _image, enabled: !_sending, onChanged: () => setState(() {}), onError: (e) => setState(() => _error = e)),
        if (_error != null) ErrorText(_error!),
        const SizedBox(height: 20),
        SendButton(sending: _sending, onPressed: _send, label: "Enviar sugestão", color: const Color(0xFFB8860B)),
      ],
    );
  }
}

// ----------------------------------------------------------------- pecas

Future<void> showSentSheet(BuildContext context, String message) async {
  final nav = Navigator.of(context);
  final goToList = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: settingsCard,
    isDismissible: false,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3DDC97).withValues(alpha: 0.15)),
            child: const Icon(Icons.check_rounded, color: Color(0xFF3DDC97), size: 38),
          ),
          const SizedBox(height: 14),
          const Text("Enviado!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 6),
          const Text("Você acompanha o andamento em Meus envios.",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: settingsPurple, foregroundColor: Colors.white),
              child: const Text("Ver meus envios"),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Fechar")),
        ]),
      ),
    ),
  );
  if (goToList == true) {
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MyReportsPage()));
  } else {
    nav.pop();
  }
}

class _FormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: settingsBg,
        appBar: AppBar(backgroundColor: settingsBg, foregroundColor: Colors.white, title: Text(title)),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: children),
        ),
      );
}

class _Hero extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final String title;
  final String text;
  const _Hero({required this.icon, required this.colors, required this.accent, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.16)),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ]),
      );
}

class StepTitle extends StatelessWidget {
  final int number;
  final String text;
  final bool optional;
  const StepTitle({super.key, required this.number, required this.text, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 0, 10),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: settingsPurple),
            child: Text("$number", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          if (optional) const Text("  (opcional)", style: TextStyle(color: Colors.white38, fontSize: 12.5)),
        ]),
      );
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  const _TypeTile({required this.icon, required this.label, required this.selected, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? accent.withValues(alpha: 0.16) : settingsCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? accent : Colors.white12, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(icon, color: selected ? accent : Colors.white70, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
}

class AreaChips extends StatelessWidget {
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onSelected;
  final Color accent;
  final String? extra;
  const AreaChips({super.key, required this.selected, required this.enabled, required this.onSelected, this.accent = settingsLilac, this.extra});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final area in [?extra, ...appAreas])
          ChoiceChip(
            label: Text(area),
            selected: selected == area,
            onSelected: enabled ? (v) => onSelected(v ? area : null) : null,
            selectedColor: accent.withValues(alpha: 0.25),
            backgroundColor: settingsCard,
            side: BorderSide(color: selected == area ? accent : Colors.white12),
            labelStyle: TextStyle(color: selected == area ? Colors.white : Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
            showCheckmark: false,
          ),
      ]);
}

class DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final int minLines;
  final int? maxLength;
  final String hint;
  const DarkTextField({super.key, required this.controller, required this.enabled, this.minLines = 1, this.maxLength, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        minLines: minLines,
        maxLines: minLines == 1 ? 2 : 12,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white, height: 1.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, height: 1.5),
          filled: true,
          fillColor: settingsCard,
          counterStyle: const TextStyle(color: Colors.white30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: settingsLilac)),
        ),
      );
}

/// Guarda a imagem escolhida (bytes + extensao).
class ScreenshotController {
  Uint8List? bytes;
  String? ext;
}

class ScreenshotPicker extends StatelessWidget {
  final ScreenshotController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final ValueChanged<String> onError;
  const ScreenshotPicker({super.key, required this.controller, required this.enabled, required this.onChanged, required this.onError});

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) return onError("A imagem é muito grande (máx. 8 MB).");
      controller
        ..bytes = bytes
        ..ext = file.name.toLowerCase().endsWith(".png") ? "png" : "jpg";
      onChanged();
    } catch (_) {
      onError("Não foi possível abrir a galeria.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = controller.bytes;
    if (bytes == null) {
      return InkWell(
        onTap: enabled ? _pick : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: settingsCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, color: settingsLilac, size: 28),
            SizedBox(height: 6),
            Text("Toque para escolher da galeria", style: TextStyle(color: Colors.white60, fontSize: 12.5)),
          ]),
        ),
      );
    }
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(bytes, height: 200, width: double.infinity, fit: BoxFit.cover),
      ),
      Positioned(
        right: 6,
        top: 6,
        child: IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          onPressed: enabled
              ? () {
                  controller
                    ..bytes = null
                    ..ext = null;
                  onChanged();
                }
              : null,
          icon: const Icon(Icons.close, size: 18, color: Colors.white),
        ),
      ),
    ]);
  }
}

class _AutoInfoNote extends StatelessWidget {
  const _AutoInfoNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.verified_user_outlined, color: Colors.white38, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text("Enviamos junto, automaticamente: sua conta, a data e hora e a versão do app.",
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ]),
      );
}

class ErrorText extends StatelessWidget {
  final String text;
  const ErrorText(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(text, style: const TextStyle(color: _red, fontWeight: FontWeight.w600)),
      );
}

class SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onPressed;
  final String label;
  final Color color;
  const SendButton({super.key, required this.sending, required this.onPressed, required this.label, this.color = settingsPurple});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: sending ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: sending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(sending ? "Enviando..." : label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
