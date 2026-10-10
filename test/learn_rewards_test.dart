import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/gamification/badges.dart';
import 'package:mindquest/features/learn/article_screen.dart';
import 'package:mindquest/features/learn/learn_repository.dart';
import 'package:mindquest/features/learn/learn_screen.dart';
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
    expect(article(1, 'stress').paragraphs('en'), <String>['First paragraph of 1.', 'Second paragraph of 1.']);
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

  testWidgets('Learn shows progress, filters by topic and opens an article', (tester) async {
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
    expect(find.textContaining('Read 2 more for the Curious Mind badge'), findsOneWidget);
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
      home: LearnScreen(
        repository: FakeLearn(<Article>[article(1, 'stress')]),
        language: 'sw',
        onOpen: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Jifunze'), findsOneWidget);
    expect(find.text('Makala 1'), findsOneWidget);
  });

  testWidgets('reading an article earns XP and celebrates a new badge', (tester) async {
    tallScreen(tester);
    final FakeLearn repo = FakeLearn(<Article>[], badgesOnRead: <RewardBadge>[curious]);
    int readCalls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleScreen(article: article(7, 'mindfulness'), repository: repo, onRead: () => readCalls++),
    ));

    expect(find.text('Second paragraph of 7.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lang-sw')));
    await tester.pump();
    expect(find.text('Makala 7'), findsOneWidget);
    expect(find.text('Aya ya pili ya 7.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-read')));
    await tester.pumpAndSettle();

    expect(repo.marked, <int>[7]);
    expect(readCalls, 1);
    expect(find.byKey(const Key('new-badge-dialog')), findsOneWidget);
    expect(find.text('Akili Dadisi'), findsOneWidget);
    await tester.tap(find.text('Nice!'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('article-read')), findsOneWidget);
    expect(find.byKey(const Key('mark-read')), findsNothing);
  });

  testWidgets('an article already read has no button', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleScreen(article: article(2, 'stress', read: true), repository: FakeLearn(<Article>[])),
    ));
    expect(find.byKey(const Key('mark-read')), findsNothing);
    expect(find.byKey(const Key('article-read')), findsOneWidget);
  });

  testWidgets('Rewards shows level, weekly quest and badge progress', (tester) async {
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
          recent: <XpEvent>[XpEvent(reason: 'article_read', amount: 5, at: DateTime(2026, 10, 10))],
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
}
