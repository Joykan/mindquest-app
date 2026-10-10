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

abstract class ProgressRepository {
  Future<HomeSummary> loadHome();
  Future<MoodSaved> logMood({required int mood, String? note});
  Future<List<Helpline>> loadHelplines();
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
  Future<MoodSaved> logMood({required int mood, String? note}) async {
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
    });

    final Map<String, dynamic> profile =
        await _client.from('profiles').select('streak').eq('id', _uid).single();
    return MoodSaved(
        xpEarned: before.isEmpty ? 10 : 0,
        streak: profile['streak'] as int? ?? 0);
  }

  @override
  Future<List<Helpline>> loadHelplines() async {
    final List<dynamic> rows = await _client
        .from('helplines')
        .select('name, phone, description')
        .order('sort_order');
    return rows
        .map((dynamic r) => Helpline.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
