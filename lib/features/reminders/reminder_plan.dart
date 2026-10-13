import '../../core/l10n/tr.dart';
import '../home/progress_repository.dart';

/// One daily reminder, ready to be scheduled.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Notification id (1000 + day number), so they can all be replaced.
  final int id;

  /// When to show it, as Nairobi wall-clock time (year, month, day, hour,
  /// minute; the time zone of this DateTime is ignored).
  final DateTime at;
  final String title;
  final String body;
}

/// What Chipu says, one per weekday (Monday first) so it doesn't repeat
/// every day. Gentle, no guilt, and nothing private: the text can show on
/// the lock screen.
const List<(String, String)> reminderMessages = <(String, String)>[
  (
    'How was your day? Tap to check in. 🌱',
    'Siku yako imekuwaje? Gusa urekodi hisia zako. 🌱'
  ),
  (
    'A quick check-in keeps your streak growing. 🔥',
    'Kurekodi hisia kila siku kunakuza mfululizo wako. 🔥'
  ),
  (
    'Chipu is here. How are you feeling right now?',
    'Chipu yuko hapa. Unajisikiaje sasa hivi?'
  ),
  (
    'Pause for a moment. How is your mind today?',
    'Pumzika kidogo. Akili yako inajisikiaje leo?'
  ),
  (
    'One tap to log your mood, +10 XP. ✨',
    'Gusa mara moja urekodi hisia zako, +10 XP. ✨'
  ),
  (
    'Be kind to yourself today. How are you doing?',
    'Kumbuka kujitunza leo. Hali yako ikoje?'
  ),
  (
    'Your sprout is waiting! Check in for today. 🌿',
    'Chipukizi lako linakusubiri! Rekodi hisia za leo. 🌿'
  ),
];

/// How many days ahead reminders are scheduled. They are planned again each
/// time the app opens, so they only stop if MindQuest isn't opened for two
/// weeks (no nagging someone who has stopped using it).
const int reminderDaysAhead = 14;

/// Plans the next reminders at [hour]:[minute] Nairobi time. Today is
/// skipped if the user has already checked in or the time has passed.
List<PlannedReminder> planReminders({
  required int hour,
  required int minute,
  required bool checkedInToday,
  required String language,
  DateTime? now,
  int days = reminderDaysAhead,
}) {
  final DateTime n = nairobiNow(now);
  final List<PlannedReminder> plan = <PlannedReminder>[];
  for (int i = 0; i < days; i++) {
    final DateTime at = DateTime.utc(n.year, n.month, n.day + i, hour, minute);
    if (i == 0 && (checkedInToday || !at.isAfter(n))) continue;
    final (String en, String sw) = reminderMessages[at.weekday - 1];
    plan.add(PlannedReminder(
      id: 1000 + i,
      at: at,
      title: 'MindQuest',
      body: tr(language, en, sw),
    ));
  }
  return plan;
}
