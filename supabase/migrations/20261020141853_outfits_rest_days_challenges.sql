-- More fun, in line with the proposal's gamification (FR 3: badges,
-- challenges, streaks):
--   1. Chipu's outfits, unlocked by level.
--   2. Kinder streaks: one rest day a week, and streak badges at 3, 14 and
--      30 days.
--   3. Themed challenges: 7-day goals with a badge at the end.

-- ---------------------------------------------------------------------------
-- 1. Outfits
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column outfit text check (outfit in ('daisy', 'glasses', 'beads', 'medal', 'cape'));
comment on column public.profiles.outfit is
  'What Chipu wears for this user (null: nothing). Changed only through set_outfit().';

-- The level each outfit needs. The app has the same list (outfits.dart).
create or replace function public.outfit_level(p_outfit text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_outfit
    when 'daisy'   then 2
    when 'glasses' then 3
    when 'beads'   then 4
    when 'medal'   then 5
    when 'cape'    then 6
  end
$$;

create or replace function public.set_outfit(p_outfit text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_level integer;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if p_outfit is not null then
    if public.outfit_level(p_outfit) is null then
      raise exception 'unknown outfit' using errcode = '22023';
    end if;
    select level into v_level from public.profiles where id = auth.uid();
    if v_level < public.outfit_level(p_outfit) then
      raise exception 'outfit not unlocked yet' using errcode = '22023';
    end if;
  end if;
  update public.profiles set outfit = p_outfit where id = auth.uid();
end
$$;

revoke execute on function public.outfit_level(text) from public, anon, authenticated;
revoke execute on function public.set_outfit(text) from public, anon;
grant execute on function public.set_outfit(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Kinder streaks
-- ---------------------------------------------------------------------------

-- The streak: check-in days counted back from the latest one. Missing one
-- day doesn't end it if that week's rest day (Monday to Sunday, one per
-- week) is still free; two missed days in a row, or a second missed day in
-- the same week, end it. Rest days don't count as streak days.
-- The app works it out the same way (streaks.dart).
create or replace function public.checkin_streak(p_user uuid,
                                                 out o_streak integer,
                                                 out o_last date)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days  date[];
  v_cur   date;
  v_rest  date;
  v_used  date[] := '{}';
begin
  select array_agg(distinct public.local_date(created_at)) into v_days
    from public.xp_events
   where user_id = p_user and reason = 'mood_checkin';
  o_streak := 0;
  if v_days is null then
    return;
  end if;
  select max(d) into o_last from unnest(v_days) d;
  v_cur := o_last;
  o_streak := 1;
  loop
    if (v_cur - 1) = any (v_days) then
      v_cur := v_cur - 1;
    else
      v_rest := v_cur - 1;
      -- Monday of the missed day's week
      if (v_cur - 2) = any (v_days)
         and not ((v_rest - (extract(isodow from v_rest)::integer - 1)) = any (v_used)) then
        v_used := v_used || (v_rest - (extract(isodow from v_rest)::integer - 1));
        v_cur := v_cur - 2;
      else
        exit;
      end if;
    end if;
    o_streak := o_streak + 1;
  end loop;
end
$$;
revoke execute on function public.checkin_streak(uuid) from public, anon, authenticated;

-- Same as before (step 10), with the streak from checkin_streak().
create or replace function public.on_mood_logged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day         date := public.local_date(new.logged_at);
  v_week_start  date := v_day - (extract(isodow from v_day)::integer - 1);
  v_streak      integer;
  v_latest      date;
  v_days        integer;
begin
  -- Check-ins arriving together (e.g. a few synced at once) are handled one by one.
  perform 1 from public.profiles where id = new.user_id for update;

  -- First check-in of that day: +10 XP, stamped with the check-in time.
  if not exists (
    select 1 from public.xp_events
     where user_id = new.user_id
       and reason = 'mood_checkin'
       and public.local_date(created_at) = v_day
  ) then
    perform public.award_xp_at(new.user_id, 'mood_checkin', 10, new.logged_at);
  end if;

  select o_streak, o_last into v_streak, v_latest
    from public.checkin_streak(new.user_id);

  update public.profiles
     set streak = v_streak,
         last_checkin = v_latest
   where id = new.user_id;

  -- Weekly quest: 5 check-in days in the week (Monday to Sunday) of this check-in.
  select count(distinct public.local_date(created_at)) into v_days
    from public.xp_events
   where user_id = new.user_id
     and reason = 'mood_checkin'
     and public.local_date(created_at) between v_week_start and v_week_start + 6;

  if v_days >= 5 then
    insert into public.quest_completions (user_id, quest, week_start)
    values (new.user_id, 'weekly_checkins', v_week_start)
    on conflict do nothing;
    if found then
      perform public.award_xp_at(new.user_id, 'weekly_quest', 25, new.logged_at);
    end if;
  end if;

  perform public.evaluate_badges(new.user_id);
  return new;
end
$$;

-- New badges, and an order that keeps the streak badges together.
insert into public.badges (id, name, name_sw, description, sort_order) values
  ('streak_3',  '3-Day Streak',  'Siku 3 Mfululizo',  'Keep a 3-day streak',  4),
  ('streak_14', '14-Day Streak', 'Siku 14 Mfululizo', 'Keep a 14-day streak', 6),
  ('streak_30', '30-Day Streak', 'Siku 30 Mfululizo', 'Keep a 30-day streak', 7),
  ('challenge_exam_calm',   'Calm Mind',   'Akili Tulivu',  'Finish the Exam calm challenge',      10),
  ('challenge_good_things', 'Bright Side', 'Upande Mzuri',  'Finish the Notice the good challenge', 11),
  ('challenge_mindful',     'Here and Now', 'Hapa na Sasa', 'Finish the Mindful moments challenge', 12),
  ('challenge_talk',        'Open Heart',  'Moyo Wazi',     'Finish the Talk it out challenge',    13);
update public.badges set sort_order = 5, description = 'Keep a 7-day streak' where id = 'streak_7';
update public.badges set sort_order = 8 where id = 'mood_explorer';
update public.badges set sort_order = 9 where id = 'quest_master';

create or replace function public.evaluate_badges(p_user uuid)
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
      or (b.id = 'streak_3'      and v_streak >= 3)
      or (b.id = 'streak_7'      and v_streak >= 7)
      or (b.id = 'streak_14'     and v_streak >= 14)
      or (b.id = 'streak_30'     and v_streak >= 30)
      or (b.id = 'mood_explorer' and v_moods  >= 20)
      or (b.id = 'quest_master'  and v_quests >= 4)
  on conflict do nothing;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Challenges
-- ---------------------------------------------------------------------------

alter table public.xp_events drop constraint xp_events_reason_check;
alter table public.xp_events add constraint xp_events_reason_check
  check (reason in ('mood_checkin', 'chat_message', 'article_read', 'weekly_quest', 'challenge'));

-- Breathing and grounding exercises finished in the app (Support page).
-- Only that it happened and when; nothing else.
create table public.wellbeing_activities (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('breathing', 'grounding')),
  done_at     timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  -- Made offline and sent later: up to 7 days, never in the future.
  check (done_at <= created_at + interval '5 minutes'
         and done_at >= created_at - interval '7 days')
);
comment on table public.wellbeing_activities is
  'Breathing and grounding exercises a user finished (counts for challenges).';
create index wellbeing_activities_user_idx on public.wellbeing_activities (user_id, done_at desc);

alter table public.wellbeing_activities enable row level security;
create policy "Own activities are visible" on public.wellbeing_activities
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Users log their own activities" on public.wellbeing_activities
  for insert to authenticated with check (user_id = (select auth.uid()));
grant select on public.wellbeing_activities to authenticated;
grant insert (id, user_id, kind, done_at) on public.wellbeing_activities to authenticated;
grant select, insert, update, delete on public.wellbeing_activities to service_role;

-- The challenges. steps is a list of {"kind", "target", "category"?}:
--   checkin   days with a mood check-in
--   note      days with a check-in that has a note
--   chat      days with a message to Chipu
--   breathing / grounding   exercises finished
--   read      articles read (of "category", if given)
create table public.challenges (
  id              text primary key,
  emoji           text not null,
  title           text not null,
  title_sw        text not null,
  description     text not null,
  description_sw  text not null,
  days            integer not null default 7 check (days between 1 and 30),
  steps           jsonb not null check (jsonb_typeof(steps) = 'array'),
  xp              integer not null default 40 check (xp > 0),
  badge_id        text references public.badges (id),
  sort_order      integer not null default 0,
  active          boolean not null default true
);
comment on table public.challenges is 'Themed challenges a user can take on (FR 3).';

alter table public.challenges enable row level security;
create policy "Active challenges are visible" on public.challenges
  for select to anon, authenticated using (active or (select public.is_admin()));
create policy "Admins manage challenges" on public.challenges
  for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
grant select on public.challenges to anon, authenticated;
grant insert, update, delete on public.challenges to authenticated;
grant select, insert, update, delete on public.challenges to service_role;

-- One row each time a user takes on a challenge.
create table public.challenge_runs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  challenge_id  text not null references public.challenges (id) on delete cascade,
  started_at    timestamptz not null default now(),
  ends_at       timestamptz not null,
  completed_at  timestamptz,
  left_at       timestamptz
);
comment on table public.challenge_runs is
  'A challenge a user started; written only by start_challenge(), leave_challenge() and the triggers.';
create index challenge_runs_user_idx on public.challenge_runs (user_id, started_at desc);
create index challenge_runs_challenge_idx on public.challenge_runs (challenge_id);

alter table public.challenge_runs enable row level security;
create policy "Own challenge runs are visible" on public.challenge_runs
  for select to authenticated using (user_id = (select auth.uid()));
grant select on public.challenge_runs to authenticated;
grant select, insert, update, delete on public.challenge_runs to service_role;

insert into public.challenges
  (id, emoji, title, title_sw, description, description_sw, steps, xp, badge_id, sort_order) values
  ('exam_calm', '📝', 'Exam calm', 'Utulivu wa mitihani',
   'Stay steady through a busy week of exams or deadlines.',
   'Baki mtulivu katika wiki yenye mitihani au kazi nyingi.',
   '[{"kind": "checkin", "target": 4}, {"kind": "breathing", "target": 3},
     {"kind": "read", "target": 1, "category": "stress"}]',
   40, 'challenge_exam_calm', 1),
  ('good_things', '🌻', 'Notice the good', 'Ona mazuri',
   'On 4 days, check in and write one good thing from your day in the note.',
   'Kwa siku 4, rekodi hisia zako na uandike jambo moja zuri la siku yako kwenye maelezo.',
   '[{"kind": "note", "target": 4}]',
   40, 'challenge_good_things', 2),
  ('mindful', '🌿', 'Mindful moments', 'Nyakati za utulivu',
   'Slow down and come back to the present moment.',
   'Punguza mwendo na urudi kwenye wakati huu.',
   '[{"kind": "breathing", "target": 3}, {"kind": "grounding", "target": 2},
     {"kind": "read", "target": 1, "category": "mindfulness"}]',
   40, 'challenge_mindful', 3),
  ('talk_it_out', '💬', 'Talk it out', 'Ongea nayo',
   'Share how you feel, with Chipu and with yourself.',
   'Eleza jinsi unavyojisikia, kwa Chipu na kwako mwenyewe.',
   '[{"kind": "chat", "target": 3}, {"kind": "checkin", "target": 3},
     {"kind": "read", "target": 1, "category": "support"}]',
   40, 'challenge_talk', 4);

-- Midnight in Nairobi at the start of a day, as a time stamp.
create or replace function public.nairobi_midnight(p_day date)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select (p_day::timestamp at time zone 'Africa/Nairobi')
$$;

-- How far a run is: each step with "done" (capped at the target). Counts
-- everything from the start of the day the challenge was started until it
-- ends. A "read" step is also done when there is no unread article left to
-- read (so a challenge can be repeated).
create or replace function public.challenge_progress(p_run uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user    uuid;
  v_from    timestamptz;
  v_until   timestamptz;
  v_steps   jsonb;
  v_step    jsonb;
  v_kind    text;
  v_cat     text;
  v_target  integer;
  v_done    integer;
  v_out     jsonb := '[]';
begin
  select r.user_id,
         public.nairobi_midnight(public.local_date(r.started_at)),
         least(r.ends_at, coalesce(r.left_at, r.ends_at)),
         c.steps
    into v_user, v_from, v_until, v_steps
    from public.challenge_runs r
    join public.challenges c on c.id = r.challenge_id
   where r.id = p_run;
  if not found then
    return null;
  end if;

  for v_step in select * from jsonb_array_elements(v_steps) loop
    v_kind := v_step ->> 'kind';
    v_cat := v_step ->> 'category';
    v_target := coalesce((v_step ->> 'target')::integer, 1);
    v_done := 0;
    if v_kind = 'checkin' then
      select count(distinct public.local_date(logged_at)) into v_done
        from public.mood_logs
       where user_id = v_user and logged_at >= v_from and logged_at < v_until;
    elsif v_kind = 'note' then
      select count(distinct public.local_date(logged_at)) into v_done
        from public.mood_logs
       where user_id = v_user and logged_at >= v_from and logged_at < v_until
         and btrim(coalesce(note, '')) <> '';
    elsif v_kind = 'chat' then
      select count(distinct public.local_date(m.created_at)) into v_done
        from public.messages m
        join public.chat_sessions s on s.id = m.session_id
       where s.user_id = v_user and m.sender = 'user'
         and m.created_at >= v_from and m.created_at < v_until;
    elsif v_kind in ('breathing', 'grounding') then
      select count(*) into v_done
        from public.wellbeing_activities
       where user_id = v_user and kind = v_kind
         and done_at >= v_from and done_at < v_until;
    elsif v_kind = 'read' then
      select count(*) into v_done
        from public.resource_reads rr
        join public.resources res on res.id = rr.resource_id
       where rr.user_id = v_user and rr.read_at >= v_from and rr.read_at < v_until
         and (v_cat is null or res.category = v_cat);
      if v_done < v_target and not exists (
        select 1 from public.resources res
         where res.published and (v_cat is null or res.category = v_cat)
           and not exists (select 1 from public.resource_reads rr
                            where rr.user_id = v_user and rr.resource_id = res.id)
      ) then
        v_done := v_target;
      end if;
    end if;
    v_out := v_out || jsonb_build_object(
      'kind', v_kind, 'category', v_cat, 'target', v_target,
      'done', least(v_done, v_target));
  end loop;
  return v_out;
end
$$;

-- Finishes the user's running challenge if every step is done: +XP and
-- the challenge's badge.
create or replace function public.evaluate_challenge(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run      uuid;
  v_xp       integer;
  v_badge    text;
  v_progress jsonb;
begin
  select r.id, c.xp, c.badge_id into v_run, v_xp, v_badge
    from public.challenge_runs r
    join public.challenges c on c.id = r.challenge_id
   where r.user_id = p_user and r.completed_at is null and r.left_at is null
     and r.ends_at > now()
   order by r.started_at desc
   limit 1
     for update of r;
  if v_run is null then
    return;
  end if;
  v_progress := public.challenge_progress(v_run);
  if exists (select 1 from jsonb_array_elements(v_progress) e
              where (e ->> 'done')::integer < (e ->> 'target')::integer) then
    return;
  end if;
  update public.challenge_runs set completed_at = now() where id = v_run;
  perform public.award_xp(p_user, 'challenge', v_xp);
  if v_badge is not null then
    insert into public.user_badges (user_id, badge_id)
    values (p_user, v_badge)
    on conflict do nothing;
  end if;
end
$$;

-- After anything that can count for a challenge.
create or replace function public.on_challenge_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  if tg_table_name = 'messages' then
    if new.sender <> 'user' then
      return new;
    end if;
    select user_id into v_user from public.chat_sessions where id = new.session_id;
  else
    v_user := new.user_id;
  end if;
  if v_user is not null then
    perform public.evaluate_challenge(v_user);
  end if;
  return new;
end
$$;

-- Named "zz_..." so they run after the XP and badge triggers.
create trigger zz_challenge_mood after insert on public.mood_logs
  for each row execute function public.on_challenge_activity();
create trigger zz_challenge_message after insert on public.messages
  for each row execute function public.on_challenge_activity();
create trigger zz_challenge_read after insert on public.resource_reads
  for each row execute function public.on_challenge_activity();
create trigger zz_challenge_activity after insert on public.wellbeing_activities
  for each row execute function public.on_challenge_activity();

create or replace function public.start_challenge(p_challenge text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_days integer;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  select days into v_days from public.challenges where id = p_challenge and active;
  if v_days is null then
    raise exception 'unknown challenge' using errcode = '22023';
  end if;
  if exists (select 1 from public.challenge_runs
              where user_id = v_user and completed_at is null
                and left_at is null and ends_at > now()) then
    raise exception 'a challenge is already running' using errcode = '23P01';
  end if;
  -- Today counts as day 1; it ends at midnight after the last day.
  insert into public.challenge_runs (user_id, challenge_id, ends_at)
  values (v_user, p_challenge,
          public.nairobi_midnight(public.local_date(now()) + v_days));
  -- Things already done today count straight away.
  perform public.evaluate_challenge(v_user);
end
$$;

create or replace function public.leave_challenge()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  update public.challenge_runs
     set left_at = now()
   where user_id = auth.uid() and completed_at is null and left_at is null
     and ends_at > now();
end
$$;

-- Everything the app shows about challenges, for the signed-in user.
create or replace function public.my_challenges()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user   uuid := auth.uid();
  v_list   jsonb;
  v_active jsonb;
  v_recent jsonb;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'emoji', c.emoji, 'title', c.title, 'title_sw', c.title_sw,
           'description', c.description, 'description_sw', c.description_sw,
           'days', c.days, 'xp', c.xp, 'badge_id', c.badge_id, 'steps', c.steps,
           'completed', (select count(*) from public.challenge_runs r
                          where r.user_id = v_user and r.challenge_id = c.id
                            and r.completed_at is not null))
           order by c.sort_order), '[]')
    into v_list
    from public.challenges c
   where c.active;

  select jsonb_build_object('id', r.id, 'challenge_id', r.challenge_id,
                            'started_at', r.started_at, 'ends_at', r.ends_at,
                            'steps', public.challenge_progress(r.id))
    into v_active
    from public.challenge_runs r
   where r.user_id = v_user and r.completed_at is null and r.left_at is null
     and r.ends_at > now()
   order by r.started_at desc
   limit 1;

  -- Finished in the last 3 days: shown as a celebration on Home.
  select jsonb_build_object('challenge_id', r.challenge_id,
                            'completed_at', r.completed_at)
    into v_recent
    from public.challenge_runs r
   where r.user_id = v_user and r.completed_at > now() - interval '3 days'
   order by r.completed_at desc
   limit 1;

  return jsonb_build_object('challenges', v_list, 'active', v_active,
                            'recent', v_recent);
end
$$;

revoke execute on function public.nairobi_midnight(date) from public, anon, authenticated;
revoke execute on function public.challenge_progress(uuid) from public, anon, authenticated;
revoke execute on function public.evaluate_challenge(uuid) from public, anon, authenticated;
revoke execute on function public.on_challenge_activity() from public, anon, authenticated;
revoke execute on function public.start_challenge(text) from public, anon;
revoke execute on function public.leave_challenge() from public, anon;
revoke execute on function public.my_challenges() from public, anon;
grant execute on function public.start_challenge(text) to authenticated;
grant execute on function public.leave_challenge() to authenticated;
grant execute on function public.my_challenges() to authenticated;
