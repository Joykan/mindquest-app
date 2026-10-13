import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../home/progress_repository.dart';
import 'check_in_summary.dart';
import 'mood_tags.dart';
import 'moods.dart';

/// Mood check-in (wireframe 07, UC-02 Log mood entry).
/// The first check-in each day earns 10 XP and keeps the streak going.
class MoodScreen extends StatefulWidget {
  const MoodScreen({
    super.key,
    required this.repository,
    this.initialMood,
    this.onSaved,
    this.onBack,
    this.onHistory,
    this.onSupport,
    this.onTalk,
  });

  /// Opens the Support screen (offered after a low mood).
  final VoidCallback? onSupport;

  /// Opens the chat (offered after a low mood).
  final VoidCallback? onTalk;

  final ProgressRepository repository;

  /// Face tapped on the Home screen, if any.
  final int? initialMood;

  /// Called after a successful save (e.g. to refresh Home).
  final VoidCallback? onSaved;

  /// Shows a back arrow (to Home) when given.
  final VoidCallback? onBack;

  /// Shows a "View history" button when given.
  final VoidCallback? onHistory;

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final TextEditingController _note = TextEditingController();
  late int? _mood = widget.initialMood;
  final Set<String> _tags = <String>{};
  bool _saving = false;

  @override
  void didUpdateWidget(MoodScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialMood != null && widget.initialMood != old.initialMood) {
      setState(() => _mood = widget.initialMood);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final int? mood = _mood;
    if (mood == null) return;
    final List<String> tags = <String>[
      for (final MoodTag t in moodTags)
        if (_tags.contains(t.id)) t.id,
    ];
    final String lang = context.lang;
    setState(() => _saving = true);
    final MoodSaved saved;
    try {
      saved = await widget.repository
          .logMood(mood: mood, note: _note.text, tags: tags);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr(
                  lang,
                  "Couldn't save. Check your connection and try again.",
                  'Imeshindikana kuhifadhi. Angalia mtandao wako kisha ujaribu tena.'))),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _mood = null;
      _tags.clear();
      _note.clear();
    });
    final CheckInNext next = await showCheckInSummary(
      context,
      mood: mood,
      saved: saved,
      repository: widget.repository,
      tags: tags,
      canOpenSupport: widget.onSupport != null,
      canTalk: widget.onTalk != null,
    );
    if (!mounted) return;
    widget.onSaved?.call();
    switch (next) {
      case CheckInNext.support:
        widget.onSupport?.call();
      case CheckInNext.talk:
        widget.onTalk?.call();
      case CheckInNext.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(
        leading:
            widget.onBack == null ? null : BackButton(onPressed: widget.onBack),
        title: Text(context.tr('Mood check-in', 'Rekodi hisia')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                  context.tr('How are you feeling right now?',
                      'Unajisikiaje sasa hivi?'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              // Same height for every box, even when a label wraps
              // ("Vibaya sana").
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final MoodOption m in moodOptions)
                      _MoodChoice(
                        option: m,
                        selected: _mood == m.value,
                        onTap: () => setState(() => _mood = m.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr("What's it about?", 'Inahusu nini?'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                context.tr(
                    'Optional. Pick any that fit. Chipu uses them to spot patterns.',
                    'Si lazima. Chagua zinazofaa. Chipu huzitumia kugundua mwelekeo.'),
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MoodTag t in moodTags)
                    FilterChip(
                      key: Key('tag-${t.id}'),
                      label: Text('${t.emoji} ${t.label(context.lang)}'),
                      selected: _tags.contains(t.id),
                      onSelected: (bool on) => setState(
                          () => on ? _tags.add(t.id) : _tags.remove(t.id)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                  context.tr(
                      'Want to add a note?', 'Ungependa kuongeza maelezo?'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                context.tr('Optional. Only you can see it.',
                    'Si lazima. Ni wewe tu unayeweza kuyaona.'),
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('mood-note'),
                controller: _note,
                minLines: 3,
                maxLines: 5,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: context.tr("What's on your mind?", 'Unawaza nini?'),
                  border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-mood'),
                onPressed: _mood == null || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(context.tr('Save check-in', 'Hifadhi')),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                    'Your first check-in each day earns +10 XP and keeps your streak going.',
                    'Rekodi yako ya kwanza kila siku inakupa +10 XP na kuendeleza mfululizo wako.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              if (widget.onHistory != null) ...<Widget>[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('view-history'),
                  onPressed: widget.onHistory,
                  icon: const Icon(Icons.history),
                  label: Text(
                      context.tr('View mood history', 'Ona historia ya hisia')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodChoice extends StatelessWidget {
  const _MoodChoice(
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
        key: Key('choose-mood-${option.value}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(option.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(option.name(context.lang),
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
