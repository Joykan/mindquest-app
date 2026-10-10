import 'dart:async';

import 'package:flutter/foundation.dart';

import 'account_repository.dart';

/// Where the user is in the sign-in journey. The router listens to this and
/// sends them to Welcome, Onboarding or the app.
class SessionController extends ChangeNotifier {
  SessionController(this.account) {
    _sub = account.changes.listen((_) => refresh());
  }

  final AccountRepository account;
  late final StreamSubscription<void> _sub;

  Profile? _profile;
  bool _failed = false;

  /// Language picked on the Welcome screen before an account exists.
  String language = 'en';

  bool get signedIn => account.userId != null;
  bool get loading => signedIn && _profile == null;

  /// The profile couldn't be loaded (usually no internet). The loading
  /// screen shows a retry button.
  bool get failed => _failed;
  bool get onboarded => _profile?.onboarded ?? false;
  Profile? get profile => _profile;

  /// Loads the profile of whoever is signed in (or clears it).
  Future<void> refresh() async {
    if (!signedIn) {
      _profile = null;
      notifyListeners();
      return;
    }
    _failed = false;
    notifyListeners();
    try {
      _profile = await account.loadProfile();
      if (_profile != null) language = _profile!.language;
      _failed = _profile == null;
    } catch (_) {
      _profile = null;
      _failed = true;
    }
    notifyListeners();
  }

  void setLanguage(String code) {
    language = code;
    notifyListeners();
  }

  Future<void> completeOnboarding({required String username, required String language}) async {
    await account.completeOnboarding(username: username, language: language);
    await refresh();
  }

  Future<void> signOut() async {
    await account.signOut();
    await refresh();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
