import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/tr.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/session_controller.dart';

class MindQuestApp extends StatefulWidget {
  const MindQuestApp({super.key, this.themeController, this.session});

  /// Loaded in main() from the saved setting; tests use the default.
  final ThemeController? themeController;

  /// Null when the app was built without Supabase keys.
  final SessionController? session;

  @override
  State<MindQuestApp> createState() => _MindQuestAppState();
}

class _MindQuestAppState extends State<MindQuestApp> {
  late final ThemeController _theme =
      widget.themeController ?? ThemeController();
  late final GoRouter _router = createRouter(_theme, widget.session);

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
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: _router,
        );
      },
    );
  }
}
