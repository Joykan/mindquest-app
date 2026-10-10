import 'package:go_router/go_router.dart';

import '../../features/chat/chat_backend.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/setup/setup_status_screen.dart';
import '../config/env.dart';
import '../theme/theme_controller.dart';

/// App routes. The Welcome, Home and other screens from the wireframes are
/// added as they are built; for now the app opens on the chat screen.
GoRouter createRouter(ThemeController theme) => GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          // Without Supabase keys there is nothing to chat with, so show the
          // setup status instead (this is also what the widget test sees).
          builder: (context, state) => Env.isConfigured
              ? ChatScreen(backend: SupabaseChatBackend(), themeController: theme)
              : const SetupStatusScreen(),
        ),
        GoRoute(
          path: '/setup',
          builder: (context, state) => const SetupStatusScreen(),
        ),
      ],
    );
