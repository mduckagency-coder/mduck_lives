import 'package:supabase_flutter/supabase_flutter.dart';

/// Cuida de tudo relacionado a login/logout, conversando com o Supabase.
class AuthRepository {
  SupabaseClient? _client;

  SupabaseClient get _clientInstance {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  /// Avisa sempre que o usuário loga ou desloga.
  Stream<AuthState> get authStateChanges =>
      _clientInstance.auth.onAuthStateChange;

  bool get isLoggedIn => _clientInstance.auth.currentUser != null;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _clientInstance.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e, st) {
      print('========================');
      print('ERRO LOGIN: $e');
      print(st);
      print('========================');
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _clientInstance.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _clientInstance.auth.signOut();
  }
}