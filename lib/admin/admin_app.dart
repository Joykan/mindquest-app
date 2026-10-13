import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/google_button.dart';
import '../core/widgets/logo_mark.dart';
import '../features/auth/account_errors.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';
import 'articles_page.dart';
import 'helplines_page.dart';
import 'overview_page.dart';
import 'team_page.dart';

/// The app's theme, with normal-width buttons: on the phone, buttons fill
/// the screen; on a dashboard they sit in rows next to other controls.
ThemeData adminTheme([ThemeData? base]) {
  final ThemeData t = base ?? AppTheme.light();
  return t.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: t.filledButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 44))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: t.outlinedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 44))),
    ),
  );
}

/// MindQuest Admin (step 11): a web dashboard for administrators and
/// counsellors. Run with `flutter run -d chrome -t lib/main_admin.dart`.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MindQuest Admin',
        debugShowCheckedModeBanner: false,
        theme: adminTheme(),
        darkTheme: adminTheme(AppTheme.dark()),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminGate(repository: repository),
      );
}

/// Sign in, then check the role: only admins and counsellors get in.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late final StreamSubscription<void> _sub;
  Future<StaffProfile?>? _me;

  @override
  void initState() {
    super.initState();
    _check();
    _sub = widget.repository.changes.listen((_) {
      if (mounted) setState(_check);
    });
  }

  void _check() {
    _me = widget.repository.signedIn ? widget.repository.me() : null;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Future<StaffProfile?>? me = _me;
    if (me == null) {
      return AdminSignIn(
          repository: widget.repository, onSignedIn: () => setState(_check));
    }
    return FutureBuilder<StaffProfile?>(
      future: me,
      builder: (BuildContext context, AsyncSnapshot<StaffProfile?> snap) {
        if (snap.hasError) {
          return Scaffold(
            body: LoadProblem(
                message: '${snap.error}', onRetry: () => setState(_check)),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final StaffProfile? p = snap.data;
        if (p == null || !p.isStaff) {
          return NoAccess(
            email: widget.repository.email,
            onSignOut: () async {
              await widget.repository.signOut();
              if (mounted) setState(_check);
            },
          );
        }
        return AdminShell(
          repository: widget.repository,
          profile: p,
          onSignOut: () async {
            await widget.repository.signOut();
            if (mounted) setState(_check);
          },
        );
      },
    );
  }
}

/// Email and password (or Google) sign-in for staff.
class AdminSignIn extends StatefulWidget {
  const AdminSignIn(
      {super.key, required this.repository, required this.onSignedIn});

  final AdminRepository repository;
  final VoidCallback onSignedIn;

  @override
  State<AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends State<AdminSignIn> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onSignedIn();
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = accountError(e.message, 'en'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    await _run(() =>
        widget.repository.signIn(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: LogoMark(size: 72)),
                  const SizedBox(height: 16),
                  Text('MindQuest Admin',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  Text('For administrators and counsellors',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: mq.textMuted)),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('admin-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (String? v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('admin-password'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const <String>[AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (String? v) =>
                        (v ?? '').isEmpty ? 'Enter your password' : null,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(_error!,
                        key: const Key('admin-error'),
                        style: TextStyle(color: mq.crisis)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('admin-sign-in'),
                    onPressed: _busy ? null : _signIn,
                    child: Text(_busy ? 'Signing in...' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  GoogleButton(
                    label: 'Sign in with Google',
                    onPressed: _busy
                        ? null
                        : () => _run(widget.repository.signInWithGoogle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed in, but the account is a student account.
class NoAccess extends StatelessWidget {
  const NoAccess({super.key, this.email, required this.onSignOut});

  final String? email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                key: const Key('no-access'),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('No access',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '${email ?? 'This account'} is not an administrator or counsellor. '
                    'Ask an administrator to add you on the Team page.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: onSignOut, child: const Text('Sign out')),
                ],
              ),
            ),
          ),
        ),
      );
}

/// One page of the dashboard.
class _Section {
  const _Section(this.label, this.icon, this.selectedIcon, this.build);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
}

/// The dashboard: a side menu on wide screens, tabs at the bottom on narrow
/// ones. Counsellors only get the Overview.
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.repository,
    required this.profile,
    required this.onSignOut,
  });

  final AdminRepository repository;
  final StaffProfile profile;
  final VoidCallback onSignOut;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  List<_Section> get _sections => <_Section>[
        _Section('Overview', Icons.insights_outlined, Icons.insights,
            () => OverviewPage(repository: widget.repository)),
        if (widget.profile.isAdmin) ...<_Section>[
          _Section('Articles', Icons.menu_book_outlined, Icons.menu_book,
              () => ArticlesPage(repository: widget.repository)),
          _Section(
              'Helplines',
              Icons.phone_in_talk_outlined,
              Icons.phone_in_talk,
              () => HelplinesPage(repository: widget.repository)),
          _Section(
              'Team',
              Icons.group_outlined,
              Icons.group,
              () => TeamPage(
                  repository: widget.repository,
                  myEmail: widget.repository.email)),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final List<_Section> sections = _sections;
    final int index = _index.clamp(0, sections.length - 1);
    final bool wide = MediaQuery.sizeOf(context).width >= 760;
    final Widget page = KeyedSubtree(
        key: ValueKey<String>(sections[index].label),
        child: sections[index].build());

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            LogoMark(size: 32),
            SizedBox(width: 10),
            Text('MindQuest Admin'),
          ],
        ),
        actions: <Widget>[
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${widget.profile.username} · ${roleNames[widget.profile.role] ?? widget.profile.role}',
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: mq.textMuted),
                ),
              ),
            ),
          IconButton(
            key: const Key('admin-sign-out'),
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: <Widget>[
                if (sections.length > 1)
                  NavigationRail(
                    selectedIndex: index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (int i) =>
                        setState(() => _index = i),
                    destinations: <NavigationRailDestination>[
                      for (final _Section s in sections)
                        NavigationRailDestination(
                          icon: Icon(s.icon),
                          selectedIcon: Icon(s.selectedIcon),
                          label: Text(s.label),
                        ),
                    ],
                  ),
                if (sections.length > 1) const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide || sections.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (int i) => setState(() => _index = i),
              destinations: <NavigationDestination>[
                for (final _Section s in sections)
                  NavigationDestination(
                    icon: Icon(s.icon),
                    selectedIcon: Icon(s.selectedIcon),
                    label: s.label,
                  ),
              ],
            ),
    );
  }
}
