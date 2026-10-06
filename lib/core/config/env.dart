/// Build-time configuration.
///
/// Values come from `--dart-define-from-file=config/dev.json` so that keys
/// are never committed to the repository (see config/dev.json.example).
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both Supabase values were supplied at build time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
