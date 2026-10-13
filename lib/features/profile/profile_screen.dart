import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/language_toggle.dart';
import '../auth/account_errors.dart';
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
          title: Text(context.tr('Sign out?', 'Utoke?')),
          content: Text(context.tr(
            "You're using MindQuest without an account. If you sign out, your chats, "
                'moods and XP on this phone cannot be recovered.',
            'Unatumia MindQuest bila akaunti. Ukitoka, mazungumzo yako, '
                'hisia ulizorekodi na XP kwenye simu hii haviwezi kurejeshwa.',
          )),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Stay', 'Baki'))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Sign out', 'Toka'))),
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
    final String lang = context.lang;
    try {
      await session.deleteAccount();
      messenger.showSnackBar(SnackBar(
          content: Text(tr(lang, 'Your account and all your data were deleted.',
              'Akaunti yako na data yako yote imefutwa.'))));
    } on AccountException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr(lang, "Couldn't delete: ", 'Imeshindikana kufuta: ') +
              accountError(e.message, lang))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final MindQuestColors mq = t.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profile', 'Wasifu'))),
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
                              ? context.tr('Anonymous account (only on this phone)',
                                  'Akaunti bila jina (kwenye simu hii tu)')
                              : session.account.email ??
                                  context.tr('Signed in with email',
                                      'Umeingia kwa barua pepe'),
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
                                  '${title.emoji} ${title.name(context.lang)} · ${context.tr('Level', 'Kiwango')} $level · ${snap.data!.xp} XP',
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
                    title: Text(context.tr('Save your progress', 'Hifadhi maendeleo yako'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        context.tr(
                            "Add Google or an email so you don't lose your XP, moods and chats if you change phones.",
                            'Ongeza Google au barua pepe ili usipoteze XP, hisia na mazungumzo yako ukibadilisha simu.')),
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
                          title: Text(context.tr('My badges', 'Beji zangu')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onRewards,
                        ),
                        ListTile(
                          key: const Key('open-quests'),
                          leading:
                              const Text('🎯', style: TextStyle(fontSize: 22)),
                          title: Text(context.tr('My quests', 'Changamoto zangu')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onRewards,
                        ),
                      ],
                      if (onMoodHistory != null)
                        ListTile(
                          key: const Key('open-mood-history'),
                          leading:
                              const Text('📊', style: TextStyle(fontSize: 22)),
                          title: Text(context.tr('Mood history and insights',
                              'Historia ya hisia na maarifa')),
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
                      title: Text(context.tr('Language', 'Lugha')),
                      subtitle: Text(context.tr('For the app and Chipu',
                          'Kwa programu na Chipu')),
                      trailing: LanguageToggle(
                          value: session.language,
                          onChanged: session.changeLanguage),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Text(context.tr('Appearance', 'Mwonekano'),
                          style: t.textTheme.titleMedium),
                    ),
                    _ThemeOption(
                      key: const Key('theme-system'),
                      icon: Icons.brightness_auto_outlined,
                      label: context.tr('System default', 'Kama simu yako'),
                      subtitle: context.tr("Follows your phone's setting",
                          'Inafuata mpangilio wa simu yako'),
                      selected: theme.value == ThemeMode.system,
                      onTap: () => theme.set(ThemeMode.system),
                    ),
                    _ThemeOption(
                      key: const Key('theme-light'),
                      icon: Icons.light_mode_outlined,
                      label: context.tr('Light mode', 'Mwanga'),
                      selected: theme.value == ThemeMode.light,
                      onTap: () => theme.set(ThemeMode.light),
                    ),
                    _ThemeOption(
                      key: const Key('theme-dark'),
                      icon: Icons.dark_mode_outlined,
                      label: context.tr('Dark mode', 'Giza'),
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
                    title: Text(context.tr('Support and helplines',
                        'Msaada na nambari za msaada')),
                    subtitle: Text(context.tr('Call for help, breathing, grounding',
                        'Piga simu kupata msaada, kupumua, kutuliza akili')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onHelplines,
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('sign-out'),
                onPressed: () => _signOut(context),
                icon: Icon(Icons.logout, color: mq.crisis),
                label: Text(context.tr('Sign out', 'Toka'),
                    style: TextStyle(color: mq.crisis)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: mq.crisis)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('delete-data'),
                onPressed: () => _deleteData(context),
                icon: Icon(Icons.delete_forever_outlined, color: mq.crisis),
                label: Text(context.tr('Delete my data', 'Futa data yangu'),
                    style: TextStyle(color: mq.crisis)),
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
    // DELETE or its Kiswahili, FUTA.
    final String typed = _typed.text.trim().toUpperCase();
    final bool ok = typed == 'DELETE' || typed == 'FUTA';
    return AlertDialog(
      title: Text(context.tr('Delete all your data?', 'Futa data yako yote?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.tr(
            'This permanently deletes your account, chats, mood check-ins, notes, XP, badges and quests. '
                'It cannot be undone.',
            'Hii inafuta kabisa akaunti yako, mazungumzo, hisia ulizorekodi, maelezo, XP, beji na changamoto. '
                'Haiwezi kurudishwa.',
          )),
          const SizedBox(height: 12),
          Text(context.tr('Type DELETE to confirm.', 'Andika FUTA kuthibitisha.')),
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
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel', 'Ghairi'))),
        TextButton(
          key: const Key('delete-confirm'),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: Text(context.tr('Delete', 'Futa'),
              style: TextStyle(color: ok ? mq.crisis : null)),
        ),
      ],
    );
  }
}
