import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/gamification/badge_watcher.dart';
import 'package:mindquest/features/gamification/badges.dart';
import 'package:mindquest/features/reminders/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const RewardBadge firstCheckin = RewardBadge(
    id: 'first_checkin',
    name: 'First Check-in',
    nameSw: 'Kurekodi kwa Kwanza',
    description: 'Log your first mood');
const RewardBadge firstChat = RewardBadge(
    id: 'first_chat',
    name: 'First Chat',
    nameSw: 'Mazungumzo ya Kwanza',
    description: 'Send your first message');

class FakeBadges implements BadgeSource {
  List<RewardBadge> have = <RewardBadge>[];

  @override
  Future<List<RewardBadge>> earned() async => have;
}

Future<(BadgeWatcher, FakeBadges, List<List<RewardBadge>>)> newWatcher() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final FakeBadges source = FakeBadges()..have = <RewardBadge>[firstCheckin];
  final List<List<RewardBadge>> unlocked = <List<RewardBadge>>[];
  final BadgeWatcher w = BadgeWatcher(prefs, source,
      userId: () => 'u1', onUnlocked: unlocked.add);
  return (w, source, unlocked);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('the first check only remembers the badges already earned', () async {
    final (BadgeWatcher w, FakeBadges _, List<List<RewardBadge>> unlocked) =
        await newWatcher();
    await w.check();
    expect(w.hasWaiting, isFalse);
    expect(unlocked, isEmpty);
  });

  test('a badge earned later is announced once', () async {
    final (BadgeWatcher w, FakeBadges source, List<List<RewardBadge>> unlocked) =
        await newWatcher();
    await w.check();
    source.have = <RewardBadge>[firstCheckin, firstChat];
    await w.check();
    expect(w.hasWaiting, isTrue);
    expect(unlocked.single.single.id, 'first_chat');
    expect(w.takeWaiting().single.id, 'first_chat');

    await w.check();
    expect(w.hasWaiting, isFalse, reason: 'not announced twice');
    expect(unlocked.length, 1);
  });

  test('badges already celebrated elsewhere are not announced', () async {
    final (BadgeWatcher w, FakeBadges source, List<List<RewardBadge>> unlocked) =
        await newWatcher();
    await w.check();
    await w.markSeen(<String>['first_chat']);
    source.have = <RewardBadge>[firstCheckin, firstChat];
    await w.check();
    expect(w.hasWaiting, isFalse);
    expect(unlocked, isEmpty);
  });

  test('badge notifications use the user\'s language', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final FakeScheduler s = FakeScheduler();
    final ReminderController c = ReminderController(prefs, s);
    await c.update(signedIn: true, language: 'sw');
    await c.badgeUnlocked(<RewardBadge>[firstChat]);
    expect(s.badgeTitles.single, 'Beji mpya: Mazungumzo ya Kwanza 💬');
  });

  testWidgets('a new badge pops up wherever the user is', (tester) async {
    final (BadgeWatcher w, FakeBadges source, _) = await newWatcher();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: BadgeAlerts(watcher: w, child: const Scaffold(body: Text('Home'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-badge-dialog')), findsNothing);

    source.have = <RewardBadge>[firstCheckin, firstChat];
    await tester.runAsync(w.check);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-badge-dialog')), findsOneWidget);
    expect(find.text('First Chat'), findsOneWidget);
  });
}
