import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tells screens that progress changed (mood saved, tab switched to Home), so
/// they reload their numbers.
class ProgressTicker extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Bottom navigation from the wireframes: Home, Chat, Mood, Learn, Rewards.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.ticker});

  final StatefulNavigationShell shell;
  final ProgressTicker ticker;

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
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (int i) {
            if (i == 0) ticker.bump();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.sentiment_satisfied_outlined),
              selectedIcon: Icon(Icons.sentiment_satisfied),
              label: 'Mood',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Rewards',
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
