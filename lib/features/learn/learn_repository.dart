import 'package:supabase_flutter/supabase_flutter.dart';

import '../gamification/badges.dart';

/// Article categories (public.resources.category), in display order.
const List<String> articleCategories = <String>['stress', 'anxiety', 'mindfulness', 'support'];

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

  factory Article.fromJson(Map<String, dynamic> json, {bool read = false}) => Article(
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
  const ReadResult({required this.xpEarned, this.newBadges = const <RewardBadge>[]});

  final int xpEarned;
  final List<RewardBadge> newBadges;
}

abstract class LearnRepository {
  /// Published articles, with the user's reads marked.
  Future<List<Article>> loadArticles();

  /// Marks an article read (+5 XP the first time) and returns any badge it earned.
  Future<ReadResult> markRead(int articleId);
}

class SupabaseLearnRepository implements LearnRepository {
  SupabaseLearnRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<Article>> loadArticles() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('resources')
          .select('id, category, title_en, title_sw, body_en, body_sw, read_minutes')
          .eq('published', true)
          .order('id'),
      _client.from('resource_reads').select('resource_id').eq('user_id', _uid),
    ]);
    final Set<int> read = <int>{
      for (final dynamic r in results[1] as List<dynamic>) (r as Map<String, dynamic>)['resource_id'] as int,
    };
    return <Article>[
      for (final dynamic a in results[0] as List<dynamic>)
        Article.fromJson(a as Map<String, dynamic>, read: read.contains(a['id'])),
    ];
  }

  Future<Set<String>> _earnedBadgeIds() async {
    final List<dynamic> rows = await _client.from('user_badges').select('badge_id').eq('user_id', _uid);
    return <String>{for (final dynamic r in rows) (r as Map<String, dynamic>)['badge_id'] as String};
  }

  @override
  Future<ReadResult> markRead(int articleId) async {
    final List<dynamic> already = await _client
        .from('resource_reads')
        .select('resource_id')
        .eq('user_id', _uid)
        .eq('resource_id', articleId);
    if (already.isNotEmpty) return const ReadResult(xpEarned: 0);

    final Set<String> before = await _earnedBadgeIds();
    // The database trigger awards the XP and any badge.
    await _client.from('resource_reads').insert(<String, dynamic>{
      'user_id': _uid,
      'resource_id': articleId,
    });
    final Set<String> fresh = (await _earnedBadgeIds()).difference(before);
    if (fresh.isEmpty) return const ReadResult(xpEarned: 5);
    final List<dynamic> badges =
        await _client.from('badges').select('id, name, name_sw, description').inFilter('id', fresh.toList());
    return ReadResult(
      xpEarned: 5,
      newBadges: <RewardBadge>[
        for (final dynamic b in badges) RewardBadge.fromJson(b as Map<String, dynamic>),
      ],
    );
  }
}
