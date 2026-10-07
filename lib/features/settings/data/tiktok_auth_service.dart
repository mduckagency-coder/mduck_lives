import "package:flutter/services.dart";
import "package:flutter_web_auth_2/flutter_web_auth_2.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Login/vinculo com TikTok (Login Kit, OAuth 2.0).
///
/// O app NAO conhece client_secret nem tokens do TikTok: tudo isso fica na
/// Edge Function "tiktok-auth" (mduck_web_adm/supabase/functions/tiktok-auth).
/// O app so abre a pagina oficial do TikTok e recebe de volta
/// mduck://tiktok?status=...  (e, no login, um token de uso unico que vira
/// a sessao do Supabase via verifyOTP).
class TikTokAuthService {
  static const callbackScheme = "mduck";

  SupabaseClient get _db => Supabase.instance.client;

  /// Entrar com TikTok (tela de login).
  Future<TikTokResult> signIn() => _run("login");

  /// Conectar o TikTok na conta ja logada (Configurações > Conta).
  Future<TikTokResult> link() => _run("link");

  Future<void> unlink() async {
    final res = await _db.functions.invoke("tiktok-auth/unlink");
    if (res.status != 200) throw Exception("Não foi possível desconectar agora.");
  }

  Future<TikTokResult> _run(String mode) async {
    String url;
    try {
      final res = await _db.functions.invoke("tiktok-auth/start", body: {"mode": mode});
      url = (res.data as Map)["url"] as String;
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 503 || (details is Map && details["error"] == "tiktok_not_configured")) {
        return const TikTokResult(TikTokOutcome.notConfigured);
      }
      return TikTokResult(TikTokOutcome.error, "start_${e.status}");
    } catch (e) {
      return const TikTokResult(TikTokOutcome.error, "network");
    }

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: callbackScheme);
    } on PlatformException catch (e) {
      if (e.code == "CANCELED") return const TikTokResult(TikTokOutcome.cancelled);
      return TikTokResult(TikTokOutcome.error, e.code);
    }

    final q = Uri.parse(result).queryParameters;
    switch (q["status"]) {
      case "ok":
        final hash = q["token_hash"];
        if (hash == null) return const TikTokResult(TikTokOutcome.error, "no_token");
        await _db.auth.verifyOTP(tokenHash: hash, type: OtpType.magiclink);
        return const TikTokResult(TikTokOutcome.signedIn);
      case "linked":
        return const TikTokResult(TikTokOutcome.linked);
      case "cancelled":
        return const TikTokResult(TikTokOutcome.cancelled);
      case "not_found":
        return const TikTokResult(TikTokOutcome.notFound);
      case "already_linked":
        return const TikTokResult(TikTokOutcome.alreadyLinked);
      default:
        return TikTokResult(TikTokOutcome.error, q["reason"]);
    }
  }
}

enum TikTokOutcome { signedIn, linked, cancelled, notFound, alreadyLinked, notConfigured, error }

class TikTokResult {
  final TikTokOutcome outcome;
  final String? reason;
  const TikTokResult(this.outcome, [this.reason]);

  /// Mensagem pro usuario (null = sucesso silencioso).
  String? get message => switch (outcome) {
        TikTokOutcome.signedIn => null,
        TikTokOutcome.linked => "TikTok conectado à sua conta MDuck.",
        TikTokOutcome.cancelled => "Login com TikTok cancelado.",
        TikTokOutcome.notFound =>
          "Não encontramos seu cadastro na MDuck Agency para esta conta do TikTok. Fale com seu gestor.",
        TikTokOutcome.alreadyLinked => "Esta conta do TikTok já está conectada a outra conta MDuck.",
        TikTokOutcome.notConfigured => "O login com TikTok ainda não foi ativado pela agência.",
        TikTokOutcome.error => "Não foi possível concluir com o TikTok. Tente novamente.",
      };
}
