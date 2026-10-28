-- How each chat message was understood, for the admin dashboard and for
-- checking the model during user testing. Written by the chat Edge Function.
--   intent, confidence: user messages (what Rasa read them as; "crisis" when
--                       the keyword check matched; null if Rasa was unreachable)
--   reply_key:          bot messages (which reply was given; the next "yes" or
--                       "no" is read against it, e.g. after a breathing offer)

alter table public.messages
  add column intent     text,
  add column confidence real check (confidence is null or (confidence >= 0 and confidence <= 1)),
  add column reply_key  text;

comment on column public.messages.intent is 'User messages: intent from Rasa, or crisis.';
comment on column public.messages.reply_key is 'Bot messages: which reply was given.';
