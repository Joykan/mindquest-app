-- Onboarding: the user picks a nickname and language and agrees to the
-- privacy note. consent_at records when they agreed (Kenya Data Protection
-- Act 2019: consent must be recorded). A profile with consent_at set has
-- finished onboarding.

alter table public.profiles add column consent_at timestamptz;

comment on column public.profiles.consent_at is
  'When the user agreed to the privacy note during onboarding. Null = not onboarded yet.';

-- Saves the onboarding choices for the signed-in user. consent_at uses the
-- server clock and keeps the first time consent was given.
create or replace function public.complete_onboarding(p_username text, p_language text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  update public.profiles
     set username   = btrim(p_username),
         language   = p_language,
         consent_at = coalesce(consent_at, now())
   where id = auth.uid();
end
$$;

grant update (consent_at) on public.profiles to authenticated;
grant execute on function public.complete_onboarding(text, text) to authenticated;
