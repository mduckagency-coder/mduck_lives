import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "../../data/auth_repository.dart";
import "../../../settings/data/tiktok_auth_service.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e, stack) {
      debugPrint("DEBUG - Excecao completa: $e");
      debugPrint("DEBUG - Stack trace: $stack");
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _tiktokLoading = false;

  Future<void> _handleTikTok() async {
    setState(() {
      _tiktokLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final result = await TikTokAuthService().signIn();
      // sucesso: o AuthGate percebe a sessao nova e abre o app sozinho
      if (mounted && result.message != null) {
        setState(() => result.outcome == TikTokOutcome.cancelled
            ? _infoMessage = result.message
            : _errorMessage = result.message);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Não foi possível entrar com o TikTok. Tente novamente.");
    } finally {
      if (mounted) setState(() => _tiktokLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _infoMessage = "Digite seu e-mail acima primeiro, depois toque em Esqueci minha senha.");
      return;
    }
    try {
      await _authRepository.sendPasswordReset(_emailController.text.trim());
      setState(() => _infoMessage = "Enviamos um e-mail de recuperacao. Se nao encontrar, fale com seu gestor para redefinir manualmente.");
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("MDuck Lives", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "E-mail"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Senha",
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: const Text("Esqueci minha senha"),
                ),
              ),
              const SizedBox(height: 8),
              if (_infoMessage != null) ...[
                Text(_infoMessage!, style: const TextStyle(color: Colors.greenAccent), textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Entrar"),
              ),
              const SizedBox(height: 14),
              const Text("ou", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _tiktokLoading || _isLoading ? null : _handleTikTok,
                icon: _tiktokLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.music_note),
                label: const Text("Entrar com TikTok"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


