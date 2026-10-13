import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/tr.dart';
import '../../core/offline/offline_store.dart';
import '../gamification/badges.dart';
import '../home/progress_repository.dart';

/// One badge and how close the user is to it.
class BadgeStatus {
  const BadgeStatus(
      {required this.badge,
      this.earnedAt,
      required this.progress,
      required this.goal});

  final RewardBadge badge;
  final DateTime? earnedAt;
  final int progress;
  final int goal;

  bool get earned => earnedAt != null;

  /// 0..1 for the progress bar (1 once earned).
  double get fraction =>
      earned ? 1 : (goal == 0 ? 0 : (progress / goal).clamp(0, 1).toDouble());
}

/// One line of XP history.
class XpEvent {
  const XpEvent({required this.reason, required this.amount, required this.at});

  final String reason;
  final int amount;
  final DateTime at;

  String get label => labelIn('en');

  String labelIn(String language) => switch (reason) {
        'mood_checkin' => tr(language, 'Mood check-in', 'Kurekodi hisia'),
        'chat_message' => tr(language, 'Chat message', 'Ujumbe kwa Chipu'),
        'article_read' => tr(language, 'Article read', 'Makala imesomwa'),
        'weekly_quest' => tr(language, 'Weekly quest complete',
            'Changamoto ya wiki imekamilika'),
        _ => reason,
      };
}

/// Everything on the Rewards screen.
class RewardsSummary {
  const RewardsSummary({
    required this.xp,
    required this.streak,
    required this.badges,
    required this.weekCheckinDays,
    required this.weeklyQuestDone,
    required this.questsCompleted,
    this.recent = const <XpEvent>[],
  });

  final int xp;
  final int streak;
  final List<BadgeStatus> badges;
  final int weekCheckinDays;
  final bool weeklyQuestDone;
  final int questsCompleted;
  final List<XpEvent> recent;

  int get badgesEarned => badges.where((BadgeStatus b) => b.earned).length;
}

/// Counts used for badge progress.
class BadgeCounts {
  const BadgeCounts({
    this.checkIns = 0,
    this.chatMessages = 0,
    this.articlesRead = 0,
    this.streak = 0,
    this.weeklyQuests = 0,
  });

  final int checkIns;
  final int chatMessages;
  final int articlesRead;
  final int streak;
  final int weeklyQuests;

  int of(BadgeMeasure m) => switch (m) {
        BadgeMeasure.checkIns => checkIns,
        BadgeMeasure.chatMessages => chatMessages,
        BadgeMeasure.articlesRead => articlesRead,
        BadgeMeasure.streak => streak,
        BadgeMeasure.weeklyQuests => weeklyQuests,
      };
}

/// Combines badges, earned dates and counts into [BadgeStatus]es.
List<BadgeStatus> badgeStatuses(
  List<RewardBadge> badges,
  Map<String, DateTime> earned,
  BadgeCounts counts,
) =>
    <BadgeStatus>[
      for (final RewardBadge b in badges)
        BadgeStatus(
          badge: b,
          earnedAt: earned[b.id],
          progress:
              badgeGoals[b.id] == null ? 0 : counts.of(badgeGoals[b.id]!.$1),
          goal: badgeGoals[b.id]?.$2 ?? 1,
        ),
    ];

abstract class RewardsRepository {
  Future<RewardsSummary> loadRewards();
}

class SupabaseRewardsRepository implements RewardsRepository {
  SupabaseRewardsRepository({SupabaseClient? client, this.offline})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Shows the last saved rewards when offline (null in tests).
  final OfflineStore? offline;

  String get _uid => _client.auth.currentUser!.id;

  Future<dynamic> _load(String name, Future<dynamic> Function() query) async {
    final OfflineStore? store = offline;
    if (store == null) return query();
    await store.flush();
    return store.load(name, query);
  }

  /// Number of rows (a HEAD request, so no rows are downloaded).
  Future<int> _count(String table,
      {bool own = true, Map<String, Object> where = const <String, Object>{}}) {
    PostgrestFilterBuilder<int> q = _client.from(table).count();
    if (own) q = q.eq('user_id', _uid);
    for (final MapEntry<String, Object> w in where.entries) {
      q = q.eq(w.key, w.value);
    }
    return q;
  }

  @override
  Future<RewardsSummary> loadRewards() async {
    final DateTime n = nairobiNow();
    final DateTime monday = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
    final String mondayDate =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final DateTime weekStart = startOfWeekUtc();

    final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
      _load(
          'profile.progress',
          () => _client
              .from('profiles')
              .select('username, xp, streak, last_checkin')
              .eq('id', _uid)
              .single()),
      _load(
          'badges',
          () => _client
              .from('badges')
              .select('id, name, name_sw, description')
              .order('sort_order', ascending: true)),
      _load(
          'badges.earned',
          () => _client
              .from('user_badges')
              .select('badge_id, earned_at')
              .eq('user_id', _uid)),
      _load('count.moods', () => _count('mood_logs')),
      // Row-level security limits messages to this user's own chats.
      _load(
          'count.messages',
          () => _count('messages',
              own: false, where: <String, Object>{'sender': 'user'})),
      _load('count.reads', () => _count('resource_reads')),
      _load(
          'quests',
          () => _client
              .from('quest_completions')
              .select('week_start')
              .eq('user_id', _uid)),
      _load(
          'moods.week',
          () => _client
              .from('mood_logs')
              .select('id, mood, logged_at')
              .eq('user_id', _uid)
              .gte('logged_at', weekStart.toIso8601String())
              .order('logged_at', ascending: false)),
      _load(
          'xp.recent',
          () => _client
              .from('xp_events')
              .select('reason, amount, created_at')
              .eq('user_id', _uid)
              .order('created_at', ascending: false)
              .limit(8)),
    ]);

    final Map<String, dynamic> profile = Map<String, dynamic>.from(r[0] as Map);
    final List<RewardBadge> badges = <RewardBadge>[
      for (final dynamic b in r[1] as List<dynamic>)
        RewardBadge.fromJson(b as Map<String, dynamic>),
    ];
    final Map<String, DateTime> earned = <String, DateTime>{
      for (final dynamic u in r[2] as List<dynamic>)
        (u as Map<String, dynamic>)['badge_id'] as String:
            nairobiNow(DateTime.parse(u['earned_at'] as String)),
    };
    final List<dynamic> quests = r[6] as List<dynamic>;

    // Check-ins made offline count on this screen straight away.
    final List<String> pendingTimes = <String>[
      for (final PendingAction a
          in offline?.pending('mood') ?? const <PendingAction>[])
        a.data['logged_at'] as String,
    ];
    final Set<DateTime> pendingDays = <DateTime>{
      for (final String t in pendingTimes) nairobiDay(DateTime.parse(t)),
    };
    final Set<DateTime> days = <DateTime>{
      for (final dynamic m in r[7] as List<dynamic>)
        nairobiDay(
            DateTime.parse((m as Map<String, dynamic>)['logged_at'] as String)),
      ...pendingDays,
    }.where((DateTime d) => !d.isBefore(nairobiDay(weekStart))).toSet();

    final int streak = currentStreak(
      streak: profile['streak'] as int? ?? 0,
      lastCheckin: parseDay(profile['last_checkin'] as String?),
      pendingDays: pendingDays,
    );
    final BadgeCounts counts = BadgeCounts(
      checkIns: (r[3] as int) + pendingTimes.length,
      chatMessages: r[4] as int,
      articlesRead: (r[5] as int) +
          (offline?.pending('read') ?? const <PendingAction>[]).length,
      streak: streak,
      weeklyQuests: quests.length,
    );

    return RewardsSummary(
      xp: profile['xp'] as int? ?? 0,
      streak: streak,
      badges: badgeStatuses(badges, earned, counts),
      weekCheckinDays: days.length,
      weeklyQuestDone: quests.any((dynamic q) =>
          (q as Map<String, dynamic>)['week_start'] == mondayDate),
      questsCompleted: quests.length,
      recent: <XpEvent>[
        for (final dynamic e in r[8] as List<dynamic>)
          XpEvent(
            reason: (e as Map<String, dynamic>)['reason'] as String,
            amount: e['amount'] as int,
            at: nairobiNow(DateTime.parse(e['created_at'] as String)),
          ),
      ],
    );
  }
}
