import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/gamification/levels.dart';
import 'package:mindquest/features/support/support_screen.dart';

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('level names grow from seed to forest', () {
    expect(levelTitle(1).en, 'Seed');
    expect(levelTitle(2).en, 'Sprout');
    expect(levelTitle(3).en, 'Sapling');
    expect(levelTitle(4).sw, 'Mti mchanga');
    expect(levelTitle(5).en, 'Mighty tree');
    expect(levelTitle(9).en, 'Forest');
  });

  testWidgets('Support lists helplines with Call buttons', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SupportScreen(
        loadHelplines: () async => const <Helpline>[
          Helpline(
              name: 'Kenya Red Cross',
              phone: '1199',
              description: 'Toll-free, 24 hours'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kenya Red Cross'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.byKey(const Key('box-breathing')), findsOneWidget);
    expect(find.byKey(const Key('grounding')), findsOneWidget);
  });

  testWidgets('Support falls back to 999 and 112 if helplines fail',
      (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home:
          SupportScreen(loadHelplines: () async => throw Exception('offline')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('999'), findsWidgets);
    expect(find.text('Call'), findsNWidgets(2));
  });

  testWidgets('box breathing guides in, hold and out', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
          body: SingleChildScrollView(child: BoxBreathingCard())),
    ));
    await tester.tap(find.byKey(const Key('breathing-button')));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('Round 1 of 4'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 4100));
    expect(find.text('Hold'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);

    // All four rounds (64 s), then it says well done.
    for (int s = 0; s < 70; s++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('Well done'), findsOneWidget);
    expect(find.text('Go again'), findsOneWidget);
  });

  testWidgets('grounding is done after all five steps', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SingleChildScrollView(child: GroundingCard())),
    ));
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.byKey(Key('ground-$i')));
      await tester.pump();
    }
    expect(find.textContaining('You are here, right now'), findsOneWidget);
  });
}
