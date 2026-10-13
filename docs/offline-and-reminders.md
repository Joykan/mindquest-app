# Offline mode and daily reminders (implementation step 10)

## Offline mode

Many students have patchy data or run out of bundles, so MindQuest keeps
working without internet for everything that doesn't need Chipu.

| Feature | Without internet |
|---|---|
| Open the app | Works. The profile saved on the phone is used (after the first sign-in online). |
| Home, mood history, insights, rewards, past chats | Shows the last data loaded, with a banner: "You're offline. Showing what was saved at 14:05." |
| Learn and articles | Articles opened online before can be read. "I've read this" is saved and sent later. |
| Mood check-in | Saved on the phone and sent when the internet is back. It counts for the day it was made (XP, streak, weekly quest). |
| Support (helplines, breathing, grounding) | Works. Calling a helpline doesn't need data. |
| Chat with Chipu | Needs the internet. The app says so. **Crisis messages still open the helplines**: the same crisis phrases as the server are checked on the phone. |

### How it works

- `lib/core/offline/offline_store.dart`
  - Every request the app makes goes through `OfflineStore.load`. If the
    server answers, the result is saved on the phone (shared_preferences),
    under the user's id. If the server can't be reached (no internet, or no
    answer within 15 seconds), the saved copy is returned instead.
  - Check-ins and article reads are put in a queue first and then sent,
    oldest first. Without internet they stay in the queue. The queue is sent
    when the app opens or comes back to the front, every 30 seconds, before
    each load, and from the banner's Retry.
  - When something reaches the server, Home, Learn and Rewards reload to
    show the real XP, streak and badges.
- Each check-in gets its id on the phone (a UUID). If the connection drops
  after the server saved it, the app sends it again and the database
  rejects the copy (duplicate id), so it is never counted twice.
- Signing out removes the saved data from the phone. If something is still
  waiting to sync, the app warns first.
- `lib/features/chat/crisis_phrases.dart` is the phone's copy of
  `supabase/functions/chat/crisis.ts`. A test fails if the two lists differ.

### Database change

Migration `20261013144450_offline_checkins.sql`:

- `mood_logs.logged_at` is when the check-in was made (the phone sends it);
  `created_at` is when it reached the server. The schema already allowed
  `logged_at` up to 7 days in the past for this reason.
- The check-in trigger now uses `logged_at` for the daily +10 XP, the streak
  and the weekly quest. The streak is counted from the check-in days, so a
  late check-in fills its day even if a newer one arrived first.
- Users may send the check-in `id`.

Tested on the live database in rolled-back transactions:

| Case | Result |
|---|---|
| Check-in today, then Sunday's and Monday's arrive late | Streak 1, then 1, then 3. XP 30. |
| Second check-in the same day | No extra XP |
| Same id sent twice | Rejected as a duplicate (23505) |
| Check-in 8 days old | Rejected (23514), dropped from the queue |
| 5 days (Wed-Sun) arrive late, newest first | Streak 5, weekly quest for that week, 75 XP |

**Trade-off:** because the phone says when a check-in was made, someone
could change the phone's clock to fill a missed day (up to 7 days back).
For a wellbeing app this is an acceptable risk; the alternative would be
losing real check-ins made offline.

## Daily reminder

- Off until the user turns it on. Home asks once ("Want a daily
  reminder?"), and Profile has the switch and the time (7 PM by default).
- Only on days without a check-in: after a check-in, today's reminder is
  cancelled.
- The next 14 days are scheduled each time the app opens, so reminders stop
  by themselves if the app isn't used for two weeks.
- Seven gentle messages (one per weekday), in English or Kiswahili. On a
  locked phone only "MindQuest" shows, not the message.
- Tapping the reminder opens the mood check-in.
- Profile has "Send a test reminder", to see it straight away (useful for
  the demo).
- Android 13 and newer asks for permission to show notifications. If it is
  refused, the app explains how to turn notifications on.
- Built with `flutter_local_notifications` and `timezone` (Nairobi time,
  the same day boundary as the database). Android only; not shown on the web.

Code: `lib/features/reminders/` (plan, controller, notifications, widgets).

## Tests

- `test/offline_test.dart`: saved copies, per-user data, the sync queue
  (order, duplicates, rejected and expired-login cases), streak with waiting
  check-ins, crisis phrases match the server, offline crisis in chat, the
  banner (English and Kiswahili).
- `test/reminders_test.dart`: reminder plan (days, skipping today,
  Kiswahili), turning on and off, blocked permission, time change, sign
  out, tapping a reminder, Home card and Profile setting.

## Trying it on the phone

1. Open the app online once (so there is something saved).
2. Turn on aeroplane mode. Home shows the offline banner with the time.
3. Log a mood: the summary says "Saved on your phone". Mood history shows
   it with a cloud icon ("waiting to sync").
4. In Chat, type "I want to end it all": the helplines sheet opens.
5. Turn aeroplane mode off and tap the banner (or wait up to 30 seconds):
   the check-in is sent and Home shows the XP and streak.
6. Profile → Daily reminder → on. "Send a test reminder" shows one straight
   away; tapping it opens the mood check-in. (The scheduled one is skipped
   today if you already checked in.)
