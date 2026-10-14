import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';
import 'reminders.dart';

/// Daily reminders with flutter_local_notifications (Android).
///
/// Reminders are scheduled in Nairobi time, the same day boundary the app and
/// the database use. "Inexact" alarms are used, so no special alarm
/// permission is needed; Android may show a reminder a few minutes late.
/// After the phone restarts the plugin schedules them again
/// (ScheduledNotificationBootReceiver in AndroidManifest.xml).
class LocalNotificationScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  tz.Location? _nairobi;

  static const String _payload = 'mood';

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'daily_reminder',
    'Daily check-in reminder',
    channelDescription: 'A gentle reminder from Chipu to log your mood.',
    icon: 'ic_notification',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    // On a locked phone only "MindQuest" shows, not the message.
    visibility: NotificationVisibility.private,
  );

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> init(void Function() onTap) async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    _nairobi = tz.getLocation('Africa/Nairobi');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        if (r.payload == _payload) onTap();
      },
    );
  }

  @override
  Future<bool> launchedFromReminder() async {
    if (!supported) return false;
    final NotificationAppLaunchDetails? d =
        await _plugin.getNotificationAppLaunchDetails();
    return (d?.didNotificationLaunchApp ?? false) &&
        d?.notificationResponse?.payload == _payload;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    final tz.Location? nairobi = _nairobi;
    if (!supported || nairobi == null) return;
    await _plugin.cancelAll();
    for (final PlannedReminder r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime(
            nairobi, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        notificationDetails: const NotificationDetails(android: _android),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload,
      );
    }
  }

  @override
  Future<void> showNow(PlannedReminder reminder) async {
    if (!supported || _nairobi == null) return;
    await _plugin.show(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: const NotificationDetails(android: _android),
      payload: _payload,
    );
  }

  static const AndroidNotificationDetails _badge = AndroidNotificationDetails(
    'badges',
    'Badges',
    channelDescription: 'When you earn a new badge.',
    icon: 'ic_notification',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  Future<void> showBadge(int id, String title, String body) async {
    if (!supported || _nairobi == null) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _badge),
    );
  }
}
