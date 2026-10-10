import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/logo_mark.dart';
import '../chat/chat_models.dart';
import '../chat/crisis_sheet.dart';
import '../gamification/levels.dart';
import '../mood/moods.dart';
import 'progress_repository.dart';

/// Home (wireframe 04): streak and level, today's mood, today's quests,
/// a way into the chat and the helplines.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onMoodTap,
    required this.onTalk,
    required this.onProfile,
    this.reloadWhen,
    this.theme,
  });

  /// Shows the appearance button (System default / Light / Dark) when given.
  final ThemeController? theme;

  final ProgressRepository repository;

  /// Reloads the numbers whenever this fires (mood saved, Home tab tapped).
  final Listenable? reloadWhen;
  final ValueChanged<int> onMoodTap;
  final VoidCallback onTalk;
  final VoidCallback onProfile;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<HomeSummary> _summary = widget.repository.loadHome();

  @override
  void initState() {
    super.initState();
    widget.reloadWhen?.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.reloadWhen?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) reload();
  }

  /// Reloads the numbers, e.g. after a mood check-in.
  Future<void> reload() async {
    final Future<HomeSummary> next = widget.repository.loadHome();
    setState(() => _summary = next);
    await next;
  }

  Future<void> _showHelplines() async {
    try {
      final List<Helpline> lines = await widget.repository.loadHelplines();
      if (!mounted) return;
      await showCrisisSheet(
        context,
        ChatReply(
          reply:
              'If things feel too heavy right now, talking to someone can help. '
              'These services are free and confidential.',
          helplines: lines,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Couldn't load helplines. In an emergency call 999 or 112.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<HomeSummary>(
          future: _summary,
          builder: (BuildContext context, AsyncSnapshot<HomeSummary> snap) {
            if (snap.hasError) {
              return _Problem(onRetry: reload);
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: reload,
              child: _HomeBody(
                summary: snap.data!,
                onMoodTap: widget.onMoodTap,
                onTalk: widget.onTalk,
                onProfile: widget.onProfile,
                onHelplines: _showHelplines,
                theme: widget.theme,
              ),
            );
          },
        ),
      ),
    );
  }
}

String _dateLine(DateTime d) {
  const List<String> days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.summary,
    required this.onMoodTap,
    required this.onTalk,
    required this.onProfile,
    required this.onHelplines,
    this.theme,
  });

  final ThemeController? theme;
  final HomeSummary summary;
  final ValueChanged<int> onMoodTap;
  final VoidCallback onTalk;
  final VoidCallback onProfile;
  final VoidCallback onHelplines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final LevelProgress level = LevelProgress(summary.xp);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            const LogoMark(size: 36),
            const SizedBox(width: 10),
            Expanded(
                child: Text('MindQuest', style: theme.textTheme.titleMedium)),
            if (this.theme != null) _AppearanceButton(controller: this.theme!),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: const Key('open-profile'),
              tooltip: 'Profile and settings',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Hi, ${summary.username}', style: theme.textTheme.headlineSmall),
        Text(
          _dateLine(nairobiNow()),
          style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
        ),
        const SizedBox(height: 16),

        // Streak and level
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summary.streak == 1
                            ? '1-day streak'
                            : '${summary.streak}-day streak',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: mq.reward,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Level ${level.level}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: mq.onReward),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: level.fraction,
                    minHeight: 10,
                    backgroundColor: mq.surfaceSoft,
                    color: AppPalette.mint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${level.earned} / ${level.needed} XP to Level ${level.level + 1}',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Mood
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  summary.todayMood == null
                      ? 'How are you feeling today?'
                      : 'Today you felt',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final MoodOption m in moodOptions)
                      _MoodFace(
                        option: m,
                        selected: summary.todayMood == m.value,
                        onTap: () => onMoodTap(m.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quests
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                        child: Text("Today's quests",
                            style: theme.textTheme.titleMedium)),
                    Text(
                      '${_questsDone(summary)} / 3',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: mq.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Quest(
                    label: 'Log your mood',
                    xp: 10,
                    done: summary.doneToday.contains('mood_checkin')),
                _Quest(
                    label: 'Chat with Chipu',
                    xp: 2,
                    done: summary.doneToday.contains('chat_message')),
                _Quest(
                    label: 'Read one article',
                    xp: 5,
                    done: summary.doneToday.contains('article_read')),
                const Divider(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Weekly quest: check in on 5 days',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${summary.weekCheckinDays.clamp(0, 5)} / 5',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    const _XpChip(xp: 25),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        FilledButton.icon(
          key: const Key('talk'),
          onPressed: onTalk,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Talk to Chipu'),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('helplines'),
            leading: Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
            title: const Text('Need urgent help? View helplines',
                style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHelplines,
          ),
        ),
      ],
    );
  }

  static int _questsDone(HomeSummary s) => <String>[
        'mood_checkin',
        'chat_message',
        'article_read'
      ].where(s.doneToday.contains).length;
}

class _MoodFace extends StatelessWidget {
  const _MoodFace(
      {required this.option, required this.selected, required this.onTap});

  final MoodOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: InkWell(
        key: Key('mood-${option.value}'),
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(option.emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

class _Quest extends StatelessWidget {
  const _Quest({required this.label, required this.xp, required this.done});

  final String label;
  final int xp;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          _XpChip(xp: xp),
        ],
      ),
    );
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: mq.reward.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10)),
      child: Text(
        '+$xp XP',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            const Text("Couldn't load your progress. Check your connection.",
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick switch between System default, Light and Dark (also in Profile).
class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (BuildContext context, ThemeMode mode, _) =>
          PopupMenuButton<ThemeMode>(
        key: const Key('appearance-button'),
        tooltip: 'Appearance',
        initialValue: mode,
        onSelected: controller.set,
        icon: Icon(switch (mode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        }),
        itemBuilder: (BuildContext context) =>
            const <PopupMenuEntry<ThemeMode>>[
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.system, child: Text('System default')),
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.light, child: Text('Light mode')),
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark, child: Text('Dark mode')),
        ],
      ),
    );
  }
}
