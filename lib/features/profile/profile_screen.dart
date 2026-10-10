import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/language_toggle.dart';
import '../auth/session_controller.dart';

/// Profile and settings (wireframe 12). Badges, mood history, "save your
/// progress" and "delete my data" are added in step 9.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen(
      {super.key,
      required this.session,
      required this.theme,
      this.onHelplines,
      this.onMoodHistory});

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
                              ? 'Anonymous account'
                              : 'Signed in with email',
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: mq.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              if (onMoodHistory != null) ...<Widget>[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: const Key('open-mood-history'),
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('Mood history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onMoodHistory,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (onHelplines != null)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading:
                        Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
                    title: const Text('Crisis helplines'),
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
