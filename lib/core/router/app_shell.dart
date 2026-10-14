import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/gamification/badge_watcher.dart';
import '../l10n/tr.dart';
import '../offline/offline_store.dart';
import '../widgets/offline_banner.dart';

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

  @override
  Widget build(BuildContext context) {
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
      child: Scaffold(
        body: badges == null
            ? shell
            : BadgeAlerts(watcher: badges!, child: shell),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (connection != null)
              OfflineBanner(status: connection!, onRetry: onRetry),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (int i) {
                if (i == 0) ticker.bump();
                shell.goBranch(i, initialLocation: i == shell.currentIndex);
              },
              destinations: <NavigationDestination>[
                NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: context.tr('Home', 'Nyumbani')),
                NavigationDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  selectedIcon: const Icon(Icons.chat_bubble),
                  label: context.tr('Chat', 'Ongea'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sentiment_satisfied_outlined),
                  selectedIcon: const Icon(Icons.sentiment_satisfied),
                  label: context.tr('Mood', 'Hisia'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book),
                  label: context.tr('Learn', 'Jifunze'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.emoji_events_outlined),
                  selectedIcon: const Icon(Icons.emoji_events),
                  label: context.tr('Rewards', 'Zawadi'),
                ),
              ],
            ),
          ],
        ),
      ),
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
