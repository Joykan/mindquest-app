# Supabase

Backend for MindQuest: Auth, PostgreSQL with Row Level Security, and Edge Functions.

- `migrations/`: SQL migrations, one file per change (step 4 adds the ERD tables).
- `functions/`: Edge Functions, e.g. `chat` (step 7).

Cloud project: **mindquest-app** (ref `dqcgeugyhpiemucdypok`, region eu-central-1 Frankfurt), created 6 Oct 2026.

Link the local folder to the cloud project once:

```bash
supabase init            # creates config.toml (commit it)
supabase link --project-ref dqcgeugyhpiemucdypok
```
