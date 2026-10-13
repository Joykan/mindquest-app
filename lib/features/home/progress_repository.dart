import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_store.dart';
import '../chat/chat_models.dart';

/// Everything the Home screen shows, for the signed-in user.
class HomeSummary {
  const HomeSummary({
    required this.username,
    required this.xp,
    required this.streak,
    this.todayMood,
    this.doneToday = const <String>{},
    this.weekCheckinDays = 0,
  });

  final String username;
  final int xp;
  final int streak;

  /// Mood logged today (1-5), if any.
  final int? todayMood;

  /// XP reasons earned today: mood_checkin, chat_message, article_read.
  final Set<String> doneToday;

  /// Days with a mood check-in this week (Mon-Sun). 5 completes the weekly quest.
  final int weekCheckinDays;
}

/// Result of saving a mood check-in.
class MoodSaved {
  const MoodSaved(
      {required this.xpEarned, required this.streak, this.pending = false});

  /// 10 for the first check-in of the day, 0 after that.
  final int xpEarned;
  final int streak;

  /// Saved on the phone only (no internet). It is sent, and the XP added,
  /// when the phone is back online.
  final bool pending;
}

/// One past mood check-in.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.mood,
    required this.at,
    this.note,
    this.tags = const <String>[],
    this.pending = false,
  });

  final String id;
  final int mood;

  /// Made offline and not sent to the server yet.
  final bool pending;

  /// When it was logged, in Nairobi time.
  final DateTime at;
  final String? note;

  /// What it was about, e.g. school, sleep (see mood_tags.dart).
  final List<String> tags;
}

abstract class ProgressRepository {
  Future<HomeSummary> loadHome();
  Future<MoodSaved> logMood(
      {required int mood, String? note, List<String> tags = const <String>[]});
  Future<List<Helpline>> loadHelplines();

  /// Check-ins from the last [days] days, newest first.
  Future<List<MoodEntry>> loadMoodHistory({int days = 30});

  /// Deletes one check-in. XP already earned is kept.
  Future<void> deleteMood(String id);

  /// How often each feeling (feel_stressed, feel_anxious, feel_sad,
  /// feel_good) was detected in the user's chat messages in the last [days]
  /// days. Only the intent labels are read, never the message text.
  Future<Map<String, int>> loadChatFeelings({int days = 7});
}

/// Kenya has no daylight saving, so Nairobi time is always UTC+3. The database
/// uses the same day boundary (public.local_date).
DateTime nairobiNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));

/// Start of today in Nairobi, as a UTC instant.
DateTime startOfTodayUtc([DateTime? now]) {
  final DateTime n = nairobiNow(now);
  return DateTime.utc(n.year, n.month, n.day)
      .subtract(const Duration(hours: 3));
}

/// The Nairobi calendar day of [at] (any time zone), as a UTC midnight.
DateTime nairobiDay(DateTime at) {
  final DateTime n = nairobiNow(at);
  return DateTime.utc(n.year, n.month, n.day);
}

/// A "2026-10-13" date from the database, as a UTC midnight.
DateTime? parseDay(String? date) {
  if (date == null) return null;
  final DateTime d = DateTime.parse(date);
  return DateTime.utc(d.year, d.month, d.day);
}

/// The streak to show today.
///
/// The database keeps [streak], the days in a row ending on [lastCheckin].
/// Check-ins still waiting to sync ([pendingDays]) are added. A streak whose
/// last day is before yesterday is over, so it shows as 0.
int currentStreak({
  required int streak,
  DateTime? lastCheckin,
  Set<DateTime> pendingDays = const <DateTime>{},
  DateTime? now,
}) {
  final Set<DateTime> days = <DateTime>{
    for (final DateTime d in pendingDays) DateTime.utc(d.year, d.month, d.day),
    if (lastCheckin != null)
      for (int i = 0; i < streak; i++)
        DateTime.utc(lastCheckin.year, lastCheckin.month, lastCheckin.day - i),
  };
  final DateTime today = nairobiDay(now ?? DateTime.now());
  DateTime d = days.contains(today)
      ? today
      : DateTime.utc(today.year, today.month, today.day - 1);
  int n = 0;
  while (days.contains(d)) {
    n++;
    d = DateTime.utc(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Start of this Monday-to-Sunday week in Nairobi, as a UTC instant.
DateTime startOfWeekUtc([DateTime? now]) {
  final DateTime n = nairobiNow(now);
  final DateTime monday = DateTime.utc(n.year, n.month, n.day)
      .subtract(Duration(days: n.weekday - 1));
  return monday.subtract(const Duration(hours: 3));
}

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(
      {SupabaseClient? client, this.offline, this.onMoodLogged})
      : _client = client ?? Supabase.instance.client {
    offline?.register('mood', _insertMood);
  }

  final SupabaseClient _client;

  /// Saves what was loaded and keeps check-ins made offline (null in tests).
  final OfflineStore? offline;

  /// Called after every check-in (the daily reminder skips today then).
  final void Function()? onMoodLogged;

  String get _uid => _client.auth.currentUser!.id;

  /// Asks the server, or uses the saved copy when offline.
  Future<dynamic> _load(String name, Future<dynamic> Function() query) async {
    final OfflineStore? store = offline;
    if (store == null) return query();
    await store.flush();
    return store.load(name, query);
  }

  Future<void> _insertMood(Map<String, dynamic> data) async {
    try {
      await _client.from('mood_logs').insert(data);
    } on PostgrestException catch (e) {
      // 23514: the time is outside what the database accepts. If the phone
      // says the check-in is recent, the phone's clock is probably wrong, so
      // the server's time is used instead. Older ones (7 days) are dropped.
      final DateTime? at = DateTime.tryParse(data['logged_at'] as String? ?? '');
      final bool recent = at != null &&
          DateTime.now().toUtc().difference(at) < const Duration(days: 6);
      if (e.code != '23514' || !recent) rethrow;
      await _client
          .from('mood_logs')
          .insert(<String, dynamic>{...data}..remove('logged_at'));
    }
  }

  /// Check-ins made offline that haven't reached the server yet.
  List<MoodEntry> _pendingMoods() => <MoodEntry>[
        for (final PendingAction a
            in offline?.pending('mood') ?? const <PendingAction>[])
          _entry(a.data, pending: true),
      ];

  static MoodEntry _entry(Map<String, dynamic> m, {bool pending = false}) =>
      MoodEntry(
        id: m['id'] as String,
        mood: m['mood'] as int,
        note: m['note'] as String?,
        tags: <String>[
          for (final dynamic t in m['tags'] as List<dynamic>? ?? <dynamic>[])
            t as String
        ],
        at: nairobiNow(DateTime.parse(m['logged_at'] as String)),
        pending: pending,
      );

  Future<Map<String, dynamic>> _profile() async =>
      Map<String, dynamic>.from(await _load(
          'profile.progress',
          () => _client
              .from('profiles')
              .select('username, xp, streak, last_checkin')
              .eq('id', _uid)
              .single()) as Map);

  int _streakFrom(Map<String, dynamic> profile, List<MoodEntry> pending) =>
      currentStreak(
        streak: profile['streak'] as int? ?? 0,
        lastCheckin: parseDay(profile['last_checkin'] as String?),
        pendingDays: <DateTime>{
          for (final MoodEntry e in pending) DateTime.utc(e.at.year, e.at.month, e.at.day)
        },
      );

  /// XP reasons earned since the start of today (Nairobi).
  Future<Set<String>> _doneToday() async {
    final DateTime today = startOfTodayUtc();
    final List<dynamic> events = await _load(
        'xp.today',
        () => _client
            .from('xp_events')
            .select('reason, created_at')
            .eq('user_id', _uid)
            .gte('created_at', today.toIso8601String())) as List<dynamic>;
    return <String>{
      for (final dynamic e in events)
        // A saved copy from yesterday must not count for today.
        if (!DateTime.parse((e as Map<String, dynamic>)['created_at'] as String)
            .isBefore(today))
          e['reason'] as String,
    };
  }

  @override
  Future<HomeSummary> loadHome() async {
    final DateTime week = startOfWeekUtc();
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _profile(),
      _doneToday(),
      _load(
          'moods.week',
          () => _client
              .from('mood_logs')
              .select('id, mood, logged_at')
              .eq('user_id', _uid)
              .gte('logged_at', week.toIso8601String())
              .order('logged_at', ascending: false)),
    ]);

    final Map<String, dynamic> profile = results[0] as Map<String, dynamic>;
    final Set<String> done = results[1] as Set<String>;
    final List<MoodEntry> pending = _pendingMoods();
    final Set<String> waiting = <String>{for (final MoodEntry e in pending) e.id};
    final List<MoodEntry> moods = <MoodEntry>[
      ...pending,
      for (final dynamic m in results[2] as List<dynamic>)
        if (!waiting.contains((m as Map<String, dynamic>)['id'])) _entry(m),
    ]
        .where((MoodEntry e) => !e.at.isBefore(nairobiNow(week)))
        .toList()
      ..sort((MoodEntry a, MoodEntry b) => b.at.compareTo(a.at));

    final DateTime today = nairobiNow(startOfTodayUtc());
    int? todayMood;
    final Set<String> days = <String>{};
    for (final MoodEntry m in moods) {
      days.add('${m.at.year}-${m.at.month}-${m.at.day}');
      if (todayMood == null && !m.at.isBefore(today)) todayMood = m.mood;
    }
    if (pending.any((MoodEntry e) => !e.at.isBefore(today))) {
      done.add('mood_checkin');
    }

    return HomeSummary(
      username: profile['username'] as String? ?? 'Friend',
      xp: profile['xp'] as int? ?? 0,
      streak: _streakFrom(profile, pending),
      todayMood: todayMood,
      doneToday: done,
      weekCheckinDays: days.length,
    );
  }

  @override
  Future<MoodSaved> logMood(
      {required int mood,
      String? note,
      List<String> tags = const <String>[]}) async {
    // Was there a check-in today already? (Only the first earns XP.)
    bool first;
    try {
      first = !(await _doneToday()).contains('mood_checkin');
    } catch (_) {
      first = true;
    }
    final DateTime today = nairobiNow(startOfTodayUtc());
    if (_pendingMoods().any((MoodEntry e) => !e.at.isBefore(today))) {
      first = false;
    }

    final String id = newId();
    final Map<String, dynamic> row = <String, dynamic>{
      'id': id,
      'user_id': _uid,
      'mood': mood,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (tags.isNotEmpty) 'tags': tags,
    };

    final OfflineStore? store = offline;
    if (store == null) {
      await _insertMood(row);
    } else {
      // Saved on the phone first, then sent. Without internet it stays
      // there and is sent later.
      await store.addPending(PendingAction(id: id, kind: 'mood', data: row));
      await store.flush();
    }
    onMoodLogged?.call();

    final bool waiting = store?.isPending(id) ?? false;
    int streak;
    try {
      streak = _streakFrom(await _profile(), _pendingMoods());
    } catch (_) {
      streak = 1;
    }
    return MoodSaved(
        xpEarned: first ? 10 : 0, streak: streak, pending: waiting);
  }

  @override
  Future<List<MoodEntry>> loadMoodHistory({int days = 30}) async {
    final DateTime since = startOfTodayUtc().subtract(Duration(days: days - 1));
    final List<dynamic> rows = await _load(
        'moods.$days',
        () => _client
            .from('mood_logs')
            .select('id, mood, note, tags, logged_at')
            .eq('user_id', _uid)
            .gte('logged_at', since.toIso8601String())
            .order('logged_at', ascending: false)) as List<dynamic>;
    final List<MoodEntry> pending = _pendingMoods();
    final Set<String> waiting = <String>{for (final MoodEntry e in pending) e.id};
    return <MoodEntry>[
      ...pending,
      for (final dynamic r in rows)
        if (!waiting.contains((r as Map<String, dynamic>)['id']))
          _entry(r),
    ].where((MoodEntry e) => !e.at.isBefore(nairobiNow(since))).toList()
      ..sort((MoodEntry a, MoodEntry b) => b.at.compareTo(a.at));
  }

  @override
  Future<void> deleteMood(String id) async {
    final OfflineStore? store = offline;
    if (store != null && store.isPending(id)) {
      // Never reached the server: just forget it.
      await store.removePending(id);
      return;
    }
    await _client.from('mood_logs').delete().eq('id', id).eq('user_id', _uid);
  }

  @override
  Future<Map<String, int>> loadChatFeelings({int days = 7}) async {
    final DateTime since = startOfTodayUtc().subtract(Duration(days: days - 1));
    // Row-level security returns only this user's messages.
    final List<dynamic> rows = await _load(
        'feelings.$days',
        () => _client
            .from('messages')
            .select('intent, created_at')
            .eq('sender', 'user')
            .inFilter('intent', <String>[
          'feel_stressed',
          'feel_anxious',
          'feel_sad',
          'feel_good'
        ]).gte('created_at', since.toIso8601String())) as List<dynamic>;
    final Map<String, int> counts = <String, int>{};
    for (final dynamic r in rows) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      if (DateTime.parse(m['created_at'] as String).isBefore(since)) continue;
      final String intent = m['intent'] as String;
      counts[intent] = (counts[intent] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<Helpline>> loadHelplines() async {
    final List<dynamic> rows = await _load(
        'helplines',
        () => _client
            .from('helplines')
            .select('name, phone, description, description_sw')
            .order('sort_order', ascending: true)) as List<dynamic>;
    return rows
        .map((dynamic r) => Helpline.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
