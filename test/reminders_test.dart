import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/l10n/tr.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/reminders/reminder_plan.dart';
import 'package:mindquest/features/reminders/reminder_widgets.dart';
import 'package:mindquest/features/reminders/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

// Tuesday 13 Oct 2026, 10:00 in Nairobi.
final DateTime morning = DateTime.utc(2026, 10, 13, 7);

Future<ReminderController> controller(FakeScheduler scheduler,
    {DateTime? now}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ReminderController c =
      ReminderController(prefs, scheduler, now: () => now ?? morning);
  await c.init();
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('planReminders', () {
    test('the next 14 days at the chosen time, starting today', () {
      final List<PlannedReminder> plan = planReminders(
          hour: 19,
          minute: 0,
          checkedInToday: false,
          language: 'en',
          now: morning);
      expect(plan.length, 14);
      expect(plan.first.at, DateTime.utc(2026, 10, 13, 19));
      expect(plan.last.at, DateTime.utc(2026, 10, 26, 19));
      expect(plan.map((PlannedReminder r) => r.id).toSet().length, 14);
      // 13 Oct 2026 is a Tuesday: the second message.
      expect(plan.first.body, reminderMessages[1].$1);
      expect(plan.first.title, 'MindQuest');
    });

    test('skips today after a check-in, or when the time has passed', () {
      expect(
          planReminders(
                  hour: 19,
                  minute: 0,
                  checkedInToday: true,
                  language: 'en',
                  now: morning)
              .first
              .at,
          DateTime.utc(2026, 10, 14, 19));
      expect(
          planReminders(
                  hour: 8,
                  minute: 30,
                  checkedInToday: false,
                  language: 'en',
                  now: morning)
              .first
              .at,
          DateTime.utc(2026, 10, 14, 8, 30));
    });

    test('in Kiswahili', () {
      final PlannedReminder r = planReminders(
              hour: 19,
              minute: 0,
              checkedInToday: false,
              language: 'sw',
              now: morning)
          .first;
      expect(r.body, reminderMessages[1].$2);
    });

    test('every weekday has a message in both languages', () {
      expect(reminderMessages.length, 7);
      for (final (String en, String sw) in reminderMessages) {
        expect(en, isNotEmpty);
        expect(sw, isNotEmpty);
        expect(en, isNot(sw));
      }
    });
  });

  group('ReminderController', () {
    test('off by default; turning on asks permission and schedules', () async {
      final FakeScheduler s = FakeScheduler();
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      expect(c.enabled, isFalse);
      expect(c.shouldAsk, isTrue);
      expect(s.scheduled, isEmpty);

      expect(await c.enable(), isTrue);
      expect(s.permissionAsks, 1);
      expect(c.enabled, isTrue);
      expect(c.shouldAsk, isFalse);
      expect(s.scheduled.length, 14);
      expect(s.scheduled.first.at.hour, 19);
    });

    test('blocked notifications leave reminders off', () async {
      final FakeScheduler s = FakeScheduler(allowed: false);
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      expect(await c.enable(), isFalse);
      expect(c.enabled, isFalse);
      expect(s.scheduled, isEmpty);
    });

    test('a check-in today moves the first reminder to tomorrow', () async {
      final FakeScheduler s = FakeScheduler();
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      await c.enable();
      await c.checkedInToday();
      expect(s.scheduled.length, 13);
      expect(s.scheduled.first.at, DateTime.utc(2026, 10, 14, 19));
    });

    test('the time can be changed', () async {
      final FakeScheduler s = FakeScheduler();
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      await c.enable();
      await c.setTime(const TimeOfDay(hour: 20, minute: 30));
      expect(c.time, const TimeOfDay(hour: 20, minute: 30));
      expect(s.scheduled.first.at, DateTime.utc(2026, 10, 13, 20, 30));
    });

    test('follows the language, and stops after signing out', () async {
      final FakeScheduler s = FakeScheduler();
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      await c.enable();
      await c.update(signedIn: true, language: 'sw');
      expect(s.scheduled.first.body, reminderMessages[1].$2);
      await c.update(signedIn: false, language: 'sw');
      expect(s.scheduled, isEmpty);
    });

    test('turning off cancels the reminders', () async {
      final FakeScheduler s = FakeScheduler();
      final ReminderController c = await controller(s);
      await c.update(signedIn: true, language: 'en');
      await c.enable();
      await c.disable();
      expect(s.scheduled, isEmpty);
      expect(c.shouldAsk, isFalse);
    });

    test('"Not now" stops the question without turning them on', () async {
      final ReminderController c = await controller(FakeScheduler());
      await c.dismiss();
      expect(c.shouldAsk, isFalse);
      expect(c.enabled, isFalse);
    });

    test('tapping a reminder opens the mood check-in', () async {
      final FakeScheduler s = FakeScheduler(fromReminder: true);
      final ReminderController c = await controller(s);
      expect(c.launchLocation, '/mood');
      String? opened;
      c.onOpen = (String location) => opened = location;
      s.tap!();
      expect(opened, '/mood');
    });
  });

  testWidgets('Home asks once, and Turn on schedules the reminders',
      (tester) async {
    final FakeScheduler s = FakeScheduler();
    final ReminderController c = await controller(s);
    await c.update(signedIn: true, language: 'en');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ReminderPrompt(reminders: c)),
    ));
    expect(find.text('Want a daily reminder?'), findsOneWidget);
    expect(find.textContaining('19:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-turn-on')));
    await tester.pumpAndSettle();
    expect(s.scheduled, isNotEmpty);
    expect(find.byKey(const Key('reminder-prompt')), findsNothing);
    expect(
        find.textContaining('Chipu will remind you at 19:00'), findsOneWidget);
  });

  testWidgets('Profile setting in Kiswahili shows the time when on',
      (tester) async {
    final FakeScheduler s = FakeScheduler();
    final ReminderController c = await controller(s);
    await c.update(signedIn: true, language: 'sw');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: LanguageScope(
        language: 'sw',
        child: Scaffold(body: ReminderSettingsTile(reminders: c)),
      ),
    ));
    expect(find.text('Kikumbusho cha kila siku'), findsOneWidget);
    expect(find.text('Kimezimwa'), findsOneWidget);
    expect(find.byKey(const Key('reminder-time')), findsNothing);

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();
    expect(c.enabled, isTrue);
    expect(find.byKey(const Key('reminder-time')), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-test')));
    await tester.pump();
    expect(s.shown.single.body, reminderMessages[1].$2);
  });
}
