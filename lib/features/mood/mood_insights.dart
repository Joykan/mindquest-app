import '../home/progress_repository.dart';
import 'mood_tags.dart';

/// One short, plain-language observation about the user's moods.
/// Insights describe patterns ("tend to", "often"); they never diagnose.
class MoodInsight {
  const MoodInsight({
    required this.id,
    required this.emoji,
    required this.title,
    required this.body,
    this.needsSupport = false,
  });

  /// Stable name of the rule, for tests and analytics.
  final String id;
  final String emoji;
  final String title;
  final String body;

  /// A run of hard days: show the helplines with this insight.
  final bool needsSupport;
}

/// Check-ins needed before any insight is shown.
const int insightMinimumCheckIns = 3;

const List<String> _weekdayNames = <String>[
  'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays',
];

/// Chat intents that are feelings, and how to name them in an insight.
const Map<String, String> chatFeelingNames = <String, String>{
  'feel_stressed': 'Stress',
  'feel_anxious': 'Anxiety',
  'feel_sad': 'Feeling low',
  'feel_good': 'Feeling good',
};

/// Common words left out of note-word insights (English and Kiswahili).
const Set<String> _stopWords = <String>{
  'the', 'and', 'but', 'for', 'with', 'that', 'this', 'was', 'were', 'are', 'have', 'has',
  'had', 'not', 'just', 'been', 'from', 'about', 'feel', 'feeling', 'felt', 'today', 'really',
  'very', 'too', 'all', 'so', 'my', 'me', 'it', 'its', 'im', 'i', 'a', 'an', 'to', 'of', 'in',
  'on', 'at', 'is', 'be', 'got', 'get', 'day', 'bit', 'some', 'lot', 'more', 'much', 'what',
  'when', 'then', 'than', 'they', 'them', 'out', 'still', 'again', 'because', 'cause', 'coz',
  'leo', 'na', 'ya', 'wa', 'za', 'la', 'kwa', 'ni', 'nime', 'sana', 'tu', 'lakini', 'pia',
  'hii', 'hiyo', 'kuna', 'siku', 'mimi', 'yangu', 'wangu', 'kwenye', 'baada', 'kabla',
};

double _average(Iterable<int> values) =>
    values.isEmpty ? 0 : values.reduce((int a, int b) => a + b) / values.length;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Builds insights from up to 30 days of check-ins ([entries], newest first,
/// Nairobi time) and this week's feelings from the chat ([chatFeelings]:
/// intent -> count). The most important insight comes first; a run of hard
/// days always comes first.
List<MoodInsight> buildInsights(
  List<MoodEntry> entries, {
  DateTime? now,
  Map<String, int> chatFeelings = const <String, int>{},
}) {
  if (entries.length < insightMinimumCheckIns) return const <MoodInsight>[];
  final DateTime today = _day(now ?? nairobiNow());
  final List<MoodInsight> out = <MoodInsight>[];

  // Average mood per day.
  final Map<DateTime, List<int>> byDay = <DateTime, List<int>>{};
  for (final MoodEntry e in entries) {
    byDay.putIfAbsent(_day(e.at), () => <int>[]).add(e.mood);
  }
  double dayAverage(DateTime d) => _average(byDay[d]!);

  // 1. Three or more hard days in a row, up to today or yesterday.
  int hardRun = 0;
  DateTime d = byDay.containsKey(today) ? today : today.subtract(const Duration(days: 1));
  while (byDay.containsKey(d) && dayAverage(d) <= 2) {
    hardRun++;
    d = d.subtract(const Duration(days: 1));
  }
  if (hardRun >= 3) {
    out.add(MoodInsight(
      id: 'hard_days',
      emoji: '💚',
      title: "You've had $hardRun hard days in a row",
      body: "That's a lot to carry on your own. Talking to someone you trust, or to a "
          'counsellor, can really help. Free helplines are one tap away.',
      needsSupport: true,
    ));
  }

  // 2. This week compared with last week.
  final DateTime weekStart = today.subtract(const Duration(days: 6));
  final DateTime lastWeekStart = today.subtract(const Duration(days: 13));
  final List<int> thisWeek = <int>[
    for (final MoodEntry e in entries)
      if (!_day(e.at).isBefore(weekStart)) e.mood,
  ];
  final List<int> lastWeek = <int>[
    for (final MoodEntry e in entries)
      if (!_day(e.at).isBefore(lastWeekStart) && _day(e.at).isBefore(weekStart)) e.mood,
  ];
  if (thisWeek.length >= 2 && lastWeek.length >= 2) {
    final double change = _average(thisWeek) - _average(lastWeek);
    if (change >= 0.5) {
      out.add(const MoodInsight(
        id: 'trend_up',
        emoji: '📈',
        title: 'Brighter than last week',
        body: 'Your moods this week are higher than last week. Notice what has been helping.',
      ));
    } else if (change <= -0.5) {
      out.add(const MoodInsight(
        id: 'trend_down',
        emoji: '🌧️',
        title: 'A harder week than last',
        body: 'Your moods this week are lower than last week. Be gentle with yourself, '
            'and remember Chipu is here to talk.',
      ));
    } else {
      out.add(const MoodInsight(
        id: 'trend_steady',
        emoji: '⚖️',
        title: 'A steady week',
        body: 'Your moods this week are about the same as last week.',
      ));
    }
  }

  // 3. Best and hardest day of the week (needs 2+ check-ins on each).
  final Map<int, List<int>> byWeekday = <int, List<int>>{};
  for (final MoodEntry e in entries) {
    byWeekday.putIfAbsent(e.at.weekday, () => <int>[]).add(e.mood);
  }
  final List<MapEntry<int, double>> weekdays = <MapEntry<int, double>>[
    for (final MapEntry<int, List<int>> w in byWeekday.entries)
      if (w.value.length >= 2) MapEntry<int, double>(w.key, _average(w.value)),
  ]..sort((MapEntry<int, double> a, MapEntry<int, double> b) => b.value.compareTo(a.value));
  if (weekdays.length >= 2 && weekdays.first.value - weekdays.last.value >= 1) {
    out.add(MoodInsight(
      id: 'weekday',
      emoji: '📅',
      title: 'Your week has a pattern',
      body: 'You tend to feel best on ${_weekdayNames[weekdays.first.key - 1]} '
          'and lowest on ${_weekdayNames[weekdays.last.key - 1]}.',
    ));
  }

  // 4. Time of day (needs 2+ check-ins in at least two parts of the day).
  String part(int hour) => hour >= 5 && hour < 12
      ? 'mornings'
      : hour >= 12 && hour < 17
          ? 'afternoons'
          : 'evenings';
  final Map<String, List<int>> byPart = <String, List<int>>{};
  for (final MoodEntry e in entries) {
    byPart.putIfAbsent(part(e.at.hour), () => <int>[]).add(e.mood);
  }
  final List<MapEntry<String, double>> parts = <MapEntry<String, double>>[
    for (final MapEntry<String, List<int>> p in byPart.entries)
      if (p.value.length >= 2) MapEntry<String, double>(p.key, _average(p.value)),
  ]..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));
  if (parts.length >= 2 && parts.first.value - parts.last.value >= 0.75) {
    out.add(MoodInsight(
      id: 'time_of_day',
      emoji: parts.first.key == 'mornings' ? '🌅' : (parts.first.key == 'evenings' ? '🌙' : '☀️'),
      title: 'Your ${parts.first.key} feel better',
      body: 'You usually feel better in the ${parts.first.key} than in the ${parts.last.key}.',
    ));
  }

  // 5. Tags that keep coming up on low and on good days (2+ check-ins).
  String? commonTag(bool Function(int mood) which) {
    final Map<String, int> counts = <String, int>{};
    for (final MoodEntry e in entries) {
      if (!which(e.mood)) continue;
      for (final String t in e.tags.toSet()) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> top = counts.entries.where((MapEntry<String, int> c) => c.value >= 2).toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return top.isEmpty ? null : top.first.key;
  }

  final String? lowTag = commonTag((int m) => m <= 2);
  final String? goodTag = commonTag((int m) => m >= 4);
  final MoodTag? low = lowTag == null ? null : moodTagById(lowTag);
  final MoodTag? good = goodTag == null ? null : moodTagById(goodTag);
  if (low != null) {
    out.add(MoodInsight(
      id: 'low_tag',
      emoji: low.emoji,
      title: '${low.en} weighs on you',
      body: 'Your low days are often about ${low.en.toLowerCase()}. '
          'Talking it through with Chipu or someone you trust can help.',
    ));
  }
  if (good != null && goodTag != lowTag) {
    out.add(MoodInsight(
      id: 'good_tag',
      emoji: good.emoji,
      title: '${good.en} lifts you up',
      body: 'Your good days are often about ${good.en.toLowerCase()}. Make room for more of it.',
    ));
  }

  // 6. Words that keep coming up in notes on low and on good days.
  String? commonWord(bool Function(int mood) which) {
    final Map<String, int> counts = <String, int>{};
    for (final MoodEntry e in entries) {
      if (!which(e.mood) || e.note == null) continue;
      final Set<String> words = e.note!
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((String w) => w.length >= 3 && !_stopWords.contains(w))
          .toSet(); // count each note once
      for (final String w in words) {
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> top = counts.entries.where((MapEntry<String, int> c) => c.value >= 2).toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return top.isEmpty ? null : top.first.key;
  }

  final String? lowWord = commonWord((int m) => m <= 2);
  final String? goodWord = commonWord((int m) => m >= 4);
  if (lowWord != null && lowWord != lowTag) {
    out.add(MoodInsight(
      id: 'low_word',
      emoji: '📝',
      title: 'Something that weighs on you',
      body: 'Your notes on low days often mention "$lowWord". '
          'Chipu can help you work through it, or try a breathing exercise.',
    ));
  }
  if (goodWord != null && goodWord != lowWord && goodWord != goodTag) {
    out.add(MoodInsight(
      id: 'good_word',
      emoji: '🌱',
      title: 'Something that lifts you',
      body: 'Your notes on good days often mention "$goodWord". Make room for more of it.',
    ));
  }

  // 7. Feelings that came up in the chat this week.
  final List<MapEntry<String, int>> feelings = chatFeelings.entries
      .where((MapEntry<String, int> f) => chatFeelingNames.containsKey(f.key) && f.value >= 2)
      .toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
  if (feelings.isNotEmpty) {
    final MapEntry<String, int> top = feelings.first;
    out.add(MoodInsight(
      id: 'chat_feeling',
      emoji: '💬',
      title: '${chatFeelingNames[top.key]} came up in your chats',
      body: top.key == 'feel_good'
          ? 'You told Chipu you felt good ${top.value} times this week. Nice!'
          : '${chatFeelingNames[top.key]} came up ${top.value} times in your chats this week. '
              'A breathing exercise can help. Just ask Chipu.',
    ));
  }

  // 8. Check-in habit over the last 7 days.
  final int daysThisWeek = byDay.keys.where((DateTime day) => !day.isBefore(weekStart)).length;
  if (daysThisWeek >= 5) {
    out.add(MoodInsight(
      id: 'habit',
      emoji: '🔥',
      title: 'Great check-in habit',
      body: 'You checked in on $daysThisWeek of the last 7 days. '
          'Knowing how you feel is the first step to feeling better.',
    ));
  }

  return out;
}
