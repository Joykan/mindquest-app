import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_toggle.dart';
import '../gamification/badge_dialog.dart';
import 'learn_repository.dart';

/// Article (wireframe 10): the text in English or Kiswahili, and a button to
/// mark it read for +5 XP (once per article).
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    super.key,
    required this.article,
    required this.repository,
    this.onRead,
  });

  final Article article;
  final LearnRepository repository;

  /// Called after the article is marked read (e.g. to refresh Learn and Home).
  final VoidCallback? onRead;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  /// Starts in the app's language; the toggle switches only this article.
  late String _lang = LanguageScope.of(context);
  late bool _read = widget.article.read;
  bool _saving = false;

  /// The labels around the article follow the article's language.
  bool get _sw => _lang == 'sw';

  Future<void> _markRead() async {
    setState(() => _saving = true);
    try {
      final ReadResult result =
          await widget.repository.markRead(widget.article.id);
      if (!mounted) return;
      setState(() => _read = true);
      widget.onRead?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.pending
              ? (_sw
                  ? 'Kazi nzuri! Huna mtandao, kwa hiyo +${result.xpEarned} XP itaongezwa ukipata mtandao.'
                  : "Nice work! You're offline, so the +${result.xpEarned} XP is added when you're back online.")
              : result.xpEarned > 0
                  ? '${_sw ? 'Kazi nzuri!' : 'Nice work!'} +${result.xpEarned} XP'
                  : (_sw ? 'Imewekwa kama imesomwa' : 'Marked as read')),
        ),
      );
      if (result.newBadges.isNotEmpty) {
        await showNewBadges(context, result.newBadges, _lang);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_sw
                ? 'Imeshindikana kuhifadhi. Angalia mtandao wako kisha ujaribu tena.'
                : "Couldn't save. Check your connection and try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final Article a = widget.article;
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageToggle(
                value: _lang,
                onChanged: (String l) => setState(() => _lang = l)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(categoryEmoji[a.category] ?? '📄',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sw
                        ? '${categoryName(a.category, _lang)} · dakika ${a.minutes} za kusoma'
                        : '${categoryName(a.category, _lang)} · ${a.minutes} min read',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(a.title(_lang), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final String p in a.paragraphs(_lang))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(p,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(height: 1.55, fontSize: 16)),
              ),
            const SizedBox(height: 8),
            if (_read)
              Container(
                key: const Key('article-read'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: mq.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_sw
                            ? 'Umesoma makala hii.'
                            : 'You have read this article.')),
                  ],
                ),
              )
            else
              FilledButton.icon(
                key: const Key('mark-read'),
                onPressed: _saving ? null : _markRead,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check),
                label:
                    Text(_sw ? 'Nimeisoma · +5 XP' : "I've read this · +5 XP"),
              ),
            const SizedBox(height: 16),
            Text(
              _sw
                  ? 'Makala za MindQuest zinatoa taarifa za jumla. Si ushauri wa kitabibu. '
                      'Ukihitaji msaada, ongea na mshauri au tumia nambari za msaada zilizo kwenye ukurasa wa Nyumbani.'
                  : 'MindQuest articles share general information. They are not medical advice. '
                      'If you need help, talk to a counsellor or use the helplines on Home.',
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
