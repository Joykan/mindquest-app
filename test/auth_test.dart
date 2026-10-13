import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/core/router/app_router.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/features/auth/account_repository.dart';
import 'package:mindquest/features/auth/onboarding_screen.dart';
import 'package:mindquest/features/auth/session_controller.dart';
import 'package:mindquest/features/auth/sign_in_screen.dart';
import 'package:mindquest/features/auth/welcome_screen.dart';
import 'package:mindquest/core/theme/theme_controller.dart';
import 'package:mindquest/features/profile/profile_screen.dart';
import 'package:mindquest/features/profile/save_progress_screen.dart';

/// In-memory stand-in for Supabase auth and the profiles table.
class FakeAccount implements AccountRepository {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  String? _userId;
  bool _anonymous = false;
  Profile? profile;
  String? onboardedName;
  String? onboardedLanguage;

  @override
  String? get userId => _userId;

  @override
  bool get isAnonymous => _anonymous;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> signInAnonymously() async {
    _userId = 'anon-1';
    _anonymous = true;
    profile =
        const Profile(username: 'Friend', language: 'en', onboarded: false);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != 'correct-horse') {
      throw const AccountException('Invalid login credentials');
    }
    _userId = 'user-1';
    profile = const Profile(username: 'Amani', language: 'sw', onboarded: true);
  }

  @override
  Future<bool> signUp(
          {required String email, required String password}) async =>
      false;

  @override
  Future<void> signOut() async => _userId = null;

  @override
  Future<Profile?> loadProfile() async => _userId == null ? null : profile;

  @override
  Future<void> completeOnboarding(
      {required String username, required String language}) async {
    onboardedName = username;
    onboardedLanguage = language;
    profile = Profile(username: username, language: language, onboarded: true);
  }

  String? linkedEmail;
  bool emailConfirmed = false;
  String? password;
  bool deleted = false;

  @override
  String? get email => emailConfirmed ? linkedEmail : null;

  @override
  Future<void> linkEmail(String email) async {
    if (email == 'taken@example.com') {
      throw const AccountException(
          'A user with this email address has already been registered');
    }
    linkedEmail = email;
  }

  @override
  Future<void> confirmEmailCode(
      {required String email, required String code}) async {
    if (code != '123456') {
      throw const AccountException('Token has expired or is invalid');
    }
    emailConfirmed = true;
    _anonymous = false;
  }

  @override
  Future<bool> checkEmailConfirmed() async => emailConfirmed;

  @override
  Future<void> setPassword(String password) async => this.password = password;

  int googleSignIns = 0;
  int googleLinks = 0;

  @override
  Future<void> signInWithGoogle() async => googleSignIns++;

  @override
  Future<void> linkGoogle() async {
    googleLinks++;
    _anonymous = false;
    emailConfirmed = true;
    linkedEmail = 'candy@gmail.com';
    _changes.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    _userId = null;
  }

  @override
  Future<void> updateLanguage(String language) async {
    final Profile? p = profile;
    if (p != null) {
      profile = Profile(
          username: p.username, language: language, onboarded: p.onboarded);
    }
  }
}

Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  group('which screen the user sees', () {
    test('no Supabase keys: setup screen', () {
      expect(redirectFor(null, '/chat'), '/setup');
      expect(redirectFor(null, '/setup'), isNull);
    });

    test('signed out: welcome and sign-in pages only', () async {
      final SessionController s = SessionController(FakeAccount());
      expect(redirectFor(s, '/chat'), '/welcome');
      expect(redirectFor(s, '/sign-in'), isNull);
      expect(redirectFor(s, '/sign-up'), isNull);
    });

    test('signed in but not onboarded: onboarding', () async {
      final FakeAccount account = FakeAccount();
      final SessionController s = SessionController(account);
      await account.signInAnonymously();
      expect(redirectFor(s, '/chat'), '/loading');
      await s.refresh();
      expect(redirectFor(s, '/chat'), '/onboarding');
      expect(redirectFor(s, '/onboarding'), isNull);
    });

    test('onboarded: straight to the app, never back to welcome', () async {
      final FakeAccount account = FakeAccount();
      final SessionController s = SessionController(account);
      await account.signIn(email: 'a@b.co', password: 'correct-horse');
      await s.refresh();
      expect(redirectFor(s, '/welcome'), '/home');
      expect(redirectFor(s, '/onboarding'), '/home');
      expect(redirectFor(s, '/home'), isNull);
      expect(redirectFor(s, '/chat'), isNull);
      expect(s.language, 'sw');
    });
  });

  testWidgets('Continue anonymously signs in without an email', (tester) async {
    final FakeAccount account = FakeAccount();
    final SessionController s = SessionController(account);
    await tester.pumpWidget(wrap(WelcomeScreen(session: s)));

    await tester.tap(find.byKey(const Key('continue-anonymously')));
    await tester.pumpAndSettle();

    expect(account.userId, 'anon-1');
    expect(s.signedIn, isTrue);
    expect(s.onboarded, isFalse);
  });

  testWidgets('Onboarding needs a nickname and consent, then saves them',
      (tester) async {
    final FakeAccount account = FakeAccount();
    await account.signInAnonymously();
    final SessionController s = SessionController(account);
    await s.refresh();
    await tester.pumpWidget(wrap(OnboardingScreen(session: s)));

    FilledButton finish() =>
        tester.widget<FilledButton>(find.byKey(const Key('finish-onboarding')));
    expect(finish().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('nickname')), '  Wanjiru ');
    await tester.pump();
    expect(finish().onPressed, isNull, reason: 'consent not given yet');

    await tester.tap(find.byKey(const Key('lang-sw')));
    await tester.ensureVisible(find.byKey(const Key('consent')));
    await tester.tap(find.byKey(const Key('consent')));
    await tester.pump();
    expect(finish().onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('finish-onboarding')));
    await tester.tap(find.byKey(const Key('finish-onboarding')));
    await tester.pumpAndSettle();

    expect(account.onboardedName, 'Wanjiru');
    expect(account.onboardedLanguage, 'sw');
    expect(s.onboarded, isTrue);
  });

  testWidgets('Sign in checks the email and shows wrong-password errors',
      (tester) async {
    final SessionController s = SessionController(FakeAccount());
    await tester.pumpWidget(wrap(SignInScreen(session: s)));

    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('password')), 'whatever');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(find.text("That email doesn't look right"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'amani@example.com');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets(
      'Create account asks for 8+ characters and explains email confirmation',
      (tester) async {
    final SessionController s = SessionController(FakeAccount());
    await tester
        .pumpWidget(wrap(SignInScreen(session: s, createAccount: true)));

    await tester.enterText(find.byKey(const Key('email')), 'amani@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password')), 'long-enough-1');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Open it to confirm your email'), findsOneWidget);
  });

  Future<(FakeAccount, SessionController)> anonymousUser() async {
    final FakeAccount account = FakeAccount();
    await account.signInAnonymously();
    await account.completeOnboarding(username: 'Candy', language: 'en');
    final SessionController s = SessionController(account);
    await s.refresh();
    return (account, s);
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Save your progress: email, code, then password', (tester) async {
    tallScreen(tester);
    final (FakeAccount account, SessionController s) = await anonymousUser();
    await tester.pumpWidget(wrap(SaveProgressScreen(session: s)));

    FilledButton send() =>
        tester.widget<FilledButton>(find.byKey(const Key('send-code')));
    expect(send().onPressed, isNull, reason: 'no email yet');
    await tester.enterText(
        find.byKey(const Key('save-email')), 'candy@example.com');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    expect(account.linkedEmail, 'candy@example.com');
    expect(find.text('Check your email'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('save-code')), '000000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining("That code didn't work"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('save-code')), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-code')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('save-password')), 'short');
    await tester.enterText(find.byKey(const Key('save-password2')), 'short');
    await tester.tap(find.byKey(const Key('save-password-button')));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('save-password')), 'long-enough-1');
    await tester.enterText(
        find.byKey(const Key('save-password2')), 'long-enough-1');
    await tester.tap(find.byKey(const Key('save-password-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-done')), findsOneWidget);
    expect(account.password, 'long-enough-1');
    expect(account.isAnonymous, isFalse);
  });

  testWidgets('Save your progress explains an email that is already used',
      (tester) async {
    tallScreen(tester);
    final (FakeAccount _, SessionController s) = await anonymousUser();
    await tester.pumpWidget(wrap(SaveProgressScreen(session: s)));
    await tester.enterText(
        find.byKey(const Key('save-email')), 'taken@example.com');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('already has a MindQuest account'), findsOneWidget);
  });

  testWidgets('Delete my data needs DELETE typed, then signs out',
      (tester) async {
    tallScreen(tester);
    final (FakeAccount account, SessionController s) = await anonymousUser();
    await tester.pumpWidget(wrap(ProfileScreen(
      session: s,
      theme: ThemeController(),
      onSaveProgress: () {},
    )));
    expect(find.byKey(const Key('open-save-progress')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-data')));
    await tester.pumpAndSettle();
    TextButton confirm() =>
        tester.widget<TextButton>(find.byKey(const Key('delete-confirm')));
    expect(confirm().onPressed, isNull);
    await tester.enterText(
        find.byKey(const Key('delete-confirm-field')), 'delete');
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(account.deleted, isTrue);
    expect(s.signedIn, isFalse);
  });

  testWidgets('Welcome and Sign in offer Continue with Google', (tester) async {
    tallScreen(tester);
    final FakeAccount account = FakeAccount();
    final SessionController s = SessionController(account);
    await tester.pumpWidget(wrap(WelcomeScreen(session: s)));
    await tester.tap(find.byKey(const Key('google')));
    await tester.pumpAndSettle();
    expect(account.googleSignIns, 1);

    await tester.pumpWidget(wrap(SignInScreen(session: s)));
    await tester.tap(find.byKey(const Key('google')));
    await tester.pumpAndSettle();
    expect(account.googleSignIns, 2);
  });

  testWidgets(
      'Save your progress with Google finishes when the account is linked',
      (tester) async {
    tallScreen(tester);
    final (FakeAccount account, SessionController s) = await anonymousUser();
    await tester.pumpWidget(wrap(SaveProgressScreen(session: s)));
    await tester.tap(find.byKey(const Key('google')));
    await tester.pumpAndSettle();
    expect(account.googleLinks, 1);
    expect(find.byKey(const Key('save-done')), findsOneWidget);
    expect(find.textContaining('Continue with Google'), findsOneWidget);
  });
}
