-- XP awards are stamped with the time of the action that earned them, so the
-- daily chat cap and weekly reports use the same day as the action itself
-- (this matters for mood entries that sync later from offline use).

drop function public.award_xp(uuid, text, integer);

create function public.award_xp(p_user uuid, p_reason text, p_amount integer, p_at timestamptz default now())
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.xp_events (user_id, reason, amount, created_at)
  values (p_user, p_reason, p_amount, p_at);
  update public.profiles
     set xp = xp + p_amount,
         level = public.level_for_xp(xp + p_amount)
   where id = p_user;
end
$$;

create or replace function public.on_mood_logged()
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
    perform public.award_xp(new.user_id, 'mood_checkin', 10, new.created_at);
  end if;

  select count(distinct public.local_date(created_at)) into v_days
    from public.mood_logs
   where user_id = new.user_id
     and public.local_date(created_at) between v_week_start and v_week_start + 6;

  if v_days >= 5 then
    insert into public.quest_completions (user_id, quest, week_start)
    values (new.user_id, 'weekly_checkins', v_week_start)
    on conflict do nothing;
    if found then
      perform public.award_xp(new.user_id, 'weekly_quest', 25, new.created_at);
    end if;
  end if;

  perform public.evaluate_badges(new.user_id);
  return new;
end
$$;

create or replace function public.on_message_saved()
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
    perform public.award_xp(v_user, 'chat_message', 2, new.created_at);
  end if;

  perform public.evaluate_badges(v_user);
  return new;
end
$$;

create or replace function public.on_resource_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.award_xp(new.user_id, 'article_read', 5, new.read_at);
  perform public.evaluate_badges(new.user_id);
  return new;
end
$$;

revoke execute on function public.award_xp(uuid, text, integer, timestamptz) from public, anon, authenticated;
