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
