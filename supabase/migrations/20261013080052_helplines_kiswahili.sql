-- Kiswahili descriptions for the helplines, so the crisis sheet and the
-- Support screen can show them in the user's language.
alter table public.helplines add column if not exists description_sw text;

update public.helplines set description_sw = 'Bila malipo, saa 24'
  where name = 'Kenya Red Cross';
update public.helplines set description_sw = 'Simu ya msaada wa kihisia'
  where name = 'Befrienders Kenya';
update public.helplines set description_sw = 'Kwa walio chini ya miaka 18, bila malipo'
  where name = 'Childline Kenya';
