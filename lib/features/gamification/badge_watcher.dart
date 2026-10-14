import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/tr.dart';
import 'badge_dialog.dart';
import 'badges.dart';

/// Where the user's earned badges come from (the database; a fake in tests).
abstract class BadgeSource {
  Future<List<RewardBadge>> earned();
}

class SupabaseBadgeSource implements BadgeSource {
  SupabaseBadgeSource([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<RewardBadge>> earned() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return const <RewardBadge>[];
    final List<dynamic> rows = await _client
        .from('user_badges')
        .select('badges(id, name, name_sw, description)')
        .eq('user_id', uid);
    return <RewardBadge>[
      for (final dynamic r in rows)
        if ((r as Map<String, dynamic>)['badges'] != null)
          RewardBadge.fromJson(r['badges'] as Map<String, dynamic>),
    ];
  }
}

/// Notices badges earned anywhere in the app (a mood check-in, a chat
/// message, a check-in synced after being offline...), so every badge gets
/// the pop-up and a notification ("Earned Badges & Notifications" in the
/// proposal). The badges already seen are remembered on the phone, per user.
class BadgeWatcher extends ChangeNotifier {
  BadgeWatcher(this._prefs, this._source,
      {required this.userId, this.onUnlocked});

  final SharedPreferences _prefs;
  final BadgeSource _source;
  final String? Function() userId;

  /// Called with newly earned badges (used for the notification).
  void Function(List<RewardBadge> badges)? onUnlocked;

  final List<RewardBadge> _waiting = <RewardBadge>[];
  Future<void>? _running;
  bool _again = false;

  /// New badges not shown yet.
  bool get hasWaiting => _waiting.isNotEmpty;

  /// Hands over the badges to show, once.
  List<RewardBadge> takeWaiting() {
    final List<RewardBadge> out = List<RewardBadge>.of(_waiting);
    _waiting.clear();
    return out;
  }

  String _key(String uid) => 'badges.seen.$uid';

  /// Remembers badges that were already celebrated elsewhere (the article
  /// screen shows its own pop-up).
  Future<void> markSeen(Iterable<String> ids) async {
    final String? uid = userId();
    if (uid == null) return;
    final Set<String> seen = <String>{
      ...?_prefs.getStringList(_key(uid)),
      ...ids,
    };
    await _prefs.setStringList(_key(uid), seen.toList());
  }

  /// Looks for badges earned since the last check. The first check for a
  /// user only remembers what they already have, so old badges don't pop up.
  Future<void> check() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final Future<void> run = _check().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        unawaited(check());
      }
    });
    _running = run;
    return run;
  }

  Future<void> _check() async {
    final String? uid = userId();
    if (uid == null) return;
    List<RewardBadge> earned;
    try {
      earned = await _source.earned();
    } catch (_) {
      return; // Offline: try again next time.
    }
    final List<String>? saved = _prefs.getStringList(_key(uid));
    final Set<String> all = <String>{for (final RewardBadge b in earned) b.id};
    if (saved == null) {
      await _prefs.setStringList(_key(uid), all.toList());
      return;
    }
    final List<RewardBadge> fresh = <RewardBadge>[
      for (final RewardBadge b in earned)
        if (!saved.contains(b.id)) b,
    ];
    if (fresh.isEmpty) return;
    await _prefs.setStringList(_key(uid), <String>{...saved, ...all}.toList());
    _waiting.addAll(fresh);
    onUnlocked?.call(fresh);
    notifyListeners();
  }
}

/// Shows the new-badge pop-up whenever the [watcher] finds one.
class BadgeAlerts extends StatefulWidget {
  const BadgeAlerts({super.key, required this.watcher, required this.child});

  final BadgeWatcher watcher;
  final Widget child;

  @override
  State<BadgeAlerts> createState() => _BadgeAlertsState();
}

class _BadgeAlertsState extends State<BadgeAlerts> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.watcher.addListener(_show);
    // The first check remembers the badges the user already has.
    unawaited(widget.watcher.check());
  }

  @override
  void dispose() {
    widget.watcher.removeListener(_show);
    super.dispose();
  }

  Future<void> _show() async {
    if (_showing || !mounted || !widget.watcher.hasWaiting) return;
    _showing = true;
    try {
      await showNewBadges(
          context, widget.watcher.takeWaiting(), LanguageScope.of(context));
    } finally {
      _showing = false;
    }
    // More may have arrived while the pop-up was open.
    if (mounted && widget.watcher.hasWaiting) unawaited(_show());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
