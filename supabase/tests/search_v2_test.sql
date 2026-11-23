-- =============================================================================
-- STEP 06 checks: search_hadiths_v2, normalisation, filters, cursor paging.
--
-- Run in the SQL editor (as postgres) AFTER migrations 0001–0009, on a
-- development/branch database. One transaction ending in ROLLBACK: no test
-- rows remain. A failing check raises 'FAIL …'; success ends with
-- "ALL SEARCH V2 CHECKS PASSED".
--
-- Fixture text is marked 'TEST ONLY' — it is test data, not hadith, and the
-- gradings below are fake test rows, not scholarly gradings.
-- =============================================================================

begin;

-- ---- fixtures ---------------------------------------------------------------
insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000006b1', 'search-reviewer@test.invalid', 'authenticated', 'authenticated');
insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000006b1', 'reviewer');

insert into public.collections (id, name_ar, name_en) values ('test-search', 'TEST ONLY', 'TEST ONLY');
insert into public.categories (id, name_so) values ('test-search-cat', 'TEST ONLY');

insert into public.hadiths (id, collection_id, hadith_number, source_position, arabic_text, source_name)
values ('00000000-0000-0000-0000-000000006101', 'test-search', '1', 1, 'TEST ONLY إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ', 'TEST ONLY'),
       ('00000000-0000-0000-0000-000000006102', 'test-search', '2', 2, 'TEST ONLY الصَّلاةُ عَلَى الهُدَى', 'TEST ONLY'),
       ('00000000-0000-0000-0000-000000006103', 'test-search', '3', 3, 'TEST ONLY نص سري', 'TEST ONLY');
insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
select 'test-search', n::text, n, 'TEST ONLY نص ' || n, 'TEST ONLY' from generate_series(4, 11) n;

insert into public.translations (hadith_id, text, translator, translation_source, is_primary)
values ('00000000-0000-0000-0000-000000006101', 'TEST ONLY Ficilada waxaa lagu xukumaa NIYADDA', 'TEST', 'TEST', true);
insert into public.gradings (hadith_id, grade, scholar, source_reference)
values ('00000000-0000-0000-0000-000000006101', 'sahih', 'TEST scholar A', 'TEST ref 1'),
       ('00000000-0000-0000-0000-000000006102', 'daif',  'TEST scholar B', 'TEST ref 2'),
       ('00000000-0000-0000-0000-000000006102', 'sahih', 'TEST scholar C', 'TEST ref 3'); -- stays unpublished
insert into public.hadith_categories (hadith_id, category_id)
values ('00000000-0000-0000-0000-000000006101', 'test-search-cat');

-- Publish through the real review workflow (checks + review_record).
create function pg_temp.publish_hadith(h uuid) returns void language plpgsql as $$
declare r constant uuid := '00000000-0000-0000-0000-0000000006b1';
begin
  update public.hadiths set status = 'pending_review' where id = h;
  perform public.record_review_check(h, 'source', true, 'TEST: fixture', r);
  perform public.record_review_check(h, 'arabic', true, 'TEST: fixture', r);
  perform public.review_record('hadith', h, 'verified', 'TEST', r);
  perform public.review_record('hadith', h, 'published', 'TEST', r);
end $$;
create function pg_temp.publish_row(kind text, rid uuid) returns void language plpgsql as $$
declare r constant uuid := '00000000-0000-0000-0000-0000000006b1';
begin
  if kind = 'translation' then
    update public.translations set status = 'pending_review' where id = rid;
  else
    update public.gradings set status = 'pending_review' where id = rid;
  end if;
  perform public.review_record(kind, rid, 'verified', 'TEST', r);
  perform public.review_record(kind, rid, 'published', 'TEST', r);
end $$;

select pg_temp.publish_hadith(id) from public.hadiths
 where collection_id = 'test-search' and id <> '00000000-0000-0000-0000-000000006103';
select pg_temp.publish_row('translation', id) from public.translations
 where hadith_id = '00000000-0000-0000-0000-000000006101';
select pg_temp.publish_row('grading', id) from public.gradings
 where hadith_id in ('00000000-0000-0000-0000-000000006101', '00000000-0000-0000-0000-000000006102')
   and scholar <> 'TEST scholar C';

-- ---- 1. Arabic normalisation (matching only) --------------------------------
do $$ begin
  if public.normalize_arabic('إِنَّمَا') <> 'انما' then raise exception 'FAIL 1: tashkeel/alef'; end if;
  if public.normalize_arabic('أإآٱ') <> 'اااا' then raise exception 'FAIL 1: alef variants'; end if;
  if public.normalize_arabic('الهُدَى') <> 'الهدي' then raise exception 'FAIL 1: alef maqsura'; end if;
  if public.normalize_arabic('الصَّلاةُ') <> 'الصلاه' then raise exception 'FAIL 1: taa marbuta'; end if;
  if public.normalize_arabic('مؤمن سئل') <> 'مومن سيل' then raise exception 'FAIL 1: hamza carriers'; end if;
  if public.normalize_arabic('ســـلام') <> 'سلام' then raise exception 'FAIL 1: tatweel'; end if;
  if public.normalize_arabic('سماء') <> 'سماء' then raise exception 'FAIL 1: standalone hamza must be kept'; end if;
  if public.normalize_arabic('١٢ ۳') <> '12 3' then raise exception 'FAIL 1: digits'; end if;
  if public.normalize_arabic('  a   b ') <> 'a b' then raise exception 'FAIL 1: whitespace'; end if;
  if public.normalize_arabic(null) is not null then raise exception 'FAIL 1: null'; end if;
end $$;

-- ---- 2. Somali normalisation ------------------------------------------------
do $$ begin
  if public.normalize_somali('Ficil’ka   NIYADDA') <> 'ficil''ka niyadda' then raise exception 'FAIL 2: somali'; end if;
  if public.normalize_somali('xaq') = public.normalize_somali('haq') then raise exception 'FAIL 2: x/h merged'; end if;
end $$;

-- ---- 3. original text is never changed --------------------------------------
do $$ begin
  if (select arabic_text from public.hadiths where id = '00000000-0000-0000-0000-000000006101')
     <> 'TEST ONLY إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ' then
    raise exception 'FAIL 3: arabic_text was modified';
  end if;
end $$;

-- ---- as an anonymous reader from here on ------------------------------------
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

-- ---- 4. Arabic search ignores diacritics / letter variants -----------------
do $$ begin
  if not exists (select 1 from public.search_hadiths_v2('انما الاعمال', p_collections => array['test-search'])
                 where id = '00000000-0000-0000-0000-000000006101') then
    raise exception 'FAIL 4: undiacritised query did not match';
  end if;
  if not exists (select 1 from public.search_hadiths_v2('الصلاه علي الهدي', p_collections => array['test-search'])
                 where id = '00000000-0000-0000-0000-000000006102') then
    raise exception 'FAIL 4: ة/ى variants did not match';
  end if;
end $$;

-- ---- 5. Somali search -------------------------------------------------------
do $$ begin
  if not exists (select 1 from public.search_hadiths_v2('niyadda', p_collections => array['test-search'])
                 where id = '00000000-0000-0000-0000-000000006101') then
    raise exception 'FAIL 5: Somali query (case-insensitive) did not match';
  end if;
end $$;

-- ---- 6. unpublished records never appear -----------------------------------
do $$ begin
  if exists (select 1 from public.search_hadiths_v2('سري')) then
    raise exception 'FAIL 6: unpublished hadith found by text';
  end if;
  if exists (select 1 from public.search_hadiths_v2(null, p_collections => array['test-search'], p_limit => 50)
             where id = '00000000-0000-0000-0000-000000006103') then
    raise exception 'FAIL 6: unpublished hadith found by browsing';
  end if;
end $$;

-- ---- 7. filters are evaluated in the database ------------------------------
do $$
declare ids uuid[];
begin
  select array_agg(id) into ids
    from public.search_hadiths_v2(null, p_collections => array['test-search'], p_grades => array['sahih']::public.grade_kind[]);
  if ids is distinct from array['00000000-0000-0000-0000-000000006101'::uuid] then
    raise exception 'FAIL 7: grade filter wrong (unpublished grading must not count): %', ids;
  end if;
  select array_agg(id) into ids
    from public.search_hadiths_v2(null, p_collections => array['test-search'], p_has_translation => true);
  if ids is distinct from array['00000000-0000-0000-0000-000000006101'::uuid] then
    raise exception 'FAIL 7: has-translation filter wrong: %', ids;
  end if;
  select array_agg(id) into ids
    from public.search_hadiths_v2(null, p_categories => array['test-search-cat']);
  if ids is distinct from array['00000000-0000-0000-0000-000000006101'::uuid] then
    raise exception 'FAIL 7: category filter wrong: %', ids;
  end if;
  if exists (select 1 from public.search_hadiths_v2(null, p_collections => array['no-such-collection'])) then
    raise exception 'FAIL 7: collection filter ignored';
  end if;
  if (select grades from public.search_hadiths_v2(null, p_collections => array['test-search'])
       where id = '00000000-0000-0000-0000-000000006102') @> '[{"grade":"sahih"}]' then
    raise exception 'FAIL 7: unpublished grading returned';
  end if;
end $$;

-- ---- 8. cursor pagination: complete, no duplicates, deterministic ----------
do $$
declare
  r record; seen uuid[] := '{}'; pages int := 0; n int;
  a_rank numeric; a_col text; a_pos int;
begin
  loop
    n := 0;
    for r in select * from public.search_hadiths_v2('نص', p_collections => array['test-search'], p_limit => 3,
                                                    p_after_rank => a_rank, p_after_collection => a_col,
                                                    p_after_position => a_pos) loop
      if r.id = any (seen) then raise exception 'FAIL 8: duplicate across pages %', r.id; end if;
      seen := seen || r.id; n := n + 1;
      a_rank := r.rank; a_col := r.collection_id; a_pos := r.source_position;
    end loop;
    pages := pages + 1;
    exit when n < 3 or pages > 20;
  end loop;
  if cardinality(seen) <> (select count(*) from public.search_hadiths_v2('نص', p_collections => array['test-search'], p_limit => 50)) then
    raise exception 'FAIL 8: pages missed rows (% seen)', cardinality(seen);
  end if;
  if cardinality(seen) <> 8 then raise exception 'FAIL 8: expected 8 published نص rows, got %', cardinality(seen); end if;
end $$;

-- ---- 9. limits and hostile input --------------------------------------------
do $$ begin
  if (select count(*) from public.search_hadiths_v2(null, p_limit => 100000)) > 50 then
    raise exception 'FAIL 9: limit not capped at 50';
  end if;
  if exists (select 1 from public.search_hadiths_v2('%%', p_collections => array['test-search'])) then
    raise exception 'FAIL 9: LIKE wildcard not escaped';
  end if;
  perform * from public.search_hadiths_v2(''''' ; drop table public.hadiths; --');
  if to_regclass('public.hadiths') is null then raise exception 'FAIL 9: injection'; end if;
  if exists (select 1 from public.search_hadiths_v2('x')) then
    raise exception 'FAIL 9: 1-letter query must not search';
  end if;
end $$;

-- ---- 10. anon cannot write ---------------------------------------------------
do $$ begin
  begin
    insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
    values ('test-search', '99', 99, 'TEST ONLY', 'TEST ONLY');
    raise exception 'FAIL 10: anon could insert';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
select 'ALL SEARCH V2 CHECKS PASSED' as result;
rollback;
