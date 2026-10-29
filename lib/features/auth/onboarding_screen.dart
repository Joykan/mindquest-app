import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_toggle.dart';
import 'account_errors.dart';
import 'age_ranges.dart';
import 'account_repository.dart';
import 'session_controller.dart';

/// Onboarding (wireframe 03): nickname, language and the privacy note.
/// Consent is recorded with the time (Kenya Data Protection Act 2019).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  late String _language = widget.session.language;
  String? _age;
  bool _agreed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final String current = widget.session.profile?.username ?? '';
    if (current.isNotEmpty && current != 'Friend') _name.text = current;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _nameOk =>
      _name.text.trim().isNotEmpty && _name.text.trim().length <= 30;

  Future<void> _finish() async {
    final String lang = context.lang;
    setState(() => _busy = true);
    try {
      await widget.session.completeOnboarding(
          username: _name.text.trim(), language: _language, ageRange: _age);
    } on AccountException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(accountError(e.message, lang))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(context.tr('Make it yours', 'Ifanye iwe yako'),
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                context.tr("A few quick choices, then you're in.",
                    'Machaguo machache ya haraka, kisha umeingia.'),
                style: theme.textTheme.bodyLarge?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 28),
              Text(context.tr('What should we call you?', 'Tukuite nani?'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                key: const Key('nickname'),
                controller: _name,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: context.tr(
                      'A nickname is fine', 'Jina la utani linatosha'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                      child: Text(context.tr('Language', 'Lugha'),
                          style: theme.textTheme.titleMedium)),
                  LanguageToggle(
                      value: _language,
                      onChanged: (String v) {
                        setState(() => _language = v);
                        // Switches the whole app straight away.
                        widget.session.setLanguage(v);
                      }),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                    'The app and Chipu use this language. You can change it later.',
                    'Programu na Chipu zitatumia lugha hii. Unaweza kuibadilisha baadaye.'),
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 20),
              Text(context.tr('How old are you?', 'Una umri gani?'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final AgeRange a in ageRanges)
                    ChoiceChip(
                      key: Key('age-${a.id}'),
                      label: Text(a.label(context.lang)),
                      selected: _age == a.id,
                      onSelected: (_) => setState(() => _age = a.id),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                    'Only the range is saved, never your date of birth. MindQuest is made for ages 15–24.',
                    'Ni kundi la umri tu linalohifadhiwa, kamwe si tarehe yako ya kuzaliwa. MindQuest imetengenezwa kwa umri wa miaka 15–24.'),
                style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.shield_outlined,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(context.tr('Your privacy', 'Faragha yako'),
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Bullet(context.tr(
                          'Your chats and mood entries are private to you.',
                          'Mazungumzo yako na hisia ulizorekodi ni siri yako.')),
                      _Bullet(context.tr(
                        'If a message suggests you may be in danger, MindQuest shows crisis helplines. '
                            'It only records that this happened, never what you wrote.',
                        'Ujumbe ukionyesha kuwa huenda uko hatarini, MindQuest itakuonyesha nambari za msaada wa dharura. '
                            'Inarekodi tu kwamba hili lilitokea, kamwe si ulichoandika.',
                      )),
                      _Bullet(context.tr(
                          'MindQuest is not a therapist and cannot diagnose.',
                          'MindQuest si mtaalamu wa tiba na haiwezi kutambua ugonjwa.')),
                      _Bullet(context.tr(
                          'You can delete your data at any time from your profile.',
                          'Unaweza kufuta data yako wakati wowote kwenye wasifu wako.')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('consent'),
                value: _agreed,
                onChanged: (bool? v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr(
                    'I understand and agree', 'Ninaelewa na ninakubali')),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('finish-onboarding'),
                onPressed: _nameOk && _age != null && _agreed && !_busy
                    ? _finish
                    : null,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(context.tr("Let's go", 'Tuanze')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check, size: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
