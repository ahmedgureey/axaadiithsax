-- =============================================================================
-- Xadiith App — catalogue v2, part 7: security fixes found in the STEP 03
-- review (2026-11-20). Additive / replace-only; no data is touched.
--
-- 1. review_record(): the "no signed-in user" branch checked current_user,
--    which inside a SECURITY DEFINER function is always the function owner
--    (postgres). Any caller without auth.uid() — notably service_role (the
--    secret key used by the import script, which Supabase grants EXECUTE on
--    public functions by default) — could therefore verify/publish by naming
--    any reviewer's id. The branch now checks session_user (the role that
--    opened the connection): PostgREST/API calls always connect as
--    'authenticator', so only a direct owner connection (SQL editor) passes.
--    EXECUTE is also revoked from service_role explicitly.
-- 2. narrators get import_batch_id like hadiths/translations/gradings, so
--    every imported row is traceable to its batch.
-- 3. hadith_list_items: revoke Supabase's default ALL grant, keep SELECT.
--
-- Rollback: re-apply 20261120000003_review_workflow.sql (restores the old
-- function body), then:
--   alter table public.narrators drop column if exists import_batch_id;
-- =============================================================================

create or replace function public.review_record(
  p_entity    text,
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
  tbl text := case p_entity when 'hadith' then 'hadiths' when 'translation' then 'translations'
                            when 'grading' then 'gradings' when 'narrator' then 'narrators' end;
  who_col text := case p_entity when 'hadith' then 'verified_by' when 'narrator' then 'verified_by' else 'reviewed_by' end;
  when_col text := case p_entity when 'hadith' then 'verified_at' when 'narrator' then 'verified_at' else 'reviewed_at' end;
  found_rows integer;
begin
  if tbl is null then
    raise exception 'Unknown entity %', p_entity using errcode = 'invalid_parameter_value';
  end if;
  if p_to in ('verified', 'published') and (p_note is null or btrim(p_note) = '') then
    raise exception 'A note citing the checked source is required to verify or publish.'
      using errcode = 'invalid_parameter_value';
  end if;

  if reviewer is null then
    -- Dashboard / SQL editor only. session_user is the login role and is NOT
    -- changed by SECURITY DEFINER (current_user is). API requests log in as
    -- 'authenticator', so they can never act for a named reviewer.
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

  perform set_config('app.review_context', 'on', true);
  perform set_config('app.reviewer_id', reviewer::text, true);
  perform set_config('app.review_note', coalesce(p_note, ''), true);

  execute format(
    'update public.%I set status = $1,
       %I = case when $1 = ''verified'' then $2 else %I end,
       %I = case when $1 = ''verified'' then now() else %I end
       %s
     where id = $3',
    tbl, who_col, who_col, when_col, when_col,
    case when tbl = 'hadiths'
      then ', published_at = case when $1 = ''published'' then now() when $1 = ''needs_correction'' then null else published_at end'
      else '' end
  ) using p_to, reviewer, p_id;
  get diagnostics found_rows = row_count;

  perform set_config('app.review_context', '', true);
  perform set_config('app.reviewer_id', '', true);
  perform set_config('app.review_note', '', true);
  if found_rows = 0 then
    raise exception '% % not found', p_entity, p_id using errcode = 'no_data_found';
  end if;
  return p_to;
end $$;

revoke all on function public.review_record(text, uuid, public.content_status, text, uuid) from public, anon;
do $$ begin
  execute 'revoke all on function public.review_record(text, uuid, public.content_status, text, uuid) from service_role';
exception when undefined_object then null;  -- role exists only on Supabase
end $$;
grant execute on function public.review_record(text, uuid, public.content_status, text, uuid) to authenticated;

-- 2. provenance for narrators
alter table public.narrators add column if not exists import_batch_id uuid
  references public.import_batches (id) on delete restrict;
create index if not exists narrators_import_batch_idx on public.narrators (import_batch_id);

-- 3. read-only view
revoke all on public.hadith_list_items from anon, authenticated;
grant select on public.hadith_list_items to anon, authenticated;
