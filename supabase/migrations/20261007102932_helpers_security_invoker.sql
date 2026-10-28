-- is_admin() and is_staff() only read the caller's own profile row, which RLS
-- already allows, so they do not need elevated rights.
alter function public.is_admin() security invoker;
alter function public.is_staff() security invoker;
