import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/google_button.dart';
import '../../core/widgets/mascot.dart';
import '../auth/account_errors.dart';
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

  /// The app's language, refreshed on every build (used in async code).
  String _lang = 'en';

  String _t(String en, String sw) => tr(_lang, en, sw);

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
      if (mounted) setState(() => _error = _friendly(e.message, _lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendly(String message, String lang) {
    final String m = message.toLowerCase();
    if (m.contains('identity') && m.contains('already')) {
      return tr(
          lang,
          'This Google account is already used by another MindQuest account. '
              'Use another Google account or your email instead.',
          'Akaunti hii ya Google tayari inatumiwa na akaunti nyingine ya MindQuest. '
              'Tumia akaunti nyingine ya Google au barua pepe yako.');
    }
    if (m.contains('manual linking')) {
      return tr(
          lang,
          'Saving with Google is switched off on the server. Use your email for now.',
          'Kuhifadhi kwa Google kumezimwa kwenye seva. Tumia barua pepe yako kwa sasa.');
    }
    if (m.contains('already') && m.contains('registered')) {
      return tr(
          lang,
          'This email already has a MindQuest account. Use another email, '
              'or sign out and sign in to that account (progress here would not move across).',
          'Barua pepe hii tayari ina akaunti ya MindQuest. Tumia barua pepe nyingine, '
              'au toka kisha uingie kwenye akaunti hiyo (maendeleo ya hapa hayatahamia huko).');
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return tr(
          lang,
          "That code didn't work. Check the latest email, or send a new code.",
          'Nambari hiyo haikufanya kazi. Angalia barua pepe ya mwisho, au tuma nambari mpya.');
    }
    if (m.contains('rate') || m.contains('seconds')) {
      return tr(
          lang,
          'Too many emails sent. Please wait a few minutes and try again.',
          'Barua pepe nyingi mno zimetumwa. Tafadhali subiri dakika chache kisha ujaribu tena.');
    }
    return accountError(message, lang);
  }

  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() => _run(() async {
        await _account.linkEmail(_email.text.trim());
        if (mounted) setState(() => _step = _Step.confirm);
      });

  Future<void> _confirmCode() => _run(() async {
        await _account.confirmEmailCode(
            email: _email.text.trim(), code: _code.text.trim());
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
          setState(() => _error = _t(
              'Not confirmed yet. Open the email and tap the link, or type the code.',
              'Bado haijathibitishwa. Fungua barua pepe na ugusa kiungo, au andika nambari.'));
        }
      });

  Future<void> _savePassword() async {
    if (_password.text.length < 8) {
      setState(() =>
          _error = _t('Use at least 8 characters.', 'Tumia angalau herufi 8.'));
      return;
    }
    if (_password.text != _password2.text) {
      setState(() =>
          _error = _t("The passwords don't match.", 'Manenosiri hayalingani.'));
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
    _lang = context.lang;
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final int stepNumber = switch (_step) {
      _Step.email => 1,
      _Step.confirm => 2,
      _Step.password => 3,
      _Step.done => 3,
    };
    return Scaffold(
      appBar: AppBar(
          title: Text(_t('Save your progress', 'Hifadhi maendeleo yako'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Center(
            child: Mascot(
                pose: _step == _Step.done ? MascotPose.happy : MascotPose.wave,
                size: 96),
          ),
          const SizedBox(height: 8),
          if (_step != _Step.done)
            Text(_t('Step $stepNumber of 3', 'Hatua $stepNumber kati ya 3'),
                textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ..._body(theme, mq),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              key: const Key('save-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: mq.crisisSurface,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: theme.textTheme.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme, MindQuestColors mq) {
    Widget button(String key, String label, VoidCallback? onPressed) =>
        FilledButton(
          key: Key(key),
          onPressed: _busy ? null : onPressed,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(label),
        );
    switch (_step) {
      case _Step.email:
        return <Widget>[
          Text(
              _t('Keep your XP, moods and chats',
                  'Linda XP, hisia na mazungumzo yako'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _t(
                'Right now your account lives only on this phone. Link Google or an email and you can '
                    'sign in on any phone without losing anything. We only use it to sign you in.',
                'Kwa sasa akaunti yako iko kwenye simu hii tu. Unganisha Google au barua pepe na utaweza '
                    'kuingia kwenye simu yoyote bila kupoteza chochote. Tunaitumia tu kukuingiza.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          GoogleButton(
              label: _t('Save with Google', 'Hifadhi kwa Google'),
              onPressed: _busy ? null : _saveWithGoogle),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_t('or with email', 'au kwa barua pepe'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: mq.textMuted)),
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
            decoration: InputDecoration(labelText: _t('Email', 'Barua pepe')),
          ),
          const SizedBox(height: 16),
          button(
              'send-code',
              _t('Send confirmation email', 'Tuma barua pepe ya uthibitisho'),
              _emailOk ? _sendCode : null),
        ];
      case _Step.confirm:
        return <Widget>[
          Text(_t('Check your email', 'Angalia barua pepe yako'),
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _t(
                'We sent an email to ${_email.text.trim()}. Open it on this phone and tap the link '
                    '("Change Email"). Then come back here and tap the button below. '
                    'If the page that opens shows an error, that is fine: the link still works.',
                'Tumetuma barua pepe kwa ${_email.text.trim()}. Ifungue kwenye simu hii na ugusa kiungo '
                    '("Change Email"). Kisha rudi hapa na ugusa kitufe kilicho hapa chini. '
                    'Ukurasa utakaofunguka ukionyesha hitilafu, hakuna shida: kiungo bado kinafanya kazi.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          button('tapped-link', _t("I've tapped the link", 'Nimegusa kiungo'),
              _checkLink),
          const SizedBox(height: 20),
          Text(
              _t('Got a 6-digit code instead?',
                  'Umepata nambari ya tarakimu 6 badala yake?'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            key: const Key('save-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: _t('6-digit code', 'Nambari ya tarakimu 6'),
                counterText: ''),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('confirm-code'),
            onPressed:
                _busy || _code.text.trim().length != 6 ? null : _confirmCode,
            child: Text(_t('Confirm code', 'Thibitisha nambari')),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _step = _Step.email),
            child: Text(_t('Use a different email or send again',
                'Tumia barua pepe nyingine au tuma tena')),
          ),
        ];
      case _Step.password:
        return <Widget>[
          Text(_t('Choose a password', 'Chagua nenosiri'),
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _t('Your email is confirmed. Pick a password with at least 8 characters.',
                'Barua pepe yako imethibitishwa. Chagua nenosiri lenye angalau herufi 8.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('save-password'),
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: _t('Password', 'Nenosiri')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('save-password2'),
            controller: _password2,
            obscureText: true,
            decoration: InputDecoration(
                labelText: _t('Repeat password', 'Rudia nenosiri')),
          ),
          const SizedBox(height: 16),
          button('save-password-button',
              _t('Save my progress', 'Hifadhi maendeleo yangu'), _savePassword),
        ];
      case _Step.done:
        return <Widget>[
          Text(
              _t('Your progress is saved! 🎉',
                  'Maendeleo yako yamehifadhiwa! 🎉'),
              key: const Key('save-done'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _viaGoogle
                ? _t(
                    'On a new phone, choose "Continue with Google" and pick the same Google account.',
                    'Kwenye simu mpya, chagua "Endelea na Google" na uchague akaunti ileile ya Google.')
                : _t(
                    'On a new phone, choose "Sign in" and use ${_email.text.trim()} with your password.',
                    'Kwenye simu mpya, chagua "Ingia" na utumie ${_email.text.trim()} pamoja na nenosiri lako.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: mq.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
            child: Text(_t('Done', 'Sawa')),
          ),
        ];
    }
  }
}
