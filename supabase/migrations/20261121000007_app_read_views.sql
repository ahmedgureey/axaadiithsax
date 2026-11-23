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
