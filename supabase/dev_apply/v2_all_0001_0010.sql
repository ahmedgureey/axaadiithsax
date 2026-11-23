-- =============================================================================
-- DEV ONLY — all catalogue v2 migrations (0001 … 0010) in ONE transaction.
-- Generated from supabase/migrations/ (files concatenated in filename order,
-- unchanged). If any statement fails, NOTHING is applied (rollback).
-- Run in the Supabase SQL editor of the DEVELOPMENT project only.
-- =============================================================================

begin;


-- >>>>>>>>>> 20261120000001_catalog_core.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 1: types, helpers and catalogue tables.
--
-- Design: docs/BACKEND_DESIGN.md. Rollback: supabase/rollback/20261120_v2_down.sql
--
-- Rules encoded here:
--   * Source wording is stored exactly as received (arabic_text). Vowelized
--     text is a separate, separately verified column. Search uses a derived,
--     normalized column; the original is never modified.
--   * Hadith numbering is stored as text exactly as the source gives it, per
--     numbering scheme. Numbering is NOT assumed identical across editions.
--   * Translations and gradings live in their own tables (many per hadith),
--     each with its own source and review status. Gradings keep the scholar
--     and reference so disagreements are preserved, not merged.
--   * Nothing is public until its status is 'published'.
-- =============================================================================

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------- types ----

do $$ begin
  create type public.content_status as enum (
    'imported',          -- loaded by the import pipeline, not looked at yet
    'pending_review',    -- queued for a reviewer
    'verified',          -- reviewer confirmed against the cited source
    'published',         -- verified AND visible in the app
    'needs_correction',  -- reviewer found a problem; fix and resubmit
    'rejected'           -- will not be used
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.grade_kind as enum (
    'sahih', 'hasan', 'hasan_sahih', 'daif', 'daif_jiddan', 'mawdu', 'other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.app_role as enum ('admin', 'reviewer', 'editor');
exception when duplicate_object then null; end $$;

-- -------------------------------------------------------------- helpers ----

-- Normalized Arabic for SEARCH ONLY (never displayed, never stored as source):
-- removes tashkeel (U+064B–U+065F, U+0670) and tatweel (U+0640), unifies
-- alef forms, alef maqsura → ya, ta marbuta → ha.
create or replace function public.normalize_arabic(input text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when input is null then null else
    translate(
      regexp_replace(input, '[ً-ٰٟـ]', '', 'g'),
      'أإآٱىة',
      'اااايه'
    )
  end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ----------------------------------------------------------- collections ---

create table if not exists public.collections (
  id                text primary key check (id ~ '^[a-z0-9][a-z0-9_-]*$'),  -- e.g. 'bukhari'
  name_ar           text not null check (btrim(name_ar) <> ''),
  name_en           text not null check (btrim(name_en) <> ''),
  name_so           text,                                  -- Somali display name
  name_so_verified  boolean not null default false,        -- only show name_so when true
  compiler_ar       text,
  compiler_en       text,
  description_so    text,
  description_en    text,
  edition           text,                                  -- printed edition / dataset version
  publisher         text,
  source_reference  text,                                  -- bibliographic reference
  source_url        text check (source_url is null or source_url ~ '^https?://'),
  metadata          jsonb not null default '{}'::jsonb,
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- "Kitab" inside a collection (e.g. Kitab al-Iman).
create table if not exists public.books (
  id             uuid primary key default gen_random_uuid(),
  collection_id  text not null references public.collections (id) on delete restrict,
  book_number    text not null,                            -- as the source numbers it
  title_ar       text not null check (btrim(title_ar) <> ''),
  title_en       text,
  title_so       text,
  sort_order     integer not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (collection_id, book_number),
  unique (id, collection_id)                               -- target of composite FK below
);

-- "Bab" inside a book. Some babs are unnumbered: sort_order is the position.
create table if not exists public.chapters (
  id              uuid primary key default gen_random_uuid(),
  book_id         uuid not null references public.books (id) on delete restrict,
  chapter_number  text,
  title_ar        text not null check (btrim(title_ar) <> ''),
  title_en        text,
  title_so        text,
  sort_order      integer not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (book_id, sort_order),
  unique (id, book_id)
);

-- Topic tree used for browsing (independent of a collection's own chapters).
create table if not exists public.categories (
  id          text primary key check (id ~ '^[a-z0-9][a-z0-9_-]*$'),
  parent_id   text references public.categories (id) on delete restrict,
  name_ar     text not null default '',
  name_so     text not null check (btrim(name_so) <> ''),
  name_en     text,
  icon_key    text not null default 'topic',
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (parent_id is null or parent_id <> id)
);

-- --------------------------------------------------------------- narrators -

create table if not exists public.narrators (
  id              uuid primary key default gen_random_uuid(),
  name_ar         text not null check (btrim(name_ar) <> ''),
  name_ar_search  text generated always as (public.normalize_arabic(name_ar)) stored,
  alt_names_ar    text[] not null default '{}',
  name_latin      text,
  kunya_ar        text,
  death_year_ah   integer check (death_year_ah is null or death_year_ah between 1 and 1500),
  -- [{ "source": "...", "reference": "...", "url": "https://..." }]
  biography_refs  jsonb not null default '[]'::jsonb check (jsonb_typeof(biography_refs) = 'array'),
  status          public.content_status not null default 'imported',
  verified_by     uuid references auth.users (id) on delete set null,
  verified_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------- hadiths --

create table if not exists public.hadiths (
  id                     uuid primary key default gen_random_uuid(),
  collection_id          text not null references public.collections (id) on delete restrict,
  book_id                uuid,
  chapter_id             uuid,
  numbering_scheme       text not null default 'source',   -- e.g. 'fuad-abd-al-baqi', 'sunnah.com'
  hadith_number          text not null check (btrim(hadith_number) <> ''),  -- e.g. '1', '52a'
  source_position        integer not null,                 -- order within the collection
  arabic_text            text not null check (btrim(arabic_text) <> ''),   -- exactly as the source
  arabic_text_vowelized  text,                             -- full tashkeel, only if verified
  vowelized_verified     boolean not null default false,
  arabic_search          text generated always as (
                           public.normalize_arabic(coalesce(arabic_text_vowelized, arabic_text))
                         ) stored,
  narrator_text_ar       text,                             -- narrator as written in the source
  source_name            text not null check (btrim(source_name) <> ''),
  source_edition         text,
  source_identifier      text,                             -- the record's id in the source dataset
  source_url             text check (source_url is null or source_url ~ '^https?://'),
  normalization_notes    text,                             -- any change made to the source text
  status                 public.content_status not null default 'imported',
  verified_by            uuid references auth.users (id) on delete set null,
  verified_at            timestamptz,
  published_at           timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (collection_id, numbering_scheme, hadith_number),
  unique (collection_id, source_position),
  -- chapter must belong to the book, and the book to the collection
  foreign key (book_id, collection_id) references public.books (id, collection_id) on delete restrict,
  foreign key (chapter_id, book_id) references public.chapters (id, book_id) on delete restrict,
  check (chapter_id is null or book_id is not null),
  check (arabic_text_vowelized is not null or not vowelized_verified),
  check (status not in ('verified', 'published') or (verified_by is not null and verified_at is not null)),
  check (status <> 'published' or published_at is not null)
);

create table if not exists public.hadith_narrators (
  hadith_id    uuid not null references public.hadiths (id) on delete cascade,
  narrator_id  uuid not null references public.narrators (id) on delete restrict,
  role         text not null check (role in ('sahabi', 'chain', 'other')),
  position     smallint not null default 0,
  primary key (hadith_id, narrator_id, role)
);

create table if not exists public.hadith_categories (
  hadith_id    uuid not null references public.hadiths (id) on delete cascade,
  category_id  text not null references public.categories (id) on delete restrict,
  primary key (hadith_id, category_id)
);

-- ------------------------------------------------------------ translations -

create table if not exists public.translations (
  id                  uuid primary key default gen_random_uuid(),
  hadith_id           uuid not null references public.hadiths (id) on delete cascade,
  language            text not null default 'so' check (language ~ '^[a-z]{2,3}$'),
  text                text not null check (btrim(text) <> ''),
  text_search         tsvector generated always as (to_tsvector('simple', text)) stored,
  translator          text not null check (btrim(translator) <> ''),
  translation_source  text not null check (btrim(translation_source) <> ''),
  source_url          text check (source_url is null or source_url ~ '^https?://'),
  is_primary          boolean not null default false,       -- the one shown by default
  notes               text,
  status              public.content_status not null default 'imported',
  reviewed_by         uuid references auth.users (id) on delete set null,
  reviewed_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (hadith_id, language, translator, translation_source),
  check (status not in ('verified', 'published') or (reviewed_by is not null and reviewed_at is not null))
);

-- --------------------------------------------------------------- gradings --

create table if not exists public.gradings (
  id                  uuid primary key default gen_random_uuid(),
  hadith_id           uuid not null references public.hadiths (id) on delete cascade,
  grade               public.grade_kind not null,
  grade_label_ar      text,                                 -- wording as the scholar gave it
  scholar             text not null check (btrim(scholar) <> ''),
  source_reference    text not null check (btrim(source_reference) <> ''),
  source_url          text check (source_url is null or source_url ~ '^https?://'),
  disagreement_notes  text,
  status              public.content_status not null default 'imported',
  reviewed_by         uuid references auth.users (id) on delete set null,
  reviewed_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (hadith_id, scholar, source_reference),
  check (grade <> 'other' or grade_label_ar is not null),
  check (status not in ('verified', 'published') or (reviewed_by is not null and reviewed_at is not null))
);

-- ------------------------------------------------------------- review log --

create table if not exists public.review_log (
  id           bigint generated always as identity primary key,
  entity_type  text not null check (entity_type in ('hadith', 'translation', 'grading', 'narrator')),
  entity_id    uuid not null,
  from_status  public.content_status,
  to_status    public.content_status not null,
  actor        uuid references auth.users (id) on delete set null,
  db_role      text not null default current_user,
  note         text,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------- indexes --

create index if not exists books_collection_idx        on public.books (collection_id, sort_order);
create index if not exists chapters_book_idx           on public.chapters (book_id, sort_order);
create index if not exists categories_parent_idx       on public.categories (parent_id, sort_order);
create index if not exists hadiths_chapter_idx         on public.hadiths (chapter_id, source_position);
create index if not exists hadiths_book_idx            on public.hadiths (book_id, source_position);
create index if not exists hadiths_status_idx          on public.hadiths (status);
create index if not exists hadiths_published_order_idx on public.hadiths (collection_id, source_position)
  where status = 'published';
create index if not exists hadiths_arabic_trgm_idx     on public.hadiths using gin (arabic_search extensions.gin_trgm_ops);
create index if not exists hadiths_source_ident_idx    on public.hadiths (source_name, source_identifier);
create index if not exists hadith_narrators_narr_idx   on public.hadith_narrators (narrator_id);
create index if not exists hadith_categories_cat_idx   on public.hadith_categories (category_id);
create index if not exists narrators_search_trgm_idx   on public.narrators using gin (name_ar_search extensions.gin_trgm_ops);
create index if not exists translations_hadith_idx     on public.translations (hadith_id, language);
create unique index if not exists translations_one_primary_idx
  on public.translations (hadith_id, language) where is_primary;
create index if not exists translations_fts_idx        on public.translations using gin (text_search);
create index if not exists translations_trgm_idx       on public.translations using gin (lower(text) extensions.gin_trgm_ops);
create index if not exists gradings_hadith_idx         on public.gradings (hadith_id);
create index if not exists gradings_grade_idx          on public.gradings (grade) where status = 'published';
create index if not exists review_log_entity_idx       on public.review_log (entity_type, entity_id, created_at);

-- Duplicate detection helpers (not unique: different editions may legitimately
-- repeat a text). Used by the import report.
create index if not exists hadiths_arabic_md5_idx on public.hadiths (md5(arabic_search));

-- ---------------------------------------------------------- updated_at -----

do $$
declare t text;
begin
  foreach t in array array['collections','books','chapters','categories','narrators','hadiths','translations','gradings']
  loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function public.set_updated_at()', t);
  end loop;
end $$;


-- >>>>>>>>>> 20261120000002_users_roles.sql
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


-- >>>>>>>>>> 20261120000003_review_workflow.sql
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


-- >>>>>>>>>> 20261120000004_rls.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 4: Row Level Security.
--
-- * Everyone (anon + signed in) reads catalogue metadata and PUBLISHED records.
-- * Staff (any role in user_roles) can also read unpublished records.
-- * Nobody can write catalogue tables through the API: there are no
--   insert/update/delete policies. Content arrives through the import script
--   (secret key, trusted machine) and changes status only via review_record().
-- * Users read and write only their own profile, bookmarks and history.
-- =============================================================================

alter table public.collections       enable row level security;
alter table public.books             enable row level security;
alter table public.chapters          enable row level security;
alter table public.categories        enable row level security;
alter table public.narrators         enable row level security;
alter table public.hadiths           enable row level security;
alter table public.hadith_narrators  enable row level security;
alter table public.hadith_categories enable row level security;
alter table public.translations      enable row level security;
alter table public.gradings          enable row level security;
alter table public.review_log        enable row level security;
alter table public.profiles          enable row level security;
alter table public.bookmarks         enable row level security;
alter table public.reading_history   enable row level security;
alter table public.user_roles        enable row level security;

-- Policies are recreated so the migration can be re-run safely.
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in (
      'collections','books','chapters','categories','narrators','hadiths','hadith_narrators',
      'hadith_categories','translations','gradings','review_log','profiles','bookmarks',
      'reading_history','user_roles')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Catalogue metadata (names only, no hadith content).
create policy "read metadata" on public.collections for select to anon, authenticated using (true);
create policy "read metadata" on public.books       for select to anon, authenticated using (true);
create policy "read metadata" on public.chapters    for select to anon, authenticated using (true);
create policy "read metadata" on public.categories  for select to anon, authenticated using (true);

-- Content: published for everyone, everything for staff.
create policy "read published" on public.hadiths for select to anon, authenticated
  using (status = 'published' or public.is_staff());

create policy "read published" on public.narrators for select to anon, authenticated
  using (status = 'published' or public.is_staff());

create policy "read published" on public.translations for select to anon, authenticated
  using (
    public.is_staff()
    or (status = 'published'
        and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published'))
  );

create policy "read published" on public.gradings for select to anon, authenticated
  using (
    public.is_staff()
    or (status = 'published'
        and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published'))
  );

create policy "read published" on public.hadith_narrators for select to anon, authenticated
  using (
    public.is_staff()
    or exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );

create policy "read published" on public.hadith_categories for select to anon, authenticated
  using (
    public.is_staff()
    or exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );

create policy "staff read" on public.review_log for select to authenticated using (public.is_staff());

-- Own rows only.
create policy "own profile read"   on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "own profile insert" on public.profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own profile delete" on public.profiles for delete to authenticated using (user_id = (select auth.uid()));

create policy "own bookmarks read"   on public.bookmarks for select to authenticated using (user_id = (select auth.uid()));
create policy "own bookmarks insert" on public.bookmarks for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );
create policy "own bookmarks delete" on public.bookmarks for delete to authenticated using (user_id = (select auth.uid()));

create policy "own history read"   on public.reading_history for select to authenticated using (user_id = (select auth.uid()));
create policy "own history insert" on public.reading_history for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );
create policy "own history update" on public.reading_history for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own history delete" on public.reading_history for delete to authenticated using (user_id = (select auth.uid()));

create policy "own roles read" on public.user_roles for select to authenticated using (user_id = (select auth.uid()));

-- Table privileges (RLS still applies on top).
revoke all on public.collections, public.books, public.chapters, public.categories, public.narrators,
              public.hadiths, public.hadith_narrators, public.hadith_categories, public.translations,
              public.gradings, public.review_log, public.profiles, public.bookmarks,
              public.reading_history, public.user_roles
  from anon, authenticated;

grant select on public.collections, public.books, public.chapters, public.categories, public.narrators,
                public.hadiths, public.hadith_narrators, public.hadith_categories, public.translations,
                public.gradings
  to anon, authenticated;
grant select on public.review_log, public.user_roles to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, delete on public.bookmarks to authenticated;
grant select, insert, update, delete on public.reading_history to authenticated;


-- >>>>>>>>>> 20261120000005_api.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 5: read API for the app.
--
-- Everything here runs with the CALLER's rights (security invoker), so the
-- RLS rules of part 4 decide what is returned. Details screens use PostgREST
-- embedding on public.hadiths directly (see docs/BACKEND_DESIGN.md §5).
-- =============================================================================

-- List rows: one per hadith, with its primary published Somali translation.
-- Vowelized text is exposed only when it has been verified.
create or replace view public.hadith_list_items
with (security_invoker = true)
as
select
  h.id,
  h.collection_id,
  h.book_id,
  h.chapter_id,
  h.numbering_scheme,
  h.hadith_number,
  h.source_position,
  case when h.vowelized_verified then h.arabic_text_vowelized else h.arabic_text end as arabic_display,
  h.narrator_text_ar,
  t.text  as somali_text,
  t.translator,
  h.updated_at
from public.hadiths h
left join public.translations t
  on t.hadith_id = h.id and t.language = 'so' and t.is_primary and t.status = 'published';

grant select on public.hadith_list_items to anon, authenticated;

-- Escapes LIKE wildcards in user input.
create or replace function public.like_escape(input text)
returns text
language sql
immutable
set search_path = ''
as $$
  select replace(replace(replace(coalesce(input, ''), '\', '\\'), '%', '\%'), '_', '\_')
$$;

-- Search Arabic (diacritics-insensitive) and Somali text, with optional
-- filters. Returns at most 50 rows per call; page with p_offset.
create or replace function public.search_hadiths(
  p_query       text,
  p_collection  text default null,
  p_category    text default null,
  p_narrator    uuid default null,
  p_grade       public.grade_kind default null,
  p_limit       integer default 20,
  p_offset      integer default 0
)
returns table (
  id               uuid,
  collection_id    text,
  hadith_number    text,
  source_position  integer,
  arabic_display   text,
  somali_text      text,
  rank             real
)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select
      nullif(btrim(p_query), '')                                         as raw,
      '%' || public.like_escape(public.normalize_arabic(btrim(p_query))) || '%' as arabic_like,
      '%' || public.like_escape(lower(btrim(p_query))) || '%'            as somali_like
  )
  select
    i.id, i.collection_id, i.hadith_number, i.source_position, i.arabic_display, i.somali_text,
    greatest(
      extensions.similarity(h.arabic_search, public.normalize_arabic(q.raw)),
      coalesce(extensions.similarity(lower(i.somali_text), lower(q.raw)), 0)
    ) as rank
  from q
  join public.hadith_list_items i on true
  join public.hadiths h on h.id = i.id
  where q.raw is not null
    and char_length(q.raw) >= 2
    and (
      h.arabic_search like q.arabic_like
      or exists (
        select 1 from public.translations t
        where t.hadith_id = h.id and t.language = 'so'
          and lower(t.text) like q.somali_like
      )
    )
    and (p_collection is null or i.collection_id = p_collection)
    and (p_category is null or exists (
          select 1 from public.hadith_categories c where c.hadith_id = h.id and c.category_id = p_category))
    and (p_narrator is null or exists (
          select 1 from public.hadith_narrators n where n.hadith_id = h.id and n.narrator_id = p_narrator))
    and (p_grade is null or exists (
          select 1 from public.gradings g where g.hadith_id = h.id and g.grade = p_grade))
  order by rank desc, i.collection_id, i.source_position
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

grant execute on function public.search_hadiths(text, text, text, uuid, public.grade_kind, integer, integer)
  to anon, authenticated;

-- Same "hadith of the day" for everyone on a given date (deterministic).
create or replace function public.daily_hadith(p_day date default current_date)
returns setof public.hadith_list_items
language sql
stable
security invoker
set search_path = ''
as $$
  select i.*
  from public.hadith_list_items i
  order by i.collection_id, i.source_position
  offset (select abs(hashtext(p_day::text)) % greatest(count(*), 1) from public.hadith_list_items)
  limit 1
$$;

grant execute on function public.daily_hadith(date) to anon, authenticated;


-- >>>>>>>>>> 20261120000006_import_tracking.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 6: import provenance & error tracking.
--
-- Every imported hadith / translation / grading points at the import batch it
-- came from. A batch records the dataset's origin (source, edition, licence,
-- URL, file checksum), counts and errors. Additive only.
-- =============================================================================

create table if not exists public.import_batches (
  id               uuid primary key default gen_random_uuid(),
  source_name      text not null check (btrim(source_name) <> ''),
  source_edition   text,
  source_url       text check (source_url is null or source_url ~ '^https?://'),
  license          text not null check (btrim(license) <> ''),   -- licence / permission reference
  file_name        text not null,
  file_sha256      text not null check (file_sha256 ~ '^[0-9a-f]{64}$'),
  tool_version     text not null,
  started_at       timestamptz not null default now(),
  finished_at      timestamptz,
  state            text not null default 'running' check (state in ('running', 'completed', 'failed')),
  counts           jsonb not null default '{}'::jsonb,   -- {"inserted": n, "skipped_existing": n, ...}
  errors           jsonb not null default '[]'::jsonb check (jsonb_typeof(errors) = 'array'),
  notes            text
);

-- The same file may be re-run (resume); the checksum lets reports group runs.
create index if not exists import_batches_sha_idx on public.import_batches (file_sha256, started_at);

alter table public.hadiths      add column if not exists import_batch_id uuid references public.import_batches (id) on delete restrict;
alter table public.translations add column if not exists import_batch_id uuid references public.import_batches (id) on delete restrict;
alter table public.gradings     add column if not exists import_batch_id uuid references public.import_batches (id) on delete restrict;

create index if not exists hadiths_import_batch_idx      on public.hadiths (import_batch_id);
create index if not exists translations_import_batch_idx on public.translations (import_batch_id);
create index if not exists gradings_import_batch_idx     on public.gradings (import_batch_id);

alter table public.import_batches enable row level security;

drop policy if exists "staff read" on public.import_batches;
create policy "staff read" on public.import_batches for select to authenticated using (public.is_staff());

revoke all on public.import_batches from anon, authenticated;
grant select on public.import_batches to authenticated;

-- import_batch_id is provenance, not content: a locked (verified/published)
-- record may not be re-pointed either, so it stays in the content check.


-- >>>>>>>>>> 20261120000007_security_fixes.sql
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


-- >>>>>>>>>> 20261121000007_app_read_views.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 7: app read views (STEP 04 integration).
--
-- * hadith_list_items now returns ONLY published hadith, also for signed-in
--   staff. The app caches what it reads, so a reviewer's device must never
--   cache drafts. (Staff still see drafts in the dashboard / base tables.)
-- * catalog_counts: published hadith per collection and per book, so the app
--   can show counts without downloading records.
-- Additive: replaces a view (same columns, stricter filter) and adds one.
-- =============================================================================

create or replace view public.hadith_list_items
with (security_invoker = true)
as
select
  h.id,
  h.collection_id,
  h.book_id,
  h.chapter_id,
  h.numbering_scheme,
  h.hadith_number,
  h.source_position,
  case when h.vowelized_verified then h.arabic_text_vowelized else h.arabic_text end as arabic_display,
  h.narrator_text_ar,
  t.text  as somali_text,
  t.translator,
  h.updated_at
from public.hadiths h
left join public.translations t
  on t.hadith_id = h.id and t.language = 'so' and t.is_primary and t.status = 'published'
where h.status = 'published';

create or replace view public.catalog_counts
with (security_invoker = true)
as
select h.collection_id, h.book_id, count(*)::integer as published_count
from public.hadiths h
where h.status = 'published'
group by h.collection_id, h.book_id;

grant select on public.hadith_list_items, public.catalog_counts to anon, authenticated;


-- >>>>>>>>>> 20261123000008_review_checks.sql
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


-- >>>>>>>>>> 20261124000009_search_v2.sql
-- =============================================================================
-- Xadiith App — catalogue v2, part 9: search, filtering & pagination (STEP 06).
--
-- 1. normalize_arabic() now matches the app's ArabicNormalizer exactly (used
--    for MATCHING only — arabic_text is never changed):
--      * removes tashkeel and Quranic marks (U+0610–U+061A, U+064B–U+065F,
--        U+0670, U+06D6–U+06ED) and tatweel (U+0640)
--      * alef forms  أ إ آ ٱ → ا
--      * alef maqsura ى → ي ; ta marbuta ة → ه
--      * hamza on carriers ؤ → و , ئ → ي  (users often type them without hamza)
--      * Persian/Urdu look-alikes ک → ك , ی → ي
--      * Arabic-Indic / Eastern digits → 0-9 ; whitespace collapsed
--    Standalone hamza ء is KEPT (removing it merges unrelated words).
--    Stored arabic_search / name_ar_search values are recomputed below.
-- 2. normalize_somali(): lower-case, apostrophe variants (’ ‘ ` ´) → ',
--    whitespace collapsed. Somali letters are never merged (x ≠ h, c ≠ ').
--    translations.text_norm (generated) + trigram index.
-- 3. search_hadiths_v2(): query optional (empty = browse with filters);
--    filters for collections, books (chapters), categories, narrators,
--    documented grades, "has published Somali translation" — all evaluated
--    in the database; keyset (cursor) pagination with a deterministic order
--    (rank desc, collection_id, source_position). SECURITY INVOKER: RLS and
--    the published-only view decide what is visible.
-- The old search_hadiths() is kept for compatibility. Additive.
-- =============================================================================

create or replace function public.normalize_arabic(input text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when input is null then null else
    btrim(regexp_replace(
      translate(
        regexp_replace(input, '[ؐ-ًؚ-ٰٟۖ-ۭـ]', '', 'g'),
        'أإآٱىةؤئکی٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        'اااايهويكي01234567890123456789'
      ),
      '\s+', ' ', 'g'))
  end
$$;

-- Recompute stored search columns with the new rules. Only the generated
-- columns change; arabic_text / name_ar are written back unchanged, which the
-- content lock permits (content_changed() compares them and finds no change).
update public.hadiths set arabic_text = arabic_text;
update public.narrators set name_ar = name_ar;

create or replace function public.normalize_somali(input text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case when input is null then null else
    btrim(regexp_replace(translate(lower(input), '’‘`´', ''''''''''), '\s+', ' ', 'g'))
  end
$$;

alter table public.translations
  add column if not exists text_norm text generated always as (public.normalize_somali(text)) stored;
create index if not exists translations_norm_trgm_idx
  on public.translations using gin (text_norm extensions.gin_trgm_ops)
  where status = 'published';

-- content_changed() must ignore the new generated column.
create or replace function public.content_changed(old_row jsonb, new_row jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (old_row - array['status','verified_by','verified_at','reviewed_by','reviewed_at','published_at',
                          'updated_at','created_at','is_primary',
                          'arabic_search','name_ar_search','text_search','text_norm'])
      is distinct from
         (new_row - array['status','verified_by','verified_at','reviewed_by','reviewed_at','published_at',
                          'updated_at','created_at','is_primary',
                          'arabic_search','name_ar_search','text_search','text_norm'])
$$;

-- Filter support indexes (published rows only).
create index if not exists hadiths_published_book_idx on public.hadiths (book_id, source_position)
  where status = 'published';
create index if not exists gradings_published_hadith_grade_idx on public.gradings (hadith_id, grade)
  where status = 'published';

create or replace function public.search_hadiths_v2(
  p_query            text default null,
  p_collections      text[] default null,
  p_books            uuid[] default null,
  p_categories       text[] default null,
  p_narrators        uuid[] default null,
  p_grades           public.grade_kind[] default null,
  p_has_translation  boolean default null,
  p_limit            integer default 20,
  p_after_rank       numeric default null,
  p_after_collection text default null,
  p_after_position   integer default null
)
returns table (
  id                uuid,
  collection_id     text,
  book_id           uuid,
  numbering_scheme  text,
  hadith_number     text,
  source_position   integer,
  arabic_display    text,
  narrator_text_ar  text,
  somali_text       text,
  translator        text,
  grades            jsonb,
  rank              numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select
      nullif(btrim(left(coalesce(p_query, ''), 200)), '')                                as raw,
      public.normalize_arabic(btrim(left(coalesce(p_query, ''), 200)))                  as ar,
      public.normalize_somali(btrim(left(coalesce(p_query, ''), 200)))                  as so
  ),
  hits as (
    select
      i.*,
      case when q.raw is null then 0::numeric else round(greatest(
        extensions.similarity(h.arabic_search, q.ar),
        coalesce((select max(extensions.similarity(t.text_norm, q.so))
                  from public.translations t
                  where t.hadith_id = h.id and t.language = 'so' and t.status = 'published'), 0)
      )::numeric, 4) end as rank
    from q
    join public.hadith_list_items i on true
    join public.hadiths h on h.id = i.id
    where
      (q.raw is null
        or (char_length(q.raw) >= 2 and (
              h.arabic_search like '%' || public.like_escape(q.ar) || '%'
              or exists (select 1 from public.translations t
                         where t.hadith_id = h.id and t.language = 'so' and t.status = 'published'
                           and t.text_norm like '%' || public.like_escape(q.so) || '%'))))
      and (p_collections is null or i.collection_id = any (p_collections))
      and (p_books is null or i.book_id = any (p_books))
      and (p_categories is null or exists (
            select 1 from public.hadith_categories c where c.hadith_id = h.id and c.category_id = any (p_categories)))
      and (p_narrators is null or exists (
            select 1 from public.hadith_narrators n where n.hadith_id = h.id and n.narrator_id = any (p_narrators)))
      and (p_grades is null or exists (
            select 1 from public.gradings g
            where g.hadith_id = h.id and g.status = 'published' and g.grade = any (p_grades)))
      and (p_has_translation is null or (i.somali_text is not null) = p_has_translation)
  )
  select
    hits.id, hits.collection_id, hits.book_id, hits.numbering_scheme, hits.hadith_number,
    hits.source_position, hits.arabic_display, hits.narrator_text_ar, hits.somali_text, hits.translator,
    coalesce((select jsonb_agg(jsonb_build_object('grade', g.grade, 'scholar', g.scholar,
                                                  'label', g.grade_label_ar, 'reference', g.source_reference)
                               order by g.scholar)
              from public.gradings g where g.hadith_id = hits.id and g.status = 'published'), '[]'::jsonb) as grades,
    hits.rank
  from hits
  where p_after_rank is null
     or hits.rank < p_after_rank
     or (hits.rank = p_after_rank and (
           hits.collection_id > p_after_collection
           or (hits.collection_id = p_after_collection and hits.source_position > p_after_position)))
  order by hits.rank desc, hits.collection_id, hits.source_position
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;

revoke all on function public.search_hadiths_v2(text, text[], uuid[], text[], uuid[], public.grade_kind[], boolean,
                                                integer, numeric, text, integer) from public;
grant execute on function public.search_hadiths_v2(text, text[], uuid[], text[], uuid[], public.grade_kind[], boolean,
                                                   integer, numeric, text, integer) to anon, authenticated;


-- >>>>>>>>>> 20261125000010_hadith_audio.sql
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


commit;
select 'V2 MIGRATIONS 0001-0010 APPLIED' as result;
