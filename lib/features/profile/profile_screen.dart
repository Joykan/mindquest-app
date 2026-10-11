import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/language_toggle.dart';
import '../auth/account_repository.dart';
import '../auth/session_controller.dart';
import '../gamification/levels.dart';
import '../home/progress_repository.dart';

/// Profile and settings (wireframe 12): level, shortcuts to badges, quests
/// and mood history, language, appearance, support and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen(
      {super.key,
      required this.session,
      required this.theme,
      this.onHelplines,
      this.onMoodHistory,
      this.onRewards,
      this.onSaveProgress,
      this.progress});

  /// Opens "Save your progress" (shown for anonymous accounts).
  final VoidCallback? onSaveProgress;

  /// Opens Rewards (badges and quests).
  final VoidCallback? onRewards;

  /// Used to show the level name under the user's name.
  final ProgressRepository? progress;

  final SessionController session;
  final ThemeController theme;
  final VoidCallback? onHelplines;
  final VoidCallback? onMoodHistory;

  Future<void> _signOut(BuildContext context) async {
    if (session.account.isAnonymous) {
      final bool? sure = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            "You're using MindQuest without an account. If you sign out, your chats, "
            'moods and XP on this phone cannot be recovered.',
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out')),
          ],
        ),
      );
      if (sure != true) return;
    }
    await session.signOut();
  }

  Future<void> _deleteData(BuildContext context) async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const _DeleteDialog(),
    );
    if (sure != true || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await session.deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Your account and all your data were deleted.')));
    } on AccountException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't delete: ${e.message}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final MindQuestColors mq = t.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[session, theme]),
        builder: (BuildContext context, _) {
          final String name = session.profile?.username ?? 'Friend';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: t.colorScheme.primary,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                          color: t.colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: t.textTheme.headlineSmall),
                        Text(
                          session.account.isAnonymous
                              ? 'Anonymous account (only on this phone)'
                              : session.account.email ?? 'Signed in with email',
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: mq.textMuted),
                        ),
                        if (progress != null)
                          FutureBuilder<HomeSummary>(
                            future: progress!.loadHome(),
                            builder: (BuildContext context,
                                AsyncSnapshot<HomeSummary> snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final int level = levelForXp(snap.data!.xp);
                              final LevelTitle title = levelTitle(level);
                              return Container(
                                key: const Key('profile-level'),
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mq.reward,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${title.emoji} ${title.name(session.language)} · Level $level · ${snap.data!.xp} XP',
                                  style: t.textTheme.labelSmall
                                      ?.copyWith(color: mq.onReward),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (session.account.isAnonymous && onSaveProgress != null) ...<Widget>[
                Card(
                  clipBehavior: Clip.antiAlias,
                  color: mq.surfaceSoft,
                  child: ListTile(
                    key: const Key('open-save-progress'),
                    leading: const Text('💾', style: TextStyle(fontSize: 24)),
                    title: const Text('Save your progress',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        "Add an email so you don't lose your XP, moods and chats if you change phones."),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onSaveProgress,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (onRewards != null || onMoodHistory != null) ...<Widget>[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      if (onRewards != null) ...<Widget>[
                        ListTile(
                          key: const Key('open-badges'),
                          leading:
                              const Text('🏅', style: TextStyle(fontSize: 22)),
                          title: const Text('My badges'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onRewards,
                        ),
                        ListTile(
                          key: const Key('open-quests'),
                          leading:
                              const Text('🎯', style: TextStyle(fontSize: 22)),
                          title: const Text('My quests'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onRewards,
                        ),
                      ],
                      if (onMoodHistory != null)
                        ListTile(
                          key: const Key('open-mood-history'),
                          leading:
                              const Text('📊', style: TextStyle(fontSize: 22)),
                          title: const Text('Mood history and insights'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onMoodHistory,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.translate),
                      title: const Text('Chatbot language'),
                      trailing: LanguageToggle(
                          value: session.language,
                          onChanged: session.changeLanguage),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Text('Appearance', style: t.textTheme.titleMedium),
                    ),
                    _ThemeOption(
                      key: const Key('theme-system'),
                      icon: Icons.brightness_auto_outlined,
                      label: 'System default',
                      subtitle: "Follows your phone's setting",
                      selected: theme.value == ThemeMode.system,
                      onTap: () => theme.set(ThemeMode.system),
                    ),
                    _ThemeOption(
                      key: const Key('theme-light'),
                      icon: Icons.light_mode_outlined,
                      label: 'Light mode',
                      selected: theme.value == ThemeMode.light,
                      onTap: () => theme.set(ThemeMode.light),
                    ),
                    _ThemeOption(
                      key: const Key('theme-dark'),
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark mode',
                      selected: theme.value == ThemeMode.dark,
                      onTap: () => theme.set(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (onHelplines != null)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading:
                        Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
                    title: const Text('Support and helplines'),
                    subtitle: const Text('Call for help, breathing, grounding'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onHelplines,
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('sign-out'),
                onPressed: () => _signOut(context),
                icon: Icon(Icons.logout, color: mq.crisis),
                label: Text('Sign out', style: TextStyle(color: mq.crisis)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: mq.crisis)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('delete-data'),
                onPressed: () => _deleteData(context),
                icon: Icon(Icons.delete_forever_outlined, color: mq.crisis),
                label: Text('Delete my data', style: TextStyle(color: mq.crisis)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing:
            selected ? Icon(Icons.check_circle, color: scheme.primary) : null,
        onTap: onTap,
      ),
    );
  }
}

/// Asks the user to type DELETE, so data is never removed by accident.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    final bool ok = _typed.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      title: const Text('Delete all your data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This permanently deletes your account, chats, mood check-ins, notes, XP, badges and quests. '
            'It cannot be undone.',
          ),
          const SizedBox(height: 12),
          const Text('Type DELETE to confirm.'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('delete-confirm-field'),
            controller: _typed,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          key: const Key('delete-confirm'),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: Text('Delete', style: TextStyle(color: ok ? mq.crisis : null)),
        ),
      ],
    );
  }
}
