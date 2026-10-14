import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/home/progress_repository.dart';
import 'package:mindquest/features/reminders/reminder_plan.dart';
import 'package:mindquest/features/reminders/reminders.dart';

/// In-memory stand-in for the Supabase progress tables.
class FakeProgress implements ProgressRepository {
  FakeProgress(this.summary);

  HomeSummary summary;
  final List<(int, String?)> logged = <(int, String?)>[];
  final List<List<String>> loggedTags = <List<String>>[];

  List<MoodEntry> history = <MoodEntry>[];
  final List<String> deleted = <String>[];

  @override
  Future<HomeSummary> loadHome() async => summary;

  @override
  Future<List<MoodEntry>> loadMoodHistory({int days = 30}) async =>
      history.where((MoodEntry e) => !deleted.contains(e.id)).toList();

  @override
  Future<void> deleteMood(String id) async => deleted.add(id);

  Map<String, int> chatFeelings = <String, int>{};

  @override
  Future<Map<String, int>> loadChatFeelings({int days = 7}) async =>
      chatFeelings;

  @override
  Future<MoodSaved> logMood(
      {required int mood,
      String? note,
      List<String> tags = const <String>[]}) async {
    logged.add((mood, note));
    loggedTags.add(tags);
    history = <MoodEntry>[
      MoodEntry(
          id: 'new${logged.length}',
          mood: mood,
          at: nairobiNow(),
          note: note,
          tags: tags),
      ...history,
    ];
    return MoodSaved(xpEarned: logged.length == 1 ? 10 : 0, streak: 4);
  }

  @override
  Future<List<Helpline>> loadHelplines() async => const <Helpline>[
        Helpline(
            name: 'Kenya Red Cross',
            phone: '1199',
            description: 'Toll-free, 24 hours')
      ];
}

/// Remembers what would be scheduled instead of showing notifications.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.allowed = true, this.fromReminder = false});

  final bool allowed;
  final bool fromReminder;
  List<PlannedReminder> scheduled = <PlannedReminder>[];
  int permissionAsks = 0;
  void Function()? tap;

  @override
  bool get supported => true;

  @override
  Future<void> init(void Function() onTap) async => tap = onTap;

  @override
  Future<bool> launchedFromReminder() async => fromReminder;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allowed;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      scheduled = reminders;

  final List<PlannedReminder> shown = <PlannedReminder>[];

  @override
  Future<void> showNow(PlannedReminder reminder) async => shown.add(reminder);

  final List<String> badgeTitles = <String>[];

  @override
  Future<void> showBadge(int id, String title, String body) async =>
      badgeTitles.add(title);
}
