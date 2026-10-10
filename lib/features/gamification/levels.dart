/// Level rules, the same as public.level_for_xp in the database:
/// L1 0 XP, L2 50, L3 100, L4 200, L5 350, then every 200 XP.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  if (level == 2) return 50;
  if (level == 3) return 100;
  if (level == 4) return 200;
  return 350 + (level - 5) * 200;
}

int levelForXp(int xp) {
  if (xp < 50) return 1;
  if (xp < 100) return 2;
  if (xp < 200) return 3;
  if (xp < 350) return 4;
  return 5 + (xp - 350) ~/ 200;
}

/// Progress towards the next level, e.g. 160 XP -> 60 of 100 to Level 4.
class LevelProgress {
  LevelProgress(this.xp) : level = levelForXp(xp);

  final int xp;
  final int level;

  int get start => xpForLevel(level);
  int get next => xpForLevel(level + 1);
  int get earned => xp - start;
  int get needed => next - start;
  double get fraction => needed == 0 ? 0 : earned / needed;
}

/// Level names on Chipu's growth theme: a seed grows into a forest.
class LevelTitle {
  const LevelTitle(this.emoji, this.en, this.sw);

  final String emoji;
  final String en;
  final String sw;

  String name(String language) => language == 'sw' ? sw : en;
}

LevelTitle levelTitle(int level) => switch (level) {
      <= 1 => const LevelTitle('🌰', 'Seed', 'Mbegu'),
      2 => const LevelTitle('🌱', 'Sprout', 'Chipukizi'),
      3 => const LevelTitle('🌿', 'Sapling', 'Mche'),
      4 => const LevelTitle('🌳', 'Young tree', 'Mti mchanga'),
      5 => const LevelTitle('🌲', 'Mighty tree', 'Mti imara'),
      _ => const LevelTitle('🏞️', 'Forest', 'Msitu'),
    };
