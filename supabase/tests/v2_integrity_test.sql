-- =============================================================================
-- Data-integrity checks for catalogue v2 (migrations 01–07).
--
-- Run as postgres on a dev/branch/local database AFTER the migrations.
-- One transaction, ends with ROLLBACK: nothing is left behind. Test rows use
-- the placeholder 'TEST ONLY' — they are not hadith.
-- Success ends with "ALL INTEGRITY CHECKS PASSED".
-- =============================================================================

begin;

insert into public.collections (id, name_ar, name_en) values
  ('test-a', 'TEST ONLY', 'TEST ONLY'),
  ('test-b', 'TEST ONLY', 'TEST ONLY');
insert into public.books (id, collection_id, book_number, title_ar, sort_order) values
  ('00000000-0000-0000-0000-0000000b00a1', 'test-a', '1', 'TEST ONLY', 1),
  ('00000000-0000-0000-0000-0000000b00b1', 'test-b', '1', 'TEST ONLY', 1);
insert into public.chapters (id, book_id, title_ar, sort_order) values
  ('00000000-0000-0000-0000-0000000c00a1', '00000000-0000-0000-0000-0000000b00a1', 'TEST ONLY', 1);
insert into public.hadiths (id, collection_id, book_id, chapter_id, hadith_number, source_position, arabic_text, source_name)
values ('00000000-0000-0000-0000-00000000d001', 'test-a', '00000000-0000-0000-0000-0000000b00a1',
        '00000000-0000-0000-0000-0000000c00a1', '1', 1, 'TEST ONLY نص', 'TEST ONLY');

-- Helper: expect a statement to fail with a given SQLSTATE.
create function pg_temp.expect_fail(stmt text, code text, label text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    if sqlstate = code then return; end if;
    raise exception 'FAIL %: expected SQLSTATE %, got % (%)', label, code, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL %: statement succeeded but should have failed', label;
end $$;

-- ---- foreign keys -----------------------------------------------------------
select pg_temp.expect_fail($$insert into public.books (collection_id, book_number, title_ar, sort_order)
  values ('no-such', '1', 'x', 1)$$, '23503', 'FK book->collection');
-- chapter of a book in collection A cannot be attached to a hadith of collection B
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, book_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-b', '00000000-0000-0000-0000-0000000b00a1', '9', 9, 'x', 'x')$$, '23503', 'FK book must belong to collection');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, book_id, chapter_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-b', '00000000-0000-0000-0000-0000000b00b1', '00000000-0000-0000-0000-0000000c00a1', '9', 9, 'x', 'x')$$,
  '23503', 'FK chapter must belong to book');
select pg_temp.expect_fail($$insert into public.translations (hadith_id, text, translator, translation_source)
  values (gen_random_uuid(), 'x', 'x', 'x')$$, '23503', 'FK translation->hadith');
-- catalogue parents are protected (restrict)
select pg_temp.expect_fail($$delete from public.collections where id = 'test-a'$$, '23503', 'restrict delete collection');

-- ---- unique constraints ----------------------------------------------------
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-a', '1', 99, 'x', 'x')$$, '23505', 'unique hadith number per scheme');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-a', '99', 1, 'x', 'x')$$, '23505', 'unique source position');
-- same number under a different numbering scheme is allowed
insert into public.hadiths (collection_id, numbering_scheme, hadith_number, source_position, arabic_text, source_name)
values ('test-a', 'other-scheme', '1', 2, 'TEST ONLY نص', 'TEST ONLY');
insert into public.translations (hadith_id, text, translator, translation_source, is_primary)
values ('00000000-0000-0000-0000-00000000d001', 'TEST ONLY', 'T1', 'S1', true);
select pg_temp.expect_fail($$insert into public.translations (hadith_id, text, translator, translation_source, is_primary)
  values ('00000000-0000-0000-0000-00000000d001', 'TEST ONLY', 'T2', 'S2', true)$$, '23505', 'one primary translation');
select pg_temp.expect_fail($$insert into public.translations (hadith_id, text, translator, translation_source)
  values ('00000000-0000-0000-0000-00000000d001', 'TEST ONLY 2', 'T1', 'S1')$$, '23505', 'duplicate translation source');
insert into public.gradings (hadith_id, grade, scholar, source_reference)
values ('00000000-0000-0000-0000-00000000d001', 'sahih', 'TEST ONLY', 'TEST ONLY ref');
select pg_temp.expect_fail($$insert into public.gradings (hadith_id, grade, scholar, source_reference)
  values ('00000000-0000-0000-0000-00000000d001', 'hasan', 'TEST ONLY', 'TEST ONLY ref')$$, '23505', 'duplicate grading per scholar+ref');
-- a different scholar may disagree: preserved, not merged
insert into public.gradings (hadith_id, grade, scholar, source_reference)
values ('00000000-0000-0000-0000-00000000d001', 'daif', 'TEST ONLY 2', 'TEST ONLY ref 2');

-- ---- required fields / checks ----------------------------------------------
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-a', '5', 5, '   ', 'x')$$, '23514', 'empty arabic rejected');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, source_name)
  values ('test-a', '5', 5, 'x')$$, '23502', 'arabic required');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
  values ('test-a', '5', 5, 'x', '')$$, '23514', 'source name required');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name, source_url)
  values ('test-a', '5', 5, 'x', 'x', 'javascript:alert(1)')$$, '23514', 'source url must be http(s)');
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name, vowelized_verified)
  values ('test-a', '5', 5, 'x', 'x', true)$$, '23514', 'vowelized_verified needs vowelized text');
select pg_temp.expect_fail($$insert into public.gradings (hadith_id, grade, scholar, source_reference)
  values ('00000000-0000-0000-0000-00000000d001', 'sahih', '', 'x')$$, '23514', 'grading needs scholar');
select pg_temp.expect_fail($$insert into public.gradings (hadith_id, grade, scholar, source_reference)
  values ('00000000-0000-0000-0000-00000000d001', 'other', 'X', 'Y')$$, '23514', 'grade other needs arabic label');
-- imports cannot arrive pre-verified
select pg_temp.expect_fail($$insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name, status, verified_by, verified_at)
  values ('test-a', '5', 5, 'x', 'x', 'verified', gen_random_uuid(), now())$$, '23514', 'insert as verified rejected');

-- ---- original text kept; normalized copy separate --------------------------
update public.hadiths set arabic_text = 'TEST ONLY إِنَّمَا' where id = '00000000-0000-0000-0000-00000000d001';
do $$ begin
  if (select arabic_text from public.hadiths where id = '00000000-0000-0000-0000-00000000d001') <> 'TEST ONLY إِنَّمَا' then
    raise exception 'FAIL original text was modified';
  end if;
  if (select arabic_search from public.hadiths where id = '00000000-0000-0000-0000-00000000d001') <> 'TEST ONLY انما' then
    raise exception 'FAIL search column not normalized';
  end if;
end $$;

-- ---- duplicate detection (report query used by the import tool) -----------
do $$ begin
  if (select count(*) from (
        select md5(arabic_search) from public.hadiths where collection_id = 'test-a'
        group by 1 having count(*) > 1) d) <> 0 then
    raise exception 'FAIL duplicate detection: unexpected duplicates before test insert';
  end if;
end $$;
insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
values ('test-a', '3', 3, 'TEST ONLY إنما', 'TEST ONLY');   -- same text without tashkeel
do $$ begin
  if (select count(*) from (
        select md5(arabic_search) from public.hadiths where collection_id = 'test-a'
        group by 1 having count(*) > 1) d) <> 1 then
    raise exception 'FAIL duplicate detection did not find the repeated text';
  end if;
end $$;

-- ---- provenance on every content table -------------------------------------
do $$
declare t text;
begin
  foreach t in array array['hadiths','translations','gradings','narrators'] loop
    if not exists (select 1 from information_schema.columns
                   where table_schema = 'public' and table_name = t and column_name = 'import_batch_id') then
      raise exception 'FAIL % has no import_batch_id', t;
    end if;
  end loop;
end $$;

-- ---- RLS enabled on every table; no write grants to API roles on catalogue -
do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity loop
    raise exception 'FAIL RLS disabled on public.%', r.relname;
  end loop;
  for r in select table_name, privilege_type, grantee from information_schema.role_table_grants
           where table_schema = 'public' and grantee in ('anon', 'authenticated')
             and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
             and table_name not in ('profiles','bookmarks','reading_history') loop
    raise exception 'FAIL % has % on public.%', r.grantee, r.privilege_type, r.table_name;
  end loop;
  if has_function_privilege('anon', 'public.review_record(text, uuid, public.content_status, text, uuid)', 'execute') then
    raise exception 'FAIL anon can execute review_record';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role')
     and has_function_privilege('service_role', 'public.review_record(text, uuid, public.content_status, text, uuid)', 'execute') then
    raise exception 'FAIL service_role can execute review_record';
  end if;
end $$;

-- ---- deleting a user removes their data (cascade) --------------------------
insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000000e1', 'gone@test.invalid', 'authenticated', 'authenticated');
insert into public.profiles (user_id, display_name) values ('00000000-0000-0000-0000-0000000000e1', 'TEST');
insert into public.bookmarks (user_id, hadith_id) values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000d001');
select pg_temp.expect_fail($$insert into public.bookmarks (user_id, hadith_id)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000d001')$$, '23505', 'no duplicate bookmark');
delete from auth.users where id = '00000000-0000-0000-0000-0000000000e1';
do $$ begin
  if exists (select 1 from public.bookmarks where user_id = '00000000-0000-0000-0000-0000000000e1')
     or exists (select 1 from public.profiles where user_id = '00000000-0000-0000-0000-0000000000e1') then
    raise exception 'FAIL user data not removed with the user';
  end if;
end $$;

select 'ALL INTEGRITY CHECKS PASSED' as result;

rollback;
