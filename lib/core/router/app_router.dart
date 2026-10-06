import 'package:go_router/go_router.dart';

import '../../features/setup/setup_status_screen.dart';

/// App routes. Feature screens from the wireframes are added in later steps.
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const SetupStatusScreen(),
    ),
  ],
);
