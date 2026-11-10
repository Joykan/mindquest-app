import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/google_button.dart';
import 'account_errors.dart';
import 'account_repository.dart';
import 'session_controller.dart';

/// Sign in (wireframe 02). The same screen creates an account when
/// [createAccount] is true.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.session,
    this.createAccount = false,
  });

  final SessionController session;
  final bool createAccount;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _usePhone = false;
  bool _codeSent = false;
  String? _phoneE164;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final String value = (v ?? '').trim();
    if (value.isEmpty) {
      return context.tr('Enter your email', 'Andika barua pepe yako');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return context.tr(
        "That email doesn't look right",
        'Barua pepe hiyo haionekani sahihi',
      );
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final String value = v ?? '';
    if (value.isEmpty) {
      return context.tr('Enter your password', 'Andika nenosiri lako');
    }
    if (widget.createAccount && value.length < 8) {
      return context.tr('Use at least 8 characters', 'Tumia angalau herufi 8');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final String lang = context.lang;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (widget.createAccount) {
        final bool signedIn = await widget.session.account.signUp(
          email: _email.text,
          password: _password.text,
        );
        if (!signedIn && mounted) {
          setState(
            () => _notice = tr(
              lang,
              'Almost there! We sent a link to ${_email.text.trim()}. '
                  'Open it to confirm your email, then sign in.',
              'Karibu umalize! Tumetuma kiungo kwa ${_email.text.trim()}. '
                  'Kifungue ili kuthibitisha barua pepe yako, kisha uingie.',
            ),
          );
        }
      } else {
        await widget.session.account.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
      await widget.session.refresh();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = accountError(e.message, lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final String lang = context.lang;
    final String? number = normalizePhone(_phone.text);
    if (number == null) {
      setState(
        () => _error = tr(
          lang,
          'Enter a phone number like 0712 345 678.',
          'Andika nambari ya simu kama 0712 345 678.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.session.account.sendPhoneCode(number);
      if (mounted) {
        setState(() {
          _phoneE164 = number;
          _codeSent = true;
          _notice = tr(
            lang,
            'We sent a 6-digit code to $number.',
            'Tumetuma nambari ya tarakimu 6 kwa $number.',
          );
        });
      }
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = accountError(e.message, lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final String lang = context.lang;
    if (_code.text.trim().length < 6) {
      setState(
        () => _error = tr(
          lang,
          'Enter the 6-digit code.',
          'Andika nambari ya tarakimu 6.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.account.verifyPhoneCode(
        phone: _phoneE164!,
        code: _code.text,
      );
      await widget.session.refresh();
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = accountError(e.message, lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _phoneFields(ThemeData theme) => <Widget>[
    TextField(
      key: const Key('phone'),
      controller: _phone,
      enabled: !_codeSent,
      keyboardType: TextInputType.phone,
      autofillHints: const <String>[AutofillHints.telephoneNumber],
      decoration: InputDecoration(
        labelText: context.tr('Phone number', 'Nambari ya simu'),
        hintText: '0712 345 678',
        prefixIcon: const Icon(Icons.phone_outlined),
      ),
    ),
    if (_codeSent) ...<Widget>[
      const SizedBox(height: 12),
      TextField(
        key: const Key('code'),
        controller: _code,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofillHints: const <String>[AutofillHints.oneTimeCode],
        onSubmitted: (_) => _verifyCode(),
        decoration: InputDecoration(
          labelText: context.tr('6-digit code', 'Nambari ya tarakimu 6'),
          prefixIcon: const Icon(Icons.pin_outlined),
        ),
      ),
    ],
    if (_error != null) ...<Widget>[
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
    ],
    const SizedBox(height: 20),
    FilledButton(
      key: const Key('phone-submit'),
      onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(
              _codeSent
                  ? context.tr('Verify and continue', 'Thibitisha uendelee')
                  : context.tr('Send code', 'Tuma nambari'),
            ),
    ),
    if (_codeSent)
      TextButton(
        key: const Key('phone-change'),
        onPressed: _busy
            ? null
            : () => setState(() {
                _codeSent = false;
                _code.clear();
                _notice = null;
                _error = null;
              }),
        child: Text(
          context.tr('Use a different number', 'Tumia nambari nyingine'),
        ),
      ),
  ];

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
              Text(
                create
                    ? context.tr('Create your account', 'Fungua akaunti yako')
                    : context.tr('Welcome back', 'Karibu tena'),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                create
                    ? context.tr(
                        'Your progress is saved to your email, so you can use any phone.',
                        'Maendeleo yako yanahifadhiwa kwenye barua pepe yako, hivyo unaweza kutumia simu yoyote.',
                      )
                    : context.tr(
                        'Sign in to pick up where you left off.',
                        'Ingia ili uendelee ulipoachia.',
                      ),
                style: theme.textTheme.bodyLarge?.copyWith(color: mq.textMuted),
              ),
              const SizedBox(height: 24),
              GoogleButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final String lang = context.lang;
                        try {
                          await widget.session.account.signInWithGoogle();
                        } on AccountException catch (e) {
                          if (mounted) {
                            setState(
                              () => _error = accountError(e.message, lang),
                            );
                          }
                        }
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      context.tr('or with', 'au kwa'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mq.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                key: const Key('method'),
                showSelectedIcon: false,
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(context.tr('Email', 'Barua pepe')),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(context.tr('Phone', 'Simu')),
                  ),
                ],
                selected: <bool>{_usePhone},
                onSelectionChanged: (Set<bool> v) => setState(() {
                  _usePhone = v.first;
                  _error = null;
                  _notice = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_usePhone)
                ..._phoneFields(theme)
              else ...<Widget>[
                TextFormField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: InputDecoration(
                    labelText: context.tr('Email', 'Barua pepe'),
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: _hidePassword,
                  autofillHints: <String>[
                    create ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: context.tr('Password', 'Nenosiri'),
                    helperText: create
                        ? context.tr(
                            'At least 8 characters',
                            'Angalau herufi 8',
                          )
                        : null,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? context.tr('Show password', 'Onyesha nenosiri')
                          : context.tr('Hide password', 'Ficha nenosiri'),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
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
              if (!_usePhone) const SizedBox(height: 20),
              if (!_usePhone)
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(
                          create
                              ? context.tr('Create account', 'Fungua akaunti')
                              : context.tr('Sign in', 'Ingia'),
                        ),
                ),
              const SizedBox(height: 16),
              // Wrap so it breaks onto two lines on narrow screens.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    create
                        ? context.tr(
                            'Already have an account?',
                            'Tayari una akaunti?',
                          )
                        : context.tr('New here?', 'Mgeni hapa?'),
                  ),
                  TextButton(
                    onPressed: () => context.pushReplacement(
                      create ? '/sign-in' : '/sign-up',
                    ),
                    child: Text(
                      create
                          ? context.tr('Sign in', 'Ingia')
                          : context.tr('Create an account', 'Fungua akaunti'),
                    ),
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
                      context.tr(
                        'Your email or phone number is only used to sign in. It is never shown to anyone.',
                        'Barua pepe au nambari yako ya simu inatumika tu kukuingiza. Haionyeshwi kwa mtu yeyote.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mq.textMuted,
                      ),
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
