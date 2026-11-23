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
