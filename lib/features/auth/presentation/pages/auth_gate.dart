import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../../data/auth_repository.dart";
import "login_page.dart";
import "../../../max_intro/presentation/pages/max_intro_page.dart";

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
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
