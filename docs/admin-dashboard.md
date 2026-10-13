# Admin dashboard (implementation step 11)

A web app for administrators and counsellors (FR 7, UC-06). It uses the
same Flutter code base, theme and Supabase project as the student app, with
its own entry point: `lib/main_admin.dart`, code in `lib/admin/`.

## Running it

```
flutter run -d chrome -t lib/main_admin.dart --web-port 5050 --dart-define-from-file=config/dev.json
```

Sign in with the email and password of your MindQuest account, or with
Google. For Google sign-in on the web, add `http://localhost:5050` to
Supabase → Authentication → URL Configuration → Redirect URLs (once).

To put it online later: `flutter build web --release -t lib/main_admin.dart
--dart-define-from-file=config/dev.json` and upload `build/web` to any static
host (e.g. Vercel), then add that address to the Redirect URLs too. Only the
publishable key is in the build; the database decides what each account may
see.

## Who sees what

| | Student | Counsellor | Administrator |
|---|---|---|---|
| Overview (statistics) | No | Yes | Yes |
| Articles (add, edit, publish, delete) | No | No | Yes |
| Helplines (add, edit, verify, delete) | No | No | Yes |
| Team (give or remove access) | No | No | Yes |
| A student's messages, notes or check-ins | No one, ever | | |

The dashboard checks the role when someone signs in, but the real
protection is in the database: row-level security on `resources` and
`helplines` (only `is_admin()` may write), and the three functions below
refuse anyone without the right role. Users can't change their own role
(no update grant on `profiles.role`).

## Pages

- **Overview** – for the last 7, 30 or 90 days: students (new, saved with
  email or Google), active students, mood check-ins and the average mood,
  chats and messages, articles read, badges, how often Chipu understood, and
  crisis responses. Charts: check-ins per day, average mood per day, crisis
  responses per day. Breakdowns: check-ins by mood, by tag (with the average
  mood for each tag), what students talk to Chipu about (the NLU intents;
  greetings, thanks and yes/no grouped as small talk), app language, reads
  per article.
- **Articles** – list with topic filter, Published switch, edit (English and
  Kiswahili side by side, topic, minutes), add, delete (with a tip to
  unpublish instead).
- **Helplines** – list, Verified switch (students only see verified ones;
  with none, the app shows 999 and 112), add, edit, delete. Phone numbers
  are checked (digits, spaces, optional +).
- **Team** – admins and counsellors with their email; give access by the
  email of a MindQuest account; make admin, make counsellor, remove access.
  You can't remove your own admin access.

## Privacy

Everything on the Overview is a count or an average worked out in the
database (`admin_stats`). Message text, mood notes and individual
check-ins never leave the database for the dashboard, and crisis events
are stored without the message and are only counted. Topics come from the
intent labels the NLU model gave, not from the messages.

With very few students, an average could point to one person (for example
a single check-in on one day). So averages that come from fewer than 5
check-ins are hidden (shown as "–"); counts are still shown. This was added
before testing with students (migration
`20261013164017_admin_hide_small_averages`).

## Database

Migration `20261013152720_admin_dashboard.sql`:

- `admin_stats(p_days)` (staff only) now covers Nairobi days with today
  included, uses `logged_at` for check-ins, and adds new students, saved
  accounts, messages, articles read, per-day rows (check-ins, average mood,
  chats, crisis responses, including empty days), mood split, tags with
  average mood, chat topics, not understood, NLU server unavailable, and
  reads per article.
- `admin_staff()` (admins only): admins and counsellors with their email.
- `admin_set_role(p_email, p_role)` (admins only): gives or removes access by
  the email of a non-anonymous account; can't remove your own admin access.

Tested on the live database in rolled-back transactions:

| As | Check | Result |
|---|---|---|
| Admin | `admin_stats(7)`, `admin_stats(30)` | Totals as expected; 7 and 30 daily rows |
| Admin | `admin_staff()` | Candy, admin |
| Admin | Give access to an unknown email | Refused: no account with that email |
| Admin | Remove own admin access | Refused |
| Admin | Unknown role | Refused |
| Admin | Change a role with a direct update | Refused (no column grant) |
| Student | `admin_stats`, `admin_staff`, `admin_set_role` | Refused (42501) |
| Student | Add an article | Refused by row-level security |
| Student | See unpublished articles | None visible |

## Tests

`test/admin_test.dart`: reading the statistics (using a real answer from
the database), the phone-number rule, sign in (wrong and right password,
sign out), a student account gets no access, counsellors only get the
Overview, Overview totals and period switch, publishing and adding an
article (with validation), editing keeps the id, verifying a helpline,
giving access on the Team page (unknown email and success). CI also builds
the dashboard for the web.
