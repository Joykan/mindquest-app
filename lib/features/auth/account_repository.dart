import 'package:supabase_flutter/supabase_flutter.dart';

/// The parts of the profile the app needs to decide where to go.
class Profile {
  const Profile({required this.username, required this.language, required this.onboarded});

  final String username;
  final String language;
  final bool onboarded;
}

/// Thrown with a message that can be shown to the user as it is.
class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signing in and out, and the user's profile. Screens only use this
/// interface, so tests can swap in a fake.
abstract class AccountRepository {
  /// Null when nobody is signed in.
  String? get userId;

  /// True for "Continue anonymously" accounts (no email).
  bool get isAnonymous;

  /// Fires whenever someone signs in or out.
  Stream<void> get changes;

  Future<void> signInAnonymously();
  Future<void> signIn({required String email, required String password});

  /// Returns true if the user is signed in straight away, false if they must
  /// confirm their email first.
  Future<bool> signUp({required String email, required String password});

  Future<void> signOut();
  Future<Profile?> loadProfile();
  Future<void> completeOnboarding({required String username, required String language});

  /// Changes the language the chatbot replies in ('en' or 'sw').
  Future<void> updateLanguage(String language);
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  @override
  Stream<void> get changes => _client.auth.onAuthStateChange.map((AuthState _) {});

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AccountException(e.message);
    } catch (_) {
      throw const AccountException('Something went wrong. Check your connection and try again.');
    }
  }

  @override
  Future<void> signInAnonymously() => _guard(() => _client.auth.signInAnonymously());

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _client.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<bool> signUp({required String email, required String password}) => _guard(() async {
        final AuthResponse res = await _client.auth.signUp(email: email.trim(), password: password);
        return res.session != null;
      });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<Profile?> loadProfile() => _guard(() async {
        final String? id = userId;
        if (id == null) return null;
        final Map<String, dynamic>? row = await _client
            .from('profiles')
            .select('username, language, consent_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return Profile(
          username: row['username'] as String? ?? 'Friend',
          language: row['language'] as String? ?? 'en',
          onboarded: row['consent_at'] != null,
        );
      });

  @override
  Future<void> completeOnboarding({required String username, required String language}) => _guard(
        () => _client.rpc<void>(
          'complete_onboarding',
          params: <String, dynamic>{'p_username': username, 'p_language': language},
        ),
      );

  @override
  Future<void> updateLanguage(String language) => _guard(() async {
        final String? id = userId;
        if (id == null) return;
        await _client.from('profiles').update(<String, dynamic>{'language': language}).eq('id', id);
      });
}
