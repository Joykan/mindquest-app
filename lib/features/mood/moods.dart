/// The five moods (mood_logs.mood is 1-5).
class MoodOption {
  const MoodOption(this.value, this.emoji, this.label);

  final int value;
  final String emoji;
  final String label;
}

const List<MoodOption> moodOptions = <MoodOption>[
  MoodOption(1, '😢', 'Very low'),
  MoodOption(2, '😕', 'Low'),
  MoodOption(3, '😐', 'Okay'),
  MoodOption(4, '🙂', 'Good'),
  MoodOption(5, '😄', 'Great'),
];

/// What Chipu says after a check-in, in the chat and after saving a mood.
String moodReply(int mood) => switch (mood) {
      5 => "That's wonderful! I'm so glad to hear it.",
      4 => "I'm glad to hear that!",
      3 => 'Thanks for checking in. Want to tell me more about your day?',
      _ => "I'm sorry it's a hard day. I'm here. Tell me what's going on, "
          'or try a breathing exercise with me.',
    };
