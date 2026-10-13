import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/loading_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/chat/chat_backend.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/past_chats_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/progress_repository.dart';
import '../../features/learn/article_screen.dart';
import '../../features/learn/learn_repository.dart';
import '../../features/learn/learn_screen.dart';
import '../../features/mood/mood_history_screen.dart';
import '../../features/mood/mood_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/save_progress_screen.dart';
import '../../features/reminders/reminders.dart';
import '../../features/rewards/rewards_repository.dart';
import '../../features/rewards/rewards_screen.dart';
import '../../features/setup/setup_status_screen.dart';
import '../../features/support/support_screen.dart';
import '../config/env.dart';
import '../l10n/tr.dart';
import '../offline/offline_store.dart';
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
  if (!session.signedIn) {
    return _signedOutPages.contains(location) ? null : '/welcome';
  }
  if (session.loading) return location == '/loading' ? null : '/loading';
  if (!session.onboarded) {
    return location == '/onboarding' ? null : '/onboarding';
  }
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
/// [offline] keeps data for use without internet; [reminders] is the daily
/// check-in reminder (both null in tests).
GoRouter createRouter(ThemeController theme, SessionController? session,
    {OfflineStore? offline, ReminderController? reminders}) {
  final ProgressTicker ticker = ProgressTicker();
  final ProgressRepository? progress = session == null
      ? null
      : SupabaseProgressRepository(
          offline: offline,
          onMoodLogged: () => reminders?.checkedInToday(),
        );
  final ChatBackend? chat =
      session == null ? null : SupabaseChatBackend(offline: offline);
  final LearnRepository? learn =
      session == null ? null : SupabaseLearnRepository(offline: offline);
  final RewardsRepository? rewards =
      session == null ? null : SupabaseRewardsRepository(offline: offline);

  // Something made offline reached the server, or the internet is back:
  // screens reload to show the real XP, streak and badges.
  offline?.onSynced = ticker.bump;

  /// The offline banner's Retry: send what is waiting, then reload.
  Future<void> retryOffline() async {
    await offline?.retry();
    ticker.bump();
  }

  /// Where to go once the app is ready, when it was opened from a reminder.
  String? openAfterLoading = reminders?.launchLocation;
  reminders?.launchLocation = null;

  /// Helplines, breathing and grounding.
  void showHelplines(BuildContext context) => context.push('/support');

  void goHome(BuildContext context) {
    ticker.bump();
    context.go('/home');
  }

  final GoRouter router = GoRouter(
    refreshListenable: session,
    redirect: (context, state) {
      final String? to = redirectFor(session, state.matchedLocation);
      if (to == '/home' && openAfterLoading != null) {
        final String target = openAfterLoading!;
        openAfterLoading = null;
        return target;
      }
      return to;
    },
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
            progress: progress,
            reminders: reminders,
            connection: offline?.status,
            feedbackUrl: Env.feedbackUrl,
            onHelplines: () => showHelplines(context),
            onMoodHistory: () => context.go('/mood/history'),
            onRewards: () => context.go('/rewards'),
            onSaveProgress: () => context.push('/save-progress'),
          ),
        ),
        GoRoute(
          path: '/save-progress',
          builder: (context, state) => SaveProgressScreen(session: session),
        ),
        GoRoute(
          path: '/support',
          builder: (context, state) => SupportScreen(
            loadHelplines: progress!.loadHelplines,
            onTalk: () => context.go('/chat'),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
            shell: shell,
            ticker: ticker,
            connection: offline?.status,
            onRetry: offline == null ? null : retryOffline,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(
                  repository: progress!,
                  learn: learn,
                  onOpenArticle: (Article a) =>
                      context.go('/learn/article/${a.id}', extra: a),
                  onSupport: () => showHelplines(context),
                  onMoodHistory: () => context.go('/mood/history'),
                  reloadWhen: ticker,
                  theme: theme,
                  onMoodTap: (int mood) => context.go('/mood?mood=$mood'),
                  onTalk: () => context.go('/chat'),
                  onProfile: () => context.push('/profile'),
                  reminders: reminders,
                ),
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                  path: '/chat',
                  builder: (context, state) => ChatScreen(
                        backend: chat!,
                        progress: progress,
                        onBack: () => goHome(context),
                        onHelplines: () => showHelplines(context),
                        onMoodSaved: ticker.bump,
                        onPastChats: () => context.go('/chat/history'),
                      ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'history',
                      builder: (context, state) => PastChatsScreen(
                        backend: chat!,
                        onOpen: (ChatSessionSummary c) =>
                            context.go('/chat/history/${c.id}', extra: c),
                      ),
                      routes: <RouteBase>[
                        GoRoute(
                          path: ':id',
                          builder: (context, state) {
                            final Object? extra = state.extra;
                            if (extra is ChatSessionSummary) {
                              return ChatTranscriptScreen(
                                  backend: chat!, chat: extra);
                            }
                            // Opened without the summary (e.g. after a restart): back to the list.
                            return PastChatsScreen(
                              backend: chat!,
                              onOpen: (ChatSessionSummary c) =>
                                  context.go('/chat/history/${c.id}', extra: c),
                            );
                          },
                        ),
                      ],
                    ),
                  ]),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/mood',
                builder: (context, state) => MoodScreen(
                  repository: progress!,
                  initialMood:
                      int.tryParse(state.uri.queryParameters['mood'] ?? ''),
                  onBack: () => goHome(context),
                  onHistory: () => context.go('/mood/history'),
                  onSupport: () => showHelplines(context),
                  onTalk: () => context.go('/chat'),
                  onSaved: () {
                    // Back to Home, which reloads to show the new XP and streak.
                    ticker.bump();
                    context.go('/home');
                  },
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => MoodHistoryScreen(
                      repository: progress!,
                      onHelplines: () => showHelplines(context),
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/learn',
                builder: (context, state) => LearnScreen(
                  repository: learn!,
                  reloadWhen: ticker,
                  onBack: () => goHome(context),
                  onOpen: (Article a) =>
                      context.go('/learn/article/${a.id}', extra: a),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'article/:id',
                    builder: (context, state) {
                      final Object? extra = state.extra;
                      final int? id =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      Widget screen(Article a) => ArticleScreen(
                            article: a,
                            repository: learn!,
                            onRead: ticker.bump,
                          );
                      if (extra is Article) return screen(extra);
                      // Opened without the article (e.g. after a restart): load it.
                      return FutureBuilder<List<Article>>(
                        future: learn!.loadArticles(),
                        builder: (context, snap) {
                          for (final Article a in snap.data ?? <Article>[]) {
                            if (a.id == id) return screen(a);
                          }
                          return Scaffold(
                            appBar: AppBar(),
                            body: Center(
                              child: snap.hasData || snap.hasError
                                  ? Text(context.tr('Article not found.',
                                      'Makala haikupatikana.'))
                                  : const CircularProgressIndicator(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/rewards',
                builder: (context, state) => RewardsScreen(
                  repository: rewards!,
                  reloadWhen: ticker,
                  onBack: () => goHome(context),
                ),
              ),
            ]),
          ],
        ),
      ],
    ],
  );

  // Tapping a reminder while the app is open opens the mood check-in.
  reminders?.onOpen = (String location) {
    if (session != null && session.signedIn && session.onboarded) {
      router.go(location);
    } else {
      openAfterLoading = location;
    }
  };
  return router;
}
