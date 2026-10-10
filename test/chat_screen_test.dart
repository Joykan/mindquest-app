import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/features/chat/chat_backend.dart';
import 'package:mindquest/features/chat/chat_models.dart';
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
    await tester.pumpWidget(MaterialApp(home: ChatScreen(backend: backend)));

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
    await tester.pumpWidget(MaterialApp(home: ChatScreen(backend: backend)));

    await sendMessage(tester, 'I want to end it all');

    expect(find.text("You're not alone"), findsOneWidget);
    expect(find.text('Call 999'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);

    // Tapping outside does not close it; the button does.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text("You're not alone"), findsOneWidget);

    await tester.tap(find.text("I'm safe for now"));
    await tester.pumpAndSettle();
    expect(find.text("You're not alone"), findsNothing);
  });

  testWidgets('shows an error if the message cannot be sent', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ChatScreen(backend: FailingBackend())));

    await sendMessage(tester, 'hi');

    expect(find.textContaining("Couldn't send your message"), findsOneWidget);
  });
}
