import 'package:flutter/material.dart';

import '../../core/widgets/reload_when_visible.dart';
import '../../core/l10n/tr.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/logo_mark.dart';
import '../../core/widgets/mascot.dart';
import '../challenges/challenge_widgets.dart';
import '../challenges/challenges.dart';
import '../chat/chat_models.dart';
import '../chat/crisis_sheet.dart';
import '../gamification/levels.dart';
import '../gamification/outfits.dart';
import '../learn/learn_repository.dart';
import '../learn/recommend.dart';
import '../mood/moods.dart';
import '../reminders/reminder_widgets.dart';
import '../reminders/reminders.dart';
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
    this.learn,
    this.onOpenArticle,
    this.onSupport,
    this.onMoodHistory,
    this.reminders,
    this.outfits,
    this.challenges,
    this.onChallenges,
  });

  /// Themed challenges; without it the challenge card is hidden.
  final ChallengesRepository? challenges;
  final VoidCallback? onChallenges;

  /// What Chipu wears; Home also celebrates newly unlocked outfits.
  final OutfitController? outfits;

  /// Asks once whether the user wants a daily reminder.
  final ReminderController? reminders;

  /// For "Recommended for you". Without it the section is hidden.
  final LearnRepository? learn;
  final ValueChanged<Article>? onOpenArticle;

  /// Opens the Support screen; without it the helplines open in a sheet.
  final VoidCallback? onSupport;

  /// Opens mood history from the "This week" strip.
  final VoidCallback? onMoodHistory;

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

/// The week's moods and article picks, loaded next to the summary.
class HomeExtras {
  const HomeExtras(
      {this.week = const <MoodEntry>[],
      this.picks = const <Recommendation>[],
      this.challenges});

  final List<MoodEntry> week;
  final List<Recommendation> picks;
  final ChallengesState? challenges;
}

class HomeScreenState extends State<HomeScreen>
    with ReloadWhenVisible<HomeScreen> {
  late Future<HomeSummary> _summary = _loadSummary();

  Future<HomeSummary> _loadSummary() =>
      widget.repository.loadHome().then((HomeSummary s) {
        _afterLoad(s);
        return s;
      });

  /// Shows the user's outfit everywhere, and celebrates a new level once.
  void _afterLoad(HomeSummary s) {
    final OutfitController? outfits = widget.outfits;
    if (outfits == null || !mounted) return;
    outfits.show(s.outfit);
    final int level = levelForXp(s.xp);
    final List<Outfit> unlocked = outfits.newUnlocks(level);
    if (unlocked.isNotEmpty) {
      showLevelUp(context, level: level, unlocked: unlocked, outfits: outfits);
    }
  }
  late Future<HomeExtras> _extras = _loadExtras();

  /// Extras are a bonus: if any part fails, Home still shows the rest.
  /// The parts are loaded at the same time.
  Future<HomeExtras> _loadExtras() async {
    Future<T?> optional<T>(Future<T> Function()? load) async {
      if (load == null) return null;
      try {
        return await load();
      } catch (_) {
        return null; // Optional: Home works without it.
      }
    }

    final ChallengesRepository? challengeRepo = widget.challenges;
    final LearnRepository? learn = widget.learn;
    final List<Object?> r = await Future.wait<Object?>(<Future<Object?>>[
      optional<List<MoodEntry>>(
          () => widget.repository.loadMoodHistory(days: 7)),
      optional<Map<String, int>>(widget.repository.loadChatFeelings),
      optional<ChallengesState>(challengeRepo?.load),
      optional<List<Article>>(learn?.loadArticles),
    ]);
    final List<MoodEntry> week = r[0] as List<MoodEntry>? ?? const <MoodEntry>[];
    final Map<String, int> feelings =
        r[1] as Map<String, int>? ?? const <String, int>{};
    final List<Article>? articles = r[3] as List<Article>?;
    List<Recommendation> picks = const <Recommendation>[];
    if (articles != null) {
      try {
        picks = recommendArticles(articles,
            recentMoods: week, chatFeelings: feelings);
      } catch (_) {
        // Optional: Home works without it.
      }
    }
    return HomeExtras(
        week: week, picks: picks, challenges: r[2] as ChallengesState?);
  }

  @override
  Listenable? get reloadSignal => widget.reloadWhen;

  @override
  Future<void> reloadNow() => reload();

  /// Reloads the numbers, e.g. after a mood check-in.
  Future<void> reload() async {
    final Future<HomeSummary> next = _loadSummary();
    setState(() {
      _summary = next;
      _extras = _loadExtras();
    });
    await next;
  }

  Future<void> _showHelplines() async {
    try {
      final List<Helpline> lines = await widget.repository.loadHelplines();
      if (!mounted) return;
      await showCrisisSheet(
        context,
        ChatReply(
          reply: context.tr(
              'If things feel too heavy right now, talking to someone can help. '
                  'These services are free and confidential.',
              'Mambo yakikulemea sasa hivi, kuongea na mtu kunaweza kusaidia. '
                  'Huduma hizi ni bure na za siri.'),
          helplines: lines,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr(
                "Couldn't load helplines. In an emergency call 999 or 112.",
                'Imeshindikana kupakia nambari za msaada. Katika dharura piga 999 au 112.'))),
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
              child: FutureBuilder<HomeExtras>(
                future: _extras,
                builder:
                    (BuildContext context, AsyncSnapshot<HomeExtras> extras) =>
                        _HomeBody(
                  summary: snap.data!,
                  extras: extras.data ?? const HomeExtras(),
                  onMoodTap: widget.onMoodTap,
                  onTalk: widget.onTalk,
                  onProfile: widget.onProfile,
                  onHelplines: widget.onSupport ?? _showHelplines,
                  onMoodHistory: widget.onMoodHistory,
                  onOpenArticle: widget.onOpenArticle,
                  theme: widget.theme,
                  reminders: widget.reminders,
                  onChallenges: widget.onChallenges,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.summary,
    required this.extras,
    required this.onMoodTap,
    required this.onTalk,
    required this.onProfile,
    required this.onHelplines,
    this.onMoodHistory,
    this.onOpenArticle,
    this.theme,
    this.reminders,
    this.onChallenges,
  });

  final VoidCallback? onChallenges;
  final ReminderController? reminders;
  final HomeExtras extras;
  final VoidCallback? onMoodHistory;
  final ValueChanged<Article>? onOpenArticle;

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
    final LevelTitle title = levelTitle(level.level);
    final String lang = context.lang;

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
              tooltip:
                  context.tr('Profile and settings', 'Wasifu na mipangilio'),
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      context.tr('Hi, ${summary.username}',
                          'Habari, ${summary.username}'),
                      style: theme.textTheme.headlineSmall),
                  Text(
                    longDate(lang, nairobiNow()),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: mq.textMuted),
                  ),
                ],
              ),
            ),
            const Mascot(pose: MascotPose.wave, size: 64),
          ],
        ),
        const SizedBox(height: 12),

        // Streak and level
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Streak on the left, level pill on the right. When both
                // don't fit (long Kiswahili text or a big system font), the
                // pill moves to the next line instead of being cut off.
                // Full width, so spaceBetween can push the pill to the right
                // (a Wrap is otherwise only as wide as its children).
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text('🔥', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              summary.streak == 0
                                  ? context.tr('Start your streak today',
                                      'Anza mfululizo wako leo')
                                  : context.tr(
                                      summary.streak == 1
                                          ? '1-day streak'
                                          : '${summary.streak}-day streak',
                                      'Mfululizo wa siku ${summary.streak}'),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: mq.reward,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '${context.tr('Level', 'Kiwango')} ${level.level} · ${title.emoji} ${title.name(lang)}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: mq.onReward),
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.streak > 0) RestDayLine(summary: summary),
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
                  context.tr(
                      '${level.earned} / ${level.needed} XP to Level ${level.level + 1}',
                      'XP ${level.earned} / ${level.needed} kufikia Kiwango ${level.level + 1}'),
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
                      ? context.tr(
                          'How are you feeling today?', 'Unajisikiaje leo?')
                      : context.tr('Today you felt', 'Leo ulijisikia'),
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

        _WeekStrip(week: extras.week, onTap: onMoodHistory),
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
                        child: Text(
                            context.tr("Today's quests", 'Changamoto za leo'),
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
                    label: context.tr('Log your mood', 'Rekodi hisia zako'),
                    xp: 10,
                    done: summary.doneToday.contains('mood_checkin')),
                _Quest(
                    label: context.tr('Chat with Chipu', 'Ongea na Chipu'),
                    xp: 2,
                    done: summary.doneToday.contains('chat_message')),
                _Quest(
                    label: context.tr('Read one article', 'Soma makala moja'),
                    xp: 5,
                    done: summary.doneToday.contains('article_read')),
                const Divider(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.tr('Weekly quest: check in on 5 days',
                            'Changamoto ya wiki: rekodi hisia siku 5'),
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
        if (extras.challenges != null && onChallenges != null) ...<Widget>[
          const SizedBox(height: 12),
          ChallengeHomeCard(state: extras.challenges!, onOpen: onChallenges!),
        ],
        if (reminders != null) ReminderPrompt(reminders: reminders!),
        if (extras.picks.isNotEmpty && onOpenArticle != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(context.tr('Recommended for you', 'Tunakupendekezea'),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final Recommendation r in extras.picks)
            Card(
              margin: const EdgeInsets.only(top: 8),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: Key('recommended-${r.article.id}'),
                leading: Text(categoryEmoji[r.article.category] ?? '📄',
                    style: const TextStyle(fontSize: 26)),
                title: Text(r.article.title(lang),
                    style: theme.textTheme.titleSmall),
                subtitle: Text(context.tr(
                    '${r.reason} · ${r.article.minutes} min',
                    '${r.reasonIn('sw')} · dakika ${r.article.minutes}')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenArticle!(r.article),
              ),
            ),
        ],
        const SizedBox(height: 16),

        FilledButton.icon(
          key: const Key('talk'),
          onPressed: onTalk,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(context.tr('Talk to Chipu', 'Ongea na Chipu')),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('helplines'),
            leading: Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
            title: Text(context.tr('Need support?', 'Unahitaji msaada?'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(context.tr('Helplines and calming exercises',
                'Nambari za msaada na mazoezi ya kutuliza')),
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
      label: option.name(context.lang),
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
            Text(
                context.tr(
                    "Couldn't load your progress. Check your connection.",
                    'Imeshindikana kupakia maendeleo yako. Angalia mtandao wako.'),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
              onPressed: onRetry,
              child: Text(context.tr('Try again', 'Jaribu tena')),
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
        tooltip: context.tr('Appearance', 'Mwonekano'),
        initialValue: mode,
        onSelected: controller.set,
        icon: Icon(switch (mode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        }),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.system,
              child: Text(context.tr('System default', 'Kama simu yako'))),
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: Text(context.tr('Light mode', 'Mwanga'))),
          PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: Text(context.tr('Dark mode', 'Giza'))),
        ],
      ),
    );
  }
}

/// This week (Monday to Sunday): the latest mood face for each day.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week, this.onTap});

  final List<MoodEntry> week;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final DateTime n = nairobiNow();
    final DateTime today = DateTime(n.year, n.month, n.day);
    final DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    final Map<String, int> latest = <String, int>{};
    for (final MoodEntry e in week) {
      latest.putIfAbsent(
          '${e.at.year}-${e.at.month}-${e.at.day}', () => e.mood);
    }
    return Card(
      key: const Key('week-strip'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                      child: Text(context.tr('This week', 'Wiki hii'),
                          style: theme.textTheme.titleMedium)),
                  if (onTap != null)
                    Text(context.tr('History →', 'Historia →'),
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(builder: (BuildContext context) {
                        final DateTime d = monday.add(Duration(days: i));
                        final int? mood =
                            latest['${d.year}-${d.month}-${d.day}'];
                        final bool isToday = d == today;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.12)
                                : mq.surfaceSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 1.5)
                                : null,
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                mood == null
                                    ? '·'
                                    : moodOptions[mood - 1].emoji,
                                style: TextStyle(
                                    fontSize: 20, color: mq.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(shortDay(context.lang, d.weekday),
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(fontSize: 10)),
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
      ),
    );
  }
}

/// One line under the streak about this week's rest day; tap to learn how
/// rest days work.
class RestDayLine extends StatelessWidget {
  const RestDayLine({super.key, required this.summary});

  final HomeSummary summary;

  static Future<void> explain(BuildContext context) => showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(context.tr('Rest days 🛌', 'Siku za kupumzika 🛌')),
          content: Text(context.tr(
              'Everyone misses a day sometimes. Each week (Monday to Sunday) '
                  'you get one rest day: if you miss one day, your streak keeps '
                  'going. Miss two days in a row, or a second day in the same '
                  'week, and the streak starts again. Your XP, level and badges '
                  'always stay.',
              'Kila mtu hukosa siku moja mara kwa mara. Kila wiki (Jumatatu hadi '
                  'Jumapili) unapata siku moja ya kupumzika: ukikosa siku moja, '
                  'mfululizo wako unaendelea. Ukikosa siku mbili mfululizo, au siku '
                  'ya pili katika wiki hiyo hiyo, mfululizo unaanza upya. XP, '
                  'kiwango na beji zako hubaki daima.')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Got it', 'Nimeelewa')),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String text = summary.restYesterday
        ? context.tr(
            'Yesterday was your rest day. Check in today to keep your streak!',
            'Jana ilikuwa siku yako ya kupumzika. Rekodi hisia leo ili mfululizo uendelee!')
        : summary.restUsedThisWeek
            ? context.tr('Rest day used this week',
                'Siku ya kupumzika imetumika wiki hii')
            : context.tr('Rest day ready: miss a day and your streak stays',
                'Siku ya kupumzika ipo: ukikosa siku moja, mfululizo unabaki');
    return InkWell(
      key: const Key('rest-day'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => explain(context),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: <Widget>[
            const Text('🛌', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: summary.restYesterday
                        ? theme.colorScheme.primary
                        : mq.textMuted,
                    fontWeight: summary.restYesterday ? FontWeight.w700 : null),
              ),
            ),
            Icon(Icons.info_outline, size: 16, color: mq.textMuted),
          ],
        ),
      ),
    );
  }
}

/// "Level up!" with the outfits Chipu just unlocked. "Put it on" wears the
/// newest one.
Future<void> showLevelUp(BuildContext context,
    {required int level,
    required List<Outfit> unlocked,
    required OutfitController outfits}) {
  final String lang = LanguageScope.of(context);
  final LevelTitle title = levelTitle(level);
  final Outfit newest = unlocked.last;
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      key: const Key('level-up-dialog'),
      title: Text(tr(lang, 'Level up! 🎉', 'Umepanda kiwango! 🎉'),
          textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Mascot(
              pose: MascotPose.happy,
              size: 120,
              outfit: newest.id,
              followScope: false),
          const SizedBox(height: 8),
          Text(
            tr(
                lang,
                'You reached Level $level · ${title.emoji} ${title.name(lang)}. '
                    'Chipu is growing with you!',
                'Umefikia Kiwango $level · ${title.emoji} ${title.name(lang)}. '
                    'Chipu anakua pamoja nawe!'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
                lang,
                'New for Chipu: ${unlocked.map((Outfit o) => '${o.emoji} ${o.name(lang)}').join(', ')}',
                'Kipya kwa Chipu: ${unlocked.map((Outfit o) => '${o.emoji} ${o.name(lang)}').join(', ')}'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(lang, 'Later', 'Baadaye')),
        ),
        FilledButton(
          key: const Key('wear-new-outfit'),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          onPressed: () {
            Navigator.of(context).pop();
            outfits.wear(newest.id).catchError((Object _) {});
          },
          child: Text(tr(lang, 'Put it on', 'Mvalishe')),
        ),
      ],
    ),
  );
}
