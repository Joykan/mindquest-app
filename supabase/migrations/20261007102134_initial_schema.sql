-- MindQuest database schema
-- Tables follow the ERD in the project proposal (Section 4.3.1):
-- USER -> profiles, SESSION -> chat_sessions, MESSAGE -> messages,
-- MOOD_LOG -> mood_logs, BADGE -> badges, USERBADGE -> user_badges.
-- Extra tables support learning articles, helplines, crisis logging and
-- the gamification rules (XP ledger and weekly quests).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      text not null default 'Friend' check (char_length(username) between 1 and 30),
  language      text not null default 'en' check (language in ('en', 'sw')),
  role          text not null default 'user' check (role in ('user', 'admin', 'counsellor')),
  xp            integer not null default 0 check (xp >= 0),
  level         integer not null default 1 check (level >= 1),
  streak        integer not null default 0 check (streak >= 0),
  last_checkin  date,
  created_at    timestamptz not null default now()
);
comment on table public.profiles is 'One row per user (ERD: USER). Created automatically on sign-up.';

create table public.chat_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  check (ended_at is null or ended_at >= started_at)
);
comment on table public.chat_sessions is 'ERD: SESSION. Duration is ended_at - started_at.';

create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.chat_sessions (id) on delete cascade,
  sender      text not null check (sender in ('user', 'bot')),
  content     text not null check (char_length(content) between 1 and 2000),
  created_at  timestamptz not null default now()
);
comment on table public.messages is 'ERD: MESSAGE. Written by the chat Edge Function only.';

create table public.mood_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  mood        smallint not null check (mood between 1 and 5),
  note        text check (char_length(note) <= 200),
  logged_at   timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  -- entries made offline may sync up to 7 days later, never from the future
  check (logged_at <= created_at + interval '5 minutes'
         and logged_at >= created_at - interval '7 days')
);
comment on table public.mood_logs is 'ERD: MOOD_LOG. FR-SPEC-01: five moods, optional 200-character note.';

create table public.badges (
  id           text primary key,
  name         text not null,
  name_sw      text not null,
  description  text not null,
  sort_order   integer not null default 0
);
comment on table public.badges is 'ERD: BADGE. Rules are evaluated in public.evaluate_badges().';

create table public.user_badges (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  badge_id   text not null references public.badges (id) on delete cascade,
  earned_at  timestamptz not null default now(),
  primary key (user_id, badge_id)
);
comment on table public.user_badges is 'ERD: USERBADGE.';

create table public.resources (
  id          bigint generated always as identity primary key,
  category    text not null check (category in ('stress', 'anxiety', 'mindfulness', 'support')),
  title_en    text not null,
  title_sw    text not null,
  body_en     text not null,
  body_sw     text not null,
  read_minutes smallint not null default 3,
  published   boolean not null default false,
  updated_at  timestamptz not null default now()
);
comment on table public.resources is 'Learning articles in English and Kiswahili (FR 4).';

create table public.resource_reads (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  resource_id  bigint not null references public.resources (id) on delete cascade,
  read_at      timestamptz not null default now(),
  primary key (user_id, resource_id)
);

create table public.helplines (
  id          bigint generated always as identity primary key,
  name        text not null,
  phone       text not null,
  description text,
  verified    boolean not null default false,
  sort_order  integer not null default 0
);
comment on table public.helplines is 'Crisis helplines (FR 5). Only verified rows are shown to users.';

create table public.crisis_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);
comment on table public.crisis_events is 'Records that a crisis response was shown. Never stores message text.';

create table public.xp_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  reason      text not null check (reason in ('mood_checkin', 'chat_message', 'article_read', 'weekly_quest')),
  amount      integer not null check (amount > 0),
  created_at  timestamptz not null default now()
);
comment on table public.xp_events is 'Ledger of every XP award, used for daily caps and reports.';

create table public.quest_completions (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  quest       text not null default 'weekly_checkins',
  week_start  date not null,
  completed_at timestamptz not null default now(),
  primary key (user_id, quest, week_start)
);

-- Indexes for foreign keys and common lookups
create index chat_sessions_user_idx on public.chat_sessions (user_id);
create index messages_session_idx on public.messages (session_id, created_at);
create index mood_logs_user_idx on public.mood_logs (user_id, logged_at desc);
create index user_badges_badge_idx on public.user_badges (badge_id);
create index resource_reads_resource_idx on public.resource_reads (resource_id);
create index crisis_events_user_idx on public.crisis_events (user_id);
create index crisis_events_created_idx on public.crisis_events (created_at);
create index xp_events_user_idx on public.xp_events (user_id, reason, created_at);

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------

-- "Today" for streaks and daily caps uses Kenyan time.
create function public.local_date(ts timestamptz default now())
returns date
language sql
immutable
set search_path = ''
as $$ select (ts at time zone 'Africa/Nairobi')::date $$;

-- Level thresholds: L1 0, L2 50, L3 100, L4 200, L5 350, then every 200 XP.
create function public.level_for_xp(total integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when total < 50  then 1
    when total < 100 then 2
    when total < 200 then 3
    when total < 350 then 4
    else 5 + (total - 350) / 200
  end
$$;

create function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role in ('admin', 'counsellor')
  )
$$;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  )
$$;

-- ---------------------------------------------------------------------------
-- Gamification
-- ---------------------------------------------------------------------------

-- Adds XP to the ledger and profile, recalculating the level.
create function public.award_xp(p_user uuid, p_reason text, p_amount integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.xp_events (user_id, reason, amount) values (p_user, p_reason, p_amount);
  update public.profiles
     set xp = xp + p_amount,
         level = public.level_for_xp(xp + p_amount)
   where id = p_user;
end
$$;

-- Awards any badges the user now qualifies for. Each badge is earned once.
create function public.evaluate_badges(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_moods   integer;
  v_chats   integer;
  v_reads   integer;
  v_streak  integer;
  v_quests  integer;
begin
  select count(*) into v_moods from public.mood_logs where user_id = p_user;
  select count(*) into v_chats
    from public.messages m join public.chat_sessions s on s.id = m.session_id
   where s.user_id = p_user and m.sender = 'user';
  select count(*) into v_reads from public.resource_reads where user_id = p_user;
  select streak into v_streak from public.profiles where id = p_user;
  select count(*) into v_quests from public.quest_completions where user_id = p_user;

  insert into public.user_badges (user_id, badge_id)
  select p_user, b.id
    from public.badges b
   where (b.id = 'first_checkin' and v_moods  >= 1)
      or (b.id = 'first_chat'    and v_chats  >= 1)
      or (b.id = 'curious_mind'  and v_reads  >= 3)
      or (b.id = 'streak_7'      and v_streak >= 7)
      or (b.id = 'mood_explorer' and v_moods  >= 20)
      or (b.id = 'quest_master'  and v_quests >= 4)
  on conflict do nothing;
end
$$;

-- Mood check-in: +10 XP and streak update once per day, weekly quest, badges.
create function public.on_mood_logged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today       date := public.local_date(new.created_at);
  v_last        date;
  v_week_start  date := v_today - (extract(isodow from v_today)::integer - 1);
  v_days        integer;
begin
  select last_checkin into v_last from public.profiles where id = new.user_id for update;

  if v_last is distinct from v_today then
    update public.profiles
       set streak = case when v_last = v_today - 1 then streak + 1 else 1 end,
           last_checkin = v_today
     where id = new.user_id;
    perform public.award_xp(new.user_id, 'mood_checkin', 10);
  end if;

  -- Weekly quest: check in on 5 different days in the same Monday-Sunday week.
  select count(distinct public.local_date(created_at)) into v_days
    from public.mood_logs
   where user_id = new.user_id
     and public.local_date(created_at) between v_week_start and v_week_start + 6;

  if v_days >= 5 then
    insert into public.quest_completions (user_id, quest, week_start)
    values (new.user_id, 'weekly_checkins', v_week_start)
    on conflict do nothing;
    if found then
      perform public.award_xp(new.user_id, 'weekly_quest', 25);
    end if;
  end if;

  perform public.evaluate_badges(new.user_id);
  return new;
end
$$;

-- Chat message from the user: +2 XP, at most 20 XP per day.
create function public.on_message_saved()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user     uuid;
  v_today_xp integer;
begin
  if new.sender <> 'user' then
    return new;
  end if;

  select user_id into v_user from public.chat_sessions where id = new.session_id;

  select coalesce(sum(amount), 0) into v_today_xp
    from public.xp_events
   where user_id = v_user
     and reason = 'chat_message'
     and public.local_date(created_at) = public.local_date(new.created_at);

  if v_today_xp + 2 <= 20 then
    perform public.award_xp(v_user, 'chat_message', 2);
  end if;

  perform public.evaluate_badges(v_user);
  return new;
end
$$;

-- Article read: +5 XP once per article (the primary key stops repeats).
create function public.on_resource_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.award_xp(new.user_id, 'article_read', 5);
  perform public.evaluate_badges(new.user_id);
  return new;
end
$$;

create trigger mood_logged after insert on public.mood_logs
  for each row execute function public.on_mood_logged();
create trigger message_saved after insert on public.messages
  for each row execute function public.on_message_saved();
create trigger resource_read after insert on public.resource_reads
  for each row execute function public.on_resource_read();

-- New sign-ups (including anonymous guests) get a profile automatically.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username, language)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''), 'Friend'),
    case when new.raw_user_meta_data ->> 'language' = 'sw' then 'sw' else 'en' end
  );
  return new;
end
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

create trigger resources_touch before update on public.resources
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Admin and counsellor reporting (FR 7, UC-06). Aggregates only.
-- ---------------------------------------------------------------------------

create function public.admin_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(p_days, 1));
begin
  if not public.is_staff() then
    raise exception 'Only administrators and counsellors can view statistics'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'users',            (select count(*) from public.profiles),
    'active_users',     (select count(distinct user_id) from (
                           select user_id from public.mood_logs where created_at >= v_since
                           union
                           select user_id from public.chat_sessions where started_at >= v_since
                         ) a),
    'chat_sessions',    (select count(*) from public.chat_sessions where started_at >= v_since),
    'mood_entries',     (select count(*) from public.mood_logs where created_at >= v_since),
    'average_mood',     (select round(avg(mood)::numeric, 2) from public.mood_logs where created_at >= v_since),
    'badges_awarded',   (select count(*) from public.user_badges where earned_at >= v_since),
    'crisis_events',    (select count(*) from public.crisis_events where created_at >= v_since),
    'language_split',   (select coalesce(jsonb_object_agg(language, n), '{}'::jsonb)
                           from (select language, count(*) n from public.profiles group by language) l),
    'daily_mood',       (select coalesce(jsonb_agg(d order by d.day), '[]'::jsonb) from (
                           select public.local_date(created_at) as day,
                                  round(avg(mood)::numeric, 2) as average,
                                  count(*) as entries
                             from public.mood_logs
                            where created_at >= v_since
                            group by 1) d),
    'top_articles',     (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
                           select r.title_en as title, count(*) as reads
                             from public.resource_reads rr join public.resources r on r.id = rr.resource_id
                            group by r.title_en order by count(*) desc limit 5) t)
  );
end
$$;

-- ---------------------------------------------------------------------------
-- Function permissions: only the functions the app calls are exposed.
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.admin_stats(integer) to authenticated;
grant execute on function public.level_for_xp(integer) to anon, authenticated;
grant execute on function public.local_date(timestamptz) to anon, authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles          enable row level security;
alter table public.chat_sessions     enable row level security;
alter table public.messages          enable row level security;
alter table public.mood_logs         enable row level security;
alter table public.badges            enable row level security;
alter table public.user_badges       enable row level security;
alter table public.resources         enable row level security;
alter table public.resource_reads    enable row level security;
alter table public.helplines         enable row level security;
alter table public.crisis_events     enable row level security;
alter table public.xp_events         enable row level security;
alter table public.quest_completions enable row level security;

-- profiles: users see and edit only their own row, and only their name and language.
create policy "Own profile is visible" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Own profile is editable" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from anon, authenticated;
grant update (username, language) on public.profiles to authenticated;

-- chat: sessions and messages are written by the chat Edge Function (service role).
create policy "Own chat sessions are visible" on public.chat_sessions
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Own messages are visible" on public.messages
  for select to authenticated using (
    exists (select 1 from public.chat_sessions s
             where s.id = messages.session_id and s.user_id = (select auth.uid())));

-- mood logs: users add, read and delete their own entries.
create policy "Own moods are visible" on public.mood_logs
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users log their own moods" on public.mood_logs
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Users delete their own moods" on public.mood_logs
  for delete to authenticated using (user_id = (select auth.uid()));
-- created_at is always set by the server, so streaks and XP cannot be backdated.
revoke insert, update on public.mood_logs from anon, authenticated;
grant insert (user_id, mood, note, logged_at) on public.mood_logs to authenticated;

-- badges: the catalogue is public; earned badges are private.
create policy "Badges are public" on public.badges
  for select to anon, authenticated using (true);
create policy "Own badges are visible" on public.user_badges
  for select to authenticated using (user_id = (select auth.uid()));

-- resources: published articles for everyone; admins manage all.
create policy "Published articles are visible" on public.resources
  for select to anon, authenticated using (published or (select public.is_admin()));
create policy "Admins add articles" on public.resources
  for insert to authenticated with check ((select public.is_admin()));
create policy "Admins edit articles" on public.resources
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "Admins delete articles" on public.resources
  for delete to authenticated using ((select public.is_admin()));

create policy "Own reads are visible" on public.resource_reads
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users mark articles read" on public.resource_reads
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.resources r where r.id = resource_reads.resource_id and r.published));
revoke insert, update on public.resource_reads from anon, authenticated;
grant insert (user_id, resource_id) on public.resource_reads to authenticated;

-- helplines: verified ones are public; admins manage.
create policy "Verified helplines are visible" on public.helplines
  for select to anon, authenticated using (verified or (select public.is_admin()));
create policy "Admins manage helplines" on public.helplines
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

-- XP history and quests: read-only for the owner.
create policy "Own XP history is visible" on public.xp_events
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Own quests are visible" on public.quest_completions
  for select to authenticated using (user_id = (select auth.uid()));

-- crisis_events: no client access at all (service role only).
