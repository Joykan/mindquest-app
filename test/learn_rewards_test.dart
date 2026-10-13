import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/l10n/tr.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/gamification/badges.dart';
import 'package:mindquest/features/learn/article_screen.dart';
import 'package:mindquest/features/learn/learn_repository.dart';
import 'package:mindquest/features/learn/learn_screen.dart';
import 'package:mindquest/features/learn/recommend.dart';
import 'package:mindquest/features/home/home_screen.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_insights.dart';

import 'fakes.dart';
import 'package:mindquest/features/rewards/rewards_repository.dart';
import 'package:mindquest/features/rewards/rewards_screen.dart';

const RewardBadge curious = RewardBadge(
  id: 'curious_mind',
  name: 'Curious Mind',
  nameSw: 'Akili Dadisi',
  description: 'Read 3 articles',
);
const RewardBadge firstChat = RewardBadge(
  id: 'first_chat',
  name: 'First Chat',
  nameSw: 'Mazungumzo ya Kwanza',
  description: 'Send your first message',
);

Article article(int id, String category, {bool read = false}) => Article(
      id: id,
      category: category,
      titleEn: 'Article $id',
      titleSw: 'Makala $id',
      bodyEn: 'First paragraph of $id.\n\nSecond paragraph of $id.',
      bodySw: 'Aya ya kwanza ya $id.\n\nAya ya pili ya $id.',
      minutes: 2,
      read: read,
    );

class FakeLearn implements LearnRepository {
  FakeLearn(this.articles, {this.badgesOnRead = const <RewardBadge>[]});

  List<Article> articles;
  final List<RewardBadge> badgesOnRead;
  final List<int> marked = <int>[];

  @override
  Future<List<Article>> loadArticles() async => articles;

  @override
  Future<ReadResult> markRead(int articleId) async {
    marked.add(articleId);
    return ReadResult(xpEarned: 5, newBadges: badgesOnRead);
  }
}

class FakeRewards implements RewardsRepository {
  FakeRewards(this.summary);

  final RewardsSummary summary;

  @override
  Future<RewardsSummary> loadRewards() async => summary;
}

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('article paragraphs are split on blank lines', () {
    expect(article(1, 'stress').paragraphs('en'),
        <String>['First paragraph of 1.', 'Second paragraph of 1.']);
    expect(article(1, 'stress').title('sw'), 'Makala 1');
  });

  test('badge progress follows the database rules', () {
    final List<BadgeStatus> s = badgeStatuses(
      <RewardBadge>[curious, firstChat],
      <String, DateTime>{'first_chat': DateTime(2026, 10, 9)},
      const BadgeCounts(articlesRead: 2, chatMessages: 5),
    );
    expect(s[0].earned, isFalse);
    expect(s[0].progress, 2);
    expect(s[0].goal, 3);
    expect(s[0].fraction, closeTo(2 / 3, 0.001));
    expect(s[1].earned, isTrue);
    expect(s[1].fraction, 1);
  });

  testWidgets('Learn shows progress, filters by topic and opens an article',
      (tester) async {
    tallScreen(tester);
    Article? opened;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: LearnScreen(
        repository: FakeLearn(<Article>[
          article(1, 'stress', read: true),
          article(2, 'anxiety'),
          article(3, 'support'),
        ]),
        onOpen: (Article a) => opened = a,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('You have read 1 of 3'), findsOneWidget);
    expect(find.textContaining('Read 2 more for the Curious Mind badge'),
        findsOneWidget);
    expect(find.text('Article 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-stress')));
    await tester.pumpAndSettle();
    expect(find.text('Article 1'), findsOneWidget);
    expect(find.text('Article 2'), findsNothing);

    await tester.tap(find.byKey(const Key('article-1')));
    expect(opened?.id, 1);
  });

  testWidgets('Learn shows Kiswahili titles', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) =>
          LanguageScope(language: 'sw', child: child!),
      home: LearnScreen(
        repository: FakeLearn(<Article>[article(1, 'stress')]),
        onOpen: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Jifunze'), findsOneWidget);
    expect(find.text('Makala 1'), findsOneWidget);
    expect(find.text('Umesoma 0 kati ya 1'), findsOneWidget);
    expect(find.text('Zote'), findsOneWidget);
  });

  testWidgets('reading an article earns XP and celebrates a new badge',
      (tester) async {
    tallScreen(tester);
    final FakeLearn repo =
        FakeLearn(<Article>[], badgesOnRead: <RewardBadge>[curious]);
    int readCalls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleScreen(
          article: article(7, 'mindfulness'),
          repository: repo,
          onRead: () => readCalls++),
    ));

    expect(find.text('Second paragraph of 7.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lang-sw')));
    await tester.pump();
    expect(find.text('Makala 7'), findsOneWidget);
    expect(find.text('Aya ya pili ya 7.'), findsOneWidget);
    expect(find.text('Nimeisoma · +5 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-read')));
    await tester.pumpAndSettle();

    expect(repo.marked, <int>[7]);
    expect(readCalls, 1);
    expect(find.byKey(const Key('new-badge-dialog')), findsOneWidget);
    expect(find.text('Akili Dadisi'), findsOneWidget);
    // The article was switched to Kiswahili, so the pop-up is in Kiswahili too.
    await tester.tap(find.text('Safi!'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('article-read')), findsOneWidget);
    expect(find.byKey(const Key('mark-read')), findsNothing);
  });

  testWidgets('an article already read has no button', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleScreen(
          article: article(2, 'stress', read: true),
          repository: FakeLearn(<Article>[])),
    ));
    expect(find.byKey(const Key('mark-read')), findsNothing);
    expect(find.byKey(const Key('article-read')), findsOneWidget);
  });

  testWidgets('Rewards shows level, weekly quest and badge progress',
      (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: RewardsScreen(
        repository: FakeRewards(RewardsSummary(
          xp: 160,
          streak: 3,
          weekCheckinDays: 3,
          weeklyQuestDone: false,
          questsCompleted: 1,
          badges: badgeStatuses(
            <RewardBadge>[curious, firstChat],
            <String, DateTime>{'first_chat': DateTime(2026, 10, 9)},
            const BadgeCounts(articlesRead: 1, chatMessages: 4),
          ),
          recent: <XpEvent>[
            XpEvent(
                reason: 'article_read', amount: 5, at: DateTime(2026, 10, 10))
          ],
        )),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('60 / 100 XP to Level 4'), findsOneWidget);
    expect(find.textContaining('3 / 5 days'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Earned 9 Oct'), findsOneWidget);
    expect(find.text('Article read'), findsOneWidget);
    expect(find.text('Ways to earn XP'), findsOneWidget);
  });

  group('recommendArticles', () {
    final List<Article> all = <Article>[
      article(1, 'stress', read: true),
      article(2, 'stress'),
      article(3, 'anxiety'),
      article(4, 'support'),
      article(5, 'mindfulness'),
    ];

    test('follows feelings from the chat, unread first', () {
      final List<Recommendation> r = recommendArticles(all,
          chatFeelings: <String, int>{'feel_anxious': 1, 'feel_stressed': 3});
      expect(r.map((Recommendation x) => x.article.id), <int>[2, 3]);
      expect(r.first.reason, contains('stress'));
    });

    test('low moods point to support, otherwise mindfulness', () {
      final DateTime now = DateTime(2026, 10, 10);
      expect(
        recommendArticles(all,
                recentMoods: <MoodEntry>[MoodEntry(id: 'a', mood: 1, at: now)])
            .first
            .article
            .id,
        4,
      );
      expect(recommendArticles(all).first.article.id, 5);
    });
  });

  test('tags on low days become an insight', () {
    final DateTime now = DateTime(2026, 10, 10, 12);
    final List<MoodInsight> i = buildInsights(<MoodEntry>[
      MoodEntry(
          id: 'a', mood: 2, at: now, tags: const <String>['school', 'sleep']),
      MoodEntry(
          id: 'b',
          mood: 4,
          at: now.subtract(const Duration(days: 1)),
          tags: const <String>['friends']),
      MoodEntry(
          id: 'c',
          mood: 1,
          at: now.subtract(const Duration(days: 3)),
          tags: const <String>['school']),
      MoodEntry(
          id: 'd',
          mood: 5,
          at: now.subtract(const Duration(days: 4)),
          tags: const <String>['friends']),
    ], now: now);
    expect(i.firstWhere((MoodInsight x) => x.id == 'low_tag').body,
        contains('school'));
    expect(i.firstWhere((MoodInsight x) => x.id == 'good_tag').body,
        contains('friends'));
  });

  testWidgets('Home recommends articles and shows the week', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final FakeProgress progress = FakeProgress(
        const HomeSummary(username: 'Amani', xp: 60, streak: 1))
      ..chatFeelings = <String, int>{'feel_stressed': 2}
      ..history = <MoodEntry>[MoodEntry(id: 'm', mood: 4, at: nairobiNow())];
    Article? opened;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
        repository: progress,
        learn: FakeLearn(
            <Article>[article(1, 'stress'), article(2, 'mindfulness')]),
        onOpenArticle: (Article a) => opened = a,
        onMoodTap: (_) {},
        onTalk: () {},
        onProfile: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Level 2 · 🌱 Sprout'), findsOneWidget);
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.textContaining('Because stress came up'), findsOneWidget);
    expect(find.byKey(const Key('week-strip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recommended-1')));
    expect(opened?.id, 1);
  });
}
