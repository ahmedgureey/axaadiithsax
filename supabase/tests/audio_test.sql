-- =============================================================================
-- Checks for hadith_audio (migration 0010). Run as postgres in the SQL editor
-- on a dev database AFTER migrations 0001–0010. One transaction, ROLLBACK at
-- the end. Success ends with "ALL AUDIO CHECKS PASSED".
-- The URL below is a placeholder that is never fetched; rows are test data.
-- =============================================================================

begin;

insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000007b1', 'audio-reviewer@test.invalid', 'authenticated', 'authenticated');
insert into public.user_roles (user_id, role) values ('00000000-0000-0000-0000-0000000007b1', 'reviewer');
insert into public.collections (id, name_ar, name_en) values ('test-audio', 'TEST ONLY', 'TEST ONLY');
insert into public.hadiths (id, collection_id, hadith_number, source_position, arabic_text, source_name)
values ('00000000-0000-0000-0000-000000007101', 'test-audio', '1', 1, 'TEST ONLY نص', 'TEST ONLY');

-- publish the test hadith through the normal workflow
update public.hadiths set status = 'pending_review' where id = '00000000-0000-0000-0000-000000007101';
select public.record_review_check('00000000-0000-0000-0000-000000007101', 'source', true, 'TEST', '00000000-0000-0000-0000-0000000007b1');
select public.record_review_check('00000000-0000-0000-0000-000000007101', 'arabic', true, 'TEST', '00000000-0000-0000-0000-0000000007b1');
select public.review_record('hadith', '00000000-0000-0000-0000-000000007101', 'verified', 'TEST', '00000000-0000-0000-0000-0000000007b1');
select public.review_record('hadith', '00000000-0000-0000-0000-000000007101', 'published', 'TEST', '00000000-0000-0000-0000-0000000007b1');

insert into public.hadith_audio (id, hadith_id, audio_url, reciter, source_name, license)
values ('00000000-0000-0000-0000-000000007a01', '00000000-0000-0000-0000-000000007101',
        'https://example.invalid/test.mp3', 'TEST reciter', 'TEST source', 'TEST licence');

-- 1. http (not https) URLs and empty licence are rejected
do $$ begin
  begin
    insert into public.hadith_audio (hadith_id, audio_url, reciter, source_name, license, is_primary)
    values ('00000000-0000-0000-0000-000000007101', 'http://example.invalid/x.mp3', 'r', 's', 'l', false);
    raise exception 'FAIL 1: http URL accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.hadith_audio (hadith_id, audio_url, reciter, source_name, license, is_primary)
    values ('00000000-0000-0000-0000-000000007101', 'https://example.invalid/x.mp3', 'r', 's', ' ', false);
    raise exception 'FAIL 1: empty licence accepted';
  exception when check_violation then null;
  end;
end $$;

-- 2. direct publish is blocked
do $$ begin
  begin
    update public.hadith_audio set status = 'published', verified_by = '00000000-0000-0000-0000-0000000007b1',
                                   verified_at = now()
     where id = '00000000-0000-0000-0000-000000007a01';
    raise exception 'FAIL 2: direct publish allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 3. publish requires verified first; anon sees nothing before publishing
do $$ begin
  begin
    perform public.review_audio('00000000-0000-0000-0000-000000007a01', 'published', 'x', '00000000-0000-0000-0000-0000000007b1');
    raise exception 'FAIL 3: published without verification';
  exception when check_violation then null;
  end;
end $$;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$ begin
  if exists (select 1 from public.hadith_audio) then raise exception 'FAIL 3: anon sees unpublished audio'; end if;
end $$;
reset role;

-- 4. review flow; anon sees published audio
select public.review_audio('00000000-0000-0000-0000-000000007a01', 'verified', 'TEST: licence + hadith no. + audio checked', '00000000-0000-0000-0000-0000000007b1');
select public.review_audio('00000000-0000-0000-0000-000000007a01', 'published', 'TEST: publish', '00000000-0000-0000-0000-0000000007b1');
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$ begin
  if (select count(*) from public.hadith_audio) <> 1 then raise exception 'FAIL 4: anon cannot see published audio'; end if;
  begin
    insert into public.hadith_audio (hadith_id, audio_url, reciter, source_name, license, is_primary)
    values ('00000000-0000-0000-0000-000000007101', 'https://example.invalid/y.mp3', 'r', 's', 'l', false);
    raise exception 'FAIL 4: anon could insert';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- 5. published audio is locked
do $$ begin
  begin
    update public.hadith_audio set audio_url = 'https://example.invalid/other.mp3'
     where id = '00000000-0000-0000-0000-000000007a01';
    raise exception 'FAIL 5: published audio URL could be changed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 6. hadith text untouched
do $$ begin
  if (select arabic_text from public.hadiths where id = '00000000-0000-0000-0000-000000007101') <> 'TEST ONLY نص' then
    raise exception 'FAIL 6: hadith text changed';
  end if;
end $$;

select 'ALL AUDIO CHECKS PASSED' as result;
rollback;
