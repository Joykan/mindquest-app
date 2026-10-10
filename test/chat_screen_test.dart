import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/features/chat/chat_backend.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/chat/chat_screen.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_week_graph.dart';

import 'fakes.dart';

/// Answers from a fixed list instead of calling Supabase.
class FakeBackend implements ChatBackend {
  FakeBackend(this.replies);

  final List<ChatReply> replies;
  final List<String> sent = <String>[];

  @override
  Future<ChatReply> send(String text) async {
    sent.add(text);
    return replies.removeAt(0);
  }
}

class FailingBackend implements ChatBackend {
  @override
  Future<ChatReply> send(String text) async => throw Exception('offline');
}

Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-input')), text);
  await tester.tap(find.byKey(const Key('chat-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sends a message and shows the reply', (tester) async {
    final FakeBackend backend = FakeBackend(<ChatReply>[
      const ChatReply(
          reply: 'Nice to meet you, Joy! How are you feeling today?',
          sessionId: 's1'),
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: ChatScreen(backend: backend)));

    await sendMessage(tester, 'my name is Joy');

    expect(backend.sent, <String>['my name is Joy']);
    expect(find.text('my name is Joy'), findsOneWidget);
    expect(find.text('Nice to meet you, Joy! How are you feeling today?'),
        findsOneWidget);
  });

  testWidgets('a crisis reply opens the support sheet with call buttons',
      (tester) async {
    final FakeBackend backend = FakeBackend(<ChatReply>[
      const ChatReply(
        reply: "It sounds like you're going through something really painful.",
        crisis: true,
        helplines: <Helpline>[
          Helpline(name: 'Emergency services', phone: '999'),
          Helpline(name: 'Emergency services', phone: '112'),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: ChatScreen(backend: backend)));

    await sendMessage(tester, 'I want to end it all');

    const String title = "You don't have to go through this alone";
    expect(find.text(title), findsOneWidget);
    expect(find.text('Call'), findsNWidgets(2));
    expect(find.textContaining('999'), findsOneWidget);
    expect(find.textContaining('112'), findsOneWidget);

    // Tapping outside does not close it; the button does.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text("I'm safe, continue chatting"));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('a quick reply chip sends its text', (tester) async {
    final FakeBackend backend = FakeBackend(
        <ChatReply>[const ChatReply(reply: 'Breathing exercise...')]);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: ChatScreen(backend: backend)));

    await tester.tap(find.text('Help me breathe'));
    await tester.pumpAndSettle();

    expect(backend.sent, <String>['Help me breathe']);
    expect(find.text('Breathing exercise...'), findsOneWidget);
  });

  testWidgets('dark theme builds the chat screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: ChatScreen(backend: FakeBackend(<ChatReply>[]))));
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('shows an error if the message cannot be sent', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: ChatScreen(backend: FailingBackend())));

    await sendMessage(tester, 'hi');

    expect(find.textContaining("Couldn't send your message"), findsOneWidget);
  });

  testWidgets('the bot asks for a mood, saves it and draws the week',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final FakeProgress progress =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    progress.history = <MoodEntry>[
      MoodEntry(id: 'old', mood: 2, at: nairobiNow().subtract(const Duration(days: 2))),
    ];
    int saved = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChatScreen(
        backend: FakeBackend(<ChatReply>[]),
        progress: progress,
        onMoodSaved: () => saved++,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Hi, I'm MindQuest. How are you feeling right now?"),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-mood-5')));
    await tester.pumpAndSettle();

    expect(progress.logged, <(int, String?)>[(5, null)]);
    expect(saved, 1);
    expect(find.text('😄 Great'), findsOneWidget);
    expect(find.text("That's wonderful! I'm so glad to hear it."), findsOneWidget);
    expect(find.text("I've added that to your graph. +10 XP"), findsOneWidget);
    expect(find.byKey(const Key('chat-mood-graph')), findsOneWidget);

    // The answered picker can't be used again.
    await tester.tap(find.byKey(const Key('chat-mood-1')).first);
    await tester.pumpAndSettle();
    expect(progress.logged.length, 1);
  });

  testWidgets('the check-in chip asks again, and the bot sees no text',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final FakeBackend backend = FakeBackend(<ChatReply>[]);
    final FakeProgress progress =
        FakeProgress(const HomeSummary(username: 'A', xp: 0, streak: 0));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChatScreen(backend: backend, progress: progress),
    ));
    await tester.tap(find.text(checkInChip));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling right now?'), findsOneWidget);
    expect(find.byKey(const Key('chat-mood-3')), findsNWidgets(2));
    expect(backend.sent, isEmpty, reason: 'mood check-ins are not sent to the chatbot');
  });

  testWidgets('week graph shows a face per check-in day', (tester) async {
    final DateTime now = DateTime(2026, 10, 10, 12);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MoodWeekGraph(now: now, entries: <MoodEntry>[
          MoodEntry(id: 'a', mood: 5, at: now),
          MoodEntry(id: 'b', mood: 1, at: now.subtract(const Duration(hours: 2))),
          MoodEntry(id: 'c', mood: 3, at: now.subtract(const Duration(days: 3))),
        ]),
      ),
    ));
    // Only the latest check-in of a day is drawn.
    expect(find.text('😄'), findsOneWidget);
    expect(find.text('😢'), findsNothing);
    expect(find.text('😐'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
  });
}
