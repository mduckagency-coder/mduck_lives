import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ecpddfnzukhqafhnhmpf.supabase.co',
    anonKey: 'sb_publishable_NszHMwgU1mBr_O8LuXkNow_9Z0c_DSr',
  );
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
      home: const AuthGate(),
    );
  }
}