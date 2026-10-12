import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/google_button.dart';
import 'account_repository.dart';
import 'session_controller.dart';

/// Sign in (wireframe 02). The same screen creates an account when
/// [createAccount] is true.
class SignInScreen extends StatefulWidget {
  const SignInScreen(
      {super.key, required this.session, this.createAccount = false});

  final SessionController session;
  final bool createAccount;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static String? validateEmail(String? v) {
    final String value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value))
      return "That email doesn't look right";
    return null;
  }

  String? _validatePassword(String? v) {
    final String value = v ?? '';
    if (value.isEmpty) return 'Enter your password';
    if (widget.createAccount && value.length < 8)
      return 'Use at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (widget.createAccount) {
        final bool signedIn = await widget.session.account
            .signUp(email: _email.text, password: _password.text);
        if (!signedIn && mounted) {
          setState(() => _notice =
              'Almost there! We sent a link to ${_email.text.trim()}. '
                  'Open it to confirm your email, then sign in.');
        }
      } else {
        await widget.session.account
            .signIn(email: _email.text, password: _password.text);
      }
      await widget.session.refresh();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final bool create = widget.createAccount;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: <Widget>[
              Text(create ? 'Create your account' : 'Welcome back',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                create
                    ? 'Your progress is saved to your email, so you can use any phone.'
                    : 'Sign in to pick up where you left off.',
                style: theme.textTheme.bodyLarge?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 24),
              GoogleButton(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await widget.session.account.signInWithGoogle();
                        } on AccountException catch (e) {
                          if (mounted) setState(() => _error = e.message);
                        }
                      },
              ),
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
              TextFormField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('password'),
                controller: _password,
                obscureText: _hidePassword,
                autofillHints: <String>[
                  create ? AutofillHints.newPassword : AutofillHints.password
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: _validatePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: create ? 'At least 8 characters' : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    icon: Icon(_hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_notice != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mq.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_notice!),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(create ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(create ? 'Already have an account?' : 'New here?'),
                  TextButton(
                    onPressed: () => context
                        .pushReplacement(create ? '/sign-in' : '/sign-up'),
                    child: Text(create ? 'Sign in' : 'Create an account'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 18, color: mq.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your email is only used to sign in. It is never shown to anyone.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: mq.textMuted),
                    ),
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
