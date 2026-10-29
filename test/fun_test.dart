import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/l10n/tr.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/challenges/challenge_widgets.dart';
import 'package:mindquest/features/challenges/challenges.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/gamification/outfits.dart';
import 'package:mindquest/features/gamification/streaks.dart';
import 'package:mindquest/features/home/home_screen.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/rewards/rewards_repository.dart';
import 'package:mindquest/features/rewards/rewards_screen.dart';
import 'package:mindquest/features/support/support_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

DateTime day(int d) => DateTime.utc(2026, 10, d);
Set<DateTime> days(List<int> ds) => <DateTime>{for (final int d in ds) day(d)};

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget app(Widget screen,
        {String language = 'en', OutfitController? outfits}) =>
    MaterialApp(
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) => LanguageScope(
        language: language,
        child: OutfitScope(
            controller: outfits ?? OutfitController(), child: child!),
      ),
      home: screen,
    );

class FakeRewards implements RewardsRepository {
  FakeRewards(this.summary);

  final RewardsSummary summary;
  final List<String?> worn = <String?>[];

  @override
  Future<RewardsSummary> loadRewards() async => summary;

  @override
  Future<void> wearOutfit(String? outfit) async => worn.add(outfit);
}

class FakeChallenges implements ChallengesRepository {
  FakeChallenges(this.state, {this.busy = false});

  ChallengesState state;
  final bool busy;
  final List<String> started = <String>[];
  int left = 0;
  final List<String> activities = <String>[];

  @override
  Future<ChallengesState> load() async => state;

  @override
  Future<void> start(String challengeId) async {
    if (busy) throw const ChallengeException('busy');
    started.add(challengeId);
  }

  @override
  Future<void> leave() async => left++;

  @override
  Future<void> logActivity(String kind) async => activities.add(kind);
}

/// A real answer from public.my_challenges() (one challenge running).
Map<String, dynamic> myChallenges({bool active = true}) => <String, dynamic>{
      'challenges': <dynamic>[
        <String, dynamic>{
          'id': 'exam_calm',
          'emoji': '📝',
          'title': 'Exam calm',
          'title_sw': 'Utulivu wa mitihani',
          'description':
              'Stay steady through a busy week of exams or deadlines.',
          'description_sw':
              'Baki mtulivu katika wiki yenye mitihani au kazi nyingi.',
          'days': 7,
          'xp': 40,
          'badge_id': 'challenge_exam_calm',
          'completed': 0,
          'steps': <dynamic>[
            <String, dynamic>{'kind': 'checkin', 'target': 4},
            <String, dynamic>{'kind': 'breathing', 'target': 3},
            <String, dynamic>{
              'kind': 'read',
              'target': 1,
              'category': 'stress'
            },
          ],
        },
        <String, dynamic>{
          'id': 'mindful',
          'emoji': '🌿',
          'title': 'Mindful moments',
          'title_sw': 'Nyakati za utulivu',
          'description': 'Slow down and come back to the present moment.',
          'description_sw': 'Punguza mwendo na urudi kwenye wakati huu.',
          'days': 7,
          'xp': 40,
          'badge_id': 'challenge_mindful',
          'completed': 2,
          'steps': <dynamic>[
            <String, dynamic>{'kind': 'breathing', 'target': 3},
            <String, dynamic>{'kind': 'grounding', 'target': 2},
          ],
        },
      ],
      'active': active
          ? <String, dynamic>{
              'id': 'run-1',
              'challenge_id': 'mindful',
              'started_at': '2026-10-20T11:00:00+00:00',
              'ends_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 3, hours: 2))
                  .toIso8601String(),
              'steps': <dynamic>[
                <String, dynamic>{
                  'done': 3,
                  'kind': 'breathing',
                  'target': 3,
                  'category': null
                },
                <String, dynamic>{
                  'done': 1,
                  'kind': 'grounding',
                  'target': 2,
                  'category': null
                },
              ],
            }
          : null,
      'recent': null,
    };

void main() {
  group('rest days: the same rule as public.checkin_streak', () {
    // The same cases were run on the database (see docs/fun-features.md).
    // Mon 12 - Sun 18 Oct and Mon 19 - Sun 25 Oct 2026.
    test('one missed day keeps the streak', () {
      expect(streakRun(days(<int>[19, 20, 22]), day(22)).length, 3);
    });
    test('a second missed day in the same week ends it', () {
      expect(streakRun(days(<int>[19, 20, 22, 24]), day(24)).length, 2);
    });
    test('missed days in different weeks are both covered', () {
      expect(streakRun(days(<int>[16, 17, 19]), day(19)).length, 3);
    });
    test('two missed days in a row end it', () {
      expect(streakRun(days(<int>[17, 20]), day(20)).length, 1);
    });
    test('a full week', () {
      expect(streakRun(days(<int>[12, 13, 14, 15, 16, 17, 18]), day(18)).length,
          7);
    });
    test('the newest missed day takes the week\'s rest day', () {
      expect(streakRun(days(<int>[11, 13, 15]), day(15)).length, 2);
    });
  });

  group('the streak shown today', () {
    test('yesterday missed: the rest day keeps it until tonight', () {
      final StreakStatus s =
          streakStatus(today: day(22), checkins: days(<int>[19, 20]));
      expect(s.days, 2);
      expect(s.restYesterday, isTrue);
      expect(s.restUsedThisWeek, isTrue);
    });
    test('two days missed: no streak', () {
      expect(streakStatus(today: day(22), checkins: days(<int>[19])).days, 0);
    });
    test("last week's rest day doesn't use this week's", () {
      final StreakStatus s =
          streakStatus(today: day(20), checkins: days(<int>[16, 17, 19, 20]));
      expect(s.days, 4);
      expect(s.restUsedThisWeek, isFalse);
      expect(s.restYesterday, isFalse);
    });
    test('a streak longer than the days loaded comes from the profile', () {
      final StreakStatus s = streakStatus(
          today: day(20),
          checkins: days(<int>[18, 19, 20]),
          savedStreak: 150,
          lastCheckin: day(19));
      expect(s.days, 151);
    });
  });

  group('outfits', () {
    test('unlock at the same levels as public.outfit_level', () {
      expect(<String, int>{
        for (final Outfit o in outfits) o.id: o.level
      }, <String, int>{
        'daisy': 2,
        'glasses': 3,
        'beads': 4,
        'medal': 5,
        'cape': 6,
      });
      expect(outfitsUnlocked(1, 3).map((Outfit o) => o.id),
          <String>['daisy', 'glasses']);
    });

    test('a new level is celebrated once', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final OutfitController c = OutfitController(
          prefs: await SharedPreferences.getInstance(), userId: () => 'u1');
      expect(c.newUnlocks(2), isEmpty); // first time: just remembered
      expect(c.newUnlocks(2), isEmpty);
      expect(c.newUnlocks(4).map((Outfit o) => o.id),
          <String>['glasses', 'beads']);
      expect(c.newUnlocks(4), isEmpty);
    });
  });

  testWidgets('wardrobe: wear an unlocked outfit, locked ones stay locked',
      (tester) async {
    tall(tester);
    final FakeRewards repo = FakeRewards(const RewardsSummary(
      xp: 120, // Level 3
      streak: 2,
      badges: <BadgeStatus>[],
      weekCheckinDays: 2,
      weeklyQuestDone: false,
      questsCompleted: 0,
      outfit: 'daisy',
    ));
    final OutfitController outfits = OutfitController()..save = repo.wearOutfit;
    await tester.pumpWidget(app(
        RewardsScreen(repository: repo, outfits: outfits),
        outfits: outfits));
    await tester.pumpAndSettle();

    expect(outfits.id, 'daisy'); // from the saved profile
    expect(find.byKey(const Key('wardrobe')), findsOneWidget);
    expect(find.textContaining('Reach Level 4 to unlock the beaded headband'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('outfit-glasses')));
    await tester.pumpAndSettle();
    expect(outfits.id, 'glasses');
    expect(repo.worn, <String?>['glasses']);
    expect(
        find.text('Chipu is wearing the reading glasses 👓'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('outfit-cape')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outfit-cape')));
    await tester.pumpAndSettle();
    expect(outfits.id, 'glasses');
    expect(repo.worn, <String?>['glasses']);

    await tester.ensureVisible(find.byKey(const Key('outfit-none')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outfit-none')));
    await tester.pumpAndSettle();
    expect(outfits.id, isNull);
  });

  testWidgets('Home celebrates a new level and can put the outfit on',
      (tester) async {
    tall(tester);
    SharedPreferences.setMockInitialValues(
        <String, Object>{'outfits.u1.seenLevel': 1});
    final OutfitController outfits = OutfitController(
        prefs: await SharedPreferences.getInstance(), userId: () => 'u1');
    await tester.pumpWidget(app(
        HomeScreen(
          repository: FakeProgress(
              const HomeSummary(username: 'Amani', xp: 105, streak: 2)),
          onMoodTap: (_) {},
          onTalk: () {},
          onProfile: () {},
          outfits: outfits,
        ),
        outfits: outfits));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('level-up-dialog')), findsOneWidget);
    expect(find.textContaining('You reached Level 3'), findsOneWidget);
    expect(find.textContaining('Reading glasses'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wear-new-outfit')));
    await tester.pumpAndSettle();
    expect(outfits.id, 'glasses');
    expect(find.byKey(const Key('level-up-dialog')), findsNothing);
  });

  testWidgets('Home explains a rest day', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(HomeScreen(
      repository: FakeProgress(const HomeSummary(
          username: 'A', xp: 0, streak: 4, restYesterday: true)),
      onMoodTap: (_) {},
      onTalk: () {},
      onProfile: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('4-day streak'), findsOneWidget);
    expect(
        find.text(
            'Yesterday was your rest day. Check in today to keep your streak!'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('rest-day')));
    await tester.pumpAndSettle();
    expect(find.textContaining('one rest day'), findsOneWidget);
  });

  testWidgets('rest day in Kiswahili', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(
        HomeScreen(
          repository: FakeProgress(const HomeSummary(
              username: 'A', xp: 0, streak: 2, restUsedThisWeek: true)),
          onMoodTap: (_) {},
          onTalk: () {},
          onProfile: () {},
        ),
        language: 'sw'));
    await tester.pumpAndSettle();
    expect(find.text('Siku ya kupumzika imetumika wiki hii'), findsOneWidget);
  });

  group('challenges', () {
    test('reads public.my_challenges()', () {
      final ChallengesState s = ChallengesState.fromJson(myChallenges());
      expect(s.challenges.length, 2);
      expect(s.challenges[1].completed, 2);
      final ActiveChallenge a = s.active!;
      expect(a.challenge.id, 'mindful');
      expect(a.done, 4);
      expect(a.target, 5);
      expect(a.daysLeft(), 4);
      expect(s.challenges.first.steps[2].label('en'),
          'Read 1 article about stress');
      expect(s.challenges.first.steps[2].label('sw'),
          'Soma makala 1 kuhusu msongo');
      expect(s.challenges.first.steps[1].place, 'support');
    });

    test('a different suggestion each week', () {
      final ChallengesState s =
          ChallengesState.fromJson(myChallenges(active: false));
      final Challenge? a = s.featured(DateTime.utc(2026, 10, 20, 9));
      final Challenge? b = s.featured(DateTime.utc(2026, 10, 27, 9));
      expect(a, isNotNull);
      expect(a!.id == b!.id, isFalse);
      expect(s.featured(DateTime.utc(2026, 10, 21, 9))!.id, a.id);
    });

    testWidgets('Home shows the running challenge', (tester) async {
      tall(tester);
      bool opened = false;
      await tester.pumpWidget(app(HomeScreen(
        repository:
            FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0)),
        onMoodTap: (_) {},
        onTalk: () {},
        onProfile: () {},
        challenges: FakeChallenges(ChallengesState.fromJson(myChallenges())),
        onChallenges: () => opened = true,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-card')), findsOneWidget);
      expect(find.text('Mindful moments'), findsOneWidget);
      expect(find.text('4 days left'), findsOneWidget);
      expect(find.text('Do 5-4-3-2-1 grounding 2 times'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('challenge-card')));
      expect(opened, isTrue);
    });

    testWidgets("Home suggests this week's challenge", (tester) async {
      tall(tester);
      await tester.pumpWidget(app(HomeScreen(
        repository:
            FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0)),
        onMoodTap: (_) {},
        onTalk: () {},
        onProfile: () {},
        challenges: FakeChallenges(
            ChallengesState.fromJson(myChallenges(active: false))),
        onChallenges: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text("This week's challenge"), findsOneWidget);
    });

    testWidgets('start, a step opens its place, and leave', (tester) async {
      tall(tester);
      final FakeChallenges repo =
          FakeChallenges(ChallengesState.fromJson(myChallenges()));
      final List<String> places = <String>[];
      await tester.pumpWidget(app(ChallengesScreen(
          repository: repo, onStep: places.add, onChanged: () {})));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-challenge')), findsOneWidget);
      // Another one can't start while one is running.
      final FilledButton start =
          tester.widget<FilledButton>(find.byKey(const Key('start-exam_calm')));
      expect(start.onPressed, isNull);

      await tester.tap(find.byKey(const Key('step-grounding')));
      expect(places, <String>['support']);

      await tester.tap(find.byKey(const Key('leave-challenge')));
      await tester.pumpAndSettle();
      // After leaving, the server says nothing is running.
      repo.state = ChallengesState.fromJson(myChallenges(active: false));
      await tester.tap(find.byKey(const Key('confirm-leave')));
      await tester.pumpAndSettle();
      expect(repo.left, 1);
      expect(find.byKey(const Key('active-challenge')), findsNothing);

      await tester.tap(find.byKey(const Key('start-exam_calm')));
      await tester.pumpAndSettle();
      expect(repo.started, <String>['exam_calm']);
      expect(
          find.text("📝 Exam calm started. You've got this!"), findsOneWidget);
    });

    testWidgets('a challenge already running is explained', (tester) async {
      tall(tester);
      final FakeChallenges repo = FakeChallenges(
          ChallengesState.fromJson(myChallenges(active: false)),
          busy: true);
      await tester.pumpWidget(app(ChallengesScreen(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-mindful')));
      await tester.pumpAndSettle();
      expect(find.text('Finish or leave your current challenge first.'),
          findsOneWidget);
    });

    testWidgets('Challenges screen in Kiswahili', (tester) async {
      tall(tester);
      await tester.pumpWidget(app(
          ChallengesScreen(
              repository: FakeChallenges(
                  ChallengesState.fromJson(myChallenges(active: false)))),
          language: 'sw'));
      await tester.pumpAndSettle();
      expect(find.text('Changamoto'), findsOneWidget);
      expect(find.text('Utulivu wa mitihani'), findsOneWidget);
      expect(find.text('•  Rekodi hisia siku 4'), findsOneWidget);
      expect(find.text('✓ Umeimaliza mara 2'), findsOneWidget);
    });
  });

  testWidgets('finished exercises count for challenges', (tester) async {
    tall(tester);
    final List<String> done = <String>[];
    await tester.pumpWidget(app(SupportScreen(
      loadHelplines: () async => const <Helpline>[],
      onExerciseDone: done.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breathing-button')));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 17));
    }
    expect(done, <String>['breathing']);

    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byKey(Key('ground-$i')));
      await tester.pump();
    }
    // Unticking and ticking again doesn't count twice.
    await tester.tap(find.byKey(const Key('ground-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ground-0')));
    await tester.pump();
    expect(done, <String>['breathing', 'grounding']);
  });
}
