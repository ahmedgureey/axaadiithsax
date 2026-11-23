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
