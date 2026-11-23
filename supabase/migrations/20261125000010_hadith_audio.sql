-- =============================================================================
-- Xadiith App — catalogue v2, part 10: Arabic recitation audio metadata.
--
-- * hadith_audio: one row per recording, linked to a hadith. Only METADATA is
--   stored here (URL / storage path, reciter, source, licence, duration);
--   the audio itself lives in Supabase Storage or at the licensed source.
--   The hadith text, translations, gradings are not touched.
-- * New rows start as 'imported'. They become visible to the app only after
--   a reviewer verifies (source, licence, correct hadith, complete audio,
--   wording matches the Arabic text) and publishes them via review_audio().
--   Direct status changes to verified/published are blocked.
-- * RLS: everyone reads published audio of published hadith; staff read all.
--   No table writes from the app (inserts: SQL editor / import with the
--   secret key, which never ships in the app).
-- Additive. Rollback: supabase/rollback/20261120_v2_down.sql.
-- =============================================================================

create table if not exists public.hadith_audio (
  id                uuid primary key default gen_random_uuid(),
  hadith_id         uuid not null references public.hadiths (id) on delete cascade,
  audio_url         text not null check (audio_url ~ '^https://'),
  storage_path      text,                                   -- Supabase Storage object, if hosted there
  reciter           text not null check (btrim(reciter) <> ''),
  source_name       text not null check (btrim(source_name) <> ''),
  source_url        text check (source_url is null or source_url ~ '^https?://'),
  license           text not null check (btrim(license) <> ''),  -- licence or written permission reference
  duration_seconds  numeric check (duration_seconds is null or duration_seconds > 0),
  language          text not null default 'ar' check (language = 'ar'),
  is_primary        boolean not null default true,
  status            public.content_status not null default 'imported',
  verified_by       uuid references auth.users (id) on delete set null,
  verified_at       timestamptz,
  review_notes      text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (status not in ('verified', 'published') or (verified_by is not null and verified_at is not null))
);

create unique index if not exists hadith_audio_one_primary_idx
  on public.hadith_audio (hadith_id) where is_primary;
create index if not exists hadith_audio_published_idx
  on public.hadith_audio (hadith_id) where status = 'published';

drop trigger if exists set_updated_at on public.hadith_audio;
create trigger set_updated_at before update on public.hadith_audio
  for each row execute function public.set_updated_at();

-- Status changes to verified/published only through review_audio().
create or replace function public.guard_audio_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status in ('verified', 'published')
     and (tg_op = 'INSERT' or new.status is distinct from old.status)
     and coalesce(current_setting('app.review_context', true), '') <> 'on' then
    raise exception 'Use review_audio() to verify or publish audio.' using errcode = 'insufficient_privilege';
  end if;
  -- Published audio is locked: changing what is played needs a new review.
  if tg_op = 'UPDATE' and old.status = 'published'
     and (new.audio_url, new.storage_path, new.hadith_id, new.reciter, new.license)
         is distinct from (old.audio_url, old.storage_path, old.hadith_id, old.reciter, old.license)
     and coalesce(current_setting('app.review_context', true), '') <> 'on' then
    raise exception 'Published audio is locked; set it back to needs_correction via review_audio() first.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end $$;

drop trigger if exists guard_audio_status on public.hadith_audio;
create trigger guard_audio_status before insert or update on public.hadith_audio
  for each row execute function public.guard_audio_status();

create or replace function public.review_audio(
  p_id        uuid,
  p_to        public.content_status,
  p_note      text default null,
  p_reviewer  uuid default null
)
returns public.content_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer uuid := auth.uid();
  found_rows integer;
begin
  if p_to in ('verified', 'published') and (p_note is null or btrim(p_note) = '') then
    raise exception 'A note is required (licence checked, hadith number, audio complete, wording matches).'
      using errcode = 'invalid_parameter_value';
  end if;
  if reviewer is null then
    -- SQL editor only (same rule as review_record, migration 0007).
    if session_user::text not in ('postgres', 'supabase_admin') then
      raise exception 'Not signed in' using errcode = 'insufficient_privilege';
    end if;
    reviewer := p_reviewer;
  elsif p_reviewer is not null and p_reviewer <> reviewer then
    raise exception 'Signed-in reviewers act only as themselves.' using errcode = 'insufficient_privilege';
  end if;
  if reviewer is null or not exists (
    select 1 from public.user_roles r where r.user_id = reviewer and r.role in ('reviewer', 'admin')
  ) then
    raise exception 'Only reviewers or admins may change review status.' using errcode = 'insufficient_privilege';
  end if;
  if p_to = 'published' and not exists (
    select 1 from public.hadith_audio a where a.id = p_id and a.status = 'verified'
  ) then
    raise exception 'Audio must be verified before it is published.' using errcode = 'check_violation';
  end if;

  perform set_config('app.review_context', 'on', true);
  update public.hadith_audio
     set status = p_to,
         verified_by = case when p_to = 'verified' then reviewer
                            when p_to in ('imported', 'pending_review', 'needs_correction', 'rejected') then null
                            else verified_by end,
         verified_at = case when p_to = 'verified' then now()
                            when p_to in ('imported', 'pending_review', 'needs_correction', 'rejected') then null
                            else verified_at end,
         review_notes = concat_ws(E'\n', review_notes,
                                  to_char(now(), 'YYYY-MM-DD') || ' ' || p_to || ': ' || coalesce(p_note, ''))
   where id = p_id;
  get diagnostics found_rows = row_count;
  perform set_config('app.review_context', '', true);
  if found_rows = 0 then
    raise exception 'audio % not found', p_id using errcode = 'no_data_found';
  end if;
  return p_to;
end $$;

revoke all on function public.review_audio(uuid, public.content_status, text, uuid) from public, anon;
do $$ begin
  execute 'revoke all on function public.review_audio(uuid, public.content_status, text, uuid) from service_role';
exception when undefined_object then null;
end $$;
grant execute on function public.review_audio(uuid, public.content_status, text, uuid) to authenticated;

alter table public.hadith_audio enable row level security;
drop policy if exists "read published" on public.hadith_audio;
create policy "read published" on public.hadith_audio for select to anon, authenticated
  using (
    public.is_staff()
    or (status = 'published'
        and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published'))
  );

revoke all on public.hadith_audio from anon, authenticated;
grant select on public.hadith_audio to anon, authenticated;
