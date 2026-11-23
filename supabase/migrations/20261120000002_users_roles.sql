-- =============================================================================
-- Xadiith App — catalogue v2, part 2: user data and staff roles.
--
-- Minimal personal data: Supabase Auth already holds the e-mail; we keep only
-- an optional display name, bookmarks and (optional) reading history.
-- Deleting the auth user deletes all of it (on delete cascade).
-- =============================================================================

create table if not exists public.profiles (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  display_name  text check (display_name is null or char_length(btrim(display_name)) between 1 and 40),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.bookmarks (
  user_id     uuid not null references auth.users (id) on delete cascade,
  hadith_id   uuid not null references public.hadiths (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, hadith_id)                      -- no duplicate bookmarks
);

create table if not exists public.reading_history (
  user_id       uuid not null references auth.users (id) on delete cascade,
  hadith_id     uuid not null references public.hadiths (id) on delete cascade,
  last_read_at  timestamptz not null default now(),
  primary key (user_id, hadith_id)
);

-- Staff roles. Granted only by an admin with SQL (see docs); never from the app.
create table if not exists public.user_roles (
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        public.app_role not null,
  granted_by  uuid references auth.users (id) on delete set null,
  granted_at  timestamptz not null default now(),
  primary key (user_id, role)
);

create index if not exists bookmarks_user_idx        on public.bookmarks (user_id, created_at desc);
create index if not exists bookmarks_hadith_idx      on public.bookmarks (hadith_id);
create index if not exists reading_history_user_idx  on public.reading_history (user_id, last_read_at desc);
create index if not exists reading_history_hadith_idx on public.reading_history (hadith_id);

drop trigger if exists set_updated_at on public.profiles;
create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Role checks used by RLS and the review functions. SECURITY DEFINER so they
-- can read user_roles without exposing it; search_path pinned.
create or replace function public.has_role(wanted public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = auth.uid() and (r.role = wanted or r.role = 'admin')
  )
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.user_roles r where r.user_id = auth.uid())
$$;

revoke all on function public.has_role(public.app_role) from public;
revoke all on function public.is_staff() from public;
grant execute on function public.has_role(public.app_role) to anon, authenticated;
grant execute on function public.is_staff() to anon, authenticated;
