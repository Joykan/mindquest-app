# Making MindQuest more fun (after step 12)

Three additions to the gamification the proposal asks for (FR 3: "badges,
challenges and streaks"). They aim at a healthy daily habit of a few
minutes, not at keeping students in the app as long as possible.

## 1. Chipu grows with you (outfits)

Every level unlocks something Chipu can wear. The student picks one in
**Rewards → Chipu's wardrobe**, and Chipu wears it everywhere: on Home,
on Rewards, next to his chat messages and after a breathing exercise.

| Level | Title | Outfit |
|---|---|---|
| 1 | 🌰 Seed | Just Chipu |
| 2 | 🌱 Sprout | 🌼 Daisy |
| 3 | 🌿 Sapling | 👓 Reading glasses |
| 4 | 🌳 Young tree | 📿 Beaded headband (Kenyan beadwork colours) |
| 5 | 🌲 Mighty tree | 🏅 Gold medal |
| 6+ | 🏞️ Forest | 🦸 Hero cape |

When the student reaches a new level, Home shows **Level up!** once, with
Chipu already wearing the new outfit and a **Put it on** button.

- Pictures: `docs/design/mascot/make_outfits.py` draws each outfit as a
  see-through layer on the same 512 × 512 frame as the mascot, so it fits
  every pose (`outfits_preview.png` shows them all). The PNGs are in
  `assets/images/outfits/`.
- Database: `profiles.outfit`, changed only through `set_outfit()`, which
  refuses an outfit above the student's level.
- App: `lib/features/gamification/outfits.dart` (the list, the controller
  that every Chipu listens to, the level-up check), `Mascot` in
  `lib/core/widgets/mascot.dart`, `WardrobeCard` on Rewards. Chosen offline,
  the outfit is worn at once and saved when the phone is back online.

## 2. Kinder streaks (rest days)

Before, missing one day sent the streak back to 1. That is often the moment
people give up, and for a wellbeing app it felt like a punishment.

**Rule:** each week (Monday to Sunday) has one rest day. If a student misses
one day, the streak keeps going; the rest day doesn't count as a streak day.
Two missed days in a row, or a second missed day in the same week, start the
streak again. XP, levels and badges never go down.

- Home shows a line under the streak: "Rest day ready", "Rest day used this
  week", or, after a missed day, "Yesterday was your rest day. Check in today
  to keep your streak!". Tapping it explains the rule.
- New streak badges: ✨ 3 days, 🔥 7 days (existing), ⚡ 14 days and
  🌟 30 days.
- Database: `checkin_streak()` works the streak out from the check-in days;
  `on_mood_logged()` uses it. App: `lib/features/gamification/streaks.dart`
  has the same rule (so check-ins made offline count straight away).

The rule was checked on the database and in the app with the same cases
(Mon 12 – Sun 25 Oct 2026):

| Check-in days (Oct) | Streak | Why |
|---|---|---|
| 19, 20, 22 | 3 | 21 missed: that week's rest day |
| 19, 20, 22, 24 | 2 | 23 uses the rest day, 21 is a second miss that week |
| 16, 17, 19 | 3 | 18 (Sunday) uses the week before's rest day |
| 17, 20 | 1 | Two days missed in a row |
| 12–18 | 7 | A full week |
| 11, 13, 15 | 2 | 14 uses the rest day, 12 is a second miss that week |

## 3. Themed challenges

Short 7-day goals the student chooses (one at a time). Each gives +40 XP and
its own badge, can be repeated, and can be left at any time without losing
anything else. Home shows the running challenge with its progress; when none
is running, it suggests a different one each week.

| Challenge | Steps | Badge |
|---|---|---|
| 📝 Exam calm | Check in on 4 days · box breathing 3 times · read 1 article about stress | 🧘 Calm Mind |
| 🌻 Notice the good | Write one good thing in the check-in note on 4 days | 🌻 Bright Side |
| 🌿 Mindful moments | Box breathing 3 times · 5-4-3-2-1 grounding twice · read 1 article about mindfulness | 🍃 Here and Now |
| 💬 Talk it out | Chat with Chipu on 3 days · check in on 3 days · read 1 article about getting support | 🤝 Open Heart |

Everything counts from the start of the day the challenge was started
(Nairobi time) for 7 days. A "read" step also counts as done when the student
has already read every article on that topic, so a challenge can be repeated.
Tapping a step opens the place to do it.

- Database: `challenges` (the list; admins can change it), `challenge_runs`
  (who started what, when), `wellbeing_activities` (a finished breathing or
  grounding exercise: only the kind and the time). `start_challenge()`,
  `leave_challenge()` and `my_challenges()` are what the app calls; triggers
  on check-ins, chat messages, article reads and exercises call
  `evaluate_challenge()`, which finishes the challenge, gives the XP and the
  badge.
- App: `lib/features/challenges/`. The Support page reports finished
  exercises; made offline, they are kept on the phone and sent later.

## What was left out on purpose

No ranking of students against each other, no guilt-trip notifications, no
more than one reminder a day, no random reward boxes, and nothing designed to
maximise time in the app. MindQuest is for young people and for their
wellbeing (proposal, ethical considerations), so the aim is a few minutes a
day, regularly.

## Tests

- Database (live, in rolled-back transactions, 20 Oct 2026): the streak cases
  above; locked outfit refused, outfit worn at level 2; a second challenge
  refused while one runs; Mindful moments finished by 3 breathing, 2
  grounding and 1 article (+40 XP, badge, shown as recent); an exercise for
  someone else, an exercise from 9 days ago, a direct outfit change and a
  direct challenge insert refused; another user sees none of it; check-ins
  with one missed day give a 6-day streak and the 3-Day Streak badge.
- App: `test/fun_test.dart` (24 tests): the streak rule with the same cases
  as the database, rest-day flags, outfit levels and the level-up check,
  wearing an outfit in the wardrobe, the level-up dialog, the rest-day line
  (English and Kiswahili), reading `my_challenges()`, the weekly suggestion,
  the challenge card, starting, leaving and "already running", Kiswahili,
  and exercises reported once.
- System tests ST-54 to ST-61 in the workbook; UAT task T9 and T10 and
  statements L5, L11 and L12.

New Kiswahili texts (outfits, rest days, challenges) should be checked by a
fluent speaker before the student test, like the earlier ones.
