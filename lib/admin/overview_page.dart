import 'package:flutter/material.dart';

import '../core/l10n/tr.dart';
import '../core/theme/app_colors.dart';
import '../features/mood/mood_tags.dart';
import '../features/mood/moods.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

/// Names for the chat intents students' messages were classified as.
const Map<String, String> topicNames = <String, String>{
  'feel_stressed': 'Stressed',
  'feel_anxious': 'Anxious or worried',
  'feel_sad': 'Sad or low',
  'feel_good': 'Feeling good',
  'ask_breathing': 'Asked for a breathing exercise',
  'ask_ideas': 'Asked for ideas',
  'ask_about_bot': 'Asked about Chipu',
};

/// Greetings, thanks, yes/no and names: counted together.
const Set<String> smallTalk = <String>{
  'greet',
  'goodbye',
  'thank',
  'affirm',
  'deny',
  'tell_name',
};

String _mood(double? m) => m == null ? '–' : m.toStringAsFixed(1);

String _moodEmoji(double? m) =>
    m == null ? '' : moodOptions[(m.round() - 1).clamp(0, 4)].emoji;

/// Overview (admin wireframe 1): how students use MindQuest, as totals.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int _days = 7;
  late Future<AdminStats> _stats = widget.repository.stats(_days);

  void _load([int? days]) => setState(() {
        _days = days ?? _days;
        _stats = widget.repository.stats(_days);
      });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return FutureBuilder<AdminStats>(
      future: _stats,
      builder: (BuildContext context, AsyncSnapshot<AdminStats> snap) {
        final Widget header = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Overview', style: theme.textTheme.headlineSmall),
            SegmentedButton<int>(
              key: const Key('period'),
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 7, label: Text('7 days')),
                ButtonSegment<int>(value: 30, label: Text('30 days')),
                ButtonSegment<int>(value: 90, label: Text('90 days')),
              ],
              selected: <int>{_days},
              showSelectedIcon: false,
              onSelectionChanged: (Set<int> s) => _load(s.first),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        );
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              header,
              const SizedBox(height: 40),
              LoadProblem(message: '${snap.error}', onRetry: _load),
            ],
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final AdminStats s = snap.data!;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth - 48;
            final int tilesPerRow = width >= 1100
                ? 4
                : width >= 700
                    ? 3
                    : 2;
            final double tile = (width - 12 * (tilesPerRow - 1)) / tilesPerRow;
            final double half = width >= 1000 ? (width - 16) / 2 : width;
            return ListView(
              key: const Key('overview'),
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                header,
                const SizedBox(height: 4),
                Text(
                  '${longDate('en', s.from)} to ${longDate('en', s.to)}. '
                  "Totals only: the dashboard never shows a student's messages, notes or check-ins.",
                  style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final Widget t in _tiles(s))
                      SizedBox(width: tile, child: t),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: <Widget>[
                    for (final Widget c in _cards(context, s))
                      SizedBox(width: half, child: c),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _tiles(AdminStats s) => <Widget>[
        StatTile(
          key: const Key('tile-students'),
          icon: Icons.people_outline,
          label: 'Students',
          value: '${s.users}',
          detail: '+${s.newUsers} new · ${s.savedAccounts} saved with email or Google',
        ),
        StatTile(
          key: const Key('tile-active'),
          icon: Icons.bolt_outlined,
          label: 'Active students',
          value: '${s.activeUsers}',
          detail: 'checked in, chatted or read',
        ),
        StatTile(
          key: const Key('tile-checkins'),
          icon: Icons.sentiment_satisfied_outlined,
          label: 'Mood check-ins',
          value: '${s.moodEntries}',
          detail: 'average mood ${_mood(s.averageMood)} / 5 ${_moodEmoji(s.averageMood)}',
        ),
        StatTile(
          key: const Key('tile-chats'),
          icon: Icons.chat_bubble_outline,
          label: 'Chats with Chipu',
          value: '${s.chatSessions}',
          detail: '${s.messages} messages from students',
        ),
        StatTile(
          key: const Key('tile-articles'),
          icon: Icons.menu_book_outlined,
          label: 'Articles read',
          value: '${s.articlesRead}',
        ),
        StatTile(
          key: const Key('tile-badges'),
          icon: Icons.emoji_events_outlined,
          label: 'Badges earned',
          value: '${s.badgesAwarded}',
        ),
        StatTile(
          key: const Key('tile-understood'),
          icon: Icons.psychology_outlined,
          label: 'Chipu understood',
          value: s.understoodShare == null
              ? '–'
              : '${(s.understoodShare! * 100).round()}%',
          detail: '${s.notUnderstood} not understood'
              '${s.unavailable > 0 ? ' · NLU server down ${s.unavailable}x' : ''}',
        ),
        StatTile(
          key: const Key('tile-crisis'),
          icon: Icons.health_and_safety_outlined,
          alert: s.crisisEvents > 0,
          label: 'Crisis responses',
          value: '${s.crisisEvents}',
          detail: 'times the helplines were shown',
        ),
      ];

  List<Widget> _cards(BuildContext context, AdminStats s) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    final List<String> labels = <String>[
      for (final DailyStat d in s.daily)
        s.daily.length <= 10 ? shortDay('en', d.day.weekday) : shortDate('en', d.day),
    ];
    final int moodMax = s.moodSplit.values.fold<int>(0, (int a, int b) => a > b ? a : b);
    final int tagMax =
        s.tags.fold<int>(0, (int a, TagStat t) => a > t.checkIns ? a : t.checkIns);

    // Topics, most common first, with small talk grouped.
    final Map<String, int> topics = <String, int>{};
    int talk = 0;
    s.topics.forEach((String intent, int n) {
      if (smallTalk.contains(intent)) {
        talk += n;
      } else if (intent != 'crisis' && intent != 'fallback') {
        topics[intent] = n;
      }
    });
    final List<MapEntry<String, int>> topicList = topics.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final int topicMax = <int>[
      talk,
      s.notUnderstood,
      s.topics['crisis'] ?? 0,
      ...topics.values,
    ].fold<int>(0, (int a, int b) => a > b ? a : b);
    final int languageTotal =
        s.languages.values.fold<int>(0, (int a, int b) => a + b);
    final int readMax = s.articles
        .fold<int>(0, (int a, ArticleReads r) => a > r.reads ? a : r.reads);

    return <Widget>[
      SectionCard(
        key: const Key('chart-checkins'),
        title: 'Check-ins per day',
        subtitle: 'Counted on the day they were made, even if sent later',
        child: DayBars(
          values: <double?>[for (final DailyStat d in s.daily) d.checkIns.toDouble()],
          labels: labels,
          tooltips: <String>[
            for (final DailyStat d in s.daily)
              '${longDate('en', d.day)}: ${d.checkIns} check-ins, ${d.chats} chats',
          ],
        ),
      ),
      SectionCard(
        key: const Key('chart-mood'),
        title: 'Average mood per day',
        subtitle: '1 very low · 3 okay · 5 very good',
        child: DayBars(
          values: <double?>[for (final DailyStat d in s.daily) d.averageMood],
          max: 5,
          color: AppPalette.mint,
          labels: labels,
          tooltips: <String>[
            for (final DailyStat d in s.daily)
              '${longDate('en', d.day)}: '
                  '${d.averageMood == null ? 'no check-ins' : '${_mood(d.averageMood)} ${_moodEmoji(d.averageMood)}'}',
          ],
        ),
      ),
      SectionCard(
        key: const Key('card-moods'),
        title: 'How students felt',
        subtitle: 'Check-ins by mood',
        child: Column(
          children: <Widget>[
            for (final MoodOption m in moodOptions.reversed)
              BarRow(
                leading: Text(m.emoji, style: const TextStyle(fontSize: 18)),
                label: m.label,
                value: s.moodSplit[m.value] ?? 0,
                max: moodMax,
                color: m.value <= 2 ? mq.crisis.withValues(alpha: 0.7) : null,
              ),
          ],
        ),
      ),
      SectionCard(
        key: const Key('card-tags'),
        title: 'What check-ins were about',
        subtitle: 'Tags students chose, with their average mood',
        child: s.tags.isEmpty
            ? const Text('No tags in this period.')
            : Column(
                children: <Widget>[
                  for (final TagStat t in s.tags)
                    BarRow(
                      leading: Text(moodTagById(t.tag)?.emoji ?? '🏷️',
                          style: const TextStyle(fontSize: 18)),
                      label: moodTagById(t.tag)?.label('en') ?? t.tag,
                      value: t.checkIns,
                      max: tagMax,
                      valueLabel: '${t.checkIns} · ${_mood(t.averageMood)} ${_moodEmoji(t.averageMood)}',
                    ),
                ],
              ),
      ),
      SectionCard(
        key: const Key('card-topics'),
        title: 'What students talk to Chipu about',
        subtitle: 'What the NLU model understood. Message text is never shown.',
        child: s.topics.isEmpty
            ? const Text('No chat messages in this period.')
            : Column(
                children: <Widget>[
                  for (final MapEntry<String, int> t in topicList)
                    BarRow(
                        label: topicNames[t.key] ?? t.key,
                        value: t.value,
                        max: topicMax),
                  if (talk > 0)
                    BarRow(
                        label: 'Small talk (hello, thanks, yes/no, names)',
                        value: talk,
                        max: topicMax,
                        color: mq.textMuted),
                  if ((s.topics['crisis'] ?? 0) > 0)
                    BarRow(
                        label: 'Crisis messages',
                        value: s.topics['crisis']!,
                        max: topicMax,
                        color: mq.crisis),
                  if (s.notUnderstood > 0)
                    BarRow(
                        label: 'Not understood',
                        value: s.notUnderstood,
                        max: topicMax,
                        color: mq.reward),
                ],
              ),
      ),
      SectionCard(
        key: const Key('card-languages'),
        title: 'App language',
        subtitle: 'All students',
        child: Column(
          children: <Widget>[
            for (final String l in appLanguages)
              BarRow(
                label: l == 'sw' ? 'Kiswahili' : 'English',
                value: s.languages[l] ?? 0,
                max: languageTotal,
                valueLabel: languageTotal == 0
                    ? '0'
                    : '${s.languages[l] ?? 0} (${((s.languages[l] ?? 0) * 100 / languageTotal).round()}%)',
              ),
          ],
        ),
      ),
      SectionCard(
        key: const Key('card-articles'),
        title: 'Articles',
        subtitle: 'Reads in this period, and all time',
        child: Column(
          children: <Widget>[
            for (final ArticleReads a in s.articles)
              BarRow(
                label: a.title,
                value: a.reads,
                max: readMax,
                valueLabel: '${a.recent} · ${a.reads}',
              ),
          ],
        ),
      ),
      SectionCard(
        key: const Key('chart-crisis'),
        title: 'Crisis responses per day',
        subtitle: 'Who it was is never recorded',
        child: DayBars(
          height: 80,
          color: mq.crisis,
          values: <double?>[
            for (final DailyStat d in s.daily) d.crisisEvents.toDouble()
          ],
          labels: labels,
          tooltips: <String>[
            for (final DailyStat d in s.daily)
              '${longDate('en', d.day)}: ${d.crisisEvents}',
          ],
        ),
      ),
    ];
  }
}
