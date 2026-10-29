import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindquest/core/router/app_shell.dart';
import 'package:mindquest/core/theme/app_theme.dart';
import 'package:mindquest/core/widgets/web_layout.dart';
import 'package:mindquest/features/auth/account_repository.dart';

/// The app's tabs with a plain page in each.
GoRouter shellRouter() => GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AppShell(shell: shell, ticker: ProgressTicker()),
          branches: <StatefulShellBranch>[
            for (final String tab in <String>[
              'home',
              'chat',
              'mood',
              'learn',
              'rewards'
            ])
              StatefulShellBranch(routes: <RouteBase>[
                GoRoute(
                  path: '/$tab',
                  builder: (context, state) => Scaffold(
                    body: LayoutBuilder(
                      builder: (context, box) =>
                          Text('$tab page ${box.maxWidth.round()}'),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ],
    );

void screen(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('web sign-in comes back to the site itself', () {
    expect(webHome(Uri.parse('https://mindquest.netlify.app/?code=abc#/home')),
        'https://mindquest.netlify.app/');
    expect(webHome(Uri.parse('https://example.org/mindquest/#/welcome')),
        'https://example.org/mindquest/');
    expect(authRedirect, 'ke.ac.maseno.mindquest://login-callback');
  });

  testWidgets('a laptop screen gets a side menu and a readable width',
      (tester) async {
    screen(tester, const Size(1280, 800));
    await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light(), routerConfig: shellRouter()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('side-menu')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('home page ${readableWidth.round()}'), findsOneWidget);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.textContaining('learn page'), findsOneWidget);
  });

  testWidgets('a phone keeps the bottom tabs and the full width',
      (tester) async {
    screen(tester, const Size(360, 780));
    await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light(), routerConfig: shellRouter()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('side-menu')), findsNothing);
    expect(find.text('home page 360'), findsOneWidget);
  });

  testWidgets('full-screen pages stay readable on a big screen',
      (tester) async {
    screen(tester, const Size(1400, 900));
    await tester.pumpWidget(MaterialApp(
      home: ReadableWidth(
        child: LayoutBuilder(
            builder: (context, box) => Text('${box.maxWidth.round()}')),
      ),
    ));
    expect(find.text('${readableWidth.round()}'), findsOneWidget);
  });
}
