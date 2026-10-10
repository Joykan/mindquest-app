import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../home/progress_repository.dart';
import 'moods.dart';

/// Mood history (wireframe 08): the last 7 days as a chart, a short summary
/// and every check-in from the last 30 days, with notes. Entries can be
/// deleted; XP already earned stays.
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key, required this.repository});

  final ProgressRepository repository;

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

const List<String> _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

MoodOption _option(int mood) => moodOptions.firstWhere((MoodOption m) => m.value == mood);

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  late Future<List<MoodEntry>> _entries = widget.repository.loadMoodHistory();

  Future<void> _reload() async {
    final Future<List<MoodEntry>> next = widget.repository.loadMoodHistory();
    setState(() => _entries = next);
    await next;
  }

  Future<void> _delete(MoodEntry e) async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this check-in?'),
        content: const Text('Your XP and streak stay as they are.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await widget.repository.deleteMood(e.id);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete. Check your connection and try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mood history')),
      body: FutureBuilder<List<MoodEntry>>(
        future: _entries,
        builder: (BuildContext context, AsyncSnapshot<List<MoodEntry>> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: const Text("Couldn't load your history. Tap to try again."),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final List<MoodEntry> entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No check-ins yet. Log how you feel and your history will show here.',
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
                Text('Last 30 days', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final MoodEntry e in entries) _EntryTile(entry: e, onDelete: () => _delete(e)),
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
      latestByDay.putIfAbsent(_dayKey(e.at), () => e); // entries are newest first
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
              child: Text('Last 7 days', style: theme.textTheme.titleMedium),
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
                            ? '${_weekdays[day.weekday - 1]}: no check-in'
                            : '${_weekdays[day.weekday - 1]}: ${_option(e.mood).label}',
                        child: Column(
                          children: <Widget>[
                            Text(e == null ? ' ' : _option(e.mood).emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 4),
                            Container(
                              height: e == null ? 6 : maxBar * e.mood / 5,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: e == null ? mq.surfaceSoft : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i == 0 ? 'Today' : _weekdays[day.weekday - 1],
                              style: theme.textTheme.labelSmall?.copyWith(color: mq.textMuted),
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
    final DateTime weekAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final List<MoodEntry> week =
        entries.where((MoodEntry e) => !DateTime(e.at.year, e.at.month, e.at.day).isBefore(weekAgo)).toList();
    final int days = week.map((MoodEntry e) => _dayKey(e.at)).toSet().length;

    final Map<int, int> counts = <int, int>{};
    for (final MoodEntry e in entries) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
    }
    final int common = counts.entries.reduce((MapEntry<int, int> a, MapEntry<int, int> b) {
      if (a.value != b.value) return a.value > b.value ? a : b;
      return a.key > b.key ? a : b; // on a tie, show the better mood
    }).key;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: <Widget>[
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: <Widget>[
            stat('$days / 7', 'days checked in\nthis week'),
            stat(_option(common).emoji, 'most common mood\n(${_option(common).label.toLowerCase()})'),
            stat('${entries.length}', 'check-ins in\n30 days'),
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
    final String when = '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} · '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Text(m.emoji, style: const TextStyle(fontSize: 28)),
          title: Text(m.label, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(when, style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
              if (entry.note != null && entry.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entry.note!),
                ),
            ],
          ),
          trailing: IconButton(
            key: Key('delete-${entry.id}'),
            tooltip: 'Delete check-in',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}
