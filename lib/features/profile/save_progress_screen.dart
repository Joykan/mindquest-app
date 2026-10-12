import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/google_button.dart';
import '../../core/widgets/mascot.dart';
import '../auth/account_repository.dart';
import '../auth/session_controller.dart';

enum _Step { email, confirm, password, done }

/// "Save your progress": turns an anonymous account into one with an email
/// and password, so XP, moods and chats can be recovered on another phone.
/// 1. enter email -> 2. confirm with the link in the email (or a 6-digit code
/// if the email template includes one) ->
/// 3. choose a password.
class SaveProgressScreen extends StatefulWidget {
  const SaveProgressScreen({super.key, required this.session, this.onDone});

  final SessionController session;
  final VoidCallback? onDone;

  @override
  State<SaveProgressScreen> createState() => _SaveProgressScreenState();
}

class _SaveProgressScreenState extends State<SaveProgressScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _password2 = TextEditingController();
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  AccountRepository get _account => widget.session.account;

  /// Saved with Google: the email shown at the end comes from the account.
  bool _viaGoogle = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  /// After "Save with Google" the app comes back from the browser with the
  /// account no longer anonymous.
  void _onSession() {
    if (!mounted || _step != _Step.email || _account.isAnonymous) return;
    setState(() {
      _viaGoogle = true;
      _step = _Step.done;
    });
  }

  Future<void> _saveWithGoogle() => _run(() => _account.linkGoogle());

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = _friendly(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendly(String message) {
    final String m = message.toLowerCase();
    if (m.contains('identity') && m.contains('already')) {
      return 'This Google account is already used by another MindQuest account. '
          'Use another Google account or your email instead.';
    }
    if (m.contains('manual linking')) {
      return 'Saving with Google is switched off on the server. Use your email for now.';
    }
    if (m.contains('already') && m.contains('registered')) {
      return 'This email already has a MindQuest account. Use another email, '
          'or sign out and sign in to that account (progress here would not move across).';
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return "That code didn't work. Check the latest email, or send a new code.";
    }
    if (m.contains('rate') || m.contains('seconds')) {
      return 'Too many emails sent. Please wait a few minutes and try again.';
    }
    return message;
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() => _run(() async {
        await _account.linkEmail(_email.text.trim());
        if (mounted) setState(() => _step = _Step.confirm);
      });

  Future<void> _confirmCode() => _run(() async {
        await _account.confirmEmailCode(email: _email.text.trim(), code: _code.text.trim());
        await widget.session.accountChanged();
        if (mounted) setState(() => _step = _Step.password);
      });

  Future<void> _checkLink() => _run(() async {
        final bool ok = await _account.checkEmailConfirmed();
        if (!mounted) return;
        if (ok) {
          await widget.session.accountChanged();
          if (mounted) setState(() => _step = _Step.password);
        } else {
          setState(() => _error = "Not confirmed yet. Open the email and tap the link, or type the code.");
        }
      });

  Future<void> _savePassword() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (_password.text != _password2.text) {
      setState(() => _error = "The passwords don't match.");
      return;
    }
    await _run(() async {
      await _account.setPassword(_password.text);
      await widget.session.accountChanged();
      if (mounted) setState(() => _step = _Step.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final int stepNumber = switch (_step) {
      _Step.email => 1,
      _Step.confirm => 2,
      _Step.password => 3,
      _Step.done => 3,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Save your progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Center(
            child: Mascot(pose: _step == _Step.done ? MascotPose.happy : MascotPose.wave, size: 96),
          ),
          const SizedBox(height: 8),
          if (_step != _Step.done)
            Text('Step $stepNumber of 3', textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ..._body(theme, mq),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              key: const Key('save-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: mq.crisisSurface, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: theme.textTheme.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme, MindQuestColors mq) {
    Widget button(String key, String label, VoidCallback? onPressed) => FilledButton(
          key: Key(key),
          onPressed: _busy ? null : onPressed,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(label),
        );
    switch (_step) {
      case _Step.email:
        return <Widget>[
          Text('Keep your XP, moods and chats', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Right now your account lives only on this phone. Link Google or an email and you can '
            'sign in on any phone without losing anything. We only use it to sign you in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          GoogleButton(label: 'Save with Google', onPressed: _busy ? null : _saveWithGoogle),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or with email', style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('save-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 16),
          button('send-code', 'Send confirmation email', _emailOk ? _sendCode : null),
        ];
      case _Step.confirm:
        return <Widget>[
          Text('Check your email', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'We sent an email to ${_email.text.trim()}. Open it on this phone and tap the link '
            '("Change Email"). Then come back here and tap the button below. '
            'If the page that opens shows an error, that is fine: the link still works.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          button('tapped-link', "I've tapped the link", _checkLink),
          const SizedBox(height: 20),
          Text('Got a 6-digit code instead?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            key: const Key('save-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('confirm-code'),
            onPressed: _busy || _code.text.trim().length != 6 ? null : _confirmCode,
            child: const Text('Confirm code'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _step = _Step.email),
            child: const Text('Use a different email or send again'),
          ),
        ];
      case _Step.password:
        return <Widget>[
          Text('Choose a password', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your email is confirmed. Pick a password with at least 8 characters.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('save-password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('save-password2'),
            controller: _password2,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repeat password'),
          ),
          const SizedBox(height: 16),
          button('save-password-button', 'Save my progress', _savePassword),
        ];
      case _Step.done:
        return <Widget>[
          Text('Your progress is saved! 🎉',
              key: const Key('save-done'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _viaGoogle
                ? 'On a new phone, choose "Continue with Google" and pick the same Google account.'
                : 'On a new phone, choose "Sign in" and use ${_email.text.trim()} with your password.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ];
    }
  }
}
