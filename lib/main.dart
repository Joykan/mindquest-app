import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/offline/offline_store.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/account_repository.dart';
import 'features/auth/session_controller.dart';
import 'features/reminders/local_notifications.dart';
import 'features/reminders/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SessionController? session;
  OfflineStore? offline;
  ReminderController? reminders;
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Saved data and check-ins made without internet (step 10).
    offline = OfflineStore(prefs,
        userId: () => Supabase.instance.client.auth.currentUser?.id)
      // A tiny request to notice when the internet is back.
      ..probe = () async {
        await Supabase.instance.client.from('badges').select('id').limit(1);
      };
    session = SessionController(SupabaseAccountRepository(offline: offline));
    // Loads the profile in the background; the router shows Loading meanwhile.
    unawaited(session.refresh());

    // Daily check-in reminders.
    reminders = ReminderController(prefs, LocalNotificationScheduler());
    try {
      await reminders.init();
    } catch (e) {
      debugPrint('Reminders are not available: $e');
    }
  }

  final ThemeController theme = await ThemeController.load();
  runApp(MindQuestApp(
    themeController: theme,
    session: session,
    offline: offline,
    reminders: reminders,
  ));
  offline?.start();
}
