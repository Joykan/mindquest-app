-- What a mood check-in is about (optional tags), used for mood insights such
-- as "your low days are often tagged School". Tags are a fixed list so they
-- can be counted and translated in the app.

alter table public.mood_logs
  add column tags text[] not null default '{}'
  constraint mood_logs_tags_known check (
    tags <@ array['school', 'family', 'friends', 'relationships', 'sleep', 'health', 'work', 'money']::text[]
    and cardinality(tags) <= 8
  );

comment on column public.mood_logs.tags is
  'Optional topics for the check-in: school, family, friends, relationships, sleep, health, work, money.';

grant insert (tags) on public.mood_logs to authenticated;
