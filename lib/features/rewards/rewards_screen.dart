import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../gamification/badges.dart';
import '../gamification/levels.dart';
import 'rewards_repository.dart';

/// Rewards (wireframe 11): level and XP, the weekly quest, badges with
/// progress, how to earn XP, and recent XP.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({
    super.key,
    required this.repository,
    this.language = 'en',
    this.onBack,
    this.reloadWhen,
  });

  final RewardsRepository repository;
  final String language;
  final VoidCallback? onBack;
  final Listenable? reloadWhen;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<RewardsSummary> _summary = widget.repository.loadRewards();

  @override
  void initState() {
    super.initState();
    widget.reloadWhen?.addListener(_reload);
  }

  @override
  void dispose() {
    widget.reloadWhen?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final Future<RewardsSummary> next = widget.repository.loadRewards();
    setState(() => _summary = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading:
            widget.onBack == null ? null : BackButton(onPressed: widget.onBack),
        title: Text(widget.language == 'sw' ? 'Zawadi' : 'Rewards'),
      ),
      body: FutureBuilder<RewardsSummary>(
        future: _summary,
        builder: (BuildContext context, AsyncSnapshot<RewardsSummary> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child:
                    const Text("Couldn't load your rewards. Tap to try again."),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final RewardsSummary s = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                _LevelCard(summary: s),
                const SizedBox(height: 12),
                _QuestCard(summary: s),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                        child:
                            Text('Badges', style: theme.textTheme.titleMedium)),
                    Text('${s.badgesEarned} of ${s.badges.length}',
                        style: theme.textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final double width = (box.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        for (final BadgeStatus b in s.badges)
                          SizedBox(
                              width: width,
                              child: _BadgeTile(
                                  status: b, language: widget.language)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text('Ways to earn XP', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: <Widget>[
                      for (final (String emoji, String what, int xp) in xpRules)
                        ListTile(
                          dense: true,
                          leading:
                              Text(emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(what),
                          trailing: Text('+$xp XP',
                              style: theme.textTheme.labelLarge),
                        ),
                    ],
                  ),
                ),
                if (s.recent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text('Recent XP', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final XpEvent e in s.recent)
                          ListTile(
                            dense: true,
                            title: Text(e.label),
                            subtitle: Text(_date(e.at)),
                            trailing: Text(
                              '+${e.amount} XP',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary});

  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final LevelProgress level = LevelProgress(summary.xp);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Mascot(pose: MascotPose.happy, size: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Level ${level.level}',
                      style: theme.textTheme.headlineSmall),
                  Text(
                      '${summary.xp} XP in total · '
                      '${summary.streak == 0 ? 'No streak yet' : '${summary.streak}-day streak 🔥'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: mq.textMuted)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: level.fraction,
                      minHeight: 10,
                      backgroundColor: mq.surfaceSoft,
                      color: AppPalette.mint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${level.earned} / ${level.needed} XP to Level ${level.level + 1}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: mq.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.summary});

  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final int days = summary.weekCheckinDays.clamp(0, 5);
    return Card(
      key: const Key('weekly-quest'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🎯', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Weekly quest',
                        style: theme.textTheme.titleMedium)),
                Text(summary.weeklyQuestDone ? 'Done ✓' : '+25 XP',
                    style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              summary.weeklyQuestDone
                  ? 'You checked in on 5 days this week. Well done!'
                  : 'Check in on 5 days this week (Monday to Sunday).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                for (int i = 0; i < 5; i++)
                  Expanded(
                    child: Container(
                      height: 10,
                      margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i < days
                            ? theme.colorScheme.primary
                            : mq.surfaceSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$days / 5 days · ${summary.questsCompleted} weekly '
              '${summary.questsCompleted == 1 ? 'quest' : 'quests'} completed so far',
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.status, required this.language});

  final BadgeStatus status;
  final String language;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final RewardBadge b = status.badge;
    final bool earned = status.earned;
    return Semantics(
      label: '${b.displayName(language)}. ${b.description}. '
          '${earned ? 'Earned' : 'Not earned yet, ${status.progress} of ${status.goal}'}',
      excludeSemantics: true,
      child: Card(
        key: Key('badge-${b.id}'),
        color: earned ? null : mq.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Opacity(
                opacity: earned ? 1 : 0.35,
                child: Text(b.emoji, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 6),
              Text(
                b.displayName(language),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                b.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 8),
              if (earned)
                Text(
                  'Earned ${_date(status.earnedAt!)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                )
              else ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: status.fraction,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.progress.clamp(0, status.goal)} / ${status.goal}',
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: mq.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
