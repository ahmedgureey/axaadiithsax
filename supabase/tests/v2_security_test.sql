-- =============================================================================
-- Security & workflow checks for catalogue v2.
--
-- Run in the SQL editor (as postgres) AFTER the v2 migrations, on a
-- development/branch database. Everything runs inside one transaction that
-- ends with ROLLBACK: no test rows remain. Each check raises an exception with
-- a clear message if it fails; success ends with "ALL V2 CHECKS PASSED".
--
-- Test rows use the placeholder text 'TEST ONLY' — they are not hadith and are
-- rolled back.
-- =============================================================================

begin;

-- ---- fixtures ---------------------------------------------------------------
insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000000a1', 'reader@test.invalid', 'authenticated', 'authenticated'),
       ('00000000-0000-0000-0000-0000000000a2', 'other@test.invalid',  'authenticated', 'authenticated'),
       ('00000000-0000-0000-0000-0000000000b1', 'reviewer@test.invalid', 'authenticated', 'authenticated');
insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000000b1', 'reviewer');

insert into public.collections (id, name_ar, name_en) values ('test-col', 'TEST ONLY', 'TEST ONLY');
insert into public.hadiths (id, collection_id, hadith_number, source_position, arabic_text, source_name)
values ('00000000-0000-0000-0000-00000000c001', 'test-col', '1', 1, 'TEST ONLY نص', 'TEST ONLY'),
       ('00000000-0000-0000-0000-00000000c002', 'test-col', '2', 2, 'TEST ONLY نص', 'TEST ONLY');
insert into public.translations (hadith_id, text, translator, translation_source, is_primary)
values ('00000000-0000-0000-0000-00000000c001', 'TEST ONLY', 'TEST ONLY', 'TEST ONLY', true);

-- ---- 1. direct verification is blocked ------------------------------------
do $$ begin
  begin
    update public.hadiths set status = 'pending_review' where id = '00000000-0000-0000-0000-00000000c001';
    update public.hadiths set status = 'verified', verified_by = '00000000-0000-0000-0000-0000000000b1',
                              verified_at = now()
      where id = '00000000-0000-0000-0000-00000000c001';
    raise exception 'FAIL 1: direct UPDATE to verified was allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- 2. skipping steps is blocked -----------------------------------------
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000c002', 'published', 'x',
                                 '00000000-0000-0000-0000-0000000000b1');
    raise exception 'FAIL 2: imported -> published was allowed';
  exception when check_violation then null;
  end;
end $$;

-- ---- 3. a non-reviewer cannot review --------------------------------------
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000c001', 'verified', 'x',
                                 '00000000-0000-0000-0000-0000000000a1');
    raise exception 'FAIL 3: non-reviewer could verify';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- 4. verification needs a note -----------------------------------------
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000c001', 'verified', '',
                                 '00000000-0000-0000-0000-0000000000b1');
    raise exception 'FAIL 4: verify without a source note was allowed';
  exception when invalid_parameter_value then null;
  end;
end $$;

-- ---- 5. reviewer path works and is logged ---------------------------------
-- (Check 1 rolled its own changes back, so the hadith is 'imported' again.)
update public.hadiths set status = 'pending_review' where id = '00000000-0000-0000-0000-00000000c001';

-- ---- 5a. (migration 0008) verification needs passed source + Arabic checks
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000c001', 'verified', 'x',
                                 '00000000-0000-0000-0000-0000000000b1');
    raise exception 'FAIL 5a: verified without review checks';
  exception when check_violation then null;
  end;
  begin
    perform public.record_review_check('00000000-0000-0000-0000-00000000c001', 'source', true, 'x',
                                       '00000000-0000-0000-0000-0000000000a1');
    raise exception 'FAIL 5a: non-reviewer recorded a check';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.record_review_check('00000000-0000-0000-0000-00000000c001', 'source', true, '',
                                       '00000000-0000-0000-0000-0000000000b1');
    raise exception 'FAIL 5a: check without a note was accepted';
  exception when invalid_parameter_value then null;
  end;
end $$;

-- A failed check sends the record back for correction; resubmit, then pass.
select public.record_review_check('00000000-0000-0000-0000-00000000c001', 'arabic', false,
                                  'TEST: wording differs from source', '00000000-0000-0000-0000-0000000000b1');
do $$ begin
  if (select status from public.hadiths where id = '00000000-0000-0000-0000-00000000c001') <> 'needs_correction' then
    raise exception 'FAIL 5a: failed check did not set needs_correction';
  end if;
  if (select editorial_stage from public.hadith_review_queue where id = '00000000-0000-0000-0000-00000000c001')
     <> 'needs_correction' then
    raise exception 'FAIL 5a: review queue stage wrong after failed check';
  end if;
end $$;
update public.hadiths set status = 'pending_review' where id = '00000000-0000-0000-0000-00000000c001';
select public.record_review_check('00000000-0000-0000-0000-00000000c001', 'source', true,
                                  'TEST: matches test edition', '00000000-0000-0000-0000-0000000000b1');
do $$ begin
  if (select editorial_stage from public.hadith_review_queue where id = '00000000-0000-0000-0000-00000000c001')
     <> 'pending_arabic_review' then
    raise exception 'FAIL 5a: expected pending_arabic_review';
  end if;
end $$;
select public.record_review_check('00000000-0000-0000-0000-00000000c001', 'arabic', true,
                                  'TEST: wording matches', '00000000-0000-0000-0000-0000000000b1');

select public.review_record('hadith', '00000000-0000-0000-0000-00000000c001', 'verified',
                            'TEST: checked against test source', '00000000-0000-0000-0000-0000000000b1');
select public.review_record('hadith', '00000000-0000-0000-0000-00000000c001', 'published',
                            'TEST: publish', '00000000-0000-0000-0000-0000000000b1');
update public.translations set status = 'pending_review' where hadith_id = '00000000-0000-0000-0000-00000000c001';
select public.review_record('translation', (select id from public.translations
                              where hadith_id = '00000000-0000-0000-0000-00000000c001'),
                            'verified', 'TEST', '00000000-0000-0000-0000-0000000000b1');
select public.review_record('translation', (select id from public.translations
                              where hadith_id = '00000000-0000-0000-0000-00000000c001'),
                            'published', 'TEST', '00000000-0000-0000-0000-0000000000b1');
do $$ begin
  if (select count(*) from public.review_log where entity_id = '00000000-0000-0000-0000-00000000c001') < 3 then
    raise exception 'FAIL 5: status changes were not logged';
  end if;
  if (select verified_by from public.hadiths where id = '00000000-0000-0000-0000-00000000c001')
     is distinct from '00000000-0000-0000-0000-0000000000b1' then
    raise exception 'FAIL 5: verified_by not recorded';
  end if;
end $$;

-- ---- 6. published content is locked ---------------------------------------
do $$ begin
  begin
    update public.hadiths set arabic_text = 'changed' where id = '00000000-0000-0000-0000-00000000c001';
    raise exception 'FAIL 6: published text could be edited';
  exception when check_violation then null;
  end;
end $$;

-- ---- 7. anonymous users see only published --------------------------------
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$ begin
  if (select count(*) from public.hadiths where collection_id = 'test-col') <> 1 then
    raise exception 'FAIL 7: anon sees unpublished hadith';
  end if;
  if (select count(*) from public.hadith_list_items where collection_id = 'test-col' and somali_text is not null) <> 1 then
    raise exception 'FAIL 7: published translation not visible in list view';
  end if;
  if (select count(*) from public.search_hadiths('نص', 'test-col')) <> 1 then
    raise exception 'FAIL 7: search returned unpublished rows or nothing';
  end if;
  begin
    insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name)
    values ('test-col', '9', 9, 'x', 'x');
    raise exception 'FAIL 7: anon could insert a hadith';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- 8. users only touch their own bookmarks ------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
insert into public.bookmarks (user_id, hadith_id)
values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000c001');
do $$ begin
  begin
    insert into public.bookmarks (user_id, hadith_id)
    values ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000c001');
    raise exception 'FAIL 8: could bookmark for another user';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.bookmarks (user_id, hadith_id)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000c002');
    raise exception 'FAIL 8: could bookmark an unpublished hadith';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.hadiths set narrator_text_ar = 'x';
    if found then raise exception 'FAIL 8: signed-in user could update hadiths'; end if;
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';
do $$ begin
  if (select count(*) from public.bookmarks) <> 0 then
    raise exception 'FAIL 8: user can read another user''s bookmarks';
  end if;
  if (select count(*) from public.review_log) <> 0 then
    raise exception 'FAIL 8: non-staff can read the review log';
  end if;
end $$;
reset role;

-- ---- 9. normalization keeps the source intact -----------------------------
do $$ begin
  if public.normalize_arabic('إِنَّمَا الْأَعْمَالُ') <> 'انما الاعمال' then
    raise exception 'FAIL 9: normalize_arabic unexpected result: %', public.normalize_arabic('إِنَّمَا الْأَعْمَالُ');
  end if;
  if public.normalize_arabic('رَحْمَةٌ') <> 'رحمه' or public.normalize_arabic('مُصْطَفَىٰ') <> 'مصطفي' then
    raise exception 'FAIL 9: ta marbuta / alef maqsura not normalized';
  end if;
end $$;

select 'ALL V2 CHECKS PASSED' as result;

rollback;
