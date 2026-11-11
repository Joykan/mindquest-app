-- Chat modes and two new check-in topics.
--
-- chat_sessions.mode: how Chipu answers in this chat. 'vent' only listens,
-- 'comfort' offers kind words, 'guide' (the default) gives practical help.
-- mood_logs.tags: adds 'disconnected' and 'future' to the allowed topics.

alter table public.chat_sessions
  add column if not exists mode text not null default 'guide';
alter table public.chat_sessions drop constraint if exists chat_sessions_mode_check;
alter table public.chat_sessions
  add constraint chat_sessions_mode_check check (mode in ('vent', 'comfort', 'guide'));
comment on column public.chat_sessions.mode is
  'How Chipu answers: vent (only listens), comfort (kind words), guide (practical help, the default).';

alter table public.mood_logs drop constraint if exists mood_logs_tags_known;
alter table public.mood_logs
  add constraint mood_logs_tags_known check (
    tags <@ array['school', 'family', 'friends', 'relationships', 'sleep', 'health', 'work', 'money',
                  'disconnected', 'future']::text[]
    and cardinality(tags) <= 10
  );
comment on column public.mood_logs.tags is
  'Optional topics for the check-in: school, family, friends, relationships, sleep, health, work, money, disconnected, future.';
