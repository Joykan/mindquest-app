import '../../core/l10n/tr.dart';

/// The five moods (mood_logs.mood is 1-5).
class MoodOption {
  const MoodOption(this.value, this.emoji, this.label, this.labelSw);

  final int value;
  final String emoji;

  /// English name.
  final String label;

  /// Kiswahili name.
  final String labelSw;

  /// The name in the given language ('en' or 'sw').
  String name(String language) => language == 'sw' ? labelSw : label;
}

const List<MoodOption> moodOptions = <MoodOption>[
  MoodOption(1, '😢', 'Very low', 'Vibaya sana'),
  MoodOption(2, '😕', 'Low', 'Vibaya'),
  MoodOption(3, '😐', 'Okay', 'Kawaida'),
  MoodOption(4, '🙂', 'Good', 'Vizuri'),
  MoodOption(5, '😄', 'Great', 'Vizuri sana'),
];

/// What Chipu says after a check-in, in the chat and after saving a mood.
String moodReply(int mood, [String language = 'en']) => switch (mood) {
      5 => tr(language, "That's wonderful! I'm so glad to hear it.",
          'Hiyo ni habari njema sana! Nafurahi kusikia hivyo.'),
      4 => tr(language, "I'm glad to hear that!", 'Nafurahi kusikia hivyo!'),
      3 => tr(
          language,
          'Thanks for checking in. Want to tell me more about your day?',
          'Asante kwa kurekodi hisia zako. Ungependa kuniambia zaidi kuhusu siku yako?'),
      _ => tr(
          language,
          "I'm sorry it's a hard day. I'm here. Tell me what's going on, "
              'or try a breathing exercise with me.',
          'Pole kwa siku ngumu. Niko hapa. Niambie kinachoendelea, '
              'au tujaribu zoezi la kupumua pamoja.'),
    };
