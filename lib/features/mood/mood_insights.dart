import '../../core/l10n/tr.dart';
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
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
  'Sundays',
];

/// Chat intents that are feelings, and how to name them in an insight.
const Map<String, String> chatFeelingNames = <String, String>{
  'feel_stressed': 'Stress',
  'feel_anxious': 'Anxiety',
  'feel_sad': 'Feeling low',
  'feel_good': 'Feeling good',
};

const Map<String, String> chatFeelingNamesSw = <String, String>{
  'feel_stressed': 'Msongo wa mawazo',
  'feel_anxious': 'Wasiwasi',
  'feel_sad': 'Huzuni',
  'feel_good': 'Kujisikia vizuri',
};

/// Common words left out of note-word insights (English and Kiswahili).
const Set<String> _stopWords = <String>{
  'the',
  'and',
  'but',
  'for',
  'with',
  'that',
  'this',
  'was',
  'were',
  'are',
  'have',
  'has',
  'had',
  'not',
  'just',
  'been',
  'from',
  'about',
  'feel',
  'feeling',
  'felt',
  'today',
  'really',
  'very',
  'too',
  'all',
  'so',
  'my',
  'me',
  'it',
  'its',
  'im',
  'i',
  'a',
  'an',
  'to',
  'of',
  'in',
  'on',
  'at',
  'is',
  'be',
  'got',
  'get',
  'day',
  'bit',
  'some',
  'lot',
  'more',
  'much',
  'what',
  'when',
  'then',
  'than',
  'they',
  'them',
  'out',
  'still',
  'again',
  'because',
  'cause',
  'coz',
  'leo',
  'na',
  'ya',
  'wa',
  'za',
  'la',
  'kwa',
  'ni',
  'nime',
  'sana',
  'tu',
  'lakini',
  'pia',
  'hii',
  'hiyo',
  'kuna',
  'siku',
  'mimi',
  'yangu',
  'wangu',
  'kwenye',
  'baada',
  'kabla',
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
  String language = 'en',
}) {
  if (entries.length < insightMinimumCheckIns) return const <MoodInsight>[];
  String t(String en, String sw) => tr(language, en, sw);
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
  DateTime d = byDay.containsKey(today)
      ? today
      : today.subtract(const Duration(days: 1));
  while (byDay.containsKey(d) && dayAverage(d) <= 2) {
    hardRun++;
    d = d.subtract(const Duration(days: 1));
  }
  if (hardRun >= 3) {
    out.add(MoodInsight(
      id: 'hard_days',
      emoji: '💚',
      title: t("You've had $hardRun hard days in a row",
          'Umekuwa na siku $hardRun ngumu mfululizo'),
      body: t(
          "That's a lot to carry on your own. Talking to someone you trust, or to a "
              'counsellor, can really help. Free helplines are one tap away.',
          'Huo ni mzigo mzito kubeba peke yako. Kuongea na mtu unayemwamini, au na '
              'mshauri, kunaweza kusaidia sana. Nambari za msaada za bure ziko karibu nawe.'),
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
      if (!_day(e.at).isBefore(lastWeekStart) && _day(e.at).isBefore(weekStart))
        e.mood,
  ];
  if (thisWeek.length >= 2 && lastWeek.length >= 2) {
    final double change = _average(thisWeek) - _average(lastWeek);
    if (change >= 0.5) {
      out.add(MoodInsight(
        id: 'trend_up',
        emoji: '📈',
        title: t('Brighter than last week', 'Bora kuliko wiki iliyopita'),
        body: t(
            'Your moods this week are higher than last week. Notice what has been helping.',
            'Hisia zako wiki hii ziko juu kuliko wiki iliyopita. Angalia kinachokusaidia.'),
      ));
    } else if (change <= -0.5) {
      out.add(MoodInsight(
        id: 'trend_down',
        emoji: '🌧️',
        title: t('A harder week than last', 'Wiki ngumu kuliko iliyopita'),
        body: t(
            'Your moods this week are lower than last week. Be gentle with yourself, '
                'and remember Chipu is here to talk.',
            'Hisia zako wiki hii ziko chini kuliko wiki iliyopita. Jihurumie, '
                'na kumbuka Chipu yuko hapa kuongea nawe.'),
      ));
    } else {
      out.add(MoodInsight(
        id: 'trend_steady',
        emoji: '⚖️',
        title: t('A steady week', 'Wiki tulivu'),
        body: t('Your moods this week are about the same as last week.',
            'Hisia zako wiki hii ni karibu sawa na wiki iliyopita.'),
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
  ]..sort((MapEntry<int, double> a, MapEntry<int, double> b) =>
      b.value.compareTo(a.value));
  if (weekdays.length >= 2 && weekdays.first.value - weekdays.last.value >= 1) {
    out.add(MoodInsight(
      id: 'weekday',
      emoji: '📅',
      title: t('Your week has a pattern', 'Wiki yako ina mwelekeo'),
      body: t(
          'You tend to feel best on ${_weekdayNames[weekdays.first.key - 1]} '
              'and lowest on ${_weekdayNames[weekdays.last.key - 1]}.',
          'Mara nyingi unajisikia vizuri zaidi siku ya ${fullDay('sw', weekdays.first.key)} '
              'na vibaya zaidi siku ya ${fullDay('sw', weekdays.last.key)}.'),
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
      if (p.value.length >= 2)
        MapEntry<String, double>(p.key, _average(p.value)),
  ]..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
      b.value.compareTo(a.value));
  if (parts.length >= 2 && parts.first.value - parts.last.value >= 0.75) {
    String partSw(String p) => switch (p) {
          'mornings' => 'asubuhi',
          'afternoons' => 'mchana',
          _ => 'jioni',
        };
    out.add(MoodInsight(
      id: 'time_of_day',
      emoji: parts.first.key == 'mornings'
          ? '🌅'
          : (parts.first.key == 'evenings' ? '🌙' : '☀️'),
      title: t('Your ${parts.first.key} feel better',
          'Wakati bora wa siku yako: ${partSw(parts.first.key)}'),
      body: t(
          'You usually feel better in the ${parts.first.key} than in the ${parts.last.key}.',
          'Kwa kawaida unajisikia vizuri zaidi ${partSw(parts.first.key)} kuliko ${partSw(parts.last.key)}.'),
    ));
  }

  // 5. Tags that keep coming up on low and on good days (2+ check-ins).
  String? commonTag(bool Function(int mood) which) {
    final Map<String, int> counts = <String, int>{};
    for (final MoodEntry e in entries) {
      if (!which(e.mood)) continue;
      for (final String tagId in e.tags.toSet()) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> top = counts.entries
        .where((MapEntry<String, int> c) => c.value >= 2)
        .toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
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
      title: t('${low.en} weighs on you', '${low.sw}: jambo linalokulemea'),
      body: t(
          'Your low days are often about ${low.en.toLowerCase()}. '
              'Talking it through with Chipu or someone you trust can help.',
          'Siku zako ngumu mara nyingi zinahusu ${low.sw.toLowerCase()}. '
              'Kuongea na Chipu au mtu unayemwamini kunaweza kusaidia.'),
    ));
  }
  if (good != null && goodTag != lowTag) {
    out.add(MoodInsight(
      id: 'good_tag',
      emoji: good.emoji,
      title: t('${good.en} lifts you up', '${good.sw}: jambo linalokuinua'),
      body: t(
          'Your good days are often about ${good.en.toLowerCase()}. Make room for more of it.',
          'Siku zako nzuri mara nyingi zinahusu ${good.sw.toLowerCase()}. Jipe muda zaidi kwa hilo.'),
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
    final List<MapEntry<String, int>> top = counts.entries
        .where((MapEntry<String, int> c) => c.value >= 2)
        .toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    return top.isEmpty ? null : top.first.key;
  }

  final String? lowWord = commonWord((int m) => m <= 2);
  final String? goodWord = commonWord((int m) => m >= 4);
  if (lowWord != null && lowWord != lowTag) {
    out.add(MoodInsight(
      id: 'low_word',
      emoji: '📝',
      title: t('Something that weighs on you', 'Jambo linalokulemea'),
      body: t(
          'Your notes on low days often mention "$lowWord". '
              'Chipu can help you work through it, or try a breathing exercise.',
          'Maelezo yako ya siku ngumu mara nyingi yanataja "$lowWord". '
              'Chipu anaweza kukusaidia kulipitia, au jaribu zoezi la kupumua.'),
    ));
  }
  if (goodWord != null && goodWord != lowWord && goodWord != goodTag) {
    out.add(MoodInsight(
      id: 'good_word',
      emoji: '🌱',
      title: t('Something that lifts you', 'Jambo linalokuinua'),
      body: t(
          'Your notes on good days often mention "$goodWord". Make room for more of it.',
          'Maelezo yako ya siku nzuri mara nyingi yanataja "$goodWord". Jipe muda zaidi kwa hilo.'),
    ));
  }

  // 7. Feelings that came up in the chat this week.
  final List<MapEntry<String, int>> feelings = chatFeelings.entries
      .where((MapEntry<String, int> f) =>
          chatFeelingNames.containsKey(f.key) && f.value >= 2)
      .toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
        b.value.compareTo(a.value));
  if (feelings.isNotEmpty) {
    final MapEntry<String, int> top = feelings.first;
    out.add(MoodInsight(
      id: 'chat_feeling',
      emoji: '💬',
      title: t('${chatFeelingNames[top.key]} came up in your chats',
          'Kwenye mazungumzo yako: ${chatFeelingNamesSw[top.key]}'),
      body: top.key == 'feel_good'
          ? t('You told Chipu you felt good ${top.value} times this week. Nice!',
              'Ulimwambia Chipu kuwa unajisikia vizuri mara ${top.value} wiki hii. Safi!')
          : t(
              '${chatFeelingNames[top.key]} came up ${top.value} times in your chats this week. '
                  'A breathing exercise can help. Just ask Chipu.',
              'Ulitaja ${chatFeelingNamesSw[top.key]!.toLowerCase()} mara ${top.value} kwenye mazungumzo yako wiki hii. '
                  'Zoezi la kupumua linaweza kusaidia. Muombe Chipu tu.'),
    ));
  }

  // 8. Check-in habit over the last 7 days.
  final int daysThisWeek =
      byDay.keys.where((DateTime day) => !day.isBefore(weekStart)).length;
  if (daysThisWeek >= 5) {
    out.add(MoodInsight(
      id: 'habit',
      emoji: '🔥',
      title: t('Great check-in habit', 'Tabia nzuri ya kurekodi hisia'),
      body: t(
          'You checked in on $daysThisWeek of the last 7 days. '
              'Knowing how you feel is the first step to feeling better.',
          'Umerekodi hisia siku $daysThisWeek kati ya 7 zilizopita. '
              'Kujua unavyojisikia ni hatua ya kwanza ya kujisikia vizuri.'),
    ));
  }

  // 9. The overall mix of moods, so there is always something to show.
  final int nGood = entries.where((MoodEntry e) => e.mood >= 4).length;
  final int nOkay = entries.where((MoodEntry e) => e.mood == 3).length;
  final int nLow = entries.where((MoodEntry e) => e.mood <= 2).length;
  final int total = entries.length;
  out.add(MoodInsight(
    id: 'mood_mix',
    emoji: nGood * 2 > total ? '🌤️' : (nLow * 2 > total ? '🌧️' : '⛅'),
    title: nGood * 2 > total
        ? t('Mostly good days', 'Siku nyingi nzuri')
        : nLow * 2 > total
            ? t('A lot of low days lately', 'Siku nyingi ngumu hivi karibuni')
            : t('A mix of ups and downs', 'Mchanganyiko wa juu na chini'),
    body: nGood * 2 > total
        ? t('$nGood of your last $total check-ins were good or great.',
            '$nGood kati ya hisia $total ulizorekodi mwisho zilikuwa nzuri au nzuri sana.')
        : nLow * 2 > total
            ? t(
                '$nLow of your last $total check-ins were low. Chipu is here to talk, and the helplines are always on Home.',
                '$nLow kati ya hisia $total ulizorekodi mwisho zilikuwa chini. Chipu yuko hapa kuongea nawe, na nambari za msaada ziko kwenye Nyumbani daima.')
            : t(
                'Of your last $total check-ins, $nGood were good, $nOkay okay and $nLow low. Ups and downs are normal.',
                'Kati ya hisia $total ulizorekodi mwisho, $nGood zilikuwa nzuri, $nOkay za kawaida na $nLow chini. Kupanda na kushuka ni kawaida.'),
  ));

  return out;
}

/// Insights about the check-in just saved: how it compares with the user's
/// usual mood, big changes during the day, and what its tags usually mean.
/// [history] is newest first and already includes the new check-in.
List<MoodInsight> checkInInsights(
    int mood, List<String> tags, List<MoodEntry> history,
    {DateTime? now, String language = 'en'}) {
  String t(String en, String sw) => tr(language, en, sw);
  final List<MoodInsight> out = <MoodInsight>[];
  final List<MoodEntry> before =
      history.length > 1 ? history.sublist(1) : const <MoodEntry>[];
  final String face = moodFace(mood);

  // Compared with the user's usual mood (needs 2+ earlier check-ins).
  if (before.length >= 2) {
    final double usual = _average(before.map((MoodEntry e) => e.mood));
    final String avg = usual.toStringAsFixed(1);
    if (mood - usual >= 1) {
      out.add(MoodInsight(
        id: 'above_usual',
        emoji: '📈',
        title: t('Brighter than usual', 'Bora kuliko kawaida'),
        body: t(
            'Today $face is higher than your usual mood ($avg out of 5). Notice what helped today.',
            'Leo $face uko juu kuliko hisia zako za kawaida ($avg kati ya 5). Angalia kilichokusaidia leo.'),
      ));
    } else if (usual - mood >= 1) {
      out.add(MoodInsight(
        id: 'below_usual',
        emoji: '📉',
        title: t('Harder than usual', 'Ngumu kuliko kawaida'),
        body: t(
            'Today $face is lower than your usual mood ($avg out of 5). Be gentle with yourself.',
            'Leo $face uko chini kuliko hisia zako za kawaida ($avg kati ya 5). Jihurumie.'),
      ));
    } else {
      out.add(MoodInsight(
        id: 'near_usual',
        emoji: '⚖️',
        title: t('About your usual', 'Karibu na kawaida yako'),
        body: t('Today $face is close to your usual mood ($avg out of 5).',
            'Leo $face uko karibu na hisia zako za kawaida ($avg kati ya 5).'),
      ));
    }
  }

  // Big changes within today.
  final DateTime todayDate = _day(now ?? nairobiNow());
  final List<int> today = <int>[
    for (final MoodEntry e in history)
      if (_day(e.at) == todayDate) e.mood,
  ];
  if (today.length >= 2) {
    final int lo = today.reduce((int a, int b) => a < b ? a : b);
    final int hi = today.reduce((int a, int b) => a > b ? a : b);
    if (hi - lo >= 2) {
      out.add(MoodInsight(
        id: 'day_swing',
        emoji: '🎢',
        title: t('Ups and downs today', 'Juu na chini leo'),
        body: t(
            'Today your mood went from ${moodFace(lo)} to ${moodFace(hi)}. '
                'Moods can change a lot in one day, and that is normal.',
            'Leo hisia zako zimetoka ${moodFace(lo)} hadi ${moodFace(hi)}. '
                'Hisia zinaweza kubadilika sana kwa siku moja, na hilo ni kawaida.'),
      ));
    }
  }

  // What the chosen tags usually go with.
  for (final String id in tags) {
    final MoodTag? tag = moodTagById(id);
    if (tag == null) continue;
    final List<int> withTag = <int>[
      for (final MoodEntry e in before)
        if (e.tags.contains(id)) e.mood,
    ];
    final String name = tag.en.toLowerCase();
    final String nameSw = tag.sw.toLowerCase();
    if (withTag.isEmpty) {
      out.add(MoodInsight(
        id: 'tag_first_$id',
        emoji: tag.emoji,
        title: t('First time you tagged ${tag.en}',
            'Mara ya kwanza kuchagua ${tag.sw}'),
        body: t(
            'Keep tagging your check-ins and Chipu will show you how $name affects your mood.',
            'Endelea kuchagua mada unaporekodi hisia na Chipu atakuonyesha jinsi mada ya $nameSw inavyoathiri hisia zako.'),
      ));
    } else {
      final double withAvg = _average(withTag);
      final double overall = _average(before.map((MoodEntry e) => e.mood));
      final String how = withAvg - overall >= 0.5
          ? t('better than usual', 'bora kuliko kawaida')
          : overall - withAvg >= 0.5
              ? t('lower than usual', 'chini kuliko kawaida')
              : t('about the same as usual', 'karibu sawa na kawaida');
      out.add(MoodInsight(
        id: 'tag_$id',
        emoji: tag.emoji,
        title: t('${tag.en} and your mood', '${tag.sw} na hisia zako'),
        body: t(
            'You tagged ${tag.en} ${withTag.length + 1} times. '
                'On those check-ins your mood is $how (${withAvg.toStringAsFixed(1)} vs ${overall.toStringAsFixed(1)}).',
            'Umechagua ${tag.sw} mara ${withTag.length + 1}. '
                'Siku hizo hisia zako ziko $how (${withAvg.toStringAsFixed(1)} dhidi ya ${overall.toStringAsFixed(1)}).'),
      ));
    }
  }
  return out;
}

String moodFace(int mood) =>
    const <String>['😢', '😕', '😐', '🙂', '😄'][(mood - 1).clamp(0, 4)];
