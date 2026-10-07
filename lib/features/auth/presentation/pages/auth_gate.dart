import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../data/auth_repository.dart";
import "login_page.dart";
import "../../../max_intro/presentation/pages/max_intro_page.dart";

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool _isSupabaseReady() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupabaseReady()) {
      return const LoginPage();
    }

    final authRepository = AuthRepository();
    return StreamBuilder<AuthState>(
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
        if (isLoggedIn) {
          return const MaxIntroPage();
        }
        return const LoginPage();
      },
    );
  }
}

