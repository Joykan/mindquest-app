import 'package:flutter/material.dart';

import '../../core/widgets/reload_when_visible.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../gamification/badges.dart';
import '../gamification/levels.dart';
import '../gamification/outfits.dart';
import 'rewards_repository.dart';

/// Rewards (wireframe 11): level and XP, the weekly quest, badges with
/// progress, how to earn XP, and recent XP.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({
    super.key,
    required this.repository,
    this.onBack,
    this.reloadWhen,
    this.outfits,
  });

  /// What Chipu wears; the wardrobe changes it.
  final OutfitController? outfits;

  final RewardsRepository repository;
  final VoidCallback? onBack;
  final Listenable? reloadWhen;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with ReloadWhenVisible<RewardsScreen> {
  late Future<RewardsSummary> _summary = _load();

  Future<RewardsSummary> _load() =>
      widget.repository.loadRewards().then((RewardsSummary s) {
        if (mounted) widget.outfits?.show(s.outfit);
        return s;
      });

  /// Wears [outfit] (null: none) everywhere at once; the choice is saved in
  /// the background (later, when offline).
  Future<void> _wear(String? outfit) async {
    final OutfitController? controller = widget.outfits;
    final String lang = context.lang;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      if (controller != null) {
        await controller.wear(outfit);
      } else {
        await widget.repository.wearOutfit(outfit);
      }
      final Outfit? o = outfitById(outfit);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(o == null
              ? tr(lang, 'Chipu is wearing nothing special now.',
                  'Chipu hajavaa kitu maalum sasa.')
              : tr(lang, 'Chipu is wearing the ${o.en.toLowerCase()} ${o.emoji}',
                  'Chipu amevaa ${o.sw.toLowerCase()} ${o.emoji}'))));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(tr(lang, "Couldn't change Chipu's outfit. Try again.",
              'Imeshindikana kubadilisha vazi la Chipu. Jaribu tena.'))));
    }
  }

  @override
  Listenable? get reloadSignal => widget.reloadWhen;

  @override
  Future<void> reloadNow() => _reload();

  Future<void> _reload() async {
    if (!mounted) return;
    final Future<RewardsSummary> next = _load();
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
        title: Text(context.tr('Rewards', 'Zawadi')),
      ),
      body: FutureBuilder<RewardsSummary>(
        future: _summary,
        builder: (BuildContext context, AsyncSnapshot<RewardsSummary> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: Text(context.tr(
                    "Couldn't load your rewards. Tap to try again.",
                    'Imeshindikana kupakia zawadi zako. Gusa ujaribu tena.')),
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
                WardrobeCard(level: LevelProgress(s.xp).level, onWear: _wear),
                const SizedBox(height: 12),
                _QuestCard(summary: s),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                        child: Text(context.tr('Badges', 'Beji'),
                            style: theme.textTheme.titleMedium)),
                    Text(
                        context.tr('${s.badgesEarned} of ${s.badges.length}',
                            '${s.badgesEarned} kati ya ${s.badges.length}'),
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
                                  status: b, language: context.lang)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(context.tr('Ways to earn XP', 'Njia za kupata XP'),
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: <Widget>[
                      for (final (
                            String emoji,
                            String what,
                            String whatSw,
                            int xp
                          ) in xpRules)
                        ListTile(
                          dense: true,
                          leading:
                              Text(emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(context.tr(what, whatSw)),
                          trailing: Text('+$xp XP',
                              style: theme.textTheme.labelLarge),
                        ),
                    ],
                  ),
                ),
                if (s.recent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(context.tr('Recent XP', 'XP za karibuni'),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final XpEvent e in s.recent)
                          ListTile(
                            dense: true,
                            title: Text(e.labelIn(context.lang)),
                            subtitle: Text(shortDate(context.lang, e.at)),
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
                  Text('${context.tr('Level', 'Kiwango')} ${level.level}',
                      style: theme.textTheme.headlineSmall),
                  Text(
                      context.tr(
                          '${summary.xp} XP in total · '
                              '${summary.streak == 0 ? 'No streak yet' : '${summary.streak}-day streak 🔥'}',
                          'XP ${summary.xp} kwa jumla · '
                              '${summary.streak == 0 ? 'Bado hakuna mfululizo' : 'Mfululizo wa siku ${summary.streak} 🔥'}'),
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
                      context.tr(
                          '${level.earned} / ${level.needed} XP to Level ${level.level + 1}',
                          'XP ${level.earned} / ${level.needed} kufikia Kiwango ${level.level + 1}'),
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
                    child: Text(
                        context.tr('Weekly quest', 'Changamoto ya wiki'),
                        style: theme.textTheme.titleMedium)),
                Text(
                    summary.weeklyQuestDone
                        ? context.tr('Done ✓', 'Imekamilika ✓')
                        : '+25 XP',
                    style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              summary.weeklyQuestDone
                  ? context.tr('You checked in on 5 days this week. Well done!',
                      'Umerekodi hisia siku 5 wiki hii. Hongera!')
                  : context.tr(
                      'Check in on 5 days this week (Monday to Sunday).',
                      'Rekodi hisia siku 5 wiki hii (Jumatatu hadi Jumapili).'),
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
              context.tr(
                  '$days / 5 days · ${summary.questsCompleted} weekly '
                      '${summary.questsCompleted == 1 ? 'quest' : 'quests'} completed so far',
                  'Siku $days / 5 · changamoto ${summary.questsCompleted} za wiki '
                      'zimekamilika hadi sasa'),
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
      label: '${b.displayName(language)}. ${b.describe(language)}. '
          '${earned ? tr(language, 'Earned', 'Umeipata') : tr(language, 'Not earned yet, ${status.progress} of ${status.goal}', 'Bado hujaipata, ${status.progress} kati ya ${status.goal}')}',
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
                b.describe(language),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 8),
              if (earned)
                Text(
                  tr(
                      language,
                      'Earned ${shortDate(language, status.earnedAt!)}',
                      'Umeipata ${shortDate(language, status.earnedAt!)}'),
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

/// Chipu's wardrobe: every outfit, unlocked ones can be worn.
class WardrobeCard extends StatelessWidget {
  const WardrobeCard({super.key, required this.level, required this.onWear});

  final int level;
  final ValueChanged<String?> onWear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String lang = context.lang;
    final String? wearing = OutfitScope.of(context);
    Outfit? next;
    for (final Outfit o in outfits) {
      if (o.level > level) {
        next = o;
        break;
      }
    }
    return Card(
      key: const Key('wardrobe'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('👕', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr("Chipu's wardrobe", 'Kabati la Chipu'),
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              next == null
                  ? context.tr('Chipu has grown into a forest. Everything is unlocked!',
                      'Chipu amekua msitu. Kila kitu kimefunguliwa!')
                  : context.tr(
                      'Chipu grows with you. Reach Level ${next.level} to unlock the ${next.en.toLowerCase()} ${next.emoji}.',
                      'Chipu anakua pamoja nawe. Fikia Kiwango ${next.level} kufungua ${next.sw.toLowerCase()} ${next.emoji}.'),
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _OutfitTile(
                    keyName: 'none',
                    label: context.tr('Just Chipu', 'Chipu tu'),
                    selected: wearing == null,
                    locked: false,
                    onTap: () => onWear(null),
                    child: const Mascot(size: 64, followScope: false),
                  ),
                  for (final Outfit o in outfits)
                    _OutfitTile(
                      keyName: o.id,
                      label: o.level > level
                          ? tr(lang, 'Level ${o.level}', 'Kiwango ${o.level}')
                          : o.name(lang),
                      selected: wearing == o.id,
                      locked: o.level > level,
                      onTap: () => onWear(o.id),
                      child:
                          Mascot(size: 64, outfit: o.id, followScope: false),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitTile extends StatelessWidget {
  const _OutfitTile({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
    required this.child,
  });

  final String keyName;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: !locked,
        selected: selected,
        label: locked
            ? context.tr('$label, locked', '$label, imefungwa')
            : label,
        excludeSemantics: true,
        child: InkWell(
          key: Key('outfit-$keyName'),
          borderRadius: BorderRadius.circular(16),
          onTap: locked ? null : onTap,
          child: Container(
            width: 92,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : mq.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.4),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Opacity(opacity: locked ? 0.35 : 1, child: child),
                    if (locked)
                      Icon(Icons.lock_outline, color: mq.textMuted, size: 26),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
