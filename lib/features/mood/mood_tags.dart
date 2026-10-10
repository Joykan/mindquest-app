/// Optional topics for a mood check-in (public.mood_logs.tags).
/// The ids must match the mood_logs_tags_known check in the database.
class MoodTag {
  const MoodTag(this.id, this.emoji, this.en, this.sw);

  final String id;
  final String emoji;
  final String en;
  final String sw;

  String label(String language) => language == 'sw' ? sw : en;
}

const List<MoodTag> moodTags = <MoodTag>[
  MoodTag('school', '📚', 'School', 'Shule'),
  MoodTag('family', '🏠', 'Family', 'Familia'),
  MoodTag('friends', '🤝', 'Friends', 'Marafiki'),
  MoodTag('relationships', '💞', 'Relationships', 'Mahusiano'),
  MoodTag('sleep', '😴', 'Sleep', 'Usingizi'),
  MoodTag('health', '🩺', 'Health', 'Afya'),
  MoodTag('work', '💼', 'Work', 'Kazi'),
  MoodTag('money', '💰', 'Money', 'Pesa'),
];

MoodTag? moodTagById(String id) {
  for (final MoodTag t in moodTags) {
    if (t.id == id) return t;
  }
  return null;
}
