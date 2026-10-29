import 'dart:math';

/// Kinder streaks. The rule is the same as public.checkin_streak in the
/// database:
///
/// - The streak counts the days with a check-in, back from the latest one.
/// - Missing one day doesn't end it, if that week's rest day is still free.
///   There is one rest day per week (Monday to Sunday). A rest day is not a
///   streak day.
/// - Two missed days in a row, or a second missed day in the same week, end
///   the streak.
///
/// Days are UTC midnights standing for Nairobi calendar days.

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _back(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day - n);

/// Monday of [day]'s week.
DateTime weekStartOf(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day - (day.weekday - 1));

/// The check-in days of one streak, and the weeks whose rest day it used.
class StreakRun {
  const StreakRun(this.days, this.restWeeks);

  /// Newest first.
  final List<DateTime> days;
  final Set<DateTime> restWeeks;

  int get length => days.length;
}

/// The streak ending on [last] (which must be a check-in day). [usedRest]
/// are weeks whose rest day is already taken by a newer missed day.
StreakRun streakRun(Set<DateTime> checkins, DateTime last,
    {Set<DateTime> usedRest = const <DateTime>{}}) {
  final List<DateTime> run = <DateTime>[_day(last)];
  final Set<DateTime> rest = <DateTime>{...usedRest};
  DateTime cur = _day(last);
  while (true) {
    final DateTime prev = _back(cur, 1);
    if (checkins.contains(prev)) {
      cur = prev;
    } else {
      final DateTime week = weekStartOf(prev);
      final DateTime before = _back(cur, 2);
      if (!checkins.contains(before) || rest.contains(week)) break;
      rest.add(week);
      cur = before;
    }
    run.add(cur);
  }
  return StreakRun(run, rest);
}

/// What Home and Rewards show about the streak.
class StreakStatus {
  const StreakStatus(
      {this.days = 0, this.restUsedThisWeek = false, this.restYesterday = false});

  /// Days in the streak (0: no streak).
  final int days;

  /// This week's rest day has already kept the streak going.
  final bool restUsedThisWeek;

  /// Yesterday had no check-in and the rest day kept the streak. Without a
  /// check-in today it ends.
  final bool restYesterday;
}

/// The streak as it stands [today].
///
/// [checkins] are the known check-in days (the last few months from the
/// server, plus check-ins still waiting to sync). [savedStreak] and
/// [lastCheckin] come from the profile: they cover streaks longer than the
/// days loaded, and are used alone when no days could be loaded.
StreakStatus streakStatus({
  required DateTime today,
  Set<DateTime> checkins = const <DateTime>{},
  int savedStreak = 0,
  DateTime? lastCheckin,
}) {
  final Set<DateTime> days = <DateTime>{
    for (final DateTime d in checkins) _day(d)
  };
  final DateTime? last = lastCheckin == null ? null : _day(lastCheckin);
  if (last != null && savedStreak > 0) {
    if (days.isEmpty) {
      // Only the profile is known: the streak's days were in a row.
      for (int i = 0; i < savedStreak; i++) {
        days.add(_back(last, i));
      }
    } else {
      days.add(last);
    }
  }

  final DateTime t = _day(today);
  final DateTime yesterday = _back(t, 1);
  StreakRun? run;
  bool restYesterday = false;
  if (days.contains(t)) {
    run = streakRun(days, t);
  } else if (days.contains(yesterday)) {
    run = streakRun(days, yesterday);
  } else if (days.contains(_back(t, 2))) {
    // Yesterday was missed: its week's rest day keeps the streak (the
    // newest missed day always gets it, as in the database).
    run = streakRun(days, _back(t, 2),
        usedRest: <DateTime>{weekStartOf(yesterday)});
    restYesterday = true;
  }
  if (run == null) return const StreakStatus();

  int n = run.length;
  // A streak longer than the days loaded: the profile knows its length up
  // to the last check-in it saw.
  if (last != null && savedStreak > 0 && run.days.contains(last)) {
    final int newer = run.days.where((DateTime d) => d.isAfter(last)).length;
    n = max(n, savedStreak + newer);
  }

  final DateTime thisWeek = weekStartOf(t);
  return StreakStatus(
    days: n,
    restUsedThisWeek: run.restWeeks.contains(thisWeek),
    restYesterday: restYesterday,
  );
}
