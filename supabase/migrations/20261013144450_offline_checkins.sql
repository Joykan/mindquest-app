-- Step 10: mood check-ins made without internet.
--
-- The app saves a check-in on the phone when there is no connection and sends
-- it later (up to 7 days, see the mood_logs check constraint). The check-in
-- must then count for the day it was made (logged_at), not the day it reached
-- the server (created_at).

-- 1. The app gives each check-in its own id. If the connection drops after the
--    check-in was saved but before the app heard back, the app sends it again;
--    the second copy is rejected as a duplicate instead of being saved twice.
grant insert (id) on public.mood_logs to authenticated;

-- 2. XP, streak and the weekly quest use the check-in's own time.
--    The streak is worked out from the check-in days (the mood_checkin XP
--    events, which are never deleted), so a check-in that arrives late still
--    fills its day, and deleting a check-in keeps the streak as before.
create or replace function public.on_mood_logged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day         date := public.local_date(new.logged_at);
  v_week_start  date := v_day - (extract(isodow from v_day)::integer - 1);
  v_latest      date;
  v_streak      integer := 0;
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

  -- Streak: days in a row with a check-in, counting back from the latest one.
  select max(public.local_date(created_at)) into v_latest
    from public.xp_events
   where user_id = new.user_id and reason = 'mood_checkin';

  while exists (
    select 1 from public.xp_events
     where user_id = new.user_id
       and reason = 'mood_checkin'
       and public.local_date(created_at) = v_latest - v_streak
  ) loop
    v_streak := v_streak + 1;
  end loop;

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
