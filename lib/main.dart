import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/account_repository.dart';
import 'features/auth/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SessionController? session;
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    session = SessionController(SupabaseAccountRepository());
    // Loads the profile in the background; the router shows Loading meanwhile.
    unawaited(session.refresh());
  }

  final ThemeController theme = await ThemeController.load();
  runApp(MindQuestApp(themeController: theme, session: session));
}
