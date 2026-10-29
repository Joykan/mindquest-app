import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/tr.dart';
import 'core/offline/offline_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/session_controller.dart';
import 'features/gamification/badge_watcher.dart';
import 'features/gamification/outfits.dart';
import 'features/reminders/reminders.dart';

class MindQuestApp extends StatefulWidget {
  const MindQuestApp(
      {super.key,
      this.themeController,
      this.session,
      this.offline,
      this.reminders,
      this.badges,
      this.outfits});

  /// Loaded in main() from the saved setting; tests use the default.
  final ThemeController? themeController;

  /// Null when the app was built without Supabase keys.
  final SessionController? session;

  /// Saved data for offline use (null in tests).
  final OfflineStore? offline;

  /// Daily check-in reminders (null in tests).
  final ReminderController? reminders;

  /// Notices new badges (null in tests).
  final BadgeWatcher? badges;

  /// What Chipu wears (tests get one that saves nothing).
  final OutfitController? outfits;

  @override
  State<MindQuestApp> createState() => _MindQuestAppState();
}

class _MindQuestAppState extends State<MindQuestApp> {
  late final ThemeController _theme =
      widget.themeController ?? ThemeController();
  late final OutfitController _outfits =
      widget.outfits ?? OutfitController();
  late final GoRouter _router = createRouter(_theme, widget.session,
      offline: widget.offline,
      reminders: widget.reminders,
      badges: widget.badges,
      outfits: _outfits);

  @override
  void initState() {
    super.initState();
    widget.session?.addListener(_updateReminders);
    _updateReminders();
  }

  @override
  void dispose() {
    widget.session?.removeListener(_updateReminders);
    super.dispose();
  }

  /// Reminders only for a signed-in user, in their language.
  void _updateReminders() {
    final SessionController? s = widget.session;
    if (s == null) return;
    // Someone else may sign in next: Chipu starts plain.
    if (!s.signedIn) _outfits.show(null);
    widget.reminders
        ?.update(signedIn: s.signedIn && s.onboarded, language: s.language);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the theme or the language changes.
    return ListenableBuilder(
      listenable: Listenable.merge(
          <Listenable?>[_theme, if (widget.session != null) widget.session]),
      builder: (BuildContext context, _) {
        final String language = widget.session?.language ?? 'en';
        return MaterialApp.router(
          title: 'MindQuest',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _theme.value,
          // Built-in texts (back button, date pickers...) follow the language too.
          locale: Locale(language),
          supportedLocales: <Locale>[
            for (final String l in appLanguages) Locale(l)
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext context, Widget? child) => LanguageScope(
            language: language,
            child: OutfitScope(
              controller: _outfits,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          routerConfig: _router,
        );
      },
    );
  }
}
