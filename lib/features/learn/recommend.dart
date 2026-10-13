import '../home/progress_repository.dart';
import 'learn_repository.dart';

/// An article picked for the user, with the reason shown under it.
class Recommendation {
  const Recommendation(this.article, this.reason, [this.reasonSw = '']);

  final Article article;

  /// Why it was picked, in English.
  final String reason;

  /// Why it was picked, in Kiswahili.
  final String reasonSw;

  String reasonIn(String language) =>
      language == 'sw' && reasonSw.isNotEmpty ? reasonSw : reason;
}

/// Picks [count] articles for Home from what the user has been feeling.
///
/// Topics in order: feelings from the chat this week (most frequent first),
/// then low recent moods (support), sleep tags (the sleep article), and
/// mindfulness as a default. Unread articles come first.
List<Recommendation> recommendArticles(
  List<Article> articles, {
  List<MoodEntry> recentMoods = const <MoodEntry>[],
  Map<String, int> chatFeelings = const <String, int>{},
  int count = 2,
}) {
  // (category or article title, reason in English, reason in Kiswahili)
  final List<(String, String, String)> wanted = <(String, String, String)>[];

  const Map<String, (String, String, String)> fromFeeling =
      <String, (String, String, String)>{
    'feel_stressed': (
      'stress',
      'Because stress came up in your chats',
      'Kwa sababu msongo ulijitokeza kwenye mazungumzo yako'
    ),
    'feel_anxious': (
      'anxiety',
      'Because worry came up in your chats',
      'Kwa sababu wasiwasi ulijitokeza kwenye mazungumzo yako'
    ),
    'feel_sad': (
      'support',
      'Because you have been feeling low',
      'Kwa sababu umekuwa ukijisikia vibaya'
    ),
  };
  final List<MapEntry<String, int>> feelings = chatFeelings.entries
      .where((MapEntry<String, int> f) =>
          fromFeeling.containsKey(f.key) && f.value > 0)
      .toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
        b.value.compareTo(a.value));
  for (final MapEntry<String, int> f in feelings) {
    wanted.add(fromFeeling[f.key]!);
  }

  if (recentMoods.isNotEmpty) {
    final double avg = recentMoods
            .map((MoodEntry e) => e.mood)
            .reduce((int a, int b) => a + b) /
        recentMoods.length;
    if (avg <= 2.5) {
      wanted.add((
        'support',
        'Because your recent moods have been low',
        'Kwa sababu hisia zako za karibuni zimekuwa chini'
      ));
    }
    final bool sleep =
        recentMoods.any((MoodEntry e) => e.tags.contains('sleep'));
    if (sleep) {
      wanted.add((
        'title:Sleep and your mood',
        'Because sleep came up in your check-ins',
        'Kwa sababu usingizi ulijitokeza kwenye hisia ulizorekodi'
      ));
    }
    final bool school = recentMoods
        .any((MoodEntry e) => e.tags.contains('school') && e.mood <= 3);
    if (school) {
      wanted.add((
        'title:Exam stress: a survival plan',
        'Because school has been on your mind',
        'Kwa sababu masomo yamekuwa akilini mwako'
      ));
    }
  }
  wanted.add((
    'mindfulness',
    'A calm moment for your day',
    'Muda wa utulivu katika siku yako'
  ));

  final List<Recommendation> out = <Recommendation>[];
  final Set<int> used = <int>{};
  bool matches(Article a, String key) => key.startsWith('title:')
      ? a.titleEn == key.substring(6)
      : a.category == key;

  // Unread first, then anything, so there is always something to show.
  for (final bool unreadOnly in <bool>[true, false]) {
    for (final (String key, String reason, String reasonSw) in wanted) {
      if (out.length >= count) return out;
      for (final Article a in articles) {
        if (used.contains(a.id) || (unreadOnly && a.read) || !matches(a, key)) {
          continue;
        }
        out.add(Recommendation(a, reason, reasonSw));
        used.add(a.id);
        break;
      }
    }
  }
  for (final Article a in articles) {
    if (out.length >= count) break;
    if (used.add(a.id)) {
      out.add(Recommendation(
          a, 'Something new to read', 'Kitu kipya cha kusoma'));
    }
  }
  return out;
}
