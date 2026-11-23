-- =============================================================================
-- Xadiith App — catalogue v2, part 3: verification & publishing workflow.
--
--   imported ─▶ pending_review ─▶ verified ─▶ published
--      │              │   ▲           │           │
--      ▼              ▼   │           ▼           ▼
--   rejected ◀─ needs_correction ◀────┴───────────┘
--
-- * 'verified' and 'published' can ONLY be set through public.review_record(),
--   by a user holding the reviewer or admin role. Direct UPDATEs (dashboard,
--   import script with the secret key) cannot verify or publish anything.
-- * Content of a verified/published record is locked; move it to
--   'needs_correction' first. Every status change is written to review_log.
-- =============================================================================

create or replace function public.status_transition_allowed(from_s public.content_status, to_s public.content_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select from_s = to_s or (from_s, to_s) in (
    ('imported'::public.content_status,         'pending_review'::public.content_status),
    ('imported',         'rejected'),
    ('pending_review',   'verified'),
    ('pending_review',   'needs_correction'),
    ('pending_review',   'rejected'),
    ('needs_correction', 'pending_review'),
    ('needs_correction', 'rejected'),
    ('verified',         'published'),
    ('verified',         'needs_correction'),
    ('published',        'needs_correction'),
    ('rejected',         'pending_review')
  )
$$;

-- Columns that may change on a locked (verified/published) record.
create or replace function public.content_changed(old_row jsonb, new_row jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (old_row - array['status','verified_by','verified_at','reviewed_by','reviewed_at','published_at',
                          'updated_at','created_at','is_primary',
                          'arabic_search','name_ar_search','text_search'])
      is distinct from
         (new_row - array['status','verified_by','verified_at','reviewed_by','reviewed_at','published_at',
                          'updated_at','created_at','is_primary',
                          'arabic_search','name_ar_search','text_search'])
$$;

create or replace function public.guard_content_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  in_review boolean := coalesce(current_setting('app.review_context', true), '') = 'on';
begin
  if tg_op = 'INSERT' then
    if new.status not in ('imported', 'pending_review') then
      raise exception 'New % records must start as imported or pending_review (got %)', tg_table_name, new.status
        using errcode = 'check_violation';
    end if;
    return new;
  end if;

  -- UPDATE
  if new.status is distinct from old.status then
    if not public.status_transition_allowed(old.status, new.status) then
      raise exception 'Status change % -> % is not allowed for %', old.status, new.status, tg_table_name
        using errcode = 'check_violation';
    end if;
    if new.status in ('verified', 'published') and not in_review then
      raise exception 'Use public.review_record() to verify or publish (%).', tg_table_name
        using errcode = 'insufficient_privilege';
    end if;
  end if;

  if old.status in ('verified', 'published')
     and new.status in ('verified', 'published')
     and public.content_changed(to_jsonb(old), to_jsonb(new)) then
    raise exception 'Content of a % % record is locked; set it to needs_correction first.', old.status, tg_table_name
      using errcode = 'check_violation';
  end if;

  return new;
end $$;

create or replace function public.log_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.review_log (entity_type, entity_id, from_status, to_status, actor, note)
    values (
      case tg_table_name when 'hadiths' then 'hadith' when 'translations' then 'translation'
                         when 'gradings' then 'grading' else 'narrator' end,
      new.id,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      coalesce(auth.uid(), nullif(current_setting('app.reviewer_id', true), '')::uuid),
      nullif(current_setting('app.review_note', true), '')
    );
  end if;
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['hadiths','translations','gradings','narrators']
  loop
    execute format('drop trigger if exists guard_content_status on public.%I', t);
    execute format('create trigger guard_content_status before insert or update on public.%I
                    for each row execute function public.guard_content_status()', t);
    execute format('drop trigger if exists log_status_change on public.%I', t);
    execute format('create trigger log_status_change after insert or update of status on public.%I
                    for each row execute function public.log_status_change()', t);
  end loop;
end $$;

-- The only way to change review status.
--   select public.review_record('hadith', '<uuid>', 'verified', 'Checked against <edition>, p. 12');
-- From the dashboard SQL editor (no logged-in user) pass the reviewer's user id:
--   select public.review_record('hadith', '<uuid>', 'verified', 'note', '<reviewer user uuid>');
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
    -- Dashboard / SQL editor: only database owners may act for a named reviewer.
    if current_user not in ('postgres', 'supabase_admin') then
      raise exception 'Not signed in' using errcode = 'insufficient_privilege';
    end if;
    reviewer := p_reviewer;
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
    -- Each (re-)verification records the reviewer who did it; publishing keeps
    -- the record of who verified it.
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
  if found_rows = 0 then
    raise exception '% % not found', p_entity, p_id using errcode = 'no_data_found';
  end if;
  return p_to;
end $$;

revoke all on function public.review_record(text, uuid, public.content_status, text, uuid) from public, anon;
grant execute on function public.review_record(text, uuid, public.content_status, text, uuid) to authenticated;
