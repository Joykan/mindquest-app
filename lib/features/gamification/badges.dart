/// A badge from public.badges (named RewardBadge because Flutter has a Badge widget).
/// The rules that award badges live in the database (public.evaluate_badges);
/// [badgeGoals] only mirrors them to show progress.
class RewardBadge {
  const RewardBadge({
    required this.id,
    required this.name,
    required this.nameSw,
    required this.description,
  });

  factory RewardBadge.fromJson(Map<String, dynamic> json) => RewardBadge(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        nameSw: json['name_sw'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  final String id;
  final String name;
  final String nameSw;
  final String description;

  String displayName(String language) =>
      language == 'sw' && nameSw.isNotEmpty ? nameSw : name;

  String get emoji => badgeEmoji[id] ?? '🏅';
}

const Map<String, String> badgeEmoji = <String, String>{
  'first_checkin': '🌱',
  'first_chat': '💬',
  'curious_mind': '📚',
  'streak_7': '🔥',
  'mood_explorer': '🧭',
  'quest_master': '🏆',
};

/// What each badge counts, and how many are needed.
enum BadgeMeasure { checkIns, chatMessages, articlesRead, streak, weeklyQuests }

const Map<String, (BadgeMeasure, int)> badgeGoals = <String, (BadgeMeasure, int)>{
  'first_checkin': (BadgeMeasure.checkIns, 1),
  'first_chat': (BadgeMeasure.chatMessages, 1),
  'curious_mind': (BadgeMeasure.articlesRead, 3),
  'streak_7': (BadgeMeasure.streak, 7),
  'mood_explorer': (BadgeMeasure.checkIns, 20),
  'quest_master': (BadgeMeasure.weeklyQuests, 4),
};

/// XP rules, the same as the database triggers. Shown on Rewards.
const List<(String, String, int)> xpRules = <(String, String, int)>[
  ('😊', 'Daily mood check-in', 10),
  ('💬', 'Each chat message (up to 20 XP a day)', 2),
  ('📖', 'Each article you read', 5),
  ('🎯', 'Weekly quest: check in on 5 days', 25),
];
