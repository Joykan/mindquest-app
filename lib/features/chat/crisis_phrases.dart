import 'chat_models.dart';

/// Crisis check on the phone, used when Chipu can't be reached (no internet).
///
/// The chat Edge Function checks every message for these phrases before the
/// NLU model (supabase/functions/chat/crisis.ts). Offline, the same check runs
/// here so the helplines still appear; calling works without data. The two
/// lists must stay the same (a test compares them).
const List<String> crisisPhrases = <String>[
  // English
  'suicide',
  'suicidal',
  'kill myself',
  'killing myself',
  'end my life',
  'ending my life',
  'take my own life',
  'want to die',
  'wanna die',
  'wish i was dead',
  'wish i were dead',
  'better off dead',
  'dont want to live',
  'do not want to live',
  'dont want to be alive',
  'no reason to live',
  'end it all',
  'hurt myself',
  'harm myself',
  'self harm',
  'cut myself',
  // Kiswahili and Sheng
  'kujiua',
  'nijiue',
  'nitajiua',
  'nataka kufa',
  'natamani kufa',
  'sitaki kuishi',
  'nimechoka kuishi',
  'kujitoa uhai',
  'nijitoe uhai',
  'kujidhuru',
  'nijidhuru',
  'nitajidhuru',
  'kujikata',
  'kujimaliza',
  'nijimalize',
  'nataka kujimaliza',
  // Added by the Kiswahili reviewer (12 Oct 2026)
  'nimefika kikomo',
  'nitajitia kitanzi',
  'ntajitia kitanzi',
  'kujitia kitanzi',
  'maisha yamenichosha',
];

/// Lower-case, drop apostrophes, turn other punctuation into spaces
/// (the same as normalize() in crisis.ts).
String normalizeForCrisis(String text) {
  final String t = text
      .toLowerCase()
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  return ' $t ';
}

final List<String> _normalized = crisisPhrases.map(normalizeForCrisis).toList();

/// True if [text] contains a crisis phrase as whole words.
bool isCrisisText(String text) {
  final String t = normalizeForCrisis(text);
  return _normalized.any(t.contains);
}

/// The reply shown when a crisis message is detected offline.
ChatReply offlineCrisisReply(String language, List<Helpline> helplines) =>
    ChatReply(
      crisis: true,
      helplines: helplines,
      reply: language == 'sw'
          ? 'Inaonekana unakumbwa na jambo linaloumiza sana. Nashukuru kwa '
              'kunielezea. Huhitaji kukabiliana nalo peke yako. Tafadhali '
              'wasiliana na mtu sasa hivi:'
          : "It sounds like you're going through something really painful, and "
              "I'm glad you told me. You don't have to face this alone. Please "
              'reach out to someone right now:',
    );
