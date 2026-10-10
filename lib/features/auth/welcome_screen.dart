import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/logo_mark.dart';
import 'account_repository.dart';
import 'session_controller.dart';

/// Welcome (wireframe 01). Anonymous is the main way in: one tap, no email.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _continueAnonymously() async {
    setState(() => _busy = true);
    try {
      await widget.session.account.signInAnonymously();
      await widget.session.refresh();
    } on AccountException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      backgroundColor: mq.brand,
      body: SafeArea(
        child: LayoutBuilder(
          // Scrolls on very small phones; fills the screen otherwise.
          builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: ListenableBuilder(
                  listenable: widget.session,
                  builder: (BuildContext context, _) => LanguageToggle(
                    value: widget.session.language,
                    onChanged: widget.session.setLanguage,
                    onDark: true,
                  ),
                ),
              ),
              const Spacer(),
              const Center(child: LogoMark()),
              const SizedBox(height: 20),
              Text(
                'MindQuest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your safe space to check in, learn and grow, in English or Kiswahili.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 28),
              const _Point(icon: Icons.chat_bubble_outline, text: 'Talk it through, any time'),
              const _Point(icon: Icons.emoji_events_outlined, text: 'Earn XP and badges for self-care'),
              const _Point(icon: Icons.lock_outline, text: 'No name or email needed'),
              const Spacer(),
              FilledButton(
                key: const Key('continue-anonymously'),
                onPressed: _busy ? null : _continueAnonymously,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.mint,
                  foregroundColor: AppPalette.forest,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppPalette.forest),
                      )
                    : const Text('Continue anonymously'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('go-sign-in'),
                onPressed: _busy ? null : () => context.push('/sign-in'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                ),
                child: const Text('Sign in or create account'),
              ),
              const SizedBox(height: 16),
              Text(
                'MindQuest offers support and information. It does not diagnose or replace professional care.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: AppPalette.mint, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
