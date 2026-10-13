-- Step 11: admin dashboard (FR 7, UC-06).
--
-- The dashboard only ever sees totals. It never shows a student's messages,
-- notes, or individual check-ins, and it doesn't say who had a crisis.
-- Admins manage articles and helplines through the tables (row-level
-- security already allows only admins). Counsellors see the statistics only.

-- 1. Statistics for the Overview page, for the last p_days days (Nairobi
--    days, today included). Check-ins count by when they were made.
create or replace function public.admin_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days   integer := least(greatest(coalesce(p_days, 7), 1), 365);
  v_today  date := public.local_date(now());
  v_first  date := v_today - (v_days - 1);
  v_since  timestamptz := v_first::timestamp at time zone 'Africa/Nairobi';
begin
  if not public.is_staff() then
    raise exception 'Only administrators and counsellors can view statistics'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'days',            v_days,
    'from',            v_first,
    'to',              v_today,

    -- Students (staff accounts are not counted).
    'users',           (select count(*) from public.profiles where role = 'user'),
    'new_users',       (select count(*) from public.profiles
                         where role = 'user' and created_at >= v_since),
    'saved_accounts',  (select count(*) from public.profiles p join auth.users u on u.id = p.id
                         where p.role = 'user' and not coalesce(u.is_anonymous, false)),
    'active_users',    (select count(distinct user_id) from (
                          select user_id from public.mood_logs where logged_at >= v_since
                          union
                          select user_id from public.chat_sessions where started_at >= v_since
                          union
                          select user_id from public.resource_reads where read_at >= v_since
                        ) a),

    -- Activity in the period.
    'chat_sessions',   (select count(*) from public.chat_sessions where started_at >= v_since),
    'messages',        (select count(*) from public.messages
                         where sender = 'user' and created_at >= v_since),
    'mood_entries',    (select count(*) from public.mood_logs where logged_at >= v_since),
    'average_mood',    (select round(avg(mood)::numeric, 2) from public.mood_logs
                         where logged_at >= v_since),
    'articles_read',   (select count(*) from public.resource_reads where read_at >= v_since),
    'badges_awarded',  (select count(*) from public.user_badges where earned_at >= v_since),
    'crisis_events',   (select count(*) from public.crisis_events where created_at >= v_since),

    -- One row per day, oldest first, including days with nothing.
    'daily',           (select coalesce(jsonb_agg(d order by d.day), '[]'::jsonb) from (
                          select g.day,
                                 (select count(*) from public.mood_logs m
                                   where public.local_date(m.logged_at) = g.day) as check_ins,
                                 (select round(avg(m.mood)::numeric, 2) from public.mood_logs m
                                   where public.local_date(m.logged_at) = g.day) as average_mood,
                                 (select count(*) from public.chat_sessions s
                                   where public.local_date(s.started_at) = g.day) as chats,
                                 (select count(*) from public.crisis_events c
                                   where public.local_date(c.created_at) = g.day) as crisis_events
                            from (select v_first + i as day
                                    from generate_series(0, v_days - 1) as i) g
                        ) d),

    -- How students felt: check-ins per mood (1 = very low ... 5 = very good).
    'mood_split',      (select coalesce(jsonb_object_agg(mood, n), '{}'::jsonb) from (
                          select mood, count(*) n from public.mood_logs
                           where logged_at >= v_since group by mood) m),

    -- What check-ins were about (tags), with the average mood for each.
    'mood_tags',       (select coalesce(jsonb_agg(t order by t.check_ins desc, t.tag), '[]'::jsonb) from (
                          select tag, count(*) as check_ins, round(avg(mood)::numeric, 2) as average_mood
                            from public.mood_logs, unnest(tags) as tag
                           where logged_at >= v_since
                           group by tag) t),

    -- What students talk to Chipu about: intents of their messages (labels only).
    'topics',          (select coalesce(jsonb_object_agg(intent, n), '{}'::jsonb) from (
                          select intent, count(*) n from public.messages
                           where sender = 'user' and intent is not null and created_at >= v_since
                           group by intent) i),

    -- How often Chipu didn't understand, and how often the NLU server was down.
    'not_understood',  (select count(*) from public.messages
                         where sender = 'user' and intent = 'fallback' and created_at >= v_since),
    'unavailable',     (select count(*) from public.messages
                         where sender = 'bot' and reply_key = 'unavailable' and created_at >= v_since),

    'language_split',  (select coalesce(jsonb_object_agg(language, n), '{}'::jsonb) from (
                          select language, count(*) n from public.profiles
                           where role = 'user' group by language) l),

    -- Reads of every article (all time) and in the period.
    'article_reads',   (select coalesce(jsonb_agg(a order by a.reads desc, a.id), '[]'::jsonb) from (
                          select r.id, r.title_en as title,
                                 count(rr.resource_id) as reads,
                                 count(rr.resource_id) filter (where rr.read_at >= v_since) as recent
                            from public.resources r
                            left join public.resource_reads rr on rr.resource_id = r.id
                           group by r.id, r.title_en) a)
  );
end
$$;

-- 2. The team: admins and counsellors, with their email (admins only).
create or replace function public.admin_staff()
returns table (id uuid, username text, email text, role text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can manage the team' using errcode = '42501';
  end if;
  return query
    select p.id, p.username, u.email::text, p.role
      from public.profiles p
      join auth.users u on u.id = p.id
     where p.role in ('admin', 'counsellor')
     order by p.role, p.username;
end
$$;

-- 3. Give or remove admin/counsellor access by email (admins only). The
--    person must already have a MindQuest account with that email.
--    Returns their nickname.
create or replace function public.admin_set_role(p_email text, p_role text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_name  text;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can manage the team' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('user', 'admin', 'counsellor') then
    raise exception 'Unknown role' using errcode = '22023';
  end if;

  select u.id into v_id
    from auth.users u
   where lower(u.email) = lower(trim(p_email))
     and not coalesce(u.is_anonymous, false);
  if v_id is null then
    raise exception 'No MindQuest account uses that email. They need to sign up in the app first.'
      using errcode = 'P0002';
  end if;
  if v_id = (select auth.uid()) and p_role <> 'admin' then
    raise exception 'You cannot remove your own admin access.' using errcode = '42501';
  end if;

  update public.profiles set role = p_role where id = v_id
  returning username into v_name;
  return v_name;
end
$$;

revoke execute on function public.admin_staff() from public, anon;
revoke execute on function public.admin_set_role(text, text) from public, anon;
grant execute on function public.admin_staff() to authenticated;
grant execute on function public.admin_set_role(text, text) to authenticated;
