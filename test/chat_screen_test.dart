import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/features/chat/chat_backend.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/chat/chat_screen.dart';

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
      const ChatReply(reply: 'Nice to meet you, Joy! How are you feeling today?', sessionId: 's1'),
    ]);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: ChatScreen(backend: backend)));

    await sendMessage(tester, 'my name is Joy');

    expect(backend.sent, <String>['my name is Joy']);
    expect(find.text('my name is Joy'), findsOneWidget);
    expect(find.text('Nice to meet you, Joy! How are you feeling today?'), findsOneWidget);
  });

  testWidgets('a crisis reply opens the support sheet with call buttons', (tester) async {
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
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: ChatScreen(backend: backend)));

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
    final FakeBackend backend = FakeBackend(<ChatReply>[const ChatReply(reply: 'Breathing exercise...')]);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: ChatScreen(backend: backend)));

    await tester.tap(find.text('Help me breathe'));
    await tester.pumpAndSettle();

    expect(backend.sent, <String>['Help me breathe']);
    expect(find.text('Breathing exercise...'), findsOneWidget);
  });

  testWidgets('dark theme builds the chat screen', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: ChatScreen(backend: FakeBackend(<ChatReply>[]))));
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('shows an error if the message cannot be sent', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: ChatScreen(backend: FailingBackend())));

    await sendMessage(tester, 'hi');

    expect(find.textContaining("Couldn't send your message"), findsOneWidget);
  });
}
