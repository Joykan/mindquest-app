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
    if (password != 'correct-horse')
      throw const AccountException('Invalid login credentials');
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

  @override
  Future<void> updateLanguage(String language) async {
    final Profile? p = profile;
    if (p != null)
      profile = Profile(
          username: p.username, language: language, onboarded: p.onboarded);
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
}
