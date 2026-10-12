import 'package:supabase_flutter/supabase_flutter.dart';

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
  const MoodSaved({required this.xpEarned, required this.streak});

  /// 10 for the first check-in of the day, 0 after that.
  final int xpEarned;
  final int streak;
}

/// One past mood check-in.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.mood,
    required this.at,
    this.note,
    this.tags = const <String>[],
  });

  final String id;
  final int mood;

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

/// Start of this Monday-to-Sunday week in Nairobi, as a UTC instant.
DateTime startOfWeekUtc([DateTime? now]) {
  final DateTime n = nairobiNow(now);
  final DateTime monday = DateTime.utc(n.year, n.month, n.day)
      .subtract(Duration(days: n.weekday - 1));
  return monday.subtract(const Duration(hours: 3));
}

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<HomeSummary> loadHome() async {
    final String today = startOfTodayUtc().toIso8601String();
    final String week = startOfWeekUtc().toIso8601String();

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('profiles')
          .select('username, xp, streak')
          .eq('id', _uid)
          .single(),
      _client
          .from('xp_events')
          .select('reason')
          .eq('user_id', _uid)
          .gte('created_at', today),
      _client
          .from('mood_logs')
          .select('mood, created_at')
          .eq('user_id', _uid)
          .gte('created_at', week)
          .order('created_at', ascending: false),
    ]);

    final Map<String, dynamic> profile = results[0] as Map<String, dynamic>;
    final List<dynamic> events = results[1] as List<dynamic>;
    final List<dynamic> moods = results[2] as List<dynamic>;

    final DateTime todayStart = startOfTodayUtc();
    int? todayMood;
    final Set<String> days = <String>{};
    for (final dynamic m in moods) {
      final DateTime at = DateTime.parse(m['created_at'] as String).toUtc();
      final DateTime local = at.add(const Duration(hours: 3));
      days.add('${local.year}-${local.month}-${local.day}');
      if (todayMood == null && !at.isBefore(todayStart))
        todayMood = m['mood'] as int;
    }

    return HomeSummary(
      username: profile['username'] as String? ?? 'Friend',
      xp: profile['xp'] as int? ?? 0,
      streak: profile['streak'] as int? ?? 0,
      todayMood: todayMood,
      doneToday: events.map((dynamic e) => e['reason'] as String).toSet(),
      weekCheckinDays: days.length,
    );
  }

  @override
  Future<MoodSaved> logMood(
      {required int mood,
      String? note,
      List<String> tags = const <String>[]}) async {
    final String today = startOfTodayUtc().toIso8601String();
    final List<dynamic> before = await _client
        .from('xp_events')
        .select('id')
        .eq('user_id', _uid)
        .eq('reason', 'mood_checkin')
        .gte('created_at', today);

    await _client.from('mood_logs').insert(<String, dynamic>{
      'user_id': _uid,
      'mood': mood,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (tags.isNotEmpty) 'tags': tags,
    });

    final Map<String, dynamic> profile =
        await _client.from('profiles').select('streak').eq('id', _uid).single();
    return MoodSaved(
        xpEarned: before.isEmpty ? 10 : 0,
        streak: profile['streak'] as int? ?? 0);
  }

  @override
  Future<List<MoodEntry>> loadMoodHistory({int days = 30}) async {
    final String since =
        startOfTodayUtc().subtract(Duration(days: days - 1)).toIso8601String();
    final List<dynamic> rows = await _client
        .from('mood_logs')
        .select('id, mood, note, tags, created_at')
        .eq('user_id', _uid)
        .gte('created_at', since)
        .order('created_at', ascending: false);
    return rows.map((dynamic r) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      return MoodEntry(
        id: m['id'] as String,
        mood: m['mood'] as int,
        note: m['note'] as String?,
        tags: <String>[
          for (final dynamic t in m['tags'] as List<dynamic>? ?? <dynamic>[])
            t as String
        ],
        at: nairobiNow(DateTime.parse(m['created_at'] as String)),
      );
    }).toList();
  }

  @override
  Future<void> deleteMood(String id) async {
    await _client.from('mood_logs').delete().eq('id', id).eq('user_id', _uid);
  }

  @override
  Future<Map<String, int>> loadChatFeelings({int days = 7}) async {
    final String since =
        startOfTodayUtc().subtract(Duration(days: days - 1)).toIso8601String();
    // Row-level security returns only this user's messages.
    final List<dynamic> rows = await _client
        .from('messages')
        .select('intent')
        .eq('sender', 'user')
        .inFilter('intent', <String>[
      'feel_stressed',
      'feel_anxious',
      'feel_sad',
      'feel_good'
    ]).gte('created_at', since);
    final Map<String, int> counts = <String, int>{};
    for (final dynamic r in rows) {
      final String intent = (r as Map<String, dynamic>)['intent'] as String;
      counts[intent] = (counts[intent] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<Helpline>> loadHelplines() async {
    final List<dynamic> rows = await _client
        .from('helplines')
        .select('name, phone, description')
        .order('sort_order', ascending: true);
    return rows
        .map((dynamic r) => Helpline.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
