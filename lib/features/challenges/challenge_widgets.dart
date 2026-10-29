import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import 'challenges.dart';

/// The challenge card on Home: the running challenge with its progress, a
/// "well done" after finishing one, or this week's suggestion.
class ChallengeHomeCard extends StatelessWidget {
  const ChallengeHomeCard({super.key, required this.state, required this.onOpen});

  final ChallengesState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String lang = context.lang;
    final ActiveChallenge? active = state.active;
    final Challenge? recent = state.recent;
    final Challenge? featured = state.featured();

    Widget body;
    if (active != null) {
      final int left = active.daysLeft();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
            emoji: active.challenge.emoji,
            title: active.challenge.name(lang),
            trailing: tr(lang, left == 1 ? 'Last day' : '$left days left',
                left == 1 ? 'Siku ya mwisho' : 'Siku $left zimebaki'),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: active.fraction,
              minHeight: 8,
              backgroundColor: mq.surfaceSoft,
              color: AppPalette.mint,
            ),
          ),
          const SizedBox(height: 6),
          for (final ChallengeStep s in active.steps) _StepLine(step: s),
        ],
      );
    } else if (recent != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
              emoji: '🎉',
              title: tr(lang, 'Challenge complete!', 'Changamoto imekamilika!'),
              trailing: '+${recent.xp} XP'),
          const SizedBox(height: 6),
          Text(
            tr(
                lang,
                'You finished ${recent.emoji} ${recent.name(lang)}. Ready for another one?',
                'Umekamilisha ${recent.emoji} ${recent.name(lang)}. Uko tayari kwa nyingine?'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    } else if (featured != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
              emoji: featured.emoji,
              title: tr(lang, "This week's challenge", 'Changamoto ya wiki hii'),
              trailing: '+${featured.xp} XP'),
          const SizedBox(height: 6),
          Text('${featured.name(lang)}: ${featured.describe(lang)}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            tr(lang, '${featured.days} days · a badge at the end',
                'Siku ${featured.days} · beji mwishoni'),
            style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('challenge-card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              body,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  active != null
                      ? tr(lang, 'Open →', 'Fungua →')
                      : tr(lang, 'See challenges →', 'Ona changamoto →'),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.emoji, required this.title, required this.trailing});

  final String emoji;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        const SizedBox(width: 8),
        Text(trailing, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.step, this.onTap});

  final ChallengeStep step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final bool done = step.complete;
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? theme.colorScheme.primary : theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(step.label(context.lang),
                style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null)),
          ),
          const SizedBox(width: 8),
          Text('${step.done.clamp(0, step.target)} / ${step.target}',
              style: theme.textTheme.labelLarge?.copyWith(color: mq.textMuted)),
          if (onTap != null && !done)
            Icon(Icons.chevron_right, size: 20, color: mq.textMuted),
        ],
      ),
    );
    if (onTap == null || done) return row;
    return InkWell(
        key: Key('step-${step.kind}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: row);
  }
}

/// All challenges: the running one with its progress (each step opens the
/// place to do it), and the others to start. One at a time.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen(
      {super.key, required this.repository, this.onStep, this.onChanged});

  final ChallengesRepository repository;

  /// Opens the place for a step: mood, chat, support or learn.
  final ValueChanged<String>? onStep;

  /// Called after starting or leaving a challenge (Home reloads).
  final VoidCallback? onChanged;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late Future<ChallengesState> _state = widget.repository.load();
  bool _busy = false;

  Future<void> _reload() async {
    final Future<ChallengesState> next = widget.repository.load();
    setState(() {
      _state = next;
    });
    await next;
  }

  void _say(String text) {
    final ScaffoldMessengerState m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(text)));
  }

  String _problem(String lang, Object e) {
    final String reason = e is ChallengeException ? e.reason : 'other';
    return switch (reason) {
      'offline' => tr(lang, 'You need internet for this. Try again when online.',
          'Unahitaji mtandao kwa hili. Jaribu tena ukiwa mtandaoni.'),
      'busy' => tr(lang, 'Finish or leave your current challenge first.',
          'Kamilisha au acha changamoto yako ya sasa kwanza.'),
      _ => tr(lang, 'Something went wrong. Try again.',
          'Kuna tatizo. Jaribu tena.'),
    };
  }

  Future<void> _start(Challenge c) async {
    final String lang = context.lang;
    setState(() => _busy = true);
    try {
      await widget.repository.start(c.id);
      widget.onChanged?.call();
      _say(tr(lang, "${c.emoji} ${c.name(lang)} started. You've got this!",
          '${c.emoji} ${c.name(lang)} imeanza. Unaweza!'));
      await _reload();
    } catch (e) {
      _say(_problem(lang, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(ActiveChallenge a) async {
    final String lang = context.lang;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(tr(lang, 'Leave this challenge?', 'Acha changamoto hii?')),
        content: Text(tr(
            lang,
            'Your progress in it will be lost. XP and badges you already have stay. You can start it again any time.',
            'Maendeleo yako ndani yake yatapotea. XP na beji ulizonazo zitabaki. Unaweza kuianza tena wakati wowote.')),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr(lang, 'Keep going', 'Endelea'))),
          TextButton(
              key: const Key('confirm-leave'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr(lang, 'Leave', 'Acha'))),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.leave();
      widget.onChanged?.call();
      await _reload();
    } catch (e) {
      _say(_problem(lang, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'Challenges', 'Changamoto'))),
      body: FutureBuilder<ChallengesState>(
        future: _state,
        builder: (BuildContext context, AsyncSnapshot<ChallengesState> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: Text(tr(
                    lang,
                    "Couldn't load the challenges. Tap to try again.",
                    'Imeshindikana kupakia changamoto. Gusa ujaribu tena.')),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ChallengesState s = snap.data!;
          final ActiveChallenge? active = s.active;
          final String? featuredId = s.featured()?.id;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                Text(
                  tr(
                      lang,
                      'Pick one challenge at a time. Finish it within its days for bonus XP and its own badge. No pressure: you can leave and come back any time.',
                      'Chagua changamoto moja kwa wakati. Ikamilishe ndani ya siku zake upate XP ya ziada na beji yake. Hakuna shinikizo: unaweza kuiacha na kurudi wakati wowote.'),
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
                ),
                const SizedBox(height: 12),
                if (active != null) ...<Widget>[
                  Card(
                    key: const Key('active-challenge'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Header(
                            emoji: active.challenge.emoji,
                            title: active.challenge.name(lang),
                            trailing: tr(
                                lang,
                                active.daysLeft() == 1
                                    ? 'Last day'
                                    : '${active.daysLeft()} days left',
                                active.daysLeft() == 1
                                    ? 'Siku ya mwisho'
                                    : 'Siku ${active.daysLeft()} zimebaki'),
                          ),
                          const SizedBox(height: 6),
                          Text(active.challenge.describe(lang),
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: active.fraction,
                              minHeight: 10,
                              backgroundColor: mq.surfaceSoft,
                              color: AppPalette.mint,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final ChallengeStep st in active.steps)
                            _StepLine(
                              step: st,
                              onTap: widget.onStep == null
                                  ? null
                                  : () => widget.onStep!(st.place),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                                lang,
                                'Finish for +${active.challenge.xp} XP and a badge.',
                                'Ikamilishe upate XP +${active.challenge.xp} na beji.'),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: mq.textMuted),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('leave-challenge'),
                              onPressed: _busy ? null : () => _leave(active),
                              child: Text(tr(lang, 'Leave challenge',
                                  'Acha changamoto')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tr(lang, 'Other challenges', 'Changamoto nyingine'),
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                for (final Challenge c in s.challenges)
                  if (c.id != active?.challenge.id)
                    _ChallengeTile(
                      challenge: c,
                      featured: c.id == featuredId,
                      canStart: active == null && !_busy,
                      onStart: () => _start(c),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.challenge,
    required this.featured,
    required this.canStart,
    required this.onStart,
  });

  final Challenge challenge;
  final bool featured;
  final bool canStart;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String lang = context.lang;
    final Challenge c = challenge;
    return Card(
      key: Key('challenge-${c.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Header(
                emoji: c.emoji, title: c.name(lang), trailing: '+${c.xp} XP'),
            if (featured || c.completed > 0) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (featured)
                    _Pill(
                        text: tr(lang, '⭐ This week', '⭐ Wiki hii'),
                        color: mq.reward,
                        textColor: mq.onReward),
                  if (c.completed > 0)
                    _Pill(
                        text: tr(lang, '✓ Done ${c.completed}×',
                            '✓ Umeimaliza mara ${c.completed}'),
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        textColor: theme.colorScheme.primary),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(c.describe(lang), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            for (final ChallengeStep st in c.steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('•  ${st.label(lang)}',
                    style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 4),
            Text(
              tr(lang, '${c.days} days, starting today',
                  'Siku ${c.days}, kuanzia leo'),
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: Key('start-${c.id}'),
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                onPressed: canStart ? onStart : null,
                child: Text(tr(lang, 'Start', 'Anza')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.textColor});

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: textColor)),
      );
}
