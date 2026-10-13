import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/l10n/tr.dart';
import 'package:mindquest/core/offline/offline_store.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/core/widgets/offline_banner.dart';
import 'package:mindquest/features/chat/chat_backend.dart';
import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/chat/chat_screen.dart';
import 'package:mindquest/features/chat/crisis_phrases.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/mood/mood_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

Future<OfflineStore> newStore([String user = 'u1']) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return OfflineStore(prefs, userId: () => user);
}

/// The phone has no internet.
Future<dynamic> noInternet() async =>
    throw const SocketException('Failed host lookup');

class OfflineBackend extends ChatBackend {
  @override
  Future<ChatReply> send(String text) async =>
      throw const SocketException('Failed host lookup');
}

/// Like FakeProgress, but the check-in is kept on the phone (no internet).
class OfflineProgress extends FakeProgress {
  OfflineProgress()
      : super(const HomeSummary(username: 'A', xp: 0, streak: 0));

  @override
  Future<MoodSaved> logMood(
      {required int mood,
      String? note,
      List<String> tags = const <String>[]}) async {
    await super.logMood(mood: mood, note: note, tags: tags);
    return const MoodSaved(xpEarned: 10, streak: 1, pending: true);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('isOfflineError', () {
    test('no internet and timeouts are offline', () {
      expect(isOfflineError(const SocketException('Failed host lookup')),
          isTrue);
      expect(isOfflineError(TimeoutException('slow')), isTrue);
      expect(
          isOfflineError(Exception(
              'ClientException with SocketException: Failed host lookup')),
          isTrue);
    });

    test('an answer from the server is not offline', () {
      expect(isOfflineError(const PostgrestException(message: 'denied')),
          isFalse);
      expect(isOfflineError(const AuthException('bad password')), isFalse);
      expect(isOfflineError(StateError('bug')), isFalse);
    });
  });

  test('newId makes version 4 UUIDs', () {
    final RegExp uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    for (int i = 0; i < 20; i++) {
      expect(newId(), matches(uuid));
    }
    expect(newId(), isNot(newId()));
  });

  group('OfflineStore.load', () {
    test('saves what the server returns and uses it offline', () async {
      final OfflineStore store = await newStore();
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'title': 'Box breathing'}
      ];
      expect(await store.load('articles', () async => rows), rows);
      expect(store.status.offline, isFalse);

      final dynamic saved = await store.load('articles', noInternet);
      expect(saved, rows);
      expect(store.status.offline, isTrue);
      expect(store.status.savedAt, isNotNull);

      // Back online.
      await store.load('articles', () async => rows);
      expect(store.status.offline, isFalse);
    });

    test('offline with nothing saved still fails', () async {
      final OfflineStore store = await newStore();
      await expectLater(store.load('rewards', noInternet),
          throwsA(isA<SocketException>()));
      expect(store.status.offline, isTrue);
    });

    test('a server error is not hidden by the saved copy', () async {
      final OfflineStore store = await newStore();
      await store.load('profile', () async => <String, dynamic>{'xp': 5});
      await expectLater(
          store.load('profile',
              () async => throw const PostgrestException(message: 'denied')),
          throwsA(isA<PostgrestException>()));
    });

    test("one user's saved data is not shown to another", () async {
      await (await newStore('u1'))
          .load('profile', () async => <String, dynamic>{'username': 'Amani'});
      final OfflineStore other = await newStore('u2');
      await expectLater(
          other.load('profile', noInternet), throwsA(isA<SocketException>()));
    });

    test('signing out removes the saved data', () async {
      final OfflineStore store = await newStore();
      await store.load('profile', () async => <String, dynamic>{'xp': 1});
      await store.addPending(const PendingAction(
          id: 'a', kind: 'mood', data: <String, dynamic>{'mood': 3}));
      await store.clearUser('u1');
      expect(store.saved('profile'), isNull);
      expect(store.pending(), isEmpty);
      expect(store.status.pending, 0);
    });
  });

  group('sync queue', () {
    PendingAction mood(String id) => PendingAction(
        id: id, kind: 'mood', data: <String, dynamic>{'id': id, 'mood': 3});

    test('sends oldest first and stops when still offline', () async {
      final OfflineStore store = await newStore();
      final List<String> sent = <String>[];
      bool online = false;
      int synced = 0;
      store.onSynced = () => synced++;
      store.register('mood', (Map<String, dynamic> d) async {
        if (!online && d['id'] == 'b') await noInternet();
        sent.add(d['id'] as String);
      });
      for (final String id in <String>['a', 'b', 'c']) {
        await store.addPending(mood(id));
      }
      expect(store.status.pending, 3);

      expect(await store.flush(), 1);
      expect(sent, <String>['a']);
      expect(store.pending().map((PendingAction a) => a.id), <String>['b', 'c']);
      expect(store.status.offline, isTrue);
      expect(store.status.pending, 2);

      online = true;
      expect(await store.flush(), 2);
      expect(sent, <String>['a', 'b', 'c']);
      expect(store.pending(), isEmpty);
      expect(store.status.pending, 0);
      expect(synced, 2);
    });

    test('already saved counts as sent; rejected is dropped', () async {
      final OfflineStore store = await newStore();
      store.register('mood', (Map<String, dynamic> d) async {
        if (d['id'] == 'dup') {
          throw const PostgrestException(message: 'duplicate', code: '23505');
        }
        if (d['id'] == 'old') {
          throw const PostgrestException(message: 'too old', code: '23514');
        }
      });
      await store.addPending(mood('dup'));
      await store.addPending(mood('old'));
      await store.addPending(mood('ok'));
      expect(await store.flush(), 2);
      expect(store.pending(), isEmpty);
    });

    test('an expired login waits instead of losing the check-in', () async {
      final OfflineStore store = await newStore();
      store.register(
          'mood',
          (Map<String, dynamic> d) async => throw const PostgrestException(
              message: 'JWT expired', code: 'PGRST301'));
      await store.addPending(mood('a'));
      expect(await store.flush(), 0);
      expect(store.pending().length, 1);
    });
  });

  group('currentStreak', () {
    // Tuesday 13 Oct 2026, 10:00 in Nairobi.
    final DateTime now = DateTime.utc(2026, 10, 13, 7);
    DateTime day(int d) => DateTime.utc(2026, 10, d);

    test('a streak that ended yesterday or today still counts', () {
      expect(
          currentStreak(streak: 4, lastCheckin: day(13), now: now), 4);
      expect(
          currentStreak(streak: 4, lastCheckin: day(12), now: now), 4);
    });

    test('a streak that ended before yesterday is over', () {
      expect(
          currentStreak(streak: 5, lastCheckin: day(11), now: now), 0);
      expect(currentStreak(streak: 0, now: now), 0);
    });

    test('check-ins waiting to sync are added', () {
      // Server: 9-11 Oct. Offline: 12 and 13 Oct.
      expect(
          currentStreak(
              streak: 3,
              lastCheckin: day(11),
              pendingDays: <DateTime>{day(12), day(13)},
              now: now),
          5);
      expect(
          currentStreak(
              streak: 0, pendingDays: <DateTime>{day(13)}, now: now),
          1);
    });
  });

  group('crisis check on the phone', () {
    test('uses the same phrases as the chat Edge Function', () {
      final String ts =
          File('supabase/functions/chat/crisis.ts').readAsStringSync();
      final String list = ts.substring(
          ts.indexOf('CRISIS_PHRASES'), ts.indexOf('];'));
      final List<String> server = <String>[
        for (final RegExpMatch m in RegExp(r'"([^"]+)"').allMatches(list))
          m.group(1)!,
      ];
      expect(server, isNotEmpty);
      expect(crisisPhrases, server);
    });

    test('catches the same messages as the server tests', () {
      for (final String t in <String>[
        'I want to kill myself',
        "I don't want to live anymore",
        'nataka kujiua',
        'sitaki kuishi tena',
        'I want to END IT ALL!!!',
        'ntajitia kitanzi leo',
      ]) {
        expect(isCrisisText(t), isTrue, reason: t);
      }
      for (final String t in <String>[
        "I'm stressed about exams",
        'this assignment is killing me',
        'nina huzuni leo',
        'skill myself up',
      ]) {
        expect(isCrisisText(t), isFalse, reason: t);
      }
    });
  });

  testWidgets('offline, a crisis message still opens the helplines',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChatScreen(
          backend: OfflineBackend(),
          progress: FakeProgress(
              const HomeSummary(username: 'A', xp: 0, streak: 0))),
    ));
    await tester.enterText(
        find.byKey(const Key('chat-input')), 'I want to end it all');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(find.text("You don't have to go through this alone"),
        findsOneWidget);
    expect(find.textContaining('Kenya Red Cross'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('offline, without saved helplines, the emergency numbers show',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChatScreen(backend: OfflineBackend()),
    ));
    await tester.enterText(find.byKey(const Key('chat-input')), 'nataka kujiua');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('999'), findsOneWidget);
    expect(find.textContaining('112'), findsOneWidget);
  });

  testWidgets('offline, an ordinary message says Chipu needs the internet',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ChatScreen(backend: OfflineBackend()),
    ));
    await tester.enterText(
        find.byKey(const Key('chat-input')), "I'm stressed about exams");
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text("You don't have to go through this alone"), findsNothing);
  });

  testWidgets('a check-in made offline says it is saved on the phone',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MoodScreen(repository: OfflineProgress(), initialMood: 4),
    ));
    await tester.tap(find.byKey(const Key('save-mood')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-pending')), findsOneWidget);
    expect(find.textContaining('Saved on your phone'), findsOneWidget);
  });

  group('offline banner', () {
    Widget banner(ConnectionStatus status, {String language = 'en'}) =>
        MaterialApp(
          theme: AppTheme.light(),
          home: LanguageScope(
            language: language,
            child: Scaffold(
                body: OfflineBanner(status: status, onRetry: () {})),
          ),
        );

    testWidgets('hidden while online with nothing waiting', (tester) async {
      await tester.pumpWidget(banner(ConnectionStatus()));
      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });

    testWidgets('shows when the data was saved and what is waiting',
        (tester) async {
      final DateTime savedAt = DateTime.now().toUtc();
      final ConnectionStatus status = ConnectionStatus()
        ..markOffline(savedAt)
        ..setPending(2);
      await tester.pumpWidget(banner(status));
      final String time = OfflineBanner.savedTime('en', savedAt);
      expect(
          find.text(
              "You're offline. Showing what was saved at $time. 2 waiting to sync."),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      status.markOnline();
      await tester.pump();
      expect(find.text('Syncing 2 saved on your phone...'), findsOneWidget);
      status.setPending(0);
      await tester.pump();
      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });

    testWidgets('in Kiswahili', (tester) async {
      await tester.pumpWidget(
          banner(ConnectionStatus()..markOffline(), language: 'sw'));
      expect(find.text('Huna mtandao.'), findsOneWidget);
      expect(find.text('Jaribu tena'), findsOneWidget);
    });

    test('an older save shows the date too', () {
      final DateTime now = DateTime.utc(2026, 10, 13, 7);
      expect(OfflineBanner.savedTime('en', DateTime.utc(2026, 10, 13, 6, 5), now),
          '09:05');
      expect(OfflineBanner.savedTime('en', DateTime.utc(2026, 10, 12, 6, 5), now),
          '12 Oct 09:05');
    });
  });
}
