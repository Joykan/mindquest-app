import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/core/theme/theme_controller.dart';
import 'package:mindquest/features/gamification/levels.dart';
import 'package:mindquest/features/home/home_screen.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_history_screen.dart';
import 'package:mindquest/features/mood/mood_screen.dart';

import 'fakes.dart';

/// A phone-sized screen (360 x 800) so the whole Home screen is laid out.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('levels match public.level_for_xp', () {
    test('thresholds', () {
      final Map<int, int> cases = <int, int>{
        0: 1,
        49: 1,
        50: 2,
        99: 2,
        100: 3,
        199: 3,
        200: 4,
        349: 4,
        350: 5,
        549: 5,
        550: 6,
        750: 7
      };
      cases.forEach((int xp, int level) =>
          expect(levelForXp(xp), level, reason: '$xp XP'));
    });

    test('progress to the next level (the wireframe example: 160 XP)', () {
      final LevelProgress p = LevelProgress(160);
      expect(p.level, 3);
      expect(p.earned, 60);
      expect(p.needed, 100);
    });
  });

  group('Nairobi day and week boundaries', () {
    test('just after midnight in Nairobi is already the new day', () {
      // 21:30 UTC on 10 Oct = 00:30 on 11 Oct in Nairobi.
      final DateTime start =
          startOfTodayUtc(DateTime.utc(2026, 10, 10, 21, 30));
      expect(start, DateTime.utc(2026, 10, 10, 21));
    });

    test('week starts on Monday', () {
      // Saturday 10 Oct 2026, noon Nairobi -> Monday 5 Oct 00:00 Nairobi.
      final DateTime start = startOfWeekUtc(DateTime.utc(2026, 10, 10, 9));
      expect(start, DateTime.utc(2026, 10, 4, 21));
    });
  });

  testWidgets('Home shows streak, level progress and quests', (tester) async {
    // A tall screen (360 x 2000) so every card is built without scrolling.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    int? tappedMood;
    final FakeProgress repo = FakeProgress(const HomeSummary(
      username: 'Amani',
      xp: 160,
      streak: 3,
      doneToday: <String>{'chat_message'},
      weekCheckinDays: 2,
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
        repository: repo,
        onMoodTap: (int m) => tappedMood = m,
        onTalk: () {},
        onProfile: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Amani'), findsOneWidget);
    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.text('Level 3 · 🌿 Sapling'), findsOneWidget);
    expect(find.byKey(const Key('week-strip')), findsOneWidget);
    expect(find.text('60 / 100 XP to Level 4'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mood-4')));
    expect(tappedMood, 4);

    await tester.tap(find.byKey(const Key('helplines')));
    await tester.pumpAndSettle();
    expect(find.text('Kenya Red Cross'), findsOneWidget);
  });

  testWidgets('Mood check-in saves face, tags and note, then shows insights',
      (tester) async {
    usePhoneScreen(tester);
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    int savedCalls = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MoodScreen(repository: repo, onSaved: () => savedCalls++),
    ));

    FilledButton save() =>
        tester.widget<FilledButton>(find.byKey(const Key('save-mood')));
    expect(save().onPressed, isNull, reason: 'nothing chosen yet');

    await tester.tap(find.byKey(const Key('choose-mood-2')));
    await tester.tap(find.byKey(const Key('tag-school')));
    await tester.ensureVisible(find.byKey(const Key('mood-note')));
    await tester.enterText(
        find.byKey(const Key('mood-note')), 'exams tomorrow');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-mood')));
    await tester.tap(find.byKey(const Key('save-mood')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Chipu "thinks" first, then shows the summary.
    expect(find.byKey(const Key('insights-thinking')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(repo.logged, <(int, String?)>[(2, 'exams tomorrow')]);
    expect(repo.loggedTags, <List<String>>[<String>['school']]);
    expect(find.byKey(const Key('check-in-summary')), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('🔥 4-day streak'), findsOneWidget);
    expect(find.textContaining('Chipu will start spotting patterns'), findsOneWidget);
    expect(savedCalls, 0, reason: 'goes Home only after Done');

    await tester.tap(find.byKey(const Key('summary-done')));
    await tester.pumpAndSettle();
    expect(savedCalls, 1);
  });

  testWidgets('After a low mood the summary offers a breathing exercise',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final DateTime n = nairobiNow();
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0))
          ..history = <MoodEntry>[
            MoodEntry(id: 'a', mood: 1, at: n, tags: const <String>['school']),
            MoodEntry(id: 'b', mood: 2, at: n.subtract(const Duration(days: 1)), tags: const <String>['school']),
            MoodEntry(id: 'c', mood: 2, at: n.subtract(const Duration(days: 2))),
          ];
    int support = 0;
    int saved = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MoodScreen(
        repository: repo,
        initialMood: 1,
        onSaved: () => saved++,
        onSupport: () => support++,
        onTalk: () {},
      ),
    ));
    await tester.tap(find.byKey(const Key('save-mood')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-insight-hard_days')), findsOneWidget);
    expect(find.byKey(const Key('summary-insight-low_tag')), findsOneWidget);
    expect(find.byKey(const Key('summary-talk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('summary-support')));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(support, 1);
  });

  testWidgets('A face tapped on Home arrives already selected', (tester) async {
    usePhoneScreen(tester);
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: MoodScreen(repository: repo, initialMood: 5)));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-mood')))
            .onPressed,
        isNotNull);
  });

  testWidgets('Appearance button offers System default, Light and Dark',
      (tester) async {
    usePhoneScreen(tester);
    final ThemeController theme = ThemeController();
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
          repository: repo,
          theme: theme,
          onMoodTap: (_) {},
          onTalk: () {},
          onProfile: () {}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appearance-button')));
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light mode'), findsOneWidget);
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    expect(theme.value, ThemeMode.dark);
  });

  testWidgets('Mood check-in has a back arrow to Home', (tester) async {
    usePhoneScreen(tester);
    bool wentBack = false;
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MoodScreen(repository: repo, onBack: () => wentBack = true),
    ));
    await tester.tap(find.byType(BackButton));
    expect(wentBack, isTrue);
  });

  testWidgets('Mood history shows the week, a summary and deletable entries',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final DateTime now = nairobiNow();
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0))
          ..history = <MoodEntry>[
            MoodEntry(id: 'a', mood: 4, at: now, note: 'good lecture'),
            MoodEntry(
                id: 'b', mood: 2, at: now.subtract(const Duration(days: 1))),
            MoodEntry(
                id: 'c', mood: 4, at: now.subtract(const Duration(days: 3))),
          ];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: MoodHistoryScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('3 / 7'), findsOneWidget);
    expect(find.text('good lecture'), findsOneWidget);
    expect(find.textContaining('most common mood'), findsOneWidget);
    expect(find.textContaining('(good)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, <String>['a']);
    expect(find.text('good lecture'), findsNothing);
  });

  testWidgets('Mood screen links to the history', (tester) async {
    usePhoneScreen(tester);
    bool opened = false;
    final FakeProgress repo =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MoodScreen(repository: repo, onHistory: () => opened = true),
    ));
    await tester.ensureVisible(find.byKey(const Key('view-history')));
    await tester.tap(find.byKey(const Key('view-history')));
    expect(opened, isTrue);
  });
}
