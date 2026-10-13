# Testing (implementation step 12)

Testing happens at four levels. The first three are done or run automatically;
the fourth is with students.

| Level | What is tested | How | Where the results are |
|---|---|---|---|
| 1. Unit and widget tests | App logic and every screen, in English and Kiswahili | 125 Flutter tests + 20 Edge Function tests, run by CI on every push | GitHub Actions; test/ and supabase/functions/chat/logic_test.ts |
| 2. Database tests | XP, streaks, badges, row-level security, admin functions | SQL run on the live database inside transactions that are rolled back | Step write-ups (below) |
| 3. System tests | The whole app on a real phone, plus the admin dashboard | 48 manual test cases | [MindQuest_testing.xlsx](MindQuest_testing.xlsx), sheet System tests |
| 4. User acceptance testing | Whether students can use it and find it useful | 10–20 students, remote, Google Form with SUS | [uat-plan.md](uat-plan.md); workbook sheets UAT tasks, SUS, Likert |

The NLU model is evaluated separately (held-out test phrases and 5-fold
cross-validation): see `nlp/README.md`.

## 1. Automated tests

CI (`.github/workflows/ci.yml`) runs on every push: formatting check,
`dart analyze` with warnings treated as errors, all tests, the web build of the
app and of the admin dashboard, a debug APK and a release APK. A change is
only finished when CI is green.

| Test file | Tests | Covers |
|---|---|---|
| `auth_test.dart` | 14 | Welcome, sign in, create account, onboarding, router redirects, save progress, delete my data, Google, feedback link |
| `chat_screen_test.dart` | 12 | Replies, crisis sheet (cannot be dismissed by accident, call buttons), quick replies, errors, mood check-in in chat, week graph, new chat, past chats |
| `home_mood_test.dart` | 12 | Level thresholds, Nairobi day and week boundaries, Home, mood check-in and summary, mood history, delete |
| `mood_insights_test.dart` | 15 | Every insight rule (hard days, weekdays, time of day, tags, notes, chat feelings, habit) |
| `learn_rewards_test.dart` | 11 | Articles, read XP and badge pop-up, Rewards, badge progress, recommendations |
| `support_test.dart` | 5 | Helplines, breathing, grounding |
| `kiswahili_test.dart` | 7 | Kiswahili dates, insights, errors and screens |
| `offline_test.dart` | 24 | Saved copies per user, sync queue (order, duplicates, rejected, expired login), streak with waiting check-ins, crisis phrases match the server, offline crisis in chat, offline banner |
| `reminders_test.dart` | 14 | Reminder plan, on/off, permission refused, time, language, sign out, tap opens mood, Home card, Profile setting |
| `admin_test.dart` | 10 | Statistics parsing, phone rule, staff sign-in, no access for students, counsellor view, overview, articles, helplines, team |
| `widget_test.dart` | 1 | App starts without keys |
| `supabase/functions/chat/logic_test.ts` | 20 | Crisis phrases (EN/SW/Sheng, whole words), reply rules, names, confidence threshold, every intent has replies in both languages |

## 2. Database tests

Run as a real signed-in user (role `authenticated` with that user's id), inside
a transaction that is rolled back, so nothing stays in the database.

- Step 4: XP rules, daily chat XP cap, streak restart, weekly quest, badges,
  and row-level security (users only see and change their own data, cannot
  raise their XP, make themselves admin, or backdate check-ins).
- Step 10 (`docs/offline-and-reminders.md`): late check-ins count on their own
  day, duplicates rejected, check-ins older than 7 days rejected.
- Step 11 (`docs/admin-dashboard.md`): admin functions refuse students;
  admins can't remove their own access; small averages hidden.

## 3. System tests (manual)

48 test cases in the workbook, grouped by area: sign-in and onboarding,
privacy, language, chatbot, crisis detection, mood tracking, gamification,
Learn, Support, offline, reminders, usability (dark mode, large fonts,
TalkBack), admin dashboard, security, performance and compatibility. Each
row has the steps and the expected result; fill in Result, Notes, Date and
Device. The Summary sheet counts the results by area.

Run them with:

- the **release APK** (the same build students will get), on your phone and,
  if possible, a second Android phone of another brand (ST-48);
- the admin dashboard in Chrome;
- Rasa running wherever it will run during UAT (see the UAT plan).

Every failed test goes in the Bugs sheet with its severity. Critical and
major bugs are fixed and re-tested before UAT starts.

### Non-functional checks

| Quality | Check | Status |
|---|---|---|
| Security | Row-level security on every table; tested as a user (step 4, 10, 11). Supabase security advisor (13 Oct): no errors. Warnings are by design: anonymous sign-in is the main way in; the admin functions are callable by signed-in users but refuse anyone who isn't staff; `crisis_events` has no policies on purpose (only the server writes it). Remaining: leaked-password protection is off (needs a paid plan). | Done |
| Privacy | Message text, notes and check-ins never shown on the dashboard; averages from fewer than 5 check-ins hidden; crisis events stored without text; delete my data removes everything. | Done |
| Performance | Chat reply time (ST-20, target 3 s) and start-up time (ST-47, target 5 s) measured on the phone. The Edge Function's own time is also visible in Supabase → Edge Functions → chat → Invocations. | To run |
| Usability | Dark mode, largest font, TalkBack (ST-38 to ST-40); SUS in UAT. | To run |
| Reliability | Works offline (step 10); retries; CI on every change. | Done |
| Portability | Release APK on a second phone (ST-48). | To run |

## 4. User acceptance testing

See [uat-plan.md](uat-plan.md).

## Before testing with students (done in step 12)

- Release builds now ask for internet access (`android.permission.INTERNET`
  in the main AndroidManifest; debug builds had it automatically, release
  builds would have failed to connect).
- CI builds a release APK on every push.
- Version 1.0.0 (build 2) for the test release.
- Admin dashboard hides averages from fewer than 5 check-ins (migration
  `20261013164017_admin_hide_small_averages`).
- Profile has "Give feedback on MindQuest", opening the Google Form; it only
  shows when `FEEDBACK_URL` is set in `config/dev.json`.
- `nlp/rasa/Dockerfile` so Rasa can run online during UAT instead of on the PC.
