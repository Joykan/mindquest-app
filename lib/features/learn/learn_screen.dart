import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'learn_repository.dart';

/// Learn (wireframe 09): short articles by topic. Each article read earns
/// 5 XP once; three earn the Curious Mind badge.
class LearnScreen extends StatefulWidget {
  const LearnScreen({
    super.key,
    required this.repository,
    required this.onOpen,
    this.language = 'en',
    this.onBack,
    this.reloadWhen,
  });

  final LearnRepository repository;
  final ValueChanged<Article> onOpen;

  /// Which language to show titles in ('en' or 'sw').
  final String language;
  final VoidCallback? onBack;

  /// Reloads (e.g. after an article is marked read).
  final Listenable? reloadWhen;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<List<Article>> _articles = widget.repository.loadArticles();
  String? _category; // null = all

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
    final Future<List<Article>> next = widget.repository.loadArticles();
    setState(() => _articles = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String lang = widget.language;
    return Scaffold(
      appBar: AppBar(
        leading:
            widget.onBack == null ? null : BackButton(onPressed: widget.onBack),
        title: Text(lang == 'sw' ? 'Jifunze' : 'Learn'),
      ),
      body: FutureBuilder<List<Article>>(
        future: _articles,
        builder: (BuildContext context, AsyncSnapshot<List<Article>> snap) {
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child:
                    const Text("Couldn't load the articles. Tap to try again."),
              ),
            );
          }
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final List<Article> all = snap.data!;
          final List<Article> shown = _category == null
              ? all
              : all.where((Article a) => a.category == _category).toList();
          final int read = all.where((Article a) => a.read).length;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text('📖', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You have read $read of ${all.length}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: all.isEmpty ? 0 : read / all.length,
                            minHeight: 8,
                            backgroundColor: mq.surfaceSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          read < 3
                              ? 'Each new article earns +5 XP. Read ${3 - read} more for the Curious Mind badge 📚'
                              : 'Each new article earns +5 XP.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: mq.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (final String? c in <String?>[
                        null,
                        ...articleCategories
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('category-${c ?? 'all'}'),
                            label: Text(c == null
                                ? (lang == 'sw' ? 'Zote' : 'All')
                                : categoryName(c, lang)),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No articles here yet.',
                        textAlign: TextAlign.center),
                  ),
                for (final Article a in shown)
                  _ArticleTile(
                      article: a,
                      language: lang,
                      onTap: () => widget.onOpen(a)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile(
      {required this.article, required this.language, required this.onTap});

  final Article article;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final List<String> paragraphs = article.paragraphs(language);
    final String firstLine = paragraphs.isEmpty ? '' : paragraphs.first;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('article-${article.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mq.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(categoryEmoji[article.category] ?? '📄',
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(article.title(language),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        firstLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: mq.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${categoryName(article.category, language)} · ${article.minutes} min',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                article.read
                    ? Semantics(
                        label: 'Read',
                        child: Icon(Icons.check_circle,
                            color: theme.colorScheme.primary),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: mq.reward.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('+5 XP', style: theme.textTheme.labelSmall),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
