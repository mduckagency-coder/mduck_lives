import "package:flutter/material.dart";
import "package:mduck_lives/core/media/media_cache.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../auth/presentation/pages/auth_gate.dart";
import "data/settings_repository.dart";
import "data/tiktok_auth_service.dart";
import "my_reports_page.dart";
import "report_problem_page.dart";
import "settings_info_pages.dart";

const settingsBg = Color(0xFF0E0820);
const settingsCard = Color(0xFF1A1233);
const settingsPurple = Color(0xFF7A2BE2);
const settingsLilac = Color(0xFFC084FC);

/// Engrenagem ao lado do sino de notificacoes.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.settings_outlined, color: Colors.white, size: 25),
        ),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = SettingsRepository();
  final _tiktok = TikTokAuthService();
  AppConfig _config = const AppConfig({});
  MyAccount? _account;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchConfig().catchError((_) => const AppConfig({})),
        _repo.fetchAccount(),
      ]);
      if (!mounted) return;
      setState(() {
        _config = results[0] as AppConfig;
        _account = results[1] as MyAccount;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Não foi possível carregar suas informações.";
          _loading = false;
        });
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _connectTikTok() async {
    setState(() => _busy = true);
    final result = await _tiktok.link();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.message != null) _snack(result.message!);
    if (result.outcome == TikTokOutcome.linked) _load();
  }

  Future<void> _disconnectTikTok() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: settingsCard,
        title: const Text("Desconectar TikTok?"),
        content: const Text(
          "Sua conta MDuck e seus dados continuam iguais. Você só não poderá entrar pelo botão do TikTok até conectar de novo.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Desconectar")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _tiktok.unlink();
      _snack("TikTok desconectado.");
      await _load();
    } catch (e) {
      _snack("Não foi possível desconectar agora. Tente novamente.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: settingsCard,
        title: const Text("Sair da conta?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sair")),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        backgroundColor: settingsBg,
        foregroundColor: Colors.white,
        title: Text(_config.text("settings_title", "Configurações")),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: settingsLilac))
          : _error != null
              ? _ErrorRetry(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                    _profileCard(),
                    const _SectionTitle("CONTA"),
                    _accountCard(),
                    const _SectionTitle("AJUDA E SUPORTE"),
                    _Group(children: [
                      _Tile(
                        icon: Icons.bug_report_outlined,
                        title: "Reportar um problema",
                        onTap: () => _open(ReportProblemPage(config: _config)),
                      ),
                      _Tile(
                        icon: Icons.lightbulb_outline,
                        title: "Enviar sugestão",
                        onTap: () => _open(SuggestionPage(config: _config)),
                      ),
                      _Tile(icon: Icons.inbox_outlined, title: "Meus envios", onTap: () => _open(const MyReportsPage())),
                      _Tile(icon: Icons.menu_book_outlined, title: "Central de Informações", onTap: () => _open(HelpPage(config: _config))),
                    ]),
                    const _SectionTitle("SOBRE"),
                    _Group(children: [
                      _Tile(
                        icon: Icons.info_outline,
                        title: _config.text("about_title", "Sobre a MDuck"),
                        onTap: () => _open(AboutPage(config: _config)),
                      ),
                      _Tile(
                        icon: Icons.phone_android,
                        title: "Informações do app",
                        onTap: () => _open(AppInfoPage(config: _config)),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _footer(),
                  ]),
                ),
    );
  }

  Widget _profileCard() {
    final a = _account!;
    final avatar = a.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF2A1652), Color(0xFF1A1233)]),
        border: Border.all(color: settingsLilac.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: settingsPurple,
          backgroundImage: avatar != null && avatar.isNotEmpty ? MediaCacheImage(avatar) : null,
          child: avatar == null || avatar.isEmpty
              ? Text(a.name.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            if (a.username != null)
              Text("@${a.username}", style: const TextStyle(color: settingsLilac, fontSize: 13.5)),
            const SizedBox(height: 6),
            if (a.hasRealEmail) _kv("E-mail", a.email!),
            if (a.joinedAt != null) _kv("Na MDuck desde", _date(a.joinedAt!)),
            if (a.profileId != null) _kv("ID da conta", a.profileId!.substring(0, 8).toUpperCase()),
          ]),
        ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text("$k: $v", style: const TextStyle(color: Colors.white60, fontSize: 12)),
      );

  Widget _accountCard() {
    final t = _account!.tiktok;
    return _Group(children: [
      ListTile(
        leading: const Icon(Icons.music_note, color: Colors.white),
        title: Text(t.connected ? "TikTok conectado" : "TikTok não conectado",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          t.connected
              ? [t.displayName, if (t.username != null) "@${t.username}"].whereType<String>().join(" · ")
              : "Conecte para entrar com o TikTok e usar sua foto oficial.",
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: t.connected ? _disconnectTikTok : _connectTikTok,
                child: Text(t.connected ? "Desconectar" : "Conectar"),
              ),
      ),
      ListTile(
        leading: const Icon(Icons.login, color: Colors.white),
        title: const Text("Forma de login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          [if (_account!.hasRealEmail) "E-mail e senha", if (t.connected) "TikTok"].join(" + ").ifEmpty("TikTok"),
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
      _Tile(icon: Icons.logout, title: "Sair", danger: true, onTap: _logout),
    ]);
  }

  Widget _footer() {
    final date = _config.lastUpdateLabel;
    return Column(children: [
      Text("Versão ${_config.versionLabel}", style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
      if (date.isNotEmpty)
        Text("Última atualização: $date", style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
      const SizedBox(height: 6),
      const Text("MDuck Agency", style: TextStyle(color: Colors.white38, fontSize: 11.5, fontWeight: FontWeight.w600)),
    ]);
  }

  static String _date(DateTime d) =>
      "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 0, 8),
        child: Text(text,
            style: const TextStyle(color: settingsLilac, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: settingsCard, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Colors.white10, indent: 56),
            children[i],
          ],
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  const _Tile({required this.icon, required this.title, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B81) : Colors.white;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: danger ? null : const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text("Tentar de novo")),
        ]),
      );
}
