import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in staff member.
class StaffProfile {
  const StaffProfile({required this.username, required this.role});

  final String username;

  /// 'admin', 'counsellor' or 'user'.
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'admin' || role == 'counsellor';
}

/// One day on the Overview charts.
class DailyStat {
  const DailyStat({
    required this.day,
    required this.checkIns,
    required this.chats,
    required this.crisisEvents,
    this.averageMood,
  });

  final DateTime day;
  final int checkIns;
  final double? averageMood;
  final int chats;
  final int crisisEvents;
}

/// A mood tag (school, sleep...) with how often it was used.
class TagStat {
  const TagStat(
      {required this.tag, required this.checkIns, this.averageMood});

  final String tag;
  final int checkIns;
  final double? averageMood;
}

/// How often an article was read.
class ArticleReads {
  const ArticleReads(
      {required this.id,
      required this.title,
      required this.reads,
      required this.recent});

  final int id;
  final String title;

  /// All time.
  final int reads;

  /// In the selected period.
  final int recent;
}

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _double(dynamic v) => (v as num?)?.toDouble();
Map<String, int> _counts(dynamic v) => <String, int>{
      for (final MapEntry<String, dynamic> e
          in (v as Map<String, dynamic>? ?? <String, dynamic>{}).entries)
        e.key: _int(e.value),
    };

/// Everything on the Overview page (from public.admin_stats). Totals only:
/// no messages, notes or individual check-ins.
class AdminStats {
  const AdminStats({
    required this.days,
    required this.from,
    required this.to,
    this.users = 0,
    this.newUsers = 0,
    this.savedAccounts = 0,
    this.activeUsers = 0,
    this.chatSessions = 0,
    this.messages = 0,
    this.moodEntries = 0,
    this.averageMood,
    this.articlesRead = 0,
    this.badgesAwarded = 0,
    this.crisisEvents = 0,
    this.notUnderstood = 0,
    this.unavailable = 0,
    this.daily = const <DailyStat>[],
    this.moodSplit = const <int, int>{},
    this.tags = const <TagStat>[],
    this.topics = const <String, int>{},
    this.languages = const <String, int>{},
    this.articles = const <ArticleReads>[],
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        days: _int(j['days']),
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        users: _int(j['users']),
        newUsers: _int(j['new_users']),
        savedAccounts: _int(j['saved_accounts']),
        activeUsers: _int(j['active_users']),
        chatSessions: _int(j['chat_sessions']),
        messages: _int(j['messages']),
        moodEntries: _int(j['mood_entries']),
        averageMood: _double(j['average_mood']),
        articlesRead: _int(j['articles_read']),
        badgesAwarded: _int(j['badges_awarded']),
        crisisEvents: _int(j['crisis_events']),
        notUnderstood: _int(j['not_understood']),
        unavailable: _int(j['unavailable']),
        daily: <DailyStat>[
          for (final dynamic d in j['daily'] as List<dynamic>? ?? <dynamic>[])
            DailyStat(
              day: DateTime.parse((d as Map<String, dynamic>)['day'] as String),
              checkIns: _int(d['check_ins']),
              averageMood: _double(d['average_mood']),
              chats: _int(d['chats']),
              crisisEvents: _int(d['crisis_events']),
            ),
        ],
        moodSplit: <int, int>{
          for (final MapEntry<String, int> e in _counts(j['mood_split']).entries)
            int.parse(e.key): e.value,
        },
        tags: <TagStat>[
          for (final dynamic t in j['mood_tags'] as List<dynamic>? ?? <dynamic>[])
            TagStat(
              tag: (t as Map<String, dynamic>)['tag'] as String,
              checkIns: _int(t['check_ins']),
              averageMood: _double(t['average_mood']),
            ),
        ],
        topics: _counts(j['topics']),
        languages: _counts(j['language_split']),
        articles: <ArticleReads>[
          for (final dynamic a
              in j['article_reads'] as List<dynamic>? ?? <dynamic>[])
            ArticleReads(
              id: _int((a as Map<String, dynamic>)['id']),
              title: a['title'] as String? ?? '',
              reads: _int(a['reads']),
              recent: _int(a['recent']),
            ),
        ],
      );

  final int days;
  final DateTime from;
  final DateTime to;
  final int users;
  final int newUsers;
  final int savedAccounts;
  final int activeUsers;
  final int chatSessions;
  final int messages;
  final int moodEntries;
  final double? averageMood;
  final int articlesRead;
  final int badgesAwarded;
  final int crisisEvents;
  final int notUnderstood;
  final int unavailable;
  final List<DailyStat> daily;

  /// Check-ins per mood, 1 (very low) to 5 (very good).
  final Map<int, int> moodSplit;
  final List<TagStat> tags;

  /// Intents of students' chat messages, e.g. feel_stressed: 5.
  final Map<String, int> topics;

  /// Students per app language (en, sw).
  final Map<String, int> languages;
  final List<ArticleReads> articles;

  /// Share of messages Chipu understood (crisis messages are not counted:
  /// they are answered with the helplines before the NLU model).
  double? get understoodShare {
    final int asked = messages - (topics['crisis'] ?? 0);
    if (asked <= 0) return null;
    return ((asked - notUnderstood) / asked).clamp(0, 1).toDouble();
  }
}

/// An article as the admin sees it (published or not).
class AdminArticle {
  const AdminArticle({
    this.id,
    required this.category,
    required this.titleEn,
    required this.titleSw,
    required this.bodyEn,
    required this.bodySw,
    this.minutes = 2,
    this.published = false,
    this.updatedAt,
  });

  factory AdminArticle.fromJson(Map<String, dynamic> j) => AdminArticle(
        id: _int(j['id']),
        category: j['category'] as String,
        titleEn: j['title_en'] as String? ?? '',
        titleSw: j['title_sw'] as String? ?? '',
        bodyEn: j['body_en'] as String? ?? '',
        bodySw: j['body_sw'] as String? ?? '',
        minutes: _int(j['read_minutes']),
        published: j['published'] == true,
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
      );

  /// Null for a new article.
  final int? id;
  final String category;
  final String titleEn;
  final String titleSw;
  final String bodyEn;
  final String bodySw;
  final int minutes;
  final bool published;
  final DateTime? updatedAt;

  Map<String, dynamic> toRow() => <String, dynamic>{
        'category': category,
        'title_en': titleEn.trim(),
        'title_sw': titleSw.trim(),
        'body_en': bodyEn.trim(),
        'body_sw': bodySw.trim(),
        'read_minutes': minutes,
        'published': published,
      };
}

/// A crisis helpline. Students only see verified ones.
class AdminHelpline {
  const AdminHelpline({
    this.id,
    required this.name,
    required this.phone,
    this.description,
    this.descriptionSw,
    this.verified = false,
    this.sortOrder = 0,
  });

  factory AdminHelpline.fromJson(Map<String, dynamic> j) => AdminHelpline(
        id: _int(j['id']),
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        description: j['description'] as String?,
        descriptionSw: j['description_sw'] as String?,
        verified: j['verified'] == true,
        sortOrder: _int(j['sort_order']),
      );

  final int? id;
  final String name;
  final String phone;
  final String? description;
  final String? descriptionSw;
  final bool verified;
  final int sortOrder;

  Map<String, dynamic> toRow() {
    String? clean(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    return <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'description': clean(description),
      'description_sw': clean(descriptionSw),
      'verified': verified,
      'sort_order': sortOrder,
    };
  }
}

/// An admin or counsellor.
class StaffMember {
  const StaffMember(
      {required this.id,
      required this.username,
      required this.email,
      required this.role});

  final String id;
  final String username;
  final String email;
  final String role;
}

/// Thrown with a message that can be shown to the admin as it is.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the dashboard reads and changes. Pages only use this
/// interface, so tests can use a fake.
abstract class AdminRepository {
  /// Fires when someone signs in or out.
  Stream<void> get changes;

  bool get signedIn;
  String? get email;

  Future<void> signIn({required String email, required String password});
  Future<void> signInWithGoogle();
  Future<void> signOut();

  /// The signed-in person's name and role, or null if there is no profile.
  Future<StaffProfile?> me();

  Future<AdminStats> stats(int days);

  Future<List<AdminArticle>> articles();
  Future<void> saveArticle(AdminArticle article);
  Future<void> setPublished(int id, bool published);
  Future<void> deleteArticle(int id);

  Future<List<AdminHelpline>> helplines();
  Future<void> saveHelpline(AdminHelpline helpline);
  Future<void> setVerified(int id, bool verified);
  Future<void> deleteHelpline(int id);

  Future<List<StaffMember>> staff();

  /// Gives (or with role 'user' removes) access. Returns their nickname.
  Future<String> setRole(String email, String role);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Turns database and login errors into sentences for the admin.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AdminException(
            "Your account isn't allowed to do that. Ask an administrator.");
      }
      if (e.code == 'P0002' || e.code == '22023') {
        throw AdminException(e.message);
      }
      throw AdminException('The database said: ${e.message}');
    } on AuthException catch (e) {
      throw AdminException(e.message);
    } on AdminException {
      rethrow;
    } catch (_) {
      throw const AdminException(
          'Something went wrong. Check your connection and try again.');
    }
  }

  @override
  Stream<void> get changes =>
      _client.auth.onAuthStateChange.map((AuthState _) {});

  @override
  bool get signedIn => _client.auth.currentUser != null;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _client.auth
          .signInWithPassword(email: email.trim(), password: password));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        // On the web, Google sends the admin back to this same page.
        await _client.auth.signInWithOAuth(OAuthProvider.google,
            redirectTo: kIsWeb ? Uri.base.origin : null);
      });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<StaffProfile?> me() => _guard(() async {
        final String? id = _client.auth.currentUser?.id;
        if (id == null) return null;
        final Map<String, dynamic>? row = await _client
            .from('profiles')
            .select('username, role')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return StaffProfile(
            username: row['username'] as String? ?? 'Friend',
            role: row['role'] as String? ?? 'user');
      });

  @override
  Future<AdminStats> stats(int days) => _guard(() async {
        final dynamic data = await _client
            .rpc<dynamic>('admin_stats', params: <String, dynamic>{'p_days': days});
        return AdminStats.fromJson(Map<String, dynamic>.from(data as Map));
      });

  @override
  Future<List<AdminArticle>> articles() => _guard(() async {
        final List<dynamic> rows = await _client
            .from('resources')
            .select(
                'id, category, title_en, title_sw, body_en, body_sw, read_minutes, published, updated_at')
            .order('id', ascending: true);
        return <AdminArticle>[
          for (final dynamic r in rows)
            AdminArticle.fromJson(r as Map<String, dynamic>),
        ];
      });

  @override
  Future<void> saveArticle(AdminArticle article) => _guard(() async {
        final int? id = article.id;
        if (id == null) {
          await _client.from('resources').insert(article.toRow());
        } else {
          await _client.from('resources').update(article.toRow()).eq('id', id);
        }
      });

  @override
  Future<void> setPublished(int id, bool published) => _guard(() => _client
      .from('resources')
      .update(<String, dynamic>{'published': published}).eq('id', id));

  @override
  Future<void> deleteArticle(int id) =>
      _guard(() => _client.from('resources').delete().eq('id', id));

  @override
  Future<List<AdminHelpline>> helplines() => _guard(() async {
        final List<dynamic> rows = await _client
            .from('helplines')
            .select(
                'id, name, phone, description, description_sw, verified, sort_order')
            .order('sort_order', ascending: true)
            .order('id', ascending: true);
        return <AdminHelpline>[
          for (final dynamic r in rows)
            AdminHelpline.fromJson(r as Map<String, dynamic>),
        ];
      });

  @override
  Future<void> saveHelpline(AdminHelpline helpline) => _guard(() async {
        final int? id = helpline.id;
        if (id == null) {
          await _client.from('helplines').insert(helpline.toRow());
        } else {
          await _client.from('helplines').update(helpline.toRow()).eq('id', id);
        }
      });

  @override
  Future<void> setVerified(int id, bool verified) => _guard(() => _client
      .from('helplines')
      .update(<String, dynamic>{'verified': verified}).eq('id', id));

  @override
  Future<void> deleteHelpline(int id) =>
      _guard(() => _client.from('helplines').delete().eq('id', id));

  @override
  Future<List<StaffMember>> staff() => _guard(() async {
        final dynamic rows = await _client.rpc<dynamic>('admin_staff');
        return <StaffMember>[
          for (final dynamic r in rows as List<dynamic>)
            StaffMember(
              id: (r as Map<String, dynamic>)['id'] as String,
              username: r['username'] as String? ?? '',
              email: r['email'] as String? ?? '',
              role: r['role'] as String? ?? 'user',
            ),
        ];
      });

  @override
  Future<String> setRole(String email, String role) => _guard(() async {
        final dynamic name = await _client.rpc<dynamic>('admin_set_role',
            params: <String, dynamic>{'p_email': email.trim(), 'p_role': role});
        return name as String? ?? email;
      });
}
