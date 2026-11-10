-- "Other" is a valid answer to "How old are you?" (for example, people outside 15-24 who do not want to say which range).
alter table public.profiles drop constraint if exists profiles_age_range_check;
alter table public.profiles add constraint profiles_age_range_check
  check (age_range in ('under_15', '15_17', '18_20', '21_24', '25_plus', 'other', 'prefer_not'));
