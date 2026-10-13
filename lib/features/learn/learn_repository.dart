import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_store.dart';
import '../gamification/badges.dart';

/// Article categories (public.resources.category), in display order.
const List<String> articleCategories = <String>[
  'stress',
  'anxiety',
  'mindfulness',
  'support'
];

String categoryName(String category, String language) {
  const Map<String, (String, String)> names = <String, (String, String)>{
    'stress': ('Stress', 'Msongo'),
    'anxiety': ('Anxiety', 'Wasiwasi'),
    'mindfulness': ('Mindfulness', 'Utulivu'),
    'support': ('Getting support', 'Kupata msaada'),
  };
  final (String, String)? n = names[category];
  if (n == null) return category;
  return language == 'sw' ? n.$2 : n.$1;
}

const Map<String, String> categoryEmoji = <String, String>{
  'stress': '🌊',
  'anxiety': '💭',
  'mindfulness': '🧘',
  'support': '🤝',
};

/// A published article, in both languages.
class Article {
  const Article({
    required this.id,
    required this.category,
    required this.titleEn,
    required this.titleSw,
    required this.bodyEn,
    required this.bodySw,
    required this.minutes,
    this.read = false,
  });

  factory Article.fromJson(Map<String, dynamic> json, {bool read = false}) =>
      Article(
        id: json['id'] as int,
        category: json['category'] as String,
        titleEn: json['title_en'] as String,
        titleSw: json['title_sw'] as String,
        bodyEn: json['body_en'] as String,
        bodySw: json['body_sw'] as String,
        minutes: json['read_minutes'] as int? ?? 2,
        read: read,
      );

  final int id;
  final String category;
  final String titleEn;
  final String titleSw;
  final String bodyEn;
  final String bodySw;
  final int minutes;
  final bool read;

  String title(String language) => language == 'sw' ? titleSw : titleEn;
  String body(String language) => language == 'sw' ? bodySw : bodyEn;

  /// Paragraphs are separated by a blank line.
  List<String> paragraphs(String language) => body(language)
      .split(RegExp(r'\n\s*\n'))
      .map((String p) => p.trim())
      .where((String p) => p.isNotEmpty)
      .toList();

  Article markedRead() => Article(
        id: id,
        category: category,
        titleEn: titleEn,
        titleSw: titleSw,
        bodyEn: bodyEn,
        bodySw: bodySw,
        minutes: minutes,
        read: true,
      );
}

/// What reading an article earned.
class ReadResult {
  const ReadResult(
      {required this.xpEarned,
      this.newBadges = const <RewardBadge>[],
      this.pending = false});

  final int xpEarned;
  final List<RewardBadge> newBadges;

  /// Saved on the phone only (no internet); the XP is added once it syncs.
  final bool pending;
}

abstract class LearnRepository {
  /// Published articles, with the user's reads marked.
  Future<List<Article>> loadArticles();

  /// Marks an article read (+5 XP the first time) and returns any badge it earned.
  Future<ReadResult> markRead(int articleId);
}

class SupabaseLearnRepository implements LearnRepository {
  SupabaseLearnRepository({SupabaseClient? client, this.offline})
      : _client = client ?? Supabase.instance.client {
    offline?.register('read', _insertRead);
  }

  final SupabaseClient _client;

  /// Keeps the articles for reading offline (null in tests).
  final OfflineStore? offline;

  String get _uid => _client.auth.currentUser!.id;

  Future<dynamic> _load(String name, Future<dynamic> Function() query) async {
    final OfflineStore? store = offline;
    if (store == null) return query();
    await store.flush();
    return store.load(name, query);
  }

  Future<void> _insertRead(Map<String, dynamic> data) =>
      _client.from('resource_reads').insert(data);

  /// Articles marked read offline, not sent yet.
  Set<int> _pendingReads() => <int>{
        for (final PendingAction a
            in offline?.pending('read') ?? const <PendingAction>[])
          a.data['resource_id'] as int,
      };

  Future<Set<int>> _readIds() async => <int>{
        for (final dynamic r in await _load(
            'reads',
            () => _client
                .from('resource_reads')
                .select('resource_id')
                .eq('user_id', _uid)) as List<dynamic>)
          (r as Map<String, dynamic>)['resource_id'] as int,
        ..._pendingReads(),
      };

  @override
  Future<List<Article>> loadArticles() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _load(
          'articles',
          () => _client
              .from('resources')
              .select(
                  'id, category, title_en, title_sw, body_en, body_sw, read_minutes')
              .eq('published', true)
              .order('id', ascending: true)),
      _readIds(),
    ]);
    final Set<int> read = results[1] as Set<int>;
    return <Article>[
      for (final dynamic a in results[0] as List<dynamic>)
        Article.fromJson(a as Map<String, dynamic>,
            read: read.contains(a['id'])),
    ];
  }

  Future<Set<String>> _earnedBadgeIds() async {
    final List<dynamic> rows = await _client
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', _uid);
    return <String>{
      for (final dynamic r in rows)
        (r as Map<String, dynamic>)['badge_id'] as String
    };
  }

  @override
  Future<ReadResult> markRead(int articleId) async {
    if ((await _readIds()).contains(articleId)) {
      return const ReadResult(xpEarned: 0);
    }
    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': _uid,
      'resource_id': articleId,
    };

    Set<String>? before;
    try {
      before = await _earnedBadgeIds();
    } catch (e) {
      if (offline == null || !isOfflineError(e)) rethrow;
    }

    final OfflineStore? store = offline;
    if (store == null) {
      // The database trigger awards the XP and any badge.
      await _insertRead(row);
    } else {
      final String id = newId();
      await store.addPending(PendingAction(id: id, kind: 'read', data: row));
      await store.flush();
      if (store.isPending(id)) {
        return const ReadResult(xpEarned: 5, pending: true);
      }
    }
    if (before == null) return const ReadResult(xpEarned: 5);

    try {
      final Set<String> fresh = (await _earnedBadgeIds()).difference(before);
      if (fresh.isEmpty) return const ReadResult(xpEarned: 5);
      final List<dynamic> badges = await _client
          .from('badges')
          .select('id, name, name_sw, description')
          .inFilter('id', fresh.toList());
      return ReadResult(
        xpEarned: 5,
        newBadges: <RewardBadge>[
          for (final dynamic b in badges)
            RewardBadge.fromJson(b as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      // The read is saved; the badge pop-up is a bonus.
      return const ReadResult(xpEarned: 5);
    }
  }
}
