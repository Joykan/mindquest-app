import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../home/progress_repository.dart';
import 'moods.dart';

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// The last 7 days as a line of mood faces: higher = better mood, an empty
/// circle = no check-in that day. Uses each day's latest check-in.
/// [entries] are newest first, with times in Nairobi time (as
/// [ProgressRepository.loadMoodHistory] returns them).
class MoodWeekGraph extends StatelessWidget {
  const MoodWeekGraph(
      {super.key, required this.entries, this.now, this.height = 130});

  final List<MoodEntry> entries;

  /// Today in Nairobi time; defaults to now (tests pass a fixed date).
  final DateTime? now;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final DateTime n = now ?? nairobiNow();
    final DateTime today = DateTime(n.year, n.month, n.day);
    final Map<String, int> latest = <String, int>{};
    for (final MoodEntry e in entries) {
      latest.putIfAbsent(_dayKey(e.at), () => e.mood);
    }
    final List<DateTime> days = <DateTime>[
      for (int i = 6; i >= 0; i--) today.subtract(Duration(days: i))
    ];
    final List<int?> moods = <int?>[
      for (final DateTime d in days) latest[_dayKey(d)]
    ];

    final String lang = context.lang;
    final String summary = <String>[
      for (int i = 0; i < 7; i++)
        '${fullDay(lang, days[i].weekday)}: '
            '${moods[i] == null ? tr(lang, 'no check-in', 'hakuna rekodi') : moodOptions[moods[i]! - 1].name(lang)}',
    ].join(', ');

    return Semantics(
      label: tr(lang, 'Your moods this week. $summary',
          'Hisia zako wiki hii. $summary'),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            const double labelHeight = 18;
            const double face = 26;
            final double plotHeight = height - labelHeight - face;
            final double slot = box.maxWidth / 7;
            Offset point(int i, int mood) => Offset(
                slot * i + slot / 2, face / 2 + plotHeight * (5 - mood) / 4);
            final List<Offset?> points = <Offset?>[
              for (int i = 0; i < 7; i++)
                moods[i] == null ? null : point(i, moods[i]!),
            ];
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LinePainter(
                      points: points,
                      line: theme.colorScheme.primary.withValues(alpha: 0.45),
                      empty: mq.textMuted.withValues(alpha: 0.45),
                      emptyY: face / 2 + plotHeight / 2,
                      slot: slot,
                    ),
                  ),
                ),
                for (int i = 0; i < 7; i++)
                  if (points[i] != null)
                    Positioned(
                      left: points[i]!.dx - face / 2,
                      top: points[i]!.dy - face / 2,
                      width: face,
                      height: face,
                      child: Center(
                        child: Text(moodOptions[moods[i]! - 1].emoji,
                            style: const TextStyle(fontSize: 20, height: 1)),
                      ),
                    ),
                for (int i = 0; i < 7; i++)
                  Positioned(
                    left: slot * i,
                    width: slot,
                    bottom: 0,
                    height: labelHeight,
                    child: Text(
                      i == 6
                          ? tr(lang, 'Today', 'Leo')
                          : shortDay(lang, days[i].weekday),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            i == 6 ? theme.colorScheme.primary : mq.textMuted,
                        fontWeight: i == 6 ? FontWeight.w800 : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dotted line through the days that have a mood, and empty circles for
/// days without one.
class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.line,
    required this.empty,
    required this.emptyY,
    required this.slot,
  });

  final List<Offset?> points;
  final Color line;
  final Color empty;
  final double emptyY;
  final double slot;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dots = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final List<Offset> known = points.whereType<Offset>().toList();
    for (int i = 0; i + 1 < known.length; i++) {
      final Offset a = known[i];
      final Offset b = known[i + 1];
      final double length = (b - a).distance;
      for (double t = 0; t < length; t += 7) {
        canvas.drawCircle(Offset.lerp(a, b, t / length)!, 1.3, dots);
      }
    }
    final Paint ring = Paint()
      ..color = empty
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < points.length; i++) {
      if (points[i] == null) {
        canvas.drawCircle(Offset(slot * i + slot / 2, emptyY), 7, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.line != line || old.empty != empty;
}
