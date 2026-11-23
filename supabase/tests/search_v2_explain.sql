-- =============================================================================
-- Query-plan check for search_hadiths_v2 (STEP 06). Read-only.
--
-- Run on a dev database that has a realistic number of PUBLISHED records
-- (plans on an almost empty table always show sequential scans and say
-- nothing). Look for: Bitmap Index Scan on hadiths_arabic_trgm_idx /
-- translations_norm_trgm_idx for text queries, hadiths_published_* indexes
-- for browse queries, and execution times well under ~200 ms.
--
-- The function is SQL-language, so EXPLAIN on the call only shows a Function
-- Scan; the statements below repeat its core predicates so the planner's
-- choices are visible. auto_explain on a branch is the alternative.
-- =============================================================================

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

-- 1. Arabic text query (trigram LIKE on the normalised column).
explain (analyze, buffers, format text)
select h.id from public.hadiths h
 where h.status = 'published'
   and h.arabic_search like '%' || public.like_escape(public.normalize_arabic('إنما الأعمال')) || '%'
 limit 50;

-- 2. Somali text query (trigram LIKE on translations.text_norm).
explain (analyze, buffers, format text)
select t.hadith_id from public.translations t
 where t.status = 'published' and t.language = 'so'
   and t.text_norm like '%' || public.like_escape(public.normalize_somali('niyadda')) || '%'
 limit 50;

-- 3. Browse one chapter (v2 book) in order.
explain (analyze, buffers, format text)
select h.id from public.hadiths h
 where h.status = 'published' and h.book_id = (select id from public.books limit 1)
 order by h.source_position limit 20;

-- 4. Grade filter.
explain (analyze, buffers, format text)
select h.id from public.hadiths h
 where h.status = 'published'
   and exists (select 1 from public.gradings g
                where g.hadith_id = h.id and g.status = 'published' and g.grade = any (array['sahih']::public.grade_kind[]))
 order by h.collection_id, h.source_position limit 20;

-- 5. End-to-end timing of the function itself (first page and a later page).
explain (analyze, format text)
select * from public.search_hadiths_v2('نص', p_limit => 20);
explain (analyze, format text)
select * from public.search_hadiths_v2(null, p_limit => 20, p_after_rank => 0, p_after_collection => 'bukhari',
                                       p_after_position => 1000);

reset role;
