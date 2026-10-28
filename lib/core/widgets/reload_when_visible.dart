import 'package:flutter/widgets.dart';

/// For the tabs (Home, Learn, Rewards): reload when the app says progress
/// changed, but only while the tab is on screen. A hidden tab (kept alive
/// behind the others) waits and reloads when it is shown again, so a change
/// doesn't send three tabs' worth of requests at once.
mixin ReloadWhenVisible<T extends StatefulWidget> on State<T> {
  /// Fires when the data may have changed.
  Listenable? get reloadSignal;

  /// Loads the tab's data again.
  Future<void> reloadNow();

  bool _stale = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    reloadSignal?.addListener(_onSignal);
  }

  @override
  void dispose() {
    reloadSignal?.removeListener(_onSignal);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden tabs have their tickers turned off.
    final bool visible = TickerMode.of(context);
    if (visible && !_visible && _stale) {
      _stale = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reloadNow();
      });
    }
    _visible = visible;
  }

  void _onSignal() {
    if (!mounted) return;
    if (_visible) {
      reloadNow();
    } else {
      _stale = true;
    }
  }
}
