import 'package:supabase_flutter/supabase_flutter.dart';

/// Cuida de tudo relacionado a login/logout, conversando com o Supabase.
class AuthRepository {
  final _client = Supabase.instance.client;

  /// Avisa sempre que o usuário loga ou desloga.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  bool get isLoggedIn => _client.auth.currentUser != null;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}