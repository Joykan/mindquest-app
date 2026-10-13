import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/l10n/tr.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/auth/account_errors.dart';
import 'package:mindquest/features/chat/chat_backend.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/chat/chat_screen.dart';
import 'package:mindquest/features/home/home_screen.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_insights.dart';
import 'package:mindquest/features/mood/mood_screen.dart';
import 'package:mindquest/features/mood/moods.dart';
import 'package:mindquest/features/support/support_screen.dart';

import 'fakes.dart';

/// Builds [screen] the way the app does, with the language above it.
Widget inLanguage(String language, Widget screen) => MaterialApp(
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) =>
          LanguageScope(language: language, child: child!),
      home: screen,
    );

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

class _Backend extends ChatBackend {
  @override
  Future<ChatReply> send(String text) async => const ChatReply(reply: 'ok');
}

void main() {
  test('dates and moods have Kiswahili names', () {
    final DateTime d = DateTime(2026, 10, 13, 9, 5); // a Tuesday
    expect(longDate('sw', d), 'Jumanne, 13 Oktoba');
    expect(longDate('en', d), 'Tuesday, 13 October');
    expect(shortDate('sw', d), '13 Okt');
    expect(clock(d), '09:05');
    expect(moodOptions.first.name('sw'), 'Vibaya sana');
    expect(moodReply(5, 'sw'), contains('habari njema'));
  });

  test('insights can be built in Kiswahili', () {
    final DateTime now = DateTime(2026, 10, 13, 12);
    final List<MoodEntry> entries = <MoodEntry>[
      for (int i = 0; i < 3; i++)
        MoodEntry(id: '$i', mood: 5, at: now.subtract(Duration(hours: i))),
    ];
    final MoodInsight mix =
        buildInsights(entries, now: now, language: 'sw').last;
    expect(mix.id, 'mood_mix');
    expect(mix.title, 'Siku nyingi nzuri');
    expect(buildInsights(entries, now: now).last.title, 'Mostly good days');
  });

  test('sign-in errors are friendly in both languages', () {
    expect(accountError('Invalid login credentials', 'sw'),
        'Barua pepe au nenosiri si sahihi.');
    expect(accountError('Invalid login credentials', 'en'),
        'That email or password is not right.');
  });

  testWidgets('Home is in Kiswahili', (tester) async {
    tall(tester);
    await tester.pumpWidget(inLanguage(
      'sw',
      HomeScreen(
        repository: FakeProgress(
            const HomeSummary(username: 'Amani', xp: 60, streak: 3)),
        onMoodTap: (_) {},
        onTalk: () {},
        onProfile: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Habari, Amani'), findsOneWidget);
    expect(find.text('Mfululizo wa siku 3'), findsOneWidget);
    expect(find.text('Changamoto za leo'), findsOneWidget);
    expect(find.text('Ongea na Chipu'), findsWidgets);
    expect(find.text("Today's quests"), findsNothing);
  });

  testWidgets('Mood check-in is in Kiswahili', (tester) async {
    tall(tester);
    await tester.pumpWidget(inLanguage(
        'sw',
        MoodScreen(
            repository: FakeProgress(
                const HomeSummary(username: 'A', xp: 0, streak: 0)))));
    expect(find.text('Rekodi hisia'), findsOneWidget);
    expect(find.text('Vibaya sana'), findsOneWidget);
    expect(find.text('📚 Shule'), findsOneWidget);
    expect(find.text('Hifadhi'), findsOneWidget);
  });

  testWidgets('Chipu greets in Kiswahili with Kiswahili suggestions',
      (tester) async {
    await tester.pumpWidget(inLanguage(
        'sw',
        ChatScreen(
            backend: _Backend(),
            progress: FakeProgress(
                const HomeSummary(username: 'A', xp: 0, streak: 0)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Habari, mimi ni Chipu'), findsOneWidget);
    expect(find.text(checkInChipSw), findsOneWidget);
    expect(find.text(quickRepliesSw.first), findsOneWidget);
    expect(find.text(checkInChip), findsNothing);
  });

  testWidgets('Support is in Kiswahili, emergency numbers included',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(inLanguage(
        'sw',
        SupportScreen(
            loadHelplines: () async => throw Exception('offline'))));
    await tester.pumpAndSettle();
    expect(find.text('Msaada'), findsOneWidget);
    expect(find.text('Huduma za dharura'), findsNWidgets(2));
    expect(find.textContaining('Polisi, ambulensi na zimamoto'), findsOneWidget);
    expect(find.text('Anza kupumua'), findsOneWidget);
  });
}
