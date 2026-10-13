import 'package:flutter/material.dart';

import '../core/l10n/tr.dart';
import '../core/theme/app_colors.dart';
import '../features/learn/learn_repository.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

/// Content management (admin wireframe 2): the learning articles.
/// Students only see published articles, in their language.
class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  late Future<List<AdminArticle>> _articles = widget.repository.articles();
  String? _category;

  void _reload() =>
      setState(() {
        _articles = widget.repository.articles();
      });

  Future<void> _edit([AdminArticle? article]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => ArticleEditor(
          repository: widget.repository, article: article),
    );
    if (saved == true && mounted) {
      showMessage(context, article == null ? 'Article added.' : 'Article saved.');
      _reload();
    }
  }

  Future<void> _togglePublished(AdminArticle a) async {
    try {
      await widget.repository.setPublished(a.id!, !a.published);
      if (!mounted) return;
      showMessage(
          context,
          a.published
              ? '"${a.titleEn}" is hidden from students.'
              : '"${a.titleEn}" is now in the Learn tab.');
      _reload();
    } on AdminException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _delete(AdminArticle a) async {
    final bool sure = await confirmDelete(
      context,
      title: 'Delete "${a.titleEn}"?',
      message:
          'It is removed for good, with the record of who read it (their XP stays). '
          'To only hide it from students, unpublish it instead.',
    );
    if (!sure) return;
    try {
      await widget.repository.deleteArticle(a.id!);
      if (!mounted) return;
      showMessage(context, 'Article deleted.');
      _reload();
    } on AdminException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return FutureBuilder<List<AdminArticle>>(
      future: _articles,
      builder: (BuildContext context, AsyncSnapshot<List<AdminArticle>> snap) {
        if (snap.hasError) {
          return LoadProblem(message: '${snap.error}', onRetry: _reload);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<AdminArticle> all = snap.data!;
        final List<AdminArticle> shown = <AdminArticle>[
          for (final AdminArticle a in all)
            if (_category == null || a.category == _category) a,
        ];
        final int published = all.where((AdminArticle a) => a.published).length;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Articles', style: theme.textTheme.headlineSmall),
                ),
                FilledButton.icon(
                  key: const Key('new-article'),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('New article'),
                ),
              ],
            ),
            Text(
              '$published of ${all.length} published. Students see published articles '
              'in the Learn tab, in English or Kiswahili.',
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final String c in articleCategories)
                  ChoiceChip(
                    key: Key('filter-$c'),
                    label: Text('${categoryEmoji[c] ?? ''} ${categoryName(c, 'en')}'),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No articles here yet.'),
              ),
            for (final AdminArticle a in shown)
              Card(
                key: Key('article-${a.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(categoryEmoji[a.category] ?? '📄',
                      style: const TextStyle(fontSize: 26)),
                  title: Text(a.titleEn),
                  subtitle: Text(
                      '${a.titleSw}\n${categoryName(a.category, 'en')} · ${a.minutes} min'
                      '${a.updatedAt == null ? '' : ' · edited ${shortDate('en', a.updatedAt!.toLocal())}'}'),
                  isThreeLine: true,
                  onTap: () => _edit(a),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(a.published ? 'Published' : 'Hidden',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: a.published
                                  ? theme.colorScheme.primary
                                  : mq.textMuted)),
                      Switch(
                        key: Key('publish-${a.id}'),
                        value: a.published,
                        onChanged: (_) => _togglePublished(a),
                      ),
                      IconButton(
                        key: Key('delete-article-${a.id}'),
                        tooltip: 'Delete',
                        onPressed: () => _delete(a),
                        icon: Icon(Icons.delete_outline, color: mq.crisis),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Add or edit an article, in English and Kiswahili.
class ArticleEditor extends StatefulWidget {
  const ArticleEditor({super.key, required this.repository, this.article});

  final AdminRepository repository;

  /// Null to add a new article.
  final AdminArticle? article;

  @override
  State<ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<ArticleEditor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final AdminArticle? _a = widget.article;
  late String _category = _a?.category ?? articleCategories.first;
  late final TextEditingController _titleEn =
      TextEditingController(text: _a?.titleEn);
  late final TextEditingController _titleSw =
      TextEditingController(text: _a?.titleSw);
  late final TextEditingController _bodyEn =
      TextEditingController(text: _a?.bodyEn);
  late final TextEditingController _bodySw =
      TextEditingController(text: _a?.bodySw);
  late final TextEditingController _minutes =
      TextEditingController(text: '${_a?.minutes ?? 2}');
  late bool _published = _a?.published ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _titleEn,
      _titleSw,
      _bodyEn,
      _bodySw,
      _minutes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Required' : null;

  static String? _title(String? v) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length > 120) return 'Keep it under 120 characters';
    return null;
  }

  static String? _validMinutes(String? v) {
    final int? n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1 || n > 30) return '1 to 30';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveArticle(AdminArticle(
        id: _a?.id,
        category: _category,
        titleEn: _titleEn.text,
        titleSw: _titleSw.text,
        bodyEn: _bodyEn.text,
        bodySw: _bodySw.text,
        minutes: int.parse(_minutes.text.trim()),
        published: _published,
      ));
      if (mounted) Navigator.pop(context, true);
    } on AdminException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  Widget _language(String name, TextEditingController title,
          TextEditingController body, String key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            key: Key('title-$key'),
            controller: title,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: _title,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: Key('body-$key'),
            controller: body,
            minLines: 10,
            maxLines: 20,
            decoration: const InputDecoration(
              labelText: 'Text',
              helperText: 'Leave an empty line between paragraphs.',
              alignLabelWithHint: true,
            ),
            validator: _required,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(_a == null ? 'New article' : 'Edit article',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      key: const Key('category'),
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Topic'),
                      items: <DropdownMenuItem<String>>[
                        for (final String c in articleCategories)
                          DropdownMenuItem<String>(
                            value: c,
                            child: Text(
                                '${categoryEmoji[c] ?? ''} ${categoryName(c, 'en')}'),
                          ),
                      ],
                      onChanged: (String? v) =>
                          setState(() => _category = v ?? _category),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      key: const Key('minutes'),
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Minutes to read'),
                      validator: _validMinutes,
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: SwitchListTile(
                      key: const Key('published'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Published'),
                      subtitle: const Text('Shown to students'),
                      value: _published,
                      onChanged: (bool v) => setState(() => _published = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                        child: _language('English', _titleEn, _bodyEn, 'en')),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _language('Kiswahili', _titleSw, _bodySw, 'sw')),
                  ],
                )
              else ...<Widget>[
                _language('English', _titleEn, _bodyEn, 'en'),
                const SizedBox(height: 16),
                _language('Kiswahili', _titleSw, _bodySw, 'sw'),
              ],
              const SizedBox(height: 8),
              Text(
                'Articles are general information, not medical advice. '
                'Ask a fluent speaker to check the Kiswahili before publishing.',
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: mq.crisis)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('save-article'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
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
