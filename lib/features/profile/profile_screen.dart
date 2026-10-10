import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/language_toggle.dart';
import '../auth/session_controller.dart';

/// Profile and settings (wireframe 12). Badges, mood history, "save your
/// progress" and "delete my data" are added in step 9.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.session, required this.theme, this.onHelplines});

  final SessionController session;
  final ThemeController theme;
  final VoidCallback? onHelplines;

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
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
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
                      style: TextStyle(color: t.colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: t.textTheme.headlineSmall),
                        Text(
                          session.account.isAnonymous ? 'Anonymous account' : 'Signed in with email',
                          style: t.textTheme.bodySmall?.copyWith(color: mq.textMuted),
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
                      trailing: LanguageToggle(value: session.language, onChanged: session.changeLanguage),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.contrast),
                              const SizedBox(width: 16),
                              Text('Appearance', style: t.textTheme.bodyLarge),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<ThemeMode>(
                            key: const Key('appearance'),
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<ThemeMode>>[
                              ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('Phone')),
                              ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Light')),
                              ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Dark')),
                            ],
                            selected: <ThemeMode>{theme.value},
                            onSelectionChanged: (Set<ThemeMode> s) => theme.set(s.first),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (onHelplines != null)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(Icons.phone_in_talk_outlined, color: mq.crisis),
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
                style: OutlinedButton.styleFrom(side: BorderSide(color: mq.crisis)),
              ),
            ],
          );
        },
      ),
    );
  }
}
