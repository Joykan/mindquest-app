import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

/// Crisis helplines. Only verified ones are shown to students (in the crisis
/// sheet and on Support); without any, the app shows 999 and 112.
class HelplinesPage extends StatefulWidget {
  const HelplinesPage({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<HelplinesPage> createState() => _HelplinesPageState();
}

class _HelplinesPageState extends State<HelplinesPage> {
  late Future<List<AdminHelpline>> _lines = widget.repository.helplines();

  void _reload() => setState(() {
        _lines = widget.repository.helplines();
      });

  Future<void> _edit([AdminHelpline? line]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          HelplineEditor(repository: widget.repository, helpline: line),
    );
    if (saved == true && mounted) {
      showMessage(context, line == null ? 'Helpline added.' : 'Helpline saved.');
      _reload();
    }
  }

  Future<void> _toggleVerified(AdminHelpline h) async {
    try {
      await widget.repository.setVerified(h.id!, !h.verified);
      if (!mounted) return;
      showMessage(
          context,
          h.verified
              ? '${h.name} is hidden from students.'
              : '${h.name} is now shown to students.');
      _reload();
    } on AdminException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _delete(AdminHelpline h) async {
    final bool sure = await confirmDelete(context,
        title: 'Delete ${h.name}?',
        message: 'Students will no longer see this number.');
    if (!sure) return;
    try {
      await widget.repository.deleteHelpline(h.id!);
      if (!mounted) return;
      showMessage(context, 'Helpline deleted.');
      _reload();
    } on AdminException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return FutureBuilder<List<AdminHelpline>>(
      future: _lines,
      builder:
          (BuildContext context, AsyncSnapshot<List<AdminHelpline>> snap) {
        if (snap.hasError) {
          return LoadProblem(message: '${snap.error}', onRetry: _reload);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<AdminHelpline> lines = snap.data!;
        final int verified = lines.where((AdminHelpline h) => h.verified).length;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      Text('Helplines', style: theme.textTheme.headlineSmall),
                ),
                FilledButton.icon(
                  key: const Key('new-helpline'),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('New helpline'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mq.crisisSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$verified of ${lines.length} verified. Students only see verified helplines. '
                'Call each number yourself before marking it verified. '
                'With none verified, the app shows 999 and 112.',
              ),
            ),
            const SizedBox(height: 12),
            for (final AdminHelpline h in lines)
              Card(
                key: Key('helpline-${h.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
                  title: Text('${h.name} · ${h.phone}'),
                  subtitle: Text(<String>[
                    if ((h.description ?? '').isNotEmpty) h.description!,
                    if ((h.descriptionSw ?? '').isNotEmpty) h.descriptionSw!,
                    'Order ${h.sortOrder}',
                  ].join('\n')),
                  isThreeLine: true,
                  onTap: () => _edit(h),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(h.verified ? 'Verified' : 'Not verified',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: h.verified
                                  ? theme.colorScheme.primary
                                  : mq.textMuted)),
                      Switch(
                        key: Key('verify-${h.id}'),
                        value: h.verified,
                        onChanged: (_) => _toggleVerified(h),
                      ),
                      IconButton(
                        key: Key('delete-helpline-${h.id}'),
                        tooltip: 'Delete',
                        onPressed: () => _delete(h),
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

/// Digits, spaces and an optional + at the start (e.g. 1199, +254 722 178 177).
String? validHelplinePhone(String? v) {
  final String p = (v ?? '').trim();
  if (p.isEmpty) return 'Required';
  if (!RegExp(r'^\+?[0-9][0-9 ]{1,18}$').hasMatch(p)) {
    return 'Digits and spaces only, e.g. 1199 or +254 722 178 177';
  }
  return null;
}

/// Add or edit a helpline.
class HelplineEditor extends StatefulWidget {
  const HelplineEditor({super.key, required this.repository, this.helpline});

  final AdminRepository repository;
  final AdminHelpline? helpline;

  @override
  State<HelplineEditor> createState() => _HelplineEditorState();
}

class _HelplineEditorState extends State<HelplineEditor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final AdminHelpline? _h = widget.helpline;
  late final TextEditingController _name =
      TextEditingController(text: _h?.name);
  late final TextEditingController _phone =
      TextEditingController(text: _h?.phone);
  late final TextEditingController _description =
      TextEditingController(text: _h?.description);
  late final TextEditingController _descriptionSw =
      TextEditingController(text: _h?.descriptionSw);
  late final TextEditingController _order =
      TextEditingController(text: '${_h?.sortOrder ?? 0}');
  late bool _verified = _h?.verified ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _phone,
      _description,
      _descriptionSw,
      _order
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveHelpline(AdminHelpline(
        id: _h?.id,
        name: _name.text,
        phone: _phone.text,
        description: _description.text,
        descriptionSw: _descriptionSw.text,
        verified: _verified,
        sortOrder: int.tryParse(_order.text.trim()) ?? 0,
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return AlertDialog(
      title: Text(_h == null ? 'New helpline' : 'Edit helpline'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  key: const Key('helpline-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (String? v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('helpline-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: validHelplinePhone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('helpline-description'),
                  controller: _description,
                  decoration: const InputDecoration(
                      labelText: 'Description (English)',
                      hintText: 'e.g. Toll-free, 24 hours'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('helpline-description-sw'),
                  controller: _descriptionSw,
                  decoration: const InputDecoration(
                      labelText: 'Description (Kiswahili)',
                      hintText: 'mf. Bila malipo, saa 24'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('helpline-order'),
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Order', helperText: 'Lower numbers show first'),
                  validator: (String? v) => int.tryParse((v ?? '').trim()) == null
                      ? 'A whole number'
                      : null,
                ),
                SwitchListTile(
                  key: const Key('helpline-verified'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified'),
                  subtitle: const Text('I called it and it works'),
                  value: _verified,
                  onChanged: (bool v) => setState(() => _verified = v),
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: mq.crisis)),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-helpline'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
