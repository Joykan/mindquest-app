# Supabase

Backend for MindQuest: Auth, PostgreSQL with Row Level Security, and Edge Functions.

Cloud project: **mindquest-app** (ref `dqcgeugyhpiemucdypok`, region eu-central-1 Frankfurt).

## Database

Migrations in `migrations/` are applied in filename order.

| Table | What it holds |
|---|---|
| `profiles` | One row per user: name, language, role, XP, level, streak. Created automatically on sign-up. |
| `chat_sessions`, `messages` | Chat history. Written only by the chat Edge Function. |
| `mood_logs` | Mood check-ins (1 to 5) with an optional note of up to 200 characters. |
| `badges`, `user_badges` | Badge catalogue and the badges each user has earned. |
| `resources`, `resource_reads` | Learning articles in English and Kiswahili, and which ones a user has read. |
| `helplines` | Crisis helplines. Only rows marked `verified` are shown in the app. |
| `crisis_events` | A record that a crisis response was shown. No message text is stored. |
| `xp_events`, `quest_completions` | XP history and completed weekly quests. |

### Gamification rules (database triggers)

| Action | XP | Limit |
|---|---|---|
| Mood check-in | +10 | once per day |
| Chat message | +2 | 20 XP per day |
| Article read | +5 | once per article |
| Weekly quest: check in on 5 days in one week | +25 | once per week |

Levels: L1 0 XP, L2 50, L3 100, L4 200, L5 350, then a new level every 200 XP.
Missing a day restarts the streak at 1 but never removes XP, levels or badges.
Days are counted in Kenyan time.

### Security

- Row Level Security is on for every table. Users can only read their own data.
- Users can change only their name and language. XP, level, streak and role are set by the database.
- Mood logs get their timestamp from the server, so check-ins cannot be backdated.
- `admin_stats()` returns anonymised totals and only works for admins and counsellors.

To make someone an admin, run in the SQL editor:

```sql
update public.profiles set role = 'admin' where id = 'USER-ID';
```

## Linking the CLI

```bash
supabase init
supabase link --project-ref dqcgeugyhpiemucdypok
```
