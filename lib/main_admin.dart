import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_app.dart';
import 'admin/admin_repository.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/setup/setup_status_screen.dart';

/// MindQuest Admin, the web dashboard for administrators and counsellors
/// (step 11). Run it with:
///
///   flutter run -d chrome -t lib/main_admin.dart --web-port 5050 \
///     --dart-define-from-file=config/dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(
        MaterialApp(theme: AppTheme.light(), home: const SetupStatusScreen()));
    return;
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  runApp(AdminApp(repository: SupabaseAdminRepository()));
}
