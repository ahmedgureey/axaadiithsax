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
