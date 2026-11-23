-- =============================================================================
-- API-role checks for catalogue v2: what a request through the Supabase API
-- (PostgREST) can and cannot do.
--
-- MUST be run while logged in as the 'authenticator' role (the role PostgREST
-- connects as), NOT as postgres — otherwise session_user is postgres and the
-- review_record() owner branch would be (correctly) open. Locally:
--   psql -U authenticator -d <db> -f supabase/tests/v2_api_role_test.sql
-- On a Supabase dev/branch project, connect with the pooler/direct URL using
-- the 'authenticator' user is not possible; there, these behaviours are
-- covered by calling the RPC with the publishable / secret key instead.
--
-- One transaction, ends with ROLLBACK. Success: "ALL API ROLE CHECKS PASSED".
-- =============================================================================

begin;

do $$ begin
  if session_user::text <> 'authenticator' then
    raise exception 'Run this file as the authenticator role (session_user is %)', session_user;
  end if;
end $$;

-- ---- 1. secret key (service_role) cannot verify/publish via review_record --
set local role service_role;
do $$ begin
  begin
    perform public.review_record('hadith', gen_random_uuid(), 'verified', 'x', gen_random_uuid());
    raise exception 'FAIL 1: service_role could call review_record';
  exception when insufficient_privilege then
    -- Must be refused before any reviewer lookup (no EXECUTE, or "Not signed in").
    -- "Only reviewers ..." would mean the owner branch was open to the API.
    if sqlerrm like 'Only reviewers%' then
      raise exception 'FAIL 1: service_role reached the reviewer lookup (could act for a real reviewer)';
    end if;
  end;
end $$;

-- ---- 2. service_role (import script) inserts only as imported ---------------
insert into public.collections (id, name_ar, name_en) values ('test-api', 'TEST ONLY', 'TEST ONLY');
insert into public.hadiths (id, collection_id, hadith_number, source_position, arabic_text, source_name)
values ('00000000-0000-0000-0000-00000000f001', 'test-api', '1', 1, 'TEST ONLY', 'TEST ONLY');
do $$ begin
  begin
    insert into public.hadiths (collection_id, hadith_number, source_position, arabic_text, source_name,
                                status, verified_by, verified_at, published_at)
    values ('test-api', '2', 2, 'TEST ONLY', 'TEST ONLY', 'published', gen_random_uuid(), now(), now());
    raise exception 'FAIL 2: service_role inserted a published hadith';
  exception when check_violation then null;
  end;
  update public.hadiths set status = 'pending_review' where id = '00000000-0000-0000-0000-00000000f001';
  begin
    update public.hadiths set status = 'verified', verified_by = gen_random_uuid(), verified_at = now()
      where id = '00000000-0000-0000-0000-00000000f001';
    raise exception 'FAIL 2: service_role verified by direct UPDATE';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- 3. a signed-in request without a user id cannot name a reviewer -------
set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated"}';
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000f001', 'verified', 'x',
                                 gen_random_uuid());
    raise exception 'FAIL 3: request without sub acted as a named reviewer';
  exception when insufficient_privilege then
    if sqlerrm <> 'Not signed in' then
      raise exception 'FAIL 3: request without sub reached the reviewer lookup (%): could act for a real reviewer', sqlerrm;
    end if;
  end;
end $$;

-- ---- 4. a signed-in user cannot act as somebody else -----------------------
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000f001', 'verified', 'x',
                                 '00000000-0000-0000-0000-0000000000b1');
    raise exception 'FAIL 4: user acted as another reviewer';
  exception when insufficient_privilege then null;
  end;
  -- and sees nothing unpublished
  if exists (select 1 from public.hadiths where collection_id = 'test-api') then
    raise exception 'FAIL 4: signed-in user sees unpublished hadith';
  end if;
  begin
    insert into public.collections (id, name_ar, name_en) values ('test-api-2', 'x', 'x');
    raise exception 'FAIL 4: signed-in user created a collection';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- 5. anonymous -----------------------------------------------------------
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$ begin
  begin
    perform public.review_record('hadith', '00000000-0000-0000-0000-00000000f001', 'verified', 'x', gen_random_uuid());
    raise exception 'FAIL 5: anon could call review_record';
  exception when insufficient_privilege then null;
  end;
  if exists (select 1 from public.hadiths where collection_id = 'test-api') then
    raise exception 'FAIL 5: anon sees unpublished hadith';
  end if;
  begin
    perform 1 from public.import_batches;
    raise exception 'FAIL 5: anon can read import batches';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.bookmarks (user_id, hadith_id) values (gen_random_uuid(), '00000000-0000-0000-0000-00000000f001');
    raise exception 'FAIL 5: anon inserted a bookmark';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select 'ALL API ROLE CHECKS PASSED' as result;

rollback;
