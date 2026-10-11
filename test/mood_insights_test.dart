import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_history_screen.dart';
import 'package:mindquest/features/mood/mood_insights.dart';

import 'fakes.dart';

/// Saturday 10 Oct 2026, noon (Nairobi time).
final DateTime now = DateTime(2026, 10, 10, 12);

int _n = 0;
MoodEntry at(int daysAgo, int mood, {int hour = 12, String? note}) {
  final DateTime d = DateTime(now.year, now.month, now.day - daysAgo, hour);
  return MoodEntry(id: 'e${_n++}', mood: mood, at: d, note: note);
}

/// Newest first, like the repository returns them.
List<MoodEntry> sorted(List<MoodEntry> e) =>
    e..sort((MoodEntry a, MoodEntry b) => b.at.compareTo(a.at));

List<String> ids(List<MoodInsight> i) =>
    i.map((MoodInsight x) => x.id).toList();

void main() {
  group('buildInsights', () {
    test('needs at least 3 check-ins', () {
      expect(buildInsights(<MoodEntry>[at(0, 5), at(1, 5)], now: now), isEmpty);
    });

    test('three hard days in a row come first, with helplines', () {
      final List<MoodInsight> i = buildInsights(
          sorted(<MoodEntry>[at(0, 1), at(1, 2), at(2, 2), at(3, 5)]),
          now: now);
      expect(i.first.id, 'hard_days');
      expect(i.first.needsSupport, isTrue);
      expect(i.first.title, contains('3 hard days'));
    });

    test('a hard run that ended earlier is not flagged', () {
      final List<MoodInsight> i = buildInsights(
          sorted(<MoodEntry>[at(0, 4), at(1, 2), at(2, 2), at(3, 1)]),
          now: now);
      expect(ids(i), isNot(contains('hard_days')));
    });

    test('compares this week with last week', () {
      expect(
          ids(buildInsights(
              sorted(<MoodEntry>[at(0, 5), at(2, 4), at(8, 2), at(9, 2)]),
              now: now)),
          contains('trend_up'));
      expect(
          ids(buildInsights(
              sorted(<MoodEntry>[at(0, 2), at(2, 2), at(8, 4), at(9, 5)]),
              now: now)),
          contains('trend_down'));
      expect(
          ids(buildInsights(
              sorted(<MoodEntry>[at(0, 3), at(2, 4), at(8, 4), at(9, 3)]),
              now: now)),
          contains('trend_steady'));
    });

    test('finds the best and hardest weekday', () {
      // Mondays: 5 and 12 days ago; Fridays: 1 and 8 days ago.
      final MoodInsight w = buildInsights(
              sorted(<MoodEntry>[at(5, 5), at(12, 5), at(1, 2), at(8, 2)]),
              now: now)
          .firstWhere((MoodInsight x) => x.id == 'weekday');
      expect(w.body, 'You tend to feel best on Mondays and lowest on Fridays.');
    });

    test('finds the better time of day', () {
      final MoodInsight t = buildInsights(
              sorted(<MoodEntry>[
                at(0, 5, hour: 8),
                at(1, 5, hour: 9),
                at(2, 2, hour: 21),
                at(3, 2, hour: 22),
              ]),
              now: now)
          .firstWhere((MoodInsight x) => x.id == 'time_of_day');
      expect(t.body,
          'You usually feel better in the mornings than in the evenings.');
    });

    test('spots words that keep coming up in notes', () {
      final List<MoodInsight> i = buildInsights(
          sorted(<MoodEntry>[
            at(0, 2, note: 'Exams tomorrow'),
            at(2, 1, note: 'worried about my exams'),
            at(3, 5, note: 'football with friends'),
            at(5, 4, note: 'Friends came over!'),
          ]),
          now: now);
      expect(i.firstWhere((MoodInsight x) => x.id == 'low_word').body,
          contains('"exams"'));
      expect(i.firstWhere((MoodInsight x) => x.id == 'good_word').body,
          contains('"friends"'));
    });

    test('uses feelings from the chat', () {
      final MoodInsight c = buildInsights(
              sorted(<MoodEntry>[at(0, 3), at(1, 3), at(2, 3)]),
              now: now,
              chatFeelings: <String, int>{'feel_stressed': 4, 'feel_sad': 1})
          .firstWhere((MoodInsight x) => x.id == 'chat_feeling');
      expect(c.body, startsWith('Stress came up 4 times'));
    });

    test('praises a check-in habit of 5+ days a week', () {
      expect(
          ids(buildInsights(
              sorted(<MoodEntry>[for (int d = 0; d < 5; d++) at(d, 3)]),
              now: now)),
          contains('habit'));
    });

    test('never uses diagnostic words', () {
      final List<MoodInsight> i = buildInsights(
          sorted(<MoodEntry>[
            at(0, 1, note: 'exams'),
            at(1, 1, note: 'exams'),
            at(2, 1),
            at(8, 5),
            at(9, 5),
          ]),
          now: now,
          chatFeelings: <String, int>{'feel_sad': 3});
      for (final MoodInsight x in i) {
        expect('${x.title} ${x.body}'.toLowerCase(),
            isNot(matches(RegExp('depress|disorder|diagnos(ed|is)|illness'))));
      }
    });
  });

  group('Mood history insights', () {
    Future<FakeProgress> show(WidgetTester tester, List<MoodEntry> history,
        {VoidCallback? onHelplines}) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final FakeProgress repo =
          FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0))
            ..history = history;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: MoodHistoryScreen(repository: repo, onHelplines: onHelplines),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('are locked until 3 check-ins', (tester) async {
      await show(
          tester, <MoodEntry>[MoodEntry(id: 'a', mood: 4, at: nairobiNow())]);
      expect(find.byKey(const Key('insights-locked')), findsOneWidget);
      expect(find.textContaining('(1/3)'), findsOneWidget);
    });

    testWidgets('a run of hard days offers the helplines', (tester) async {
      int opened = 0;
      final DateTime n = nairobiNow();
      await show(
        tester,
        <MoodEntry>[
          MoodEntry(id: 'a', mood: 1, at: n),
          MoodEntry(id: 'b', mood: 2, at: n.subtract(const Duration(days: 1))),
          MoodEntry(id: 'c', mood: 1, at: n.subtract(const Duration(days: 2))),
        ],
        onHelplines: () => opened++,
      );
      expect(find.byKey(const Key('insight-hard_days')), findsOneWidget);
      await tester.tap(find.byKey(const Key('insight-helplines')));
      expect(opened, 1);
    });
  });

  group('checkInInsights (about the mood just saved)', () {
    test('compares with the usual mood and explains tags', () {
      final List<MoodInsight> i = checkInInsights(
        2,
        const <String>['money'],
        sorted(<MoodEntry>[
          at(0, 2, hour: 18),
          at(1, 4),
          at(2, 5),
          at(3, 4),
        ]),
        now: now,
      );
      expect(i.first.id, 'below_usual');
      expect(i.first.body, contains('4.3 out of 5'));
      expect(i.map((MoodInsight x) => x.id), contains('tag_first_money'));
    });

    test('notices big changes within a day', () {
      final List<MoodInsight> i = checkInInsights(
        5,
        const <String>[],
        sorted(<MoodEntry>[at(0, 5, hour: 18), at(0, 2, hour: 9), at(2, 3)]),
        now: now,
      );
      expect(i.map((MoodInsight x) => x.id), contains('day_swing'));
    });

    test('mood mix is always there once insights unlock', () {
      final List<MoodInsight> i = buildInsights(
          sorted(<MoodEntry>[at(0, 5), at(1, 5), at(1, 3)]),
          now: now);
      expect(i.last.id, 'mood_mix');
      expect(i.last.title, 'Mostly good days');
    });
  });
}
