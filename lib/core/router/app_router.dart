import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/loading_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/challenges/challenge_widgets.dart';
import '../../features/challenges/challenges.dart';
import '../../features/chat/chat_backend.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/past_chats_screen.dart';
import '../../features/gamification/badge_watcher.dart';
import '../../features/gamification/outfits.dart';
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
import '../widgets/web_layout.dart';
import 'app_shell.dart';

/// A full-screen page outside the tabs. On big screens it is kept to a
/// readable width in the middle.
GoRoute page(String path,
        Widget Function(BuildContext context, GoRouterState state) build) =>
    GoRoute(
        path: path,
        builder: (BuildContext context, GoRouterState state) =>
            ReadableWidth(child: build(context, state)));

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
    {OfflineStore? offline,
    ReminderController? reminders,
    BadgeWatcher? badges,
    OutfitController? outfits}) {
  final ProgressTicker ticker = ProgressTicker();
  // Any change in progress may have earned a badge.
  if (badges != null) ticker.addListener(badges.check);
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
  if (outfits != null && rewards != null) outfits.save = rewards.wearOutfit;
  final ChallengesRepository? challenges =
      session == null ? null : SupabaseChallengesRepository(offline: offline);

  /// Opens the place for a challenge step.
  void openStep(BuildContext context, String place) {
    switch (place) {
      case 'mood':
        context.go('/mood');
      case 'chat':
        context.go('/chat');
      case 'support':
        context.push('/support');
      case 'learn':
        context.go('/learn');
      default:
        context.go('/home');
    }
  }

  // Something made offline reached the server, or the internet is back:
  // screens reload to show the real XP, streak and badges.
  offline?.onSynced = ticker.bump;
  // Opening the app shows the saved data at once; when the server's newer
  // data arrives a moment later, screens reload with it.
  offline?.onRefreshed = () {
    ticker.bump();
    session?.refresh(); // e.g. the name or language changed on another phone
  };

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
      page(
          '/', (context, state) => const SetupStatusScreen()),
      page(
          '/setup',
          (context, state) => const SetupStatusScreen()),
      if (session != null) ...<RouteBase>[
        page(
            '/welcome',
            (context, state) => WelcomeScreen(session: session)),
        page(
            '/sign-in',
            (context, state) => SignInScreen(session: session)),
        page(
          '/sign-up',
          (context, state) =>
              SignInScreen(session: session, createAccount: true),
        ),
        page(
            '/loading',
            (context, state) => LoadingScreen(session: session)),
        page(
            '/onboarding',
            (context, state) => OnboardingScreen(session: session)),
        page(
          '/profile',
          (context, state) => ProfileScreen(
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
        page(
          '/save-progress',
          (context, state) => SaveProgressScreen(session: session),
        ),
        page(
          '/support',
          (context, state) => SupportScreen(
            loadHelplines: progress!.loadHelplines,
            onTalk: () => context.go('/chat'),
            onExerciseDone: (String kind) async {
              try {
                await challenges?.logActivity(kind);
              } catch (_) {
                // Only counts for challenges; the exercise itself is done.
              }
              ticker.bump();
            },
          ),
        ),
        page(
          '/challenges',
          (context, state) => ChallengesScreen(
            repository: challenges!,
            onChanged: ticker.bump,
            onStep: (String place) => openStep(context, place),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(
            shell: shell,
            ticker: ticker,
            badges: badges,
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
                  outfits: outfits,
                  challenges: challenges,
                  onChallenges: () => context.push('/challenges'),
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
                        onMessageSent: badges?.check,
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
                            onBadgesShown: badges?.markSeen,
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
                  outfits: outfits,
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
