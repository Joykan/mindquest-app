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

## Chat function

`functions/chat` is the Edge Function behind the chat screen (UC-01). The app
sends `{ "text": "...", "session_id": "..." }` with the user's access token.

1. **Crisis check first.** Every message is checked against a list of English,
   Kiswahili and Sheng crisis phrases (`crisis.ts`). On a match the model is
   skipped, a row is added to `crisis_events` (time and user only, never the
   text) and the reply includes the verified helplines. If none are verified
   yet, Kenya's emergency numbers 999 and 112 are returned instead.
2. **Otherwise Rasa.** The text goes to the Rasa server (`/model/parse`). The
   reply is chosen in `logic.ts`:
   - below 0.5 confidence, or `nlu_fallback`, gives the fallback reply
   - stress and anxiety offer a breathing exercise; the next "yes"/"no" is read
     against that offer
   - names: a name only counts if Rasa extracted one. "My name is Joy" or
     "naitwa Furaha" is used straight away; a feeling-word name in a message
     that doesn't introduce anyone ("I feel joy") is checked first; if Rasa
     says "name" but finds none and the message has a happy word (joy,
     furaha, amani...), it is read as feeling good
   - if Rasa can't be reached, the user gets a "try again" reply and the
     crisis check still works
3. **Saved.** Both messages go into `messages`, with the intent and confidence
   on the user's message and the reply key on the bot's. Saving the user's
   message awards chat XP through the existing trigger.

Replies in both languages are in `replies.ts`; the user's `profiles.language`
picks which. Tests: `cd supabase/functions/chat && deno test` (also run in CI).

Secrets (Dashboard > Edge Functions > Secrets):

| Name | Value |
|---|---|
| `RASA_URL` | Public address of the Rasa server, e.g. the ngrok address |
| `RASA_TOKEN` | Same token Rasa was started with (`nlp/rasa/.rasa-token`) |

## Helplines shown in the crisis sheet

Only rows with `verified = true` are shown. Numbers were checked against the
organisations' official listings on 10 Oct 2026.

| Order | Helpline | Number | Note | Source |
|---|---|---|---|---|
| 1 | Kenya Red Cross | 1199 | Toll-free, 24 hours | Kenya Red Cross |
| 2 | Befrienders Kenya | +254 722 178 177 | Emotional support line | [Befrienders Worldwide](https://befrienders.org/find-support-now/befrienders-kenya/) |
| 3 | Childline Kenya | 116 | For under-18s, toll-free, 24 hours | [Child Helpline International](https://childhelplineinternational.org/kenya-childline-kenya/) |

If no helpline is verified, the chat function falls back to Kenya's emergency
numbers 999 and 112. Numbers should be re-checked before each release.
