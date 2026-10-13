import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

const Map<String, String> roleNames = <String, String>{
  'admin': 'Administrator',
  'counsellor': 'Counsellor',
  'user': 'Student',
};

/// Who can open the dashboard. Admins add people by the email of their
/// MindQuest account. Counsellors only see the Overview.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.repository, this.myEmail});

  final AdminRepository repository;

  /// The signed-in admin, who can't remove their own access.
  final String? myEmail;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late Future<List<StaffMember>> _staff = widget.repository.staff();
  final TextEditingController _email = TextEditingController();
  String _role = 'counsellor';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _staff = widget.repository.staff();
      });

  Future<void> _setRole(String email, String role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String name = await widget.repository.setRole(email, role);
      if (!mounted) return;
      showMessage(
          context,
          role == 'user'
              ? '$name no longer has access.'
              : '$name is now a ${roleNames[role]!.toLowerCase()}.');
      _email.clear();
      _reload();
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final String email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter the email of their MindQuest account.');
      return;
    }
    await _setRole(email, _role);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text('Team', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Administrators see the statistics and manage articles, helplines and the team. '
          'Counsellors see the statistics only. Nobody can read students\' chats or notes.',
          style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Give someone access',
          subtitle:
              'They first create an account in the MindQuest app with this email (or Google).',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 300,
                child: TextField(
                  key: const Key('team-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  key: const Key('team-role'),
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                        value: 'counsellor', child: Text('Counsellor')),
                    DropdownMenuItem<String>(
                        value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (String? v) =>
                      setState(() => _role = v ?? _role),
                ),
              ),
              FilledButton(
                key: const Key('team-add'),
                onPressed: _busy ? null : _add,
                child: const Text('Give access'),
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_error!,
              key: const Key('team-error'),
              style: TextStyle(color: mq.crisis)),
        ],
        const SizedBox(height: 16),
        FutureBuilder<List<StaffMember>>(
          future: _staff,
          builder:
              (BuildContext context, AsyncSnapshot<List<StaffMember>> snap) {
            if (snap.hasError) {
              return LoadProblem(message: '${snap.error}', onRetry: _reload);
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final StaffMember m in snap.data!)
                    ListTile(
                      key: Key('staff-${m.email}'),
                      leading: CircleAvatar(
                        child: Text(m.username.isEmpty
                            ? '?'
                            : m.username[0].toUpperCase()),
                      ),
                      title: Text(m.username),
                      subtitle: Text('${m.email} · ${roleNames[m.role] ?? m.role}'),
                      trailing: m.email.toLowerCase() ==
                              (widget.myEmail ?? '').toLowerCase()
                          ? const Text('You')
                          : PopupMenuButton<String>(
                              key: Key('staff-menu-${m.email}'),
                              tooltip: 'Change access',
                              enabled: !_busy,
                              onSelected: (String role) =>
                                  _setRole(m.email, role),
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                if (m.role != 'admin')
                                  const PopupMenuItem<String>(
                                      value: 'admin',
                                      child: Text('Make administrator')),
                                if (m.role != 'counsellor')
                                  const PopupMenuItem<String>(
                                      value: 'counsellor',
                                      child: Text('Make counsellor')),
                                const PopupMenuItem<String>(
                                    value: 'user',
                                    child: Text('Remove access')),
                              ],
                            ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
