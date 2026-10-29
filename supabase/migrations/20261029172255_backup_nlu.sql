-- Backup NLU: when the Rasa server can't be reached, the chat function reads
-- the message with a small built-in model (supabase/functions/chat/backup_nlu.ts)
-- so Chipu still answers. Each bot reply records which one read the message,
-- and the admin dashboard counts the replies the backup handled (how often
-- Rasa was down, for NFR-SPEC-02).

alter table public.messages
  add column nlu_source text check (nlu_source in ('rasa', 'backup'));
comment on column public.messages.nlu_source is
  'Bot replies: rasa or backup (the built-in model, used when Rasa was unreachable).';

-- Same as in 20261014122222_age_range, plus backup_replies.
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
  -- Averages from fewer check-ins than this are hidden (null): with only a
  -- few students, an average could reveal how one person felt.
  v_min    constant integer := 5;
begin
  if not public.is_staff() then
    raise exception 'Only administrators and counsellors can view statistics'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'days',            v_days,
    'from',            v_first,
    'to',              v_today,
    'min_group',       v_min,

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
    'average_mood',    (select case when count(*) >= v_min then round(avg(mood)::numeric, 2) end
                          from public.mood_logs where logged_at >= v_since),
    'articles_read',   (select count(*) from public.resource_reads where read_at >= v_since),
    'badges_awarded',  (select count(*) from public.user_badges where earned_at >= v_since),
    'crisis_events',   (select count(*) from public.crisis_events where created_at >= v_since),

    -- One row per day, oldest first, including days with nothing.
    'daily',           (select coalesce(jsonb_agg(d order by d.day), '[]'::jsonb) from (
                          select g.day,
                                 (select count(*) from public.mood_logs m
                                   where public.local_date(m.logged_at) = g.day) as check_ins,
                                 (select case when count(*) >= v_min then round(avg(m.mood)::numeric, 2) end
                                    from public.mood_logs m
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
                          select tag, count(*) as check_ins,
                                 case when count(*) >= v_min then round(avg(mood)::numeric, 2) end as average_mood
                            from public.mood_logs, unnest(tags) as tag
                           where logged_at >= v_since
                           group by tag) t),

    -- What students talk to Chipu about: intents of their messages (labels only).
    'topics',          (select coalesce(jsonb_object_agg(intent, n), '{}'::jsonb) from (
                          select intent, count(*) n from public.messages
                           where sender = 'user' and intent is not null and created_at >= v_since
                           group by intent) i),

    -- Reply time on the server (NFR-SPEC-01: under 2 s for 95% of messages).
    'reply_count',     (select count(*) from public.messages
                         where sender = 'bot' and response_ms is not null and created_at >= v_since),
    'reply_median_ms', (select round(percentile_cont(0.5) within group (order by response_ms))::integer
                          from public.messages
                         where sender = 'bot' and response_ms is not null and created_at >= v_since),
    'reply_p95_ms',    (select round(percentile_cont(0.95) within group (order by response_ms))::integer
                          from public.messages
                         where sender = 'bot' and response_ms is not null and created_at >= v_since),
    'reply_within_2s', (select round(avg(case when response_ms <= 2000 then 1 else 0 end)::numeric, 3)
                          from public.messages
                         where sender = 'bot' and response_ms is not null and created_at >= v_since),

    -- How often Chipu didn't understand, and how often the NLU server was down.
    'not_understood',  (select count(*) from public.messages
                         where sender = 'user' and intent = 'fallback' and created_at >= v_since),
    'unavailable',     (select count(*) from public.messages
                         where sender = 'bot' and reply_key = 'unavailable' and created_at >= v_since),
    -- Replies read by the backup model because Rasa couldn't be reached.
    'backup_replies',  (select count(*) from public.messages
                         where sender = 'bot' and nlu_source = 'backup' and created_at >= v_since),

    'language_split',  (select coalesce(jsonb_object_agg(language, n), '{}'::jsonb) from (
                          select language, count(*) n from public.profiles
                           where role = 'user' group by language) l),

    -- Age ranges chosen at sign-up ('not_asked' for accounts made before).
    'age_split',       (select coalesce(jsonb_object_agg(a, n), '{}'::jsonb) from (
                          select coalesce(age_range, 'not_asked') a, count(*) n from public.profiles
                           where role = 'user' group by 1) g),

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
