-- Explicit Data API grants for every table.
--
-- From 30 Oct 2026 Supabase no longer grants API access to new tables in
-- "public" automatically. The live tables keep their grants, but if these
-- migrations are ever run on a fresh project (a new project, a branch or
-- `supabase db reset`), the tables would get none and the app would fail
-- with "permission denied". This migration writes down the grants the app
-- needs, matching the live database, so a rebuild works the same way.
--
-- Row-level security still decides which rows anyone can see or change.
-- Column-level grants made in earlier migrations stay as they are:
--   profiles: update (username, language, consent_at, age_range)
--   mood_logs: insert (id, user_id, mood, note, logged_at, tags)
--   resource_reads: insert (user_id, resource_id)
--   chat_sessions: update (ended_at)
-- so the table-level grants below leave out those privileges on purpose.
--
-- Rule for new tables: grant access in the same migration that creates them.

-- Server (Edge Functions with the service role key): everything.
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select, update on all sequences in schema public to service_role;

-- Reference data and tables protected only by row-level security.
grant select, insert, update, delete on
  public.badges,
  public.user_badges,
  public.resources,
  public.helplines,
  public.messages,
  public.crisis_events,
  public.xp_events,
  public.quest_completions
to anon, authenticated;

-- Tables where inserts or updates are limited to certain columns.
grant select, insert, delete on public.profiles to anon, authenticated;
grant select, delete on public.mood_logs to anon, authenticated;
grant select, delete on public.resource_reads to anon, authenticated;
grant select on public.chat_sessions to anon, authenticated;

-- Id sequences (admins adding articles and helplines; XP ledger).
grant usage, select, update on
  public.resources_id_seq,
  public.helplines_id_seq,
  public.xp_events_id_seq
to anon, authenticated;
