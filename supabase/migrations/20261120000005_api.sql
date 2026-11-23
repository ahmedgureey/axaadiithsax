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
