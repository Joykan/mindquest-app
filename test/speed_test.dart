import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/offline/offline_store.dart';
import 'package:mindquest/core/widgets/reload_when_visible.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OfflineStore> store() async =>
    OfflineStore(await SharedPreferences.getInstance(), userId: () => 'u1');

/// A server that answers when told to, and counts the requests.
class SlowServer {
  int calls = 0;
  final List<Completer<dynamic>> waiting = <Completer<dynamic>>[];

  Future<dynamic> ask() {
    calls++;
    final Completer<dynamic> c = Completer<dynamic>();
    waiting.add(c);
    return c.future;
  }

  void answer(dynamic value) {
    for (final Completer<dynamic> c in waiting) {
      c.complete(value);
    }
    waiting.clear();
  }
}

/// Opens the app once (online) so a copy is saved, like a previous day.
Future<void> savedFromLastTime(dynamic value) async {
  await (await store()).load('home', () async => value);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('opening the app shows saved data at once', () {
    test('the saved copy comes first, the server is asked in the background',
        () async {
      await savedFromLastTime(<String, dynamic>{'xp': 10});
      final OfflineStore s = await store(); // the app starts again
      int reloads = 0;
      s.onRefreshed = () => reloads++;
      final SlowServer server = SlowServer();

      // Without waiting for the (slow) server.
      expect(await s.load('home', server.ask), <String, dynamic>{'xp': 10});
      expect(server.calls, 1);

      server.answer(<String, dynamic>{'xp': 25});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(reloads, 1);

      // The reload gets the new data without asking the server again.
      expect(await s.load('home', server.ask), <String, dynamic>{'xp': 25});
      expect(server.calls, 1);

      // After that, loads ask the server as usual.
      final Future<dynamic> next = s.load('home', server.ask);
      expect(server.calls, 2);
      server.answer(<String, dynamic>{'xp': 30});
      expect(await next, <String, dynamic>{'xp': 30});
    });

    test('nothing changed: no reload', () async {
      await savedFromLastTime(<String, dynamic>{'xp': 10});
      final OfflineStore s = await store();
      int reloads = 0;
      s.onRefreshed = () => reloads++;
      await s.load('home', () async => <String, dynamic>{'xp': 10});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(reloads, 0);
    });

    test('offline at start: the saved copy and the offline banner', () async {
      await savedFromLastTime(<String, dynamic>{'xp': 10});
      final OfflineStore s = await store();
      expect(
          await s.load('home',
              () async => throw const SocketException('Failed host lookup')),
          <String, dynamic>{'xp': 10});
      await Future<void>.delayed(Duration.zero);
      expect(s.status.offline, isTrue);
      expect(s.status.savedAt, isNotNull);
    });

    test('nothing saved yet: waits for the server as before', () async {
      final OfflineStore s = await store();
      final SlowServer server = SlowServer();
      bool done = false;
      final Future<dynamic> f = s.load('home', server.ask).then((dynamic v) {
        done = true;
        return v;
      });
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      server.answer(<String, dynamic>{'xp': 1});
      expect(await f, <String, dynamic>{'xp': 1});
    });

    test('a change made by the user is never hidden by an older copy',
        () async {
      await savedFromLastTime(<String, dynamic>{'xp': 10});
      final OfflineStore s = await store();
      s.onRefreshed = () {};
      await s.load('home', () async => <String, dynamic>{'xp': 20});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // A check-in is made: the next load must ask the server.
      await s.addPending(const PendingAction(
          id: 'm1', kind: 'mood', data: <String, dynamic>{'mood': 4}));
      final SlowServer server = SlowServer();
      final Future<dynamic> next = s.load('home', server.ask);
      expect(server.calls, 1);
      server.answer(<String, dynamic>{'xp': 30});
      expect(await next, <String, dynamic>{'xp': 30});
    });
  });

  test('two screens asking at once make one request', () async {
    final OfflineStore s = await store();
    final SlowServer server = SlowServer();
    final Future<dynamic> a = s.load('profile', server.ask);
    final Future<dynamic> b = s.load('profile', server.ask);
    expect(server.calls, 1);
    server.answer(<String, dynamic>{'username': 'Amani'});
    expect(await a, await b);
  });

  testWidgets('a hidden tab waits and reloads when it is shown',
      (tester) async {
    final ValueNotifier<int> signal = ValueNotifier<int>(0);
    final ValueNotifier<bool> shown = ValueNotifier<bool>(false);
    int loads = 0;
    await tester.pumpWidget(ValueListenableBuilder<bool>(
      valueListenable: shown,
      builder: (context, visible, _) => TickerMode(
          enabled: visible, child: _Tab(signal: signal, onLoad: () => loads++)),
    ));

    signal.value++; // progress changed while the tab is hidden
    await tester.pump();
    expect(loads, 0);

    shown.value = true; // the student opens the tab
    await tester.pump();
    await tester.pump();
    expect(loads, 1);

    signal.value++; // visible: reloads at once
    await tester.pump();
    expect(loads, 2);
  });
}

class _Tab extends StatefulWidget {
  const _Tab({required this.signal, required this.onLoad});

  final Listenable signal;
  final VoidCallback onLoad;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with ReloadWhenVisible<_Tab> {
  @override
  Listenable? get reloadSignal => widget.signal;

  @override
  Future<void> reloadNow() async => widget.onLoad();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
