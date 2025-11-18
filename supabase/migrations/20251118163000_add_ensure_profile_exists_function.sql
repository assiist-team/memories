-- Migration: Ensure profile exists RPC
-- Description: Adds a SECURITY DEFINER helper that creates a profile row
--              for the currently authenticated user when it is missing.

create or replace function public.ensure_profile_exists(target_user_id uuid default null)
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  effective_user_id uuid := coalesce(target_user_id, auth.uid());
  profile_row public.profiles%rowtype;
  user_email text;
  user_metadata jsonb;
begin
  if auth.uid() is null then
    raise exception 'Missing authenticated user context';
  end if;

  if effective_user_id is null then
    raise exception 'Missing target user id';
  end if;

  if effective_user_id <> auth.uid() then
    raise exception 'Cannot create profile for a different user';
  end if;

  select *
    into profile_row
    from public.profiles
   where id = effective_user_id;

  if found then
    return profile_row;
  end if;

  select email, raw_user_meta_data
    into user_email, user_metadata
    from auth.users
   where id = effective_user_id;

  if user_email is null then
    raise exception 'User record missing for id %', effective_user_id;
  end if;

  user_metadata := coalesce(user_metadata, '{}'::jsonb);

  insert into public.profiles (id, name)
  values (
    effective_user_id,
    coalesce(
      user_metadata->>'name',
      user_metadata->>'full_name',
      split_part(user_email, '@', 1)
    )
  )
  returning * into profile_row;

  return profile_row;
end;
$$;

grant execute on function public.ensure_profile_exists(uuid) to authenticated;

