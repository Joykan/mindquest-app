import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/gamification/badge_watcher.dart';
import '../l10n/tr.dart';
import '../offline/offline_store.dart';
import '../widgets/logo_mark.dart';
import '../widgets/offline_banner.dart';
import '../widgets/web_layout.dart';

/// Tells screens that progress changed (mood saved, tab switched to Home), so
/// they reload their numbers.
class ProgressTicker extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Bottom navigation from the wireframes: Home, Chat, Mood, Learn, Rewards.
class AppShell extends StatelessWidget {
  const AppShell(
      {super.key,
      required this.shell,
      required this.ticker,
      this.connection,
      this.onRetry,
      this.badges});

  /// Shows the pop-up for badges earned anywhere in the app.
  final BadgeWatcher? badges;

  final StatefulNavigationShell shell;
  final ProgressTicker ticker;

  /// Shows the offline banner above the tabs (null in tests).
  final ConnectionStatus? connection;
  final VoidCallback? onRetry;

  void _go(int i) {
    if (i == 0) ticker.bump();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final List<(IconData, IconData, String)> tabs =
        <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, context.tr('Home', 'Nyumbani')),
      (
        Icons.chat_bubble_outline,
        Icons.chat_bubble,
        context.tr('Chat', 'Ongea')
      ),
      (
        Icons.sentiment_satisfied_outlined,
        Icons.sentiment_satisfied,
        context.tr('Mood', 'Hisia')
      ),
      (Icons.menu_book_outlined, Icons.menu_book, context.tr('Learn', 'Jifunze')),
      (
        Icons.emoji_events_outlined,
        Icons.emoji_events,
        context.tr('Rewards', 'Zawadi')
      ),
    ];
    final Widget body =
        badges == null ? shell : BadgeAlerts(watcher: badges!, child: shell);
    final bool wide = isWideScreen(context);

    // Big screens (laptops, the web): a side menu, and the screens kept to a
    // readable width in the middle.
    final Widget scaffold = wide
        ? Scaffold(
            body: SafeArea(
              child: Row(
                children: <Widget>[
                  NavigationRail(
                    key: const Key('side-menu'),
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: _go,
                    extended: MediaQuery.sizeOf(context).width >= 1100,
                    labelType: MediaQuery.sizeOf(context).width >= 1100
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LogoMark(size: 40),
                    ),
                    destinations: <NavigationRailDestination>[
                      for (final (IconData icon, IconData selected, String label)
                          in tabs)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selected),
                          label: Text(label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        if (connection != null)
                          OfflineBanner(status: connection!, onRetry: onRetry),
                        Expanded(child: ReadableWidth(child: body)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : Scaffold(
            body: body,
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (connection != null)
                  OfflineBanner(status: connection!, onRetry: onRetry),
                NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: _go,
                  destinations: <NavigationDestination>[
                    for (final (IconData icon, IconData selected, String label)
                        in tabs)
                      NavigationDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selected),
                          label: label),
                  ],
                ),
              ],
            ),
          );

    // The phone's back button: on another tab it returns to Home; on Home it
    // leaves the app as usual.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          ticker.bump();
          shell.goBranch(0);
        }
      },
      child: scaffold,
    );
  }
}

/// Learn and Rewards are built in step 9.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.text,
    required this.icon,
    this.onBack,
  });

  final String title;
  final String text;
  final IconData icon;

  /// Shows a back arrow (to Home) when given.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null ? null : BackButton(onPressed: onBack),
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: t.colorScheme.primary),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
