import 'package:go_router/go_router.dart';

import '../../features/auth/loading_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/chat/chat_backend.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/setup/setup_status_screen.dart';
import '../theme/theme_controller.dart';

const Set<String> _signedOutPages = <String>{'/welcome', '/sign-in', '/sign-up'};

/// Decides which screen the user may see (UC: sign in, onboarding).
///
/// - No Supabase keys: setup status only.
/// - Not signed in: Welcome, Sign in, Create account.
/// - Signed in, profile loading: Loading.
/// - Signed in, not onboarded: Onboarding.
/// - Otherwise: the app (chat for now; Home is added next).
String? redirectFor(SessionController? session, String location) {
  if (session == null) return location == '/setup' ? null : '/setup';
  if (!session.signedIn) return _signedOutPages.contains(location) ? null : '/welcome';
  if (session.loading) return location == '/loading' ? null : '/loading';
  if (!session.onboarded) return location == '/onboarding' ? null : '/onboarding';
  if (_signedOutPages.contains(location) ||
      location == '/onboarding' ||
      location == '/loading' ||
      location == '/' ||
      location == '/setup') {
    return '/chat';
  }
  return null;
}

/// [session] is null when the app was built without Supabase keys.
GoRouter createRouter(ThemeController theme, SessionController? session) => GoRouter(
      refreshListenable: session,
      redirect: (context, state) => redirectFor(session, state.matchedLocation),
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const SetupStatusScreen()),
        GoRoute(path: '/setup', builder: (context, state) => const SetupStatusScreen()),
        if (session != null) ...<RouteBase>[
          GoRoute(path: '/welcome', builder: (context, state) => WelcomeScreen(session: session)),
          GoRoute(path: '/sign-in', builder: (context, state) => SignInScreen(session: session)),
          GoRoute(
            path: '/sign-up',
            builder: (context, state) => SignInScreen(session: session, createAccount: true),
          ),
          GoRoute(path: '/loading', builder: (context, state) => LoadingScreen(session: session)),
          GoRoute(path: '/onboarding', builder: (context, state) => OnboardingScreen(session: session)),
          GoRoute(
            path: '/chat',
            builder: (context, state) => ChatScreen(
              backend: SupabaseChatBackend(),
              themeController: theme,
              session: session,
            ),
          ),
        ],
      ],
    );
