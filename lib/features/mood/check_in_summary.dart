import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../home/progress_repository.dart';
import 'mood_insights.dart';
import 'mood_tags.dart';
import 'moods.dart';

/// What the user chose at the end of the check-in summary.
enum CheckInNext { done, support, talk }

/// Shown after a mood is saved: Chipu "thinks" for a moment, then shows the
/// XP and streak, a reply to the mood, and what Chipu noticed (insights).
Future<CheckInNext> showCheckInSummary(
  BuildContext context, {
  required int mood,
  required MoodSaved saved,
  required ProgressRepository repository,
  List<String> tags = const <String>[],
  bool canOpenSupport = false,
  bool canTalk = false,
}) async {
  final CheckInNext? next = await showModalBottomSheet<CheckInNext>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => CheckInSummary(
      mood: mood,
      saved: saved,
      repository: repository,
      tags: tags,
      canOpenSupport: canOpenSupport,
      canTalk: canTalk,
    ),
  );
  return next ?? CheckInNext.done;
}

class CheckInSummary extends StatefulWidget {
  const CheckInSummary({
    super.key,
    required this.mood,
    required this.saved,
    required this.repository,
    this.tags = const <String>[],
    this.canOpenSupport = false,
    this.canTalk = false,
  });

  final int mood;
  final MoodSaved saved;
  final ProgressRepository repository;
  final List<String> tags;
  final bool canOpenSupport;
  final bool canTalk;

  /// How long Chipu "thinks" at least, so the spinner doesn't just flash.
  static const Duration thinking = Duration(milliseconds: 900);

  @override
  State<CheckInSummary> createState() => _CheckInSummaryState();
}

class _CheckInSummaryState extends State<CheckInSummary> {
  late final Future<(List<MoodEntry>, List<MoodInsight>)> _insights = _load();

  Future<(List<MoodEntry>, List<MoodInsight>)> _load() async {
    // Runs during the first build, so the language can be read here.
    final String lang = context.lang;
    final Future<void> wait = Future<void>.delayed(CheckInSummary.thinking);
    List<MoodEntry> history = const <MoodEntry>[];
    Map<String, int> feelings = const <String, int>{};
    try {
      history = await widget.repository.loadMoodHistory();
      feelings = await widget.repository.loadChatFeelings();
    } catch (_) {
      // Insights are a bonus; the check-in is already saved.
    }
    await wait;
    return (
      history,
      pickSummaryInsights(widget.mood, widget.tags, history, feelings,
          language: lang)
    );
  }

  String _title(BuildContext context) => switch (widget.mood) {
        5 => context.tr('Amazing!', 'Safi sana!'),
        4 =>
          context.tr("Glad you're feeling good", 'Nafurahi unajisikia vizuri'),
        3 => context.tr('Thanks for checking in', 'Asante kwa kurekodi hisia'),
        2 => context.tr("Sorry it's a tough day", 'Pole kwa siku ngumu'),
        _ => context.tr("I'm here for you", 'Niko hapa kwa ajili yako'),
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return FutureBuilder<(List<MoodEntry>, List<MoodInsight>)>(
      future: _insights,
      builder: (BuildContext context,
          AsyncSnapshot<(List<MoodEntry>, List<MoodInsight>)> snap) {
        if (!snap.hasData) {
          return Padding(
            key: const Key('insights-thinking'),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Mascot(size: 96),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                    context.tr('Chipu is looking at your moods…',
                        'Chipu anaangalia hisia zako…'),
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        final (List<MoodEntry> history, List<MoodInsight> insights) =
            snap.data!;
        final bool low =
            widget.mood <= 2 || insights.any((MoodInsight i) => i.needsSupport);
        final MoodOption m = moodOptions[widget.mood - 1];
        return SingleChildScrollView(
          key: const Key('check-in-summary'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Mascot(
                  pose: widget.mood >= 4
                      ? MascotPose.happy
                      : (widget.mood == 3 ? MascotPose.wave : MascotPose.idle),
                  size: 96,
                ),
              ),
              const SizedBox(height: 8),
              Text('${m.emoji}  ${_title(context)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (widget.saved.xpEarned > 0)
                    _Pill(
                        text: '+${widget.saved.xpEarned} XP', color: mq.reward),
                  if (widget.saved.pending)
                    _Pill(
                      key: const Key('summary-pending'),
                      text: context.tr(
                          '📴 Saved on your phone · syncs when online',
                          '📴 Imehifadhiwa kwenye simu · itatumwa ukipata mtandao'),
                      color: mq.surfaceSoft,
                    ),
                  _Pill(
                    text: context.tr('🔥 ${widget.saved.streak}-day streak',
                        '🔥 Mfululizo wa siku ${widget.saved.streak}'),
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  for (final String id in widget.tags)
                    if (moodTagById(id) != null)
                      _Pill(
                          text:
                              '${moodTagById(id)!.emoji} ${moodTagById(id)!.label(context.lang)}',
                          color: mq.surfaceSoft),
                ],
              ),
              const SizedBox(height: 14),
              Text(moodReply(widget.mood, context.lang),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 18),
              Text(context.tr('What Chipu noticed', 'Alichogundua Chipu'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final MoodInsight i in insights)
                _NoteCard(
                    key: Key('summary-insight-${i.id}'),
                    emoji: i.emoji,
                    title: i.title,
                    text: i.body),
              if (history.length < insightMinimumCheckIns)
                _NoteCard(
                  emoji: '🔒',
                  text: context.tr(
                      'Check in ${insightMinimumCheckIns - history.length} more '
                          '${insightMinimumCheckIns - history.length == 1 ? 'time' : 'times'} '
                          'and Chipu will start spotting patterns across your days.',
                      'Rekodi hisia mara ${insightMinimumCheckIns - history.length} zaidi '
                          'na Chipu ataanza kugundua mwelekeo wa siku zako.'),
                )
              else if (insights.isEmpty)
                _NoteCard(
                    emoji: '🔍',
                    text: context.tr(
                        'No clear patterns yet. Keep checking in and Chipu will spot them.',
                        'Bado hakuna mwelekeo wazi. Endelea kurekodi hisia na Chipu atauona.')),
              const SizedBox(height: 16),
              if (low && widget.canOpenSupport)
                FilledButton.icon(
                  key: const Key('summary-support'),
                  onPressed: () => Navigator.pop(context, CheckInNext.support),
                  icon: const Icon(Icons.spa_outlined),
                  label: Text(context.tr(
                      'Try a breathing exercise', 'Jaribu zoezi la kupumua')),
                ),
              if (low && widget.canTalk) ...<Widget>[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('summary-talk'),
                  onPressed: () => Navigator.pop(context, CheckInNext.talk),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(context.tr('Talk to Chipu', 'Ongea na Chipu')),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                key: const Key('summary-done'),
                onPressed: () => Navigator.pop(context, CheckInNext.done),
                child: Text(context.tr('Done', 'Sawa')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard(
      {super.key, required this.emoji, required this.text, this.title});

  final String emoji;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: mq.surfaceSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(title!, style: theme.textTheme.titleSmall),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to three insights for the check-in summary: a run of hard days first,
/// then what this check-in shows (compared with usual, ups and downs today,
/// its tags), then patterns across days. The general mood mix is used only
/// if nothing else fits.
List<MoodInsight> pickSummaryInsights(
  int mood,
  List<String> tags,
  List<MoodEntry> history,
  Map<String, int> chatFeelings, {
  String language = 'en',
}) {
  final List<MoodInsight> patterns =
      buildInsights(history, chatFeelings: chatFeelings, language: language);
  final List<MoodInsight> out = <MoodInsight>[
    ...patterns.where((MoodInsight i) => i.needsSupport),
    ...checkInInsights(mood, tags, history, language: language).take(2),
  ];
  for (final MoodInsight i in patterns) {
    if (out.length >= 3) break;
    if (!i.needsSupport && i.id != 'mood_mix') out.add(i);
  }
  if (out.isEmpty) {
    out.addAll(patterns.where((MoodInsight i) => i.id == 'mood_mix'));
  }
  return out.take(3).toList();
}
