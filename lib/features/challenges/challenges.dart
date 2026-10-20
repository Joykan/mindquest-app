import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/tr.dart';
import '../../core/offline/offline_store.dart';
import '../home/progress_repository.dart';
import '../learn/learn_repository.dart';

/// One goal in a challenge, e.g. "Do box breathing 3 times".
class ChallengeStep {
  const ChallengeStep(
      {required this.kind, required this.target, this.category, this.done = 0});

  factory ChallengeStep.fromJson(Map<String, dynamic> json) => ChallengeStep(
        kind: json['kind'] as String,
        target: (json['target'] as num?)?.toInt() ?? 1,
        category: json['category'] as String?,
        done: (json['done'] as num?)?.toInt() ?? 0,
      );

  /// checkin, note, chat, breathing, grounding or read (see the database's
  /// challenge_progress).
  final String kind;
  final int target;

  /// For read: the article topic (stress, anxiety, mindfulness, support).
  final String? category;
  final int done;

  bool get complete => done >= target;

  String label(String language) {
    final int n = target;
    String times(String one, String many) => n == 1 ? one : many;
    return switch (kind) {
      'checkin' => tr(language, 'Check in on $n ${times('day', 'days')}',
          'Rekodi hisia siku $n'),
      'note' => tr(
          language,
          'Write one good thing in your check-in note on $n ${times('day', 'days')}',
          'Andika jambo moja zuri kwenye maelezo ya hisia siku $n'),
      'chat' => tr(language, 'Chat with Chipu on $n ${times('day', 'days')}',
          'Ongea na Chipu siku $n'),
      'breathing' => tr(
          language,
          'Do box breathing ${times('once', '$n times')}',
          'Fanya zoezi la kupumua ${times('mara moja', 'mara $n')}'),
      'grounding' => tr(
          language,
          'Do 5-4-3-2-1 grounding ${times('once', '$n times')}',
          'Fanya zoezi la kutuliza akili 5-4-3-2-1 ${times('mara moja', 'mara $n')}'),
      'read' => category == null
          ? tr(language, 'Read $n ${times('article', 'articles')}',
              'Soma makala $n')
          : tr(
              language,
              'Read $n ${times('article', 'articles')} about ${categoryName(category!, 'en').toLowerCase()}',
              'Soma makala $n kuhusu ${categoryName(category!, 'sw').toLowerCase()}'),
      _ => kind,
    };
  }

  /// Where in the app to do it: mood, chat, support or learn.
  String get place => switch (kind) {
        'checkin' || 'note' => 'mood',
        'chat' => 'chat',
        'breathing' || 'grounding' => 'support',
        'read' => 'learn',
        _ => 'home',
      };
}

/// A themed challenge, e.g. "Exam calm".
class Challenge {
  const Challenge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.titleSw,
    required this.description,
    required this.descriptionSw,
    required this.steps,
    this.days = 7,
    this.xp = 40,
    this.badgeId,
    this.completed = 0,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        emoji: json['emoji'] as String? ?? '🎯',
        title: json['title'] as String? ?? '',
        titleSw: json['title_sw'] as String? ?? '',
        description: json['description'] as String? ?? '',
        descriptionSw: json['description_sw'] as String? ?? '',
        days: (json['days'] as num?)?.toInt() ?? 7,
        xp: (json['xp'] as num?)?.toInt() ?? 40,
        badgeId: json['badge_id'] as String?,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        steps: <ChallengeStep>[
          for (final dynamic s in json['steps'] as List<dynamic>? ?? <dynamic>[])
            ChallengeStep.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String id;
  final String emoji;
  final String title;
  final String titleSw;
  final String description;
  final String descriptionSw;
  final int days;
  final int xp;
  final String? badgeId;

  /// How many times this user has finished it.
  final int completed;
  final List<ChallengeStep> steps;

  String name(String language) =>
      language == 'sw' && titleSw.isNotEmpty ? titleSw : title;
  String describe(String language) =>
      language == 'sw' && descriptionSw.isNotEmpty ? descriptionSw : description;
}

/// The challenge the user is doing now.
class ActiveChallenge {
  const ActiveChallenge(
      {required this.runId,
      required this.challenge,
      required this.endsAt,
      required this.steps});

  final String runId;
  final Challenge challenge;
  final DateTime endsAt;

  /// The challenge's steps with how much is done.
  final List<ChallengeStep> steps;

  int get done =>
      steps.fold(0, (int a, ChallengeStep s) => a + s.done.clamp(0, s.target));
  int get target => steps.fold(0, (int a, ChallengeStep s) => a + s.target);
  double get fraction => target == 0 ? 0 : done / target;

  /// Days left, counting today (1 on the last day).
  int daysLeft([DateTime? now]) {
    final int hours = endsAt.difference(now ?? DateTime.now()).inHours;
    return (hours / 24).ceil().clamp(0, challenge.days);
  }
}

/// Everything the app shows about challenges.
class ChallengesState {
  const ChallengesState({
    this.challenges = const <Challenge>[],
    this.active,
    this.recent,
  });

  factory ChallengesState.fromJson(Map<String, dynamic> json) {
    final List<Challenge> list = <Challenge>[
      for (final dynamic c in json['challenges'] as List<dynamic>? ?? <dynamic>[])
        Challenge.fromJson(c as Map<String, dynamic>),
    ];
    Challenge? find(String? id) {
      for (final Challenge c in list) {
        if (c.id == id) return c;
      }
      return null;
    }

    final Map<String, dynamic>? a = json['active'] as Map<String, dynamic>?;
    final Challenge? activeChallenge = find(a?['challenge_id'] as String?);
    final Map<String, dynamic>? r = json['recent'] as Map<String, dynamic>?;
    return ChallengesState(
      challenges: list,
      active: a == null || activeChallenge == null
          ? null
          : ActiveChallenge(
              runId: a['id'] as String,
              challenge: activeChallenge,
              endsAt: DateTime.parse(a['ends_at'] as String),
              steps: <ChallengeStep>[
                for (final dynamic s in a['steps'] as List<dynamic>? ?? <dynamic>[])
                  ChallengeStep.fromJson(s as Map<String, dynamic>),
              ],
            ),
      recent: find(r?['challenge_id'] as String?),
    );
  }

  final List<Challenge> challenges;
  final ActiveChallenge? active;

  /// Finished in the last few days (celebrated on Home).
  final Challenge? recent;

  /// This week's suggestion: a different challenge each week (Nairobi).
  Challenge? featured([DateTime? now]) {
    if (challenges.isEmpty) return null;
    final DateTime day = nairobiDay(now ?? DateTime.now());
    final int week = day.difference(DateTime.utc(2026, 1, 5)).inDays ~/ 7;
    return challenges[week % challenges.length];
  }
}

/// Why starting a challenge failed.
class ChallengeException implements Exception {
  const ChallengeException(this.reason);

  /// offline, busy (another challenge is running) or other.
  final String reason;
}

abstract class ChallengesRepository {
  Future<ChallengesState> load();
  Future<void> start(String challengeId);
  Future<void> leave();

  /// Records a finished breathing or grounding exercise (kept on the phone
  /// and sent later when offline).
  Future<void> logActivity(String kind);
}

class SupabaseChallengesRepository implements ChallengesRepository {
  SupabaseChallengesRepository({SupabaseClient? client, this.offline})
      : _client = client ?? Supabase.instance.client {
    offline?.register('activity', _insertActivity);
  }

  final SupabaseClient _client;

  /// Keeps the last challenges for offline use (null in tests).
  final OfflineStore? offline;

  Future<void> _insertActivity(Map<String, dynamic> data) =>
      _client.from('wellbeing_activities').insert(data);

  @override
  Future<ChallengesState> load() async {
    Future<dynamic> query() => _client.rpc('my_challenges');
    final OfflineStore? store = offline;
    dynamic data;
    if (store == null) {
      data = await query();
    } else {
      await store.flush();
      data = await store.load('challenges', query);
    }
    return ChallengesState.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> _call(String fn, [Map<String, dynamic>? params]) async {
    try {
      await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw ChallengeException(e.code == '23P01' ? 'busy' : 'other');
    } catch (e) {
      throw ChallengeException(isOfflineError(e) ? 'offline' : 'other');
    }
  }

  @override
  Future<void> start(String challengeId) =>
      _call('start_challenge', <String, dynamic>{'p_challenge': challengeId});

  @override
  Future<void> leave() => _call('leave_challenge');

  @override
  Future<void> logActivity(String kind) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final String id = newId();
    final Map<String, dynamic> row = <String, dynamic>{
      'id': id,
      'user_id': uid,
      'kind': kind,
      'done_at': DateTime.now().toUtc().toIso8601String(),
    };
    final OfflineStore? store = offline;
    if (store == null) {
      await _insertActivity(row);
      return;
    }
    await store.addPending(PendingAction(id: id, kind: 'activity', data: row));
    await store.flush();
  }
}
