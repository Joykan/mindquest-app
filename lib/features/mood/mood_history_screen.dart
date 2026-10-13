import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../home/progress_repository.dart';
import 'mood_insights.dart';
import 'mood_tags.dart';
import 'moods.dart';

/// Mood history (wireframe 08): the last 7 days as a chart, a short summary,
/// insights, and every check-in from the last 30 days, with notes. Entries can
/// be deleted; XP already earned stays.
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen(
      {super.key, required this.repository, this.onHelplines});

  final ProgressRepository repository;

  /// Opens the helplines (shown with the "hard days" insight).
  final VoidCallback? onHelplines;

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

MoodOption _option(int mood) =>
    moodOptions.firstWhere((MoodOption m) => m.value == mood);

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  late Future<List<MoodEntry>> _entries = widget.repository.loadMoodHistory();
  late Future<Map<String, int>> _feelings = _loadFeelings();

  /// Chat feelings are extra; the screen still works without them.
  Future<Map<String, int>> _loadFeelings() async {
    try {
      return await widget.repository.loadChatFeelings();
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// Deleted entries disappear at once, before the list reloads.
  final Set<String> _removed = <String>{};

  Future<void> _reload() async {
    final Future<List<MoodEntry>> next = widget.repository.loadMoodHistory();
    setState(() {
      _entries = next;
      _feelings = _loadFeelings();
    });
    await next;
  }

  Future<void> _delete(MoodEntry e) async {
    final String lang = context.lang;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.tr('Delete this check-in?', 'Futa rekodi hii?')),
        content: Text(context.tr('Your XP and streak stay as they are.',
            'XP yako na mfululizo wako vitabaki kama vilivyo.')),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel', 'Ghairi'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Delete', 'Futa'))),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await widget.repository.deleteMood(e.id);
      if (!mounted) return;
      setState(() => _removed.add(e.id));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr(
                lang,
                "Couldn't delete. Check your connection and try again.",
                'Imeshindikana kufuta. Angalia mtandao wako kisha ujaribu tena.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(context.tr('Mood history', 'Historia ya hisia'))),
      body: FutureBuilder<List<MoodEntry>>(
        future: _entries,
        builder: (BuildContext context, AsyncSnapshot<List<MoodEntry>> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: Text(context.tr(
                    "Couldn't load your history. Tap to try again.",
                    'Imeshindikana kupakia historia yako. Gusa ujaribu tena.')),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<MoodEntry> entries = snap.data!
              .where((MoodEntry e) => !_removed.contains(e.id))
              .toList();
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.tr(
                      'No check-ins yet. Log how you feel and your history will show here.',
                      'Bado hujarekodi hisia. Rekodi unavyojisikia na historia yako itaonekana hapa.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                _WeekChart(entries: entries),
                const SizedBox(height: 12),
                _Summary(entries: entries),
                const SizedBox(height: 20),
                Text(context.tr('Insights', 'Maarifa'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, int>>(
                  future: _feelings,
                  builder: (BuildContext context,
                          AsyncSnapshot<Map<String, int>> f) =>
                      _Insights(
                    entries: entries,
                    chatFeelings: f.data ?? const <String, int>{},
                    onHelplines: widget.onHelplines,
                  ),
                ),
                const SizedBox(height: 20),
                Text(context.tr('Last 30 days', 'Siku 30 zilizopita'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final MoodEntry e in entries)
                  _EntryTile(entry: e, onDelete: () => _delete(e)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The last 7 days. Each bar is that day's latest mood (taller = better).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.entries});

  final List<MoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final DateTime now = nairobiNow();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Map<String, MoodEntry> latestByDay = <String, MoodEntry>{};
    for (final MoodEntry e in entries) {
      latestByDay.putIfAbsent(
          _dayKey(e.at), () => e); // entries are newest first
    }
    const double maxBar = 90;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(context.tr('Last 7 days', 'Siku 7 zilizopita'),
                  style: theme.textTheme.titleMedium),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 6; i >= 0; i--)
                  Expanded(
                    child: Builder(builder: (BuildContext context) {
                      final DateTime day = today.subtract(Duration(days: i));
                      final MoodEntry? e = latestByDay[_dayKey(day)];
                      return Semantics(
                        label: e == null
                            ? '${fullDay(context.lang, day.weekday)}: ${context.tr('no check-in', 'hakuna rekodi')}'
                            : '${fullDay(context.lang, day.weekday)}: ${_option(e.mood).name(context.lang)}',
                        child: Column(
                          children: <Widget>[
                            Text(e == null ? ' ' : _option(e.mood).emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 4),
                            Container(
                              height: e == null ? 6 : maxBar * e.mood / 5,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: e == null
                                    ? mq.surfaceSoft
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i == 0
                                  ? context.tr('Today', 'Leo')
                                  : shortDay(context.lang, day.weekday),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: mq.textMuted),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.entries});

  final List<MoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final DateTime now = nairobiNow();
    final DateTime weekAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final List<MoodEntry> week = entries
        .where((MoodEntry e) =>
            !DateTime(e.at.year, e.at.month, e.at.day).isBefore(weekAgo))
        .toList();
    final int days = week.map((MoodEntry e) => _dayKey(e.at)).toSet().length;

    final Map<int, int> counts = <int, int>{};
    for (final MoodEntry e in entries) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
    }
    final int top = counts.values.reduce((int a, int b) => a > b ? a : b);
    final List<int> leaders = <int>[
      for (final MapEntry<int, int> c in counts.entries)
        if (c.value == top) c.key,
    ];
    // A tie (for example one low, one great and one very low) is shown as
    // "mixed" rather than picking one mood that is not really the most common.
    final bool mixed = leaders.length > 1;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: <Widget>[
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: <Widget>[
            stat(
                '$days / 7',
                context.tr('days checked in\nthis week',
                    'siku ulizorekodi\nwiki hii')),
            if (mixed)
              stat(
                  '🎢',
                  context.tr('most common mood\n(mixed)',
                      'hisia za mara nyingi\n(mchanganyiko)'))
            else
              stat(
                  _option(leaders.first).emoji,
                  context.tr(
                      'most common mood\n(${_option(leaders.first).label.toLowerCase()})',
                      'hisia za mara nyingi\n(${_option(leaders.first).labelSw.toLowerCase()})')),
            stat('${entries.length}',
                context.tr('check-ins in\n30 days', 'rekodi katika\nsiku 30')),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});

  final MoodEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final MoodOption m = _option(entry.mood);
    final DateTime d = entry.at;
    final String lang = context.lang;
    final String when =
        '${shortDay(lang, d.weekday)} ${shortDate(lang, d)} · ${clock(d)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Text(m.emoji, style: const TextStyle(fontSize: 28)),
          title: Text(m.name(lang), style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(when,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
              if (entry.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    <String>[
                      for (final String id in entry.tags)
                        if (moodTagById(id) != null)
                          '${moodTagById(id)!.emoji} ${moodTagById(id)!.label(lang)}',
                    ].join('  '),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              if (entry.note != null && entry.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entry.note!),
                ),
            ],
          ),
          trailing: IconButton(
            key: Key('delete-${entry.id}'),
            tooltip: context.tr('Delete check-in', 'Futa rekodi'),
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights(
      {required this.entries, required this.chatFeelings, this.onHelplines});

  final List<MoodEntry> entries;
  final Map<String, int> chatFeelings;
  final VoidCallback? onHelplines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    if (entries.length < insightMinimumCheckIns) {
      return Card(
        key: const Key('insights-locked'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              const Mascot(size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(
                      'Check in $insightMinimumCheckIns times and Chipu will start spotting '
                          'patterns in your moods (${entries.length}/$insightMinimumCheckIns).',
                      'Rekodi hisia mara $insightMinimumCheckIns na Chipu ataanza kugundua '
                          'mwelekeo wa hisia zako (${entries.length}/$insightMinimumCheckIns).'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final List<MoodInsight> insights = buildInsights(entries,
        chatFeelings: chatFeelings, language: context.lang);
    if (insights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            context.tr(
                'No clear patterns yet. Keep checking in and Chipu will spot them.',
                'Bado hakuna mwelekeo wazi. Endelea kurekodi hisia na Chipu atauona.'),
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final MoodInsight i in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('insight-${i.id}'),
              color: i.needsSupport ? mq.surfaceSoft : null,
              shape: i.needsSupport
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: theme.colorScheme.primary, width: 1.5),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(i.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(i.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(i.body, style: theme.textTheme.bodyMedium),
                          if (i.needsSupport &&
                              onHelplines != null) ...<Widget>[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              key: const Key('insight-helplines'),
                              onPressed: onHelplines,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44)),
                              icon: const Icon(Icons.phone_in_talk_outlined),
                              label: Text(context.tr(
                                  'See helplines', 'Ona nambari za msaada')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(
          context.tr(
              'Insights are patterns in what you logged, not a diagnosis.',
              'Maarifa haya ni mwelekeo wa ulichorekodi, si utambuzi wa ugonjwa.'),
          style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
        ),
      ],
    );
  }
}
