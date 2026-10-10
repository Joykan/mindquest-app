-- "New chat" in the app: a user can end their own open chat session.
-- Only ended_at can be set, only once, and only on their own sessions.
-- Sessions and messages are still created by the chat Edge Function.

revoke insert, update, delete on public.chat_sessions from anon, authenticated;
grant update (ended_at) on public.chat_sessions to authenticated;

create policy "Users end their own chat sessions" on public.chat_sessions
  for update to authenticated
  using (user_id = (select auth.uid()) and ended_at is null)
  with check (user_id = (select auth.uid()) and ended_at is not null);
