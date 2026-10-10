import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class MindQuestApp extends StatefulWidget {
  const MindQuestApp({super.key, this.themeController});

  /// Loaded in main() from the saved setting; tests use the default.
  final ThemeController? themeController;

  @override
  State<MindQuestApp> createState() => _MindQuestAppState();
}

class _MindQuestAppState extends State<MindQuestApp> {
  late final ThemeController _theme = widget.themeController ?? ThemeController();
  late final GoRouter _router = createRouter(_theme);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _theme,
      builder: (BuildContext context, ThemeMode mode, _) => MaterialApp.router(
        title: 'MindQuest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: _router,
      ),
    );
  }
}
