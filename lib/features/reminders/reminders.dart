import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/progress_repository.dart';
import 'reminder_plan.dart';

/// Shows notifications on the phone. The app uses [LocalNotificationScheduler]
/// (local_notifications.dart); tests use a fake.
abstract class ReminderScheduler {
  /// False where reminders can't be shown (the web build).
  bool get supported;

  /// Sets up the plugin. [onTap] runs when a reminder is tapped while the
  /// app is open or in the background.
  Future<void> init(void Function() onTap);

  /// True if the app was opened by tapping a reminder.
  Future<bool> launchedFromReminder();

  /// Asks for permission to show notifications (Android 13 and newer).
  Future<bool> requestPermission();

  /// Cancels the reminders already scheduled and schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Shows one reminder now ("Send a test reminder" in Profile).
  Future<void> showNow(PlannedReminder reminder);
}

/// The daily check-in reminder (step 10).
///
/// Off until the user turns it on (Home asks once, or in Profile). The next
/// 14 days are scheduled at the chosen time (7 PM by default), skipping
/// today once the user has checked in. Tapping a reminder opens the mood
/// check-in. Settings are kept on this phone.
class ReminderController extends ChangeNotifier {
  ReminderController(this._prefs, this.scheduler, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final ReminderScheduler scheduler;
  final DateTime Function() _now;

  static const String _enabledKey = 'reminder.enabled';
  static const String _hourKey = 'reminder.hour';
  static const String _minuteKey = 'reminder.minute';
  static const String _askedKey = 'reminder.asked';
  static const String _checkedInKey = 'reminder.checked_in_day';

  /// Called with '/mood' when a reminder is tapped.
  void Function(String location)? onOpen;

  /// Set when the app was opened from a reminder, until the router uses it.
  String? launchLocation;

  /// The language of the reminder texts (follows the profile).
  String _language = 'en';
  bool _signedIn = false;

  bool get supported => scheduler.supported;
  bool get enabled => _prefs.getBool(_enabledKey) ?? false;
  TimeOfDay get time => TimeOfDay(
      hour: _prefs.getInt(_hourKey) ?? 19,
      minute: _prefs.getInt(_minuteKey) ?? 0);

  /// The user has said yes or no, so Home stops asking.
  bool get asked => _prefs.getBool(_askedKey) ?? false;

  /// Home shows the "Want a daily reminder?" card.
  bool get shouldAsk => supported && !asked && !enabled;

  String _today() {
    final DateTime d = nairobiNow(_now());
    return '${d.year}-${d.month}-${d.day}';
  }

  bool get _checkedInToday => _prefs.getString(_checkedInKey) == _today();

  Future<void> init() async {
    if (!supported) return;
    await scheduler.init(() => onOpen?.call('/mood'));
    if (await scheduler.launchedFromReminder()) launchLocation = '/mood';
  }

  /// Turns reminders on. Returns false if notifications are blocked.
  Future<bool> enable() async {
    final bool allowed = await scheduler.requestPermission();
    await _prefs.setBool(_askedKey, true);
    await _prefs.setBool(_enabledKey, allowed);
    notifyListeners();
    await reschedule();
    return allowed;
  }

  Future<void> disable() async {
    await _prefs.setBool(_askedKey, true);
    await _prefs.setBool(_enabledKey, false);
    notifyListeners();
    await reschedule();
  }

  /// "Not now" on the Home card.
  Future<void> dismiss() async {
    await _prefs.setBool(_askedKey, true);
    notifyListeners();
  }

  Future<void> setTime(TimeOfDay t) async {
    await _prefs.setInt(_hourKey, t.hour);
    await _prefs.setInt(_minuteKey, t.minute);
    notifyListeners();
    await reschedule();
  }

  /// After a mood check-in: no reminder needed today.
  Future<void> checkedInToday() async {
    await _prefs.setString(_checkedInKey, _today());
    await reschedule();
  }

  /// Keeps reminders in the user's language, and stops them after sign out.
  Future<void> update(
      {required bool signedIn, required String language}) async {
    if (signedIn == _signedIn && language == _language) return;
    _signedIn = signedIn;
    _language = language;
    await reschedule();
  }

  /// Shows today's reminder straight away, to see what it looks like.
  Future<void> sendTest() async {
    final DateTime n = nairobiNow(_now());
    final PlannedReminder r = planReminders(
      hour: 23,
      minute: 59,
      checkedInToday: false,
      language: _language,
      now: DateTime.utc(n.year, n.month, n.day)
          .subtract(const Duration(hours: 3)),
      days: 1,
    ).first;
    await scheduler.showNow(
        PlannedReminder(id: 999, at: r.at, title: r.title, body: r.body));
  }

  /// Plans the next two weeks again (also on every app start).
  Future<void> reschedule() async {
    if (!supported) return;
    final List<PlannedReminder> plan = enabled && _signedIn
        ? planReminders(
            hour: time.hour,
            minute: time.minute,
            checkedInToday: _checkedInToday,
            language: _language,
            now: _now(),
          )
        : const <PlannedReminder>[];
    try {
      await scheduler.replaceAll(plan);
    } catch (e) {
      debugPrint('Reminders could not be scheduled: $e');
    }
  }
}
