-- Tappable answers: some of Chipu's questions come with answers to tap
-- (School, Money, ... / Yes, please). A tapped answer is read without a
-- model, so its bot reply records nlu_source 'tap'.
alter table public.messages drop constraint messages_nlu_source_check;
alter table public.messages
  add constraint messages_nlu_source_check check (nlu_source in ('rasa', 'backup', 'tap'));
comment on column public.messages.nlu_source is
  'Bot replies: rasa, backup (the built-in model, used when Rasa was unreachable) or tap (a tapped answer, read without a model). Null for Chipu''s check-in that opens a chat.';
