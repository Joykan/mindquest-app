import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/loading_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/chat/chat_backend.dart';
import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/crisis_sheet.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/progress_repository.dart';
import '../../features/mood/mood_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/setup/setup_status_screen.dart';
import '../theme/theme_controller.dart';
import 'app_shell.dart';

const Set<String> _signedOutPages = <String>{
  '/welcome',
  '/sign-in',
  '/sign-up'
};

/// Decides which screen the user may see.
///
/// - No Supabase keys: setup status only.
/// - Not signed in: Welcome, Sign in, Create account.
/// - Signed in, profile loading: Loading.
/// - Signed in, not onboarded: Onboarding.
/// - Otherwise: the app, starting at Home.
String? redirectFor(SessionController? session, String location) {
  if (session == null) return location == '/setup' ? null : '/setup';
  if (!session.signedIn)
    return _signedOutPages.contains(location) ? null : '/welcome';
  if (session.loading) return location == '/loading' ? null : '/loading';
  if (!session.onboarded)
    return location == '/onboarding' ? null : '/onboarding';
  if (_signedOutPages.contains(location) ||
      location == '/onboarding' ||
      location == '/loading' ||
      location == '/' ||
      location == '/setup') {
    return '/home';
  }
  return null;
}

/// [session] is null when the app was built without Supabase keys.
GoRouter createRouter(ThemeController theme, SessionController? session) {
  final ProgressTicker ticker = ProgressTicker();
  final ProgressRepository? progress =
      session == null ? null : SupabaseProgressRepository();
  final ChatBackend? chat = session == null ? null : SupabaseChatBackend();

  Future<void> showHelplines(BuildContext context) async {
    try {
      final List<Helpline> lines = await progress!.loadHelplines();
      if (!context.mounted) return;
      await showCrisisSheet(
        context,
        ChatReply(
          reply:
              'If things feel too heavy right now, talking to someone can help. '
              'These services are free and confidential.',
          helplines: lines,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Couldn't load helplines. In an emergency call 999 or 112.")),
      );
    }
  }

  return GoRouter(
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
          path: '/', builder: (context, state) => const SetupStatusScreen()),
      GoRoute(
          path: '/setup',
          builder: (context, state) => const SetupStatusScreen()),
      if (session != null) ...<RouteBase>[
        GoRoute(
            path: '/welcome',
            builder: (context, state) => WelcomeScreen(session: session)),
        GoRoute(
            path: '/sign-in',
            builder: (context, state) => SignInScreen(session: session)),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) =>
              SignInScreen(session: session, createAccount: true),
        ),
        GoRoute(
            path: '/loading',
            builder: (context, state) => LoadingScreen(session: session)),
        GoRoute(
            path: '/onboarding',
            builder: (context, state) => OnboardingScreen(session: session)),
        GoRoute(
          path: '/profile',
          builder: (context, state) => ProfileScreen(
            session: session,
            theme: theme,
            onHelplines: () => showHelplines(context),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AppShell(shell: shell, ticker: ticker),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(
                  repository: progress!,
                  reloadWhen: ticker,
                  theme: theme,
                  onMoodTap: (int mood) => context.go('/mood?mood=$mood'),
                  onTalk: () => context.go('/chat'),
                  onProfile: () => context.push('/profile'),
                ),
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                  path: '/chat',
                  builder: (context, state) => ChatScreen(backend: chat!)),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/mood',
                builder: (context, state) => MoodScreen(
                  repository: progress!,
                  initialMood:
                      int.tryParse(state.uri.queryParameters['mood'] ?? ''),
                  onSaved: () {
                    // Back to Home, which reloads to show the new XP and streak.
                    ticker.bump();
                    context.go('/home');
                  },
                ),
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/learn',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Learn',
                  icon: Icons.menu_book_outlined,
                  text:
                      'Short articles on stress, sleep, exams and more are coming in the next update.',
                ),
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/rewards',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Rewards',
                  icon: Icons.emoji_events_outlined,
                  text:
                      'Your badges and weekly quests will show here in the next update.',
                ),
              ),
            ]),
          ],
        ),
      ],
    ],
  );
}
