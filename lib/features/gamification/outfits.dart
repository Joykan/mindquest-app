import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Something Chipu can wear. Each one unlocks at a level, as Chipu grows
/// with the student (the same levels as public.outfit_level in the
/// database). The pictures are layers drawn on the same frame as the mascot
/// (docs/design/mascot/make_outfits.py).
class Outfit {
  const Outfit({
    required this.id,
    required this.emoji,
    required this.en,
    required this.sw,
    required this.level,
    this.front = true,
    this.back = false,
  });

  final String id;
  final String emoji;
  final String en;
  final String sw;

  /// The level that unlocks it.
  final int level;

  /// Has a layer in front of Chipu / behind Chipu.
  final bool front;
  final bool back;

  String name(String language) => language == 'sw' ? sw : en;

  String? get frontAsset =>
      front ? 'assets/images/outfits/${id}_front.png' : null;
  String? get backAsset => back ? 'assets/images/outfits/${id}_back.png' : null;

  /// The front layer cropped like the chat avatar.
  String? get faceAsset =>
      front ? 'assets/images/outfits/${id}_face.png' : null;
}

const List<Outfit> outfits = <Outfit>[
  Outfit(id: 'daisy', emoji: '🌼', en: 'Daisy', sw: 'Ua dogo', level: 2),
  Outfit(
      id: 'glasses',
      emoji: '👓',
      en: 'Reading glasses',
      sw: 'Miwani ya kusoma',
      level: 3),
  Outfit(
      id: 'beads',
      emoji: '📿',
      en: 'Beaded headband',
      sw: 'Shanga za kichwani',
      level: 4),
  Outfit(
      id: 'medal',
      emoji: '🏅',
      en: 'Gold medal',
      sw: 'Medali ya dhahabu',
      level: 5),
  Outfit(
      id: 'cape',
      emoji: '🦸',
      en: 'Hero cape',
      sw: 'Joho la shujaa',
      level: 6,
      front: false,
      back: true),
];

Outfit? outfitById(String? id) {
  for (final Outfit o in outfits) {
    if (o.id == id) return o;
  }
  return null;
}

/// Outfits that unlock when going from level [from] to level [to].
List<Outfit> outfitsUnlocked(int from, int to) => <Outfit>[
      for (final Outfit o in outfits)
        if (o.level > from && o.level <= to) o
    ];

/// What Chipu is wearing for the signed-in user. Every Chipu in the app
/// (through [OutfitScope]) shows it.
class OutfitController extends ChangeNotifier {
  OutfitController({this.prefs, this.userId, this.save});

  /// Remembers the last level seen on this phone (null in tests).
  final SharedPreferences? prefs;
  final String? Function()? userId;

  /// Sends a new choice to the server (set by the router).
  Future<void> Function(String? outfit)? save;

  String? _id;

  /// The outfit's id, or null for none.
  String? get id => _id;

  /// Shows what the server (or the saved copy) says Chipu wears.
  void show(String? outfit) {
    final String? id = outfitById(outfit)?.id;
    if (id == _id) return;
    _id = id;
    notifyListeners();
  }

  /// Puts an outfit on (null: takes it off) and saves the choice.
  Future<void> wear(String? outfit) async {
    show(outfit);
    await save?.call(_id);
  }

  /// Outfits unlocked since the level last seen on this phone, so Home can
  /// celebrate them once. The first time, it only remembers the level.
  List<Outfit> newUnlocks(int level) {
    final SharedPreferences? p = prefs;
    final String? uid = userId?.call();
    if (p == null || uid == null) return const <Outfit>[];
    final String key = 'outfits.$uid.seenLevel';
    final int? seen = p.getInt(key);
    if (seen == null || level > seen) p.setInt(key, level);
    if (seen == null || level <= seen) return const <Outfit>[];
    return outfitsUnlocked(seen, level);
  }
}

/// Makes the current outfit available to every [Mascot] below it.
class OutfitScope extends InheritedNotifier<OutfitController> {
  const OutfitScope(
      {super.key, required OutfitController controller, required super.child})
      : super(notifier: controller);

  /// The outfit to show here, or null (also when there is no scope).
  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OutfitScope>()?.notifier?.id;
}
