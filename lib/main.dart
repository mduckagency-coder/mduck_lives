import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/app_loading_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://ecpddfnzukhqafhnhmpf.supabase.co',
      publishableKey: 'sb_publishable_NszHMwgU1mBr_O8LuXkNow_9Z0c_DSr',
    ).timeout(const Duration(seconds: 10));
  } catch (error) {
    debugPrint('Supabase nao inicializado: $error');
  }
  // Virada de mes: quem ainda nao veio na planilha do mes novo nao pode
  // aparecer com os numeros do mes passado (migration 0092). Idempotente.
  try {
    if (Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.rpc('virar_mes_streamer_stats').timeout(const Duration(seconds: 3));
    }
  } catch (_) {}
  runApp(const ProviderScope(child: MDuckLivesApp()));
}

class MDuckLivesApp extends StatelessWidget {
  const MDuckLivesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDuck Lives',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppLoadingPage(),
    );
  }
}