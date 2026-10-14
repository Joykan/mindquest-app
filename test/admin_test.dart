import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/admin/admin_app.dart';
import 'package:mindquest/admin/admin_repository.dart';
import 'package:mindquest/admin/helplines_page.dart';
import 'package:mindquest/admin/overview_page.dart';

/// What public.admin_stats(7) returned on the live database (13 Oct 2026),
/// plus the reply-time and age fields added on 14 Oct (example values).
final Map<String, dynamic> liveStats = <String, dynamic>{
  'to': '2026-10-13',
  'days': 7,
  'from': '2026-10-07',
  'daily': <dynamic>[
    for (int d = 7; d <= 9; d++)
      <String, dynamic>{
        'day': '2026-10-0$d',
        'chats': 0,
        'check_ins': 0,
        'average_mood': null,
        'crisis_events': 0
      },
    <String, dynamic>{
      'day': '2026-10-10',
      'chats': 8,
      'check_ins': 5,
      'average_mood': 3.80,
      'crisis_events': 3
    },
    <String, dynamic>{
      'day': '2026-10-11',
      'chats': 0,
      'check_ins': 1,
      'average_mood': 3.00,
      'crisis_events': 0
    },
    <String, dynamic>{
      'day': '2026-10-12',
      'chats': 1,
      'check_ins': 2,
      'average_mood': 2.00,
      'crisis_events': 0
    },
    <String, dynamic>{
      'day': '2026-10-13',
      'chats': 2,
      'check_ins': 4,
      'average_mood': 2.25,
      'crisis_events': 1
    },
  ],
  'users': 5,
  'topics': <String, dynamic>{
    'deny': 2,
    'greet': 2,
    'thank': 1,
    'affirm': 4,
    'crisis': 4,
    'fallback': 1,
    'feel_sad': 2,
    'ask_ideas': 1,
    'feel_good': 3,
    'tell_name': 3,
    'feel_anxious': 1,
    'ask_about_bot': 1,
    'ask_breathing': 2,
    'feel_stressed': 5
  },
  'messages': 32,
  'mood_tags': <dynamic>[
    <String, dynamic>{'tag': 'school', 'check_ins': 1, 'average_mood': 1.00},
    <String, dynamic>{'tag': 'health', 'check_ins': 1, 'average_mood': 5.00},
  ],
  'new_users': 5,
  'mood_split': <String, dynamic>{'1': 3, '2': 2, '3': 3, '4': 1, '5': 3},
  'unavailable': 0,
  'active_users': 5,
  'average_mood': 2.92,
  'mood_entries': 12,
  'article_reads': <dynamic>[
    <String, dynamic>{
      'id': 8,
      'reads': 1,
      'title': 'Box breathing for a racing mind',
      'recent': 1
    },
    <String, dynamic>{
      'id': 1,
      'reads': 0,
      'title': 'Understanding stress',
      'recent': 0
    },
  ],
  'articles_read': 4,
  'chat_sessions': 11,
  'crisis_events': 4,
  'badges_awarded': 9,
  'language_split': <String, dynamic>{'en': 5},
  'not_understood': 1,
  'saved_accounts': 0,
  'min_group': 5,
  'reply_count': 40,
  'reply_median_ms': 420,
  'reply_p95_ms': 1240,
  'reply_within_2s': 0.975,
  'age_split': <String, dynamic>{'18_20': 3, '21_24': 1, 'not_asked': 1},
};

class FakeAdmin implements AdminRepository {
  FakeAdmin({this.role = 'admin', this.signedIn = false});

  String role;
  @override
  bool signedIn;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  int? lastDays;
  final List<AdminArticle> savedArticles = <AdminArticle>[];
  final Map<int, bool> published = <int, bool>{};
  final Map<int, bool> verified = <int, bool>{};
  final List<(String, String)> roles = <(String, String)>[];

  List<AdminArticle> articleList = <AdminArticle>[
    const AdminArticle(
        id: 1,
        category: 'stress',
        titleEn: 'Understanding stress',
        titleSw: 'Kuelewa msongo',
        bodyEn: 'One.\n\nTwo.',
        bodySw: 'Moja.\n\nMbili.',
        published: true),
    const AdminArticle(
        id: 2,
        category: 'anxiety',
        titleEn: 'Draft about worry',
        titleSw: 'Rasimu',
        bodyEn: 'Text',
        bodySw: 'Maandishi'),
  ];

  @override
  Stream<void> get changes => _changes.stream;

  @override
  String? get email => signedIn ? 'candy@example.com' : null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != 'right-password') {
      throw const AdminException('Invalid login credentials');
    }
    signedIn = true;
    _changes.add(null);
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {
    signedIn = false;
    _changes.add(null);
  }

  @override
  Future<StaffProfile?> me() async =>
      StaffProfile(username: 'Candy', role: role);

  @override
  Future<AdminStats> stats(int days) async {
    lastDays = days;
    return AdminStats.fromJson(liveStats);
  }

  bool nluDown = false;

  @override
  Future<SystemHealth> health() async => SystemHealth(
        database: const HealthCheck(ok: true, ms: 45),
        nlu: nluDown
            ? const HealthCheck(ok: false, ms: 8000, detail: 'status 502')
            : const HealthCheck(ok: true, ms: 230, detail: 'mindquest.tar.gz'),
        checkedAt: DateTime.utc(2026, 10, 14, 12),
      );

  @override
  Future<List<AdminArticle>> articles() async => articleList;

  @override
  Future<void> saveArticle(AdminArticle article) async =>
      savedArticles.add(article);

  @override
  Future<void> setPublished(int id, bool value) async => published[id] = value;

  @override
  Future<void> deleteArticle(int id) async {}

  @override
  Future<List<AdminHelpline>> helplines() async => const <AdminHelpline>[
        AdminHelpline(
            id: 1,
            name: 'Kenya Red Cross',
            phone: '1199',
            description: 'Toll-free, 24 hours',
            verified: true),
        AdminHelpline(
            id: 2, name: 'Befrienders Kenya', phone: '+254 722 178 177'),
      ];

  @override
  Future<void> saveHelpline(AdminHelpline helpline) async {}

  @override
  Future<void> setVerified(int id, bool value) async => verified[id] = value;

  @override
  Future<void> deleteHelpline(int id) async {}

  @override
  Future<List<StaffMember>> staff() async => const <StaffMember>[
        StaffMember(
            id: 'a',
            username: 'Candy',
            email: 'candy@example.com',
            role: 'admin'),
        StaffMember(
            id: 'b',
            username: 'Rajula',
            email: 'rajula@example.com',
            role: 'counsellor'),
      ];

  @override
  Future<String> setRole(String email, String role) async {
    if (email == 'nobody@example.com') {
      throw const AdminException(
          'No MindQuest account uses that email. They need to sign up in the app first.');
    }
    roles.add((email, role));
    return 'Wanjiru';
  }
}

void desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAdmin> openDashboard(WidgetTester tester,
    {String role = 'admin'}) async {
  desktop(tester);
  final FakeAdmin admin = FakeAdmin(role: role, signedIn: true);
  await tester.pumpWidget(AdminApp(repository: admin));
  await tester.pumpAndSettle();
  return admin;
}

Future<void> openSection(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationRail), matching: find.text(name)));
  await tester.pumpAndSettle();
}

void main() {
  test('admin statistics are read from the database answer', () {
    final AdminStats s = AdminStats.fromJson(liveStats);
    expect(s.days, 7);
    expect(s.from, DateTime(2026, 10, 7));
    expect(s.daily.length, 7);
    expect(s.daily[3].averageMood, 3.8);
    expect(s.daily.first.averageMood, isNull);
    expect(s.moodSplit[1], 3);
    expect(s.tags.first.tag, 'school');
    expect(s.topics['feel_stressed'], 5);
    expect(s.languages, <String, int>{'en': 5});
    expect(s.articles.first.title, 'Box breathing for a racing mind');
    // 32 messages, 4 crisis (answered before the model), 1 not understood.
    expect(s.understoodShare, closeTo(27 / 28, 0.001));
  });

  test('helpline numbers are checked', () {
    expect(validHelplinePhone('1199'), isNull);
    expect(validHelplinePhone('+254 722 178 177'), isNull);
    expect(validHelplinePhone('call me'), isNotNull);
    expect(validHelplinePhone(''), 'Required');
  });

  testWidgets('staff sign in with email and password', (tester) async {
    desktop(tester);
    final FakeAdmin admin = FakeAdmin();
    await tester.pumpWidget(AdminApp(repository: admin));
    await tester.pumpAndSettle();
    expect(find.text('MindQuest Admin'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('admin-email')), 'candy@example.com');
    await tester.enterText(find.byKey(const Key('admin-password')), 'wrong');
    await tester.tap(find.byKey(const Key('admin-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('That email or password is not right.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('admin-password')), 'right-password');
    await tester.tap(find.byKey(const Key('admin-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-sign-in')), findsOneWidget);
  });

  testWidgets('a student account gets no access', (tester) async {
    await openDashboard(tester, role: 'user');
    expect(find.byKey(const Key('no-access')), findsOneWidget);
    expect(find.byKey(const Key('overview')), findsNothing);
  });

  testWidgets('counsellors only see the overview', (tester) async {
    await openDashboard(tester, role: 'counsellor');
    expect(find.byKey(const Key('overview')), findsOneWidget);
    // One page only, so no side menu (Articles, Helplines, Team).
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Team'), findsNothing);
  });

  testWidgets('overview shows totals and can switch period', (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    expect(admin.lastDays, 7);
    expect(
        find.descendant(
            of: find.byKey(const Key('tile-checkins')),
            matching: find.text('12')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tile-understood')),
            matching: find.text('96%')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tile-crisis')), matching: find.text('4')),
        findsOneWidget);
    expect(find.textContaining('Totals only'), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(admin.lastDays, 30);
  });

  testWidgets('articles can be published, hidden and added', (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    await openSection(tester, 'Articles');
    expect(find.text('Understanding stress'), findsOneWidget);
    expect(find.text('Draft about worry'), findsOneWidget);
    expect(find.textContaining('1 of 2 published'), findsOneWidget);

    await tester.tap(find.byKey(const Key('publish-2')));
    await tester.pumpAndSettle();
    expect(admin.published[2], isTrue);

    await tester.tap(find.byKey(const Key('new-article')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-article')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    expect(admin.savedArticles, isEmpty);

    await tester.enterText(find.byKey(const Key('title-en')), 'Sleep tips');
    await tester.enterText(
        find.byKey(const Key('title-sw')), 'Vidokezo vya usingizi');
    await tester.enterText(
        find.byKey(const Key('body-en')), 'Go to bed.\n\nWake up.');
    await tester.enterText(find.byKey(const Key('body-sw')), 'Lala.\n\nAmka.');
    await tester.tap(find.byKey(const Key('save-article')));
    await tester.pumpAndSettle();
    expect(admin.savedArticles.single.titleEn, 'Sleep tips');
    expect(admin.savedArticles.single.id, isNull);
    expect(admin.savedArticles.single.published, isFalse);
    expect(find.text('Article added.'), findsOneWidget);
  });

  testWidgets('editing keeps the article id', (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    await openSection(tester, 'Articles');
    await tester.tap(find.text('Understanding stress'));
    await tester.pumpAndSettle();
    expect(find.text('Edit article'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('title-en')), 'Stress, explained');
    await tester.tap(find.byKey(const Key('save-article')));
    await tester.pumpAndSettle();
    expect(admin.savedArticles.single.id, 1);
    expect(admin.savedArticles.single.titleEn, 'Stress, explained');
    expect(admin.savedArticles.single.bodySw, 'Moja.\n\nMbili.');
  });

  testWidgets('helplines can be verified', (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    await openSection(tester, 'Helplines');
    expect(find.textContaining('1 of 2 verified'), findsOneWidget);
    await tester.tap(find.byKey(const Key('verify-2')));
    await tester.pumpAndSettle();
    expect(admin.verified[2], isTrue);
  });

  testWidgets('team: give access by email', (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    await openSection(tester, 'Team');
    expect(find.text('Rajula'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('team-email')), 'nobody@example.com');
    await tester.tap(find.byKey(const Key('team-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('team-error')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('team-email')), 'wanjiru@example.com');
    await tester.tap(find.byKey(const Key('team-add')));
    await tester.pumpAndSettle();
    expect(admin.roles.single, ('wanjiru@example.com', 'counsellor'));
    expect(find.text('Wanjiru is now a counsellor.'), findsOneWidget);
  });

  test('reply time and ages are read from the database answer', () {
    final AdminStats s = AdminStats.fromJson(liveStats);
    expect(s.replyP95Ms, 1240);
    expect(s.replyWithin2s, 0.975);
    expect(s.ages['18_20'], 3);
    expect(s.minGroup, 5);
  });

  test('the report has the totals and one line per day', () {
    final String report = buildReport(AdminStats.fromJson(liveStats));
    expect(report, contains('MindQuest report: 2026-10-07 to 2026-10-13 (7 days)'));
    expect(report, contains('Mood check-ins: 12'));
    expect(report, contains('Chipu understood: 96%'));
    expect(report,
        contains('Reply time: median 0.4 s, 95% within 1.2 s; 98% of 40 replies within 2 s'));
    expect(report, contains('Day,Check-ins,Average mood,Chats,Crisis responses'));
    expect(report, contains('2026-10-10,5,3.80,8,3'));
    expect(report, contains('2026-10-07,0,,0,0'));
  });

  testWidgets('overview shows reply time, system health and ages',
      (tester) async {
    final FakeAdmin admin = await openDashboard(tester);
    expect(
        find.descendant(
            of: find.byKey(const Key('tile-reply')),
            matching: find.text('1.2 s')),
        findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('card-health')), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const Key('overview')),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Chatbot (Rasa NLU server)'), findsOneWidget);
    expect(find.textContaining('230 ms'), findsOneWidget);

    admin.nluDown = true;
    await tester.tap(find.byKey(const Key('check-health')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not working: status 502'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('card-ages')), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const Key('overview')),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Not asked (joined before)'), findsOneWidget);
  });

  testWidgets('Copy report puts the report on the clipboard', (tester) async {
    await openDashboard(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('copy-report')));
    await tester.pumpAndSettle();
    expect(copied, contains('MindQuest report'));
    expect(find.textContaining('Report copied'), findsOneWidget);
  });
}
