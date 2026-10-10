import 'package:mindquest/features/chat/chat_models.dart';
import 'package:mindquest/features/home/progress_repository.dart';

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
  Future<Map<String, int>> loadChatFeelings({int days = 7}) async => chatFeelings;

  @override
  Future<MoodSaved> logMood({required int mood, String? note, List<String> tags = const <String>[]}) async {
    logged.add((mood, note));
    loggedTags.add(tags);
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
