import 'package:flutter/material.dart';

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
    this.language = 'en',
  });

  /// Opens the Support screen (offered after a low mood).
  final VoidCallback? onSupport;

  /// Opens the chat (offered after a low mood).
  final VoidCallback? onTalk;
  final String language;

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
    setState(() => _saving = true);
    final MoodSaved saved;
    try {
      saved = await widget.repository.logMood(mood: mood, note: _note.text, tags: tags);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Check your connection and try again.")),
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
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: const Text('Mood check-in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('How are you feeling right now?',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final MoodOption m in moodOptions)
                    _MoodChoice(
                      option: m,
                      selected: _mood == m.value,
                      onTap: () => setState(() => _mood = m.value),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text("What's it about?", style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optional. Pick any that fit. Chipu uses them to spot patterns.',
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
                      label: Text('${t.emoji} ${t.label(widget.language)}'),
                      selected: _tags.contains(t.id),
                      onSelected: (bool on) => setState(() => on ? _tags.add(t.id) : _tags.remove(t.id)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Want to add a note?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Optional. Only you can see it.',
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('mood-note'),
                controller: _note,
                minLines: 3,
                maxLines: 5,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  enabledBorder: OutlineInputBorder(
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
                    : const Text('Save check-in'),
              ),
              const SizedBox(height: 8),
              Text(
                'Your first check-in each day earns +10 XP and keeps your streak going.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              if (widget.onHistory != null) ...<Widget>[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('view-history'),
                  onPressed: widget.onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('View mood history'),
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
      label: option.label,
      child: InkWell(
        key: Key('choose-mood-${option.value}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 60,
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
            children: <Widget>[
              Text(option.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(option.label,
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
