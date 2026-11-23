-- =============================================================================
-- Xadiith App — catalogue v2, part 8: editorial review checks (STEP 05).
--
-- A hadith passes through separate human checks before it can be verified:
--   1. source  — the record matches the cited edition / identifier / number
--   2. arabic  — the Arabic text (and vowelized text, if any) matches the source
-- Translations and gradings keep their own status and are reviewed on their
-- own rows (translations.status, gradings.status).
--
-- The editorial stage of every record is DERIVED (view hadith_review_queue):
--   imported → pending_source_verification → pending_arabic_review →
--   pending_translation_review → pending_grading_verification →
--   ready_to_verify → verified → published   (+ needs_correction, rejected)
--
-- Rules enforced here:
--   * checks are recorded only through record_review_check(), by a
--     reviewer/admin, with a note; the table is append-only (audit trail);
--   * a hadith can become 'verified' only when its LATEST source and arabic
--     checks both passed;
--   * a failed check moves a pending hadith to 'needs_correction'.
-- Same authentication rule as the fixed review_record() (migration
-- 20261120000007): session_user, never current_user.
-- Additive only.
-- =============================================================================

create table if not exists public.hadith_review_checks (
  id          bigint generated always as identity primary key,
  hadith_id   uuid not null references public.hadiths (id) on delete cascade,
  check_kind  text not null check (check_kind in ('source', 'arabic')),
  passed      boolean not null,
  reviewer    uuid not null references auth.users (id) on delete restrict,
  note        text not null check (btrim(note) <> ''),
  created_at  timestamptz not null default now()
);

create index if not exists hadith_review_checks_idx on public.hadith_review_checks (hadith_id, check_kind, created_at desc);

alter table public.hadith_review_checks enable row level security;
drop policy if exists "staff read" on public.hadith_review_checks;
create policy "staff read" on public.hadith_review_checks for select to authenticated using (public.is_staff());
revoke all on public.hadith_review_checks from anon, authenticated;
grant select on public.hadith_review_checks to authenticated;

-- Latest result per (hadith, check).
create or replace function public.hadith_check_passed(p_hadith uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select c.passed from public.hadith_review_checks c
    where c.hadith_id = p_hadith and c.check_kind = p_kind
    order by c.created_at desc, c.id desc
    limit 1
  ), false)
$$;
revoke all on function public.hadith_check_passed(uuid, text) from public, anon;
grant execute on function public.hadith_check_passed(uuid, text) to authenticated;

-- Block 'verified' until both checks passed (runs for every path, including
-- review_record()).
create or replace function public.require_hadith_checks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'verified' and old.status is distinct from 'verified' then
    if not public.hadith_check_passed(new.id, 'source') then
      raise exception 'Hadith % cannot be verified: source check has not passed.', new.id
        using errcode = 'check_violation';
    end if;
    if not public.hadith_check_passed(new.id, 'arabic') then
      raise exception 'Hadith % cannot be verified: Arabic text check has not passed.', new.id
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists require_hadith_checks on public.hadiths;
create trigger require_hadith_checks before update of status on public.hadiths
  for each row execute function public.require_hadith_checks();

-- The only way to record a check.
--   select public.record_review_check('<hadith id>', 'source', true, 'Matches <edition>, vol/page, no. 1');
-- From the SQL editor (no signed-in user) pass the reviewer's user id as the
-- last argument.
create or replace function public.record_review_check(
  p_hadith    uuid,
  p_kind      text,
  p_passed    boolean,
  p_note      text,
  p_reviewer  uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer uuid := auth.uid();
  current_status public.content_status;
  new_id bigint;
begin
  if p_kind not in ('source', 'arabic') then
    raise exception 'Unknown check %', p_kind using errcode = 'invalid_parameter_value';
  end if;
  if p_note is null or btrim(p_note) = '' then
    raise exception 'A note describing what was checked against which source is required.'
      using errcode = 'invalid_parameter_value';
  end if;

  if reviewer is null then
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
    raise exception 'Only reviewers or admins may record review checks.' using errcode = 'insufficient_privilege';
  end if;

  select h.status into current_status from public.hadiths h where h.id = p_hadith for update;
  if not found then
    raise exception 'hadith % not found', p_hadith using errcode = 'no_data_found';
  end if;
  if current_status in ('verified', 'published', 'rejected') then
    raise exception 'Hadith % is %; move it to needs_correction (or resubmit) before new checks.', p_hadith, current_status
      using errcode = 'check_violation';
  end if;

  insert into public.hadith_review_checks (hadith_id, check_kind, passed, reviewer, note)
  values (p_hadith, p_kind, p_passed, reviewer, p_note)
  returning id into new_id;

  -- Queue it for review on first check; a failed check sends it back.
  perform set_config('app.review_context', 'on', true);
  perform set_config('app.reviewer_id', reviewer::text, true);
  perform set_config('app.review_note', p_kind || ' check ' || case when p_passed then 'passed: ' else 'failed: ' end || p_note, true);
  if current_status = 'imported' then
    update public.hadiths set status = 'pending_review' where id = p_hadith;
    current_status := 'pending_review';
  end if;
  if not p_passed and current_status = 'pending_review' then
    update public.hadiths set status = 'needs_correction' where id = p_hadith;
  end if;
  perform set_config('app.review_context', '', true);
  perform set_config('app.reviewer_id', '', true);
  perform set_config('app.review_note', '', true);
  return new_id;
end $$;

revoke all on function public.record_review_check(uuid, text, boolean, text, uuid) from public, anon;
do $$ begin
  execute 'revoke all on function public.record_review_check(uuid, text, boolean, text, uuid) from service_role';
exception when undefined_object then null;
end $$;
grant execute on function public.record_review_check(uuid, text, boolean, text, uuid) to authenticated;

-- Editorial queue for staff (RLS of the base tables applies: non-staff see
-- only published rows, which are never "pending").
create or replace view public.hadith_review_queue
with (security_invoker = true)
as
select
  h.id,
  h.collection_id,
  h.numbering_scheme,
  h.hadith_number,
  h.source_name,
  h.source_identifier,
  h.status,
  case
    when h.status in ('verified', 'published', 'rejected', 'needs_correction') then h.status::text
    when not public.hadith_check_passed(h.id, 'source') then
      case when h.status = 'imported' then 'imported' else 'pending_source_verification' end
    when not public.hadith_check_passed(h.id, 'arabic') then 'pending_arabic_review'
    when exists (select 1 from public.translations t
                 where t.hadith_id = h.id and t.status in ('imported', 'pending_review', 'needs_correction'))
      then 'pending_translation_review'
    when exists (select 1 from public.gradings g
                 where g.hadith_id = h.id and g.status in ('imported', 'pending_review', 'needs_correction'))
      then 'pending_grading_verification'
    else 'ready_to_verify'
  end as editorial_stage,
  (select count(*) from public.translations t where t.hadith_id = h.id and t.status = 'published') as published_translations,
  (select count(*) from public.gradings g where g.hadith_id = h.id and g.status = 'published') as published_gradings,
  (h.source_url is null and h.source_identifier is null) as missing_source_reference,
  h.import_batch_id,
  h.updated_at
from public.hadiths h;

revoke all on public.hadith_review_queue from anon, authenticated;
grant select on public.hadith_review_queue to authenticated;

-- catalog_counts (migration 20261121000007): keep read-only like the other views.
revoke all on public.catalog_counts from anon, authenticated;
grant select on public.catalog_counts to anon, authenticated;
