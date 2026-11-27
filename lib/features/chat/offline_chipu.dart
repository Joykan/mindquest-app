import 'dart:math';

import '../../core/l10n/tr.dart';
import 'chat_models.dart';

/// What Chipu can still do on the phone when there is no internet.
///
/// The chatbot's language model runs on a server, so free conversation needs
/// a connection. These few answers need none: Chipu says it is offline, and
/// still offers the breathing exercise, a mood check-in and encouragement.
/// Crisis messages are handled separately (crisis_phrases.dart).
enum OfflineMove { none, mood, breathing }

class OfflineAnswer {
  const OfflineAnswer(this.text, this.kind,
      [this.move = OfflineMove.none, this.known = true]);

  final String text;
  final ChatItemKind kind;
  final OfflineMove move;

  /// False for the general "you're offline" reply, true for a message Chipu
  /// can really answer on the phone.
  final bool known;
}

String _plain(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"['’`]"), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

final RegExp _moodCommand = RegExp(
    r'\b(log|record|track|check in)\b.*\bmood\b|\bmood (check in|log)\b|\b(rekodi|andika)\b.*\bhisia\b');
final RegExp _breathing = RegExp(
    r'\b(breath|breathe|breathing|calm me|calm down|pumua|kupumua|zoezi la kupumua)\b');
final RegExp _encourage = RegExp(
    r'\b(encourage me|motivate me|cheer me up|give me hope|nitie moyo|nipe moyo|nihamasishe)\b');
final RegExp _better = RegExp(
    r'\bfeel(ing)? (a bit |much |now )?better\b|\b(nimepona|najisikia vizuri zaidi)\b');

/// "Log my mood", "check in": opens the mood faces, online or offline.
bool isMoodCommand(String text) => _moodCommand.hasMatch(_plain(text));

const List<(String, String)> _encouragement = <(String, String)>[
  (
    'You showed up today, and that already takes effort. One small step is enough.',
    'Umekuja leo, na hilo tayari linahitaji juhudi. Hatua moja ndogo inatosha.'
  ),
  (
    "Hard days don't last, and you've gotten through hard days before.",
    'Siku ngumu hazidumu, na umewahi kupitia siku ngumu hapo awali.'
  ),
  (
    "You're doing better than you think. Be as kind to yourself as you would be to a friend.",
    'Unafanya vizuri kuliko unavyofikiri. Jifanyie wema kama ungemfanyia rafiki.'
  ),
];

/// Chipu's answer to [text] with no internet.
OfflineAnswer offlineAnswer(String text, String language, [Random? rng]) {
  final String t = _plain(text);
  final Random r = rng ?? Random();
  if (isMoodCommand(text)) {
    return OfflineAnswer(
        tr(language, 'Sure. How are you feeling right now?',
            'Sawa. Unajisikiaje sasa hivi?'),
        ChatItemKind.moodPicker,
        OfflineMove.mood);
  }
  if (_breathing.hasMatch(t)) {
    return OfflineAnswer(
        tr(
            language,
            "Let's breathe together. Tap Start breathing and follow the circle. This works without internet.",
            'Tupumue pamoja. Gusa Anza kupumua ufuate duara. Hili linafanya kazi bila intaneti.'),
        ChatItemKind.breathing,
        OfflineMove.breathing);
  }
  if (_encourage.hasMatch(t)) {
    final (String en, String sw) =
        _encouragement[r.nextInt(_encouragement.length)];
    return OfflineAnswer(tr(language, en, sw), ChatItemKind.text);
  }
  if (_better.hasMatch(t)) {
    return OfflineAnswer(
        tr(
            language,
            "I'm glad you're feeling a bit better. A quick mood check-in will save it, and it syncs when you're back online.",
            'Nafurahi unajisikia vizuri kidogo. Kurekodi hisia kwa haraka kutaihifadhi, na itatumwa ukipata mtandao.'),
        ChatItemKind.text);
  }
  return OfflineAnswer(
      tr(
          language,
          "You're offline, so I can't reply to that right now. I can still help you breathe or log your mood, and your check-ins will sync later.",
          'Huna mtandao, kwa hiyo siwezi kujibu hilo sasa hivi. Bado naweza kukusaidia kupumua au kurekodi hisia zako, na zitatumwa baadaye.'),
      ChatItemKind.text,
      OfflineMove.none,
      false);
}
