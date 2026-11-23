-- =============================================================================
-- ROLLBACK for catalogue v2 (migrations 20261120000001 … 20261125000010).
--
-- ⚠️ DESTRUCTIVE: drops the v2 tables AND THEIR DATA (hadiths, translations,
-- gradings, bookmarks, history, roles). Run only on a database where v2 was
-- just applied and holds nothing you need — e.g. a failed first deployment.
-- Take a backup first (Dashboard → Database → Backups). Never run casually.
-- =============================================================================

begin;

drop table if exists public.hadith_audio;
drop function if exists public.review_audio(uuid, public.content_status, text, uuid);
drop function if exists public.guard_audio_status();
drop function if exists public.search_hadiths_v2(text, text[], uuid[], text[], uuid[], public.grade_kind[], boolean,
                                              integer, numeric, text, integer);
drop function if exists public.daily_hadith(date);
drop function if exists public.search_hadiths(text, text, text, uuid, public.grade_kind, integer, integer);
drop function if exists public.like_escape(text);
drop view if exists public.hadith_review_queue;
drop function if exists public.record_review_check(uuid, text, boolean, text, uuid);
drop table if exists public.hadith_review_checks;
drop trigger if exists require_hadith_checks on public.hadiths;
drop function if exists public.require_hadith_checks();
drop function if exists public.hadith_check_passed(uuid, text);
drop view if exists public.catalog_counts;
drop view if exists public.hadith_list_items;

drop function if exists public.review_record(text, uuid, public.content_status, text, uuid);

drop table if exists public.user_roles;
drop table if exists public.reading_history;
drop table if exists public.bookmarks;
drop table if exists public.profiles;
drop table if exists public.review_log;
drop table if exists public.gradings;
drop table if exists public.translations;
drop table if exists public.hadith_categories;
drop table if exists public.hadith_narrators;
drop table if exists public.hadiths;
drop table if exists public.narrators;
drop table if exists public.categories;
drop table if exists public.chapters;
drop table if exists public.books;
drop table if exists public.collections;
drop table if exists public.import_batches;

drop function if exists public.log_status_change();
drop function if exists public.guard_content_status();
drop function if exists public.content_changed(jsonb, jsonb);
drop function if exists public.status_transition_allowed(public.content_status, public.content_status);
drop function if exists public.is_staff();
drop function if exists public.has_role(public.app_role);
drop function if exists public.set_updated_at();
drop function if exists public.normalize_arabic(text);
drop function if exists public.normalize_somali(text); -- after translations (text_norm uses it)

drop type if exists public.app_role;
drop type if exists public.grade_kind;
drop type if exists public.content_status;

commit;
