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

  /// The description in the given language. The database holds English only,
  /// so the Kiswahili ones live here.
  String describe(String language) =>
      language == 'sw' ? (badgeDescriptionSw[id] ?? description) : description;
}

const Map<String, String> badgeDescriptionSw = <String, String>{
  'first_checkin': 'Rekodi hisia zako kwa mara ya kwanza',
  'first_chat': 'Tuma ujumbe wako wa kwanza kwa MindQuest',
  'curious_mind': 'Soma makala 3',
  'streak_3': 'Dumisha mfululizo wa siku 3',
  'streak_7': 'Dumisha mfululizo wa siku 7',
  'streak_14': 'Dumisha mfululizo wa siku 14',
  'streak_30': 'Dumisha mfululizo wa siku 30',
  'mood_explorer': 'Rekodi hisia mara 20',
  'quest_master': 'Kamilisha changamoto 4 za wiki',
  'challenge_exam_calm': 'Kamilisha changamoto ya Utulivu wa mitihani',
  'challenge_good_things': 'Kamilisha changamoto ya Ona mazuri',
  'challenge_mindful': 'Kamilisha changamoto ya Nyakati za utulivu',
  'challenge_talk': 'Kamilisha changamoto ya Ongea nayo',
};

const Map<String, String> badgeEmoji = <String, String>{
  'first_checkin': '🌱',
  'first_chat': '💬',
  'curious_mind': '📚',
  'streak_3': '✨',
  'streak_7': '🔥',
  'streak_14': '⚡',
  'streak_30': '🌟',
  'mood_explorer': '🧭',
  'quest_master': '🏆',
  'challenge_exam_calm': '🧘',
  'challenge_good_things': '🌻',
  'challenge_mindful': '🍃',
  'challenge_talk': '🤝',
};

/// What each badge counts, and how many are needed.
enum BadgeMeasure {
  checkIns,
  chatMessages,
  articlesRead,
  streak,
  weeklyQuests,

  /// A challenge's own badge: earned by finishing it (progress 0 or 1).
  challenge,
}

const Map<String, (BadgeMeasure, int)> badgeGoals =
    <String, (BadgeMeasure, int)>{
  'first_checkin': (BadgeMeasure.checkIns, 1),
  'first_chat': (BadgeMeasure.chatMessages, 1),
  'curious_mind': (BadgeMeasure.articlesRead, 3),
  'streak_3': (BadgeMeasure.streak, 3),
  'streak_7': (BadgeMeasure.streak, 7),
  'streak_14': (BadgeMeasure.streak, 14),
  'streak_30': (BadgeMeasure.streak, 30),
  'mood_explorer': (BadgeMeasure.checkIns, 20),
  'quest_master': (BadgeMeasure.weeklyQuests, 4),
  'challenge_exam_calm': (BadgeMeasure.challenge, 1),
  'challenge_good_things': (BadgeMeasure.challenge, 1),
  'challenge_mindful': (BadgeMeasure.challenge, 1),
  'challenge_talk': (BadgeMeasure.challenge, 1),
};

/// XP rules, the same as the database triggers. Shown on Rewards.
/// (emoji, English, Kiswahili, XP)
const List<(String, String, String, int)> xpRules =
    <(String, String, String, int)>[
  ('😊', 'Daily mood check-in', 'Kurekodi hisia kila siku', 10),
  (
    '💬',
    'Each chat message (up to 20 XP a day)',
    'Kila ujumbe kwa Chipu (hadi XP 20 kwa siku)',
    2
  ),
  ('📖', 'Each article you read', 'Kila makala unayosoma', 5),
  (
    '🎯',
    'Weekly quest: check in on 5 days',
    'Changamoto ya wiki: rekodi hisia siku 5',
    25
  ),
  ('🏅', 'Finish a 7-day challenge', 'Kamilisha changamoto ya siku 7', 40),
];
