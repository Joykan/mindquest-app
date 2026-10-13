import '../../core/l10n/tr.dart';

/// Turns a sign-in error into a short message in the user's language.
/// Supabase sends its errors in English, so the common ones are mapped here.
String accountError(String message, String language) {
  final String m = message.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return tr(language, 'That email or password is not right.',
        'Barua pepe au nenosiri si sahihi.');
  }
  if (m.contains('email not confirmed')) {
    return tr(language,
        'Please confirm your email first. Open the link we sent you.',
        'Tafadhali thibitisha barua pepe yako kwanza. Fungua kiungo tulichokutumia.');
  }
  if (m.contains('already') && m.contains('registered')) {
    return tr(language, 'This email already has a MindQuest account. Sign in instead.',
        'Barua pepe hii tayari ina akaunti ya MindQuest. Ingia badala yake.');
  }
  if (m.contains('rate') || m.contains('seconds')) {
    return tr(language, 'Too many tries. Please wait a few minutes and try again.',
        'Umejaribu mara nyingi sana. Tafadhali subiri dakika chache kisha ujaribu tena.');
  }
  if (m.contains('google sign-in')) {
    return tr(language, "Couldn't open Google sign-in.",
        'Imeshindikana kufungua Google.');
  }
  if (m.contains('check your connection')) {
    return tr(language, 'Something went wrong. Check your connection and try again.',
        'Kuna tatizo. Angalia mtandao wako kisha ujaribu tena.');
  }
  return message;
}
