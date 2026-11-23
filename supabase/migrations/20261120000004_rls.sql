-- =============================================================================
-- Xadiith App — catalogue v2, part 4: Row Level Security.
--
-- * Everyone (anon + signed in) reads catalogue metadata and PUBLISHED records.
-- * Staff (any role in user_roles) can also read unpublished records.
-- * Nobody can write catalogue tables through the API: there are no
--   insert/update/delete policies. Content arrives through the import script
--   (secret key, trusted machine) and changes status only via review_record().
-- * Users read and write only their own profile, bookmarks and history.
-- =============================================================================

alter table public.collections       enable row level security;
alter table public.books             enable row level security;
alter table public.chapters          enable row level security;
alter table public.categories        enable row level security;
alter table public.narrators         enable row level security;
alter table public.hadiths           enable row level security;
alter table public.hadith_narrators  enable row level security;
alter table public.hadith_categories enable row level security;
alter table public.translations      enable row level security;
alter table public.gradings          enable row level security;
alter table public.review_log        enable row level security;
alter table public.profiles          enable row level security;
alter table public.bookmarks         enable row level security;
alter table public.reading_history   enable row level security;
alter table public.user_roles        enable row level security;

-- Policies are recreated so the migration can be re-run safely.
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in (
      'collections','books','chapters','categories','narrators','hadiths','hadith_narrators',
      'hadith_categories','translations','gradings','review_log','profiles','bookmarks',
      'reading_history','user_roles')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Catalogue metadata (names only, no hadith content).
create policy "read metadata" on public.collections for select to anon, authenticated using (true);
create policy "read metadata" on public.books       for select to anon, authenticated using (true);
create policy "read metadata" on public.chapters    for select to anon, authenticated using (true);
create policy "read metadata" on public.categories  for select to anon, authenticated using (true);

-- Content: published for everyone, everything for staff.
create policy "read published" on public.hadiths for select to anon, authenticated
  using (status = 'published' or public.is_staff());

create policy "read published" on public.narrators for select to anon, authenticated
  using (status = 'published' or public.is_staff());

create policy "read published" on public.translations for select to anon, authenticated
  using (
    public.is_staff()
    or (status = 'published'
        and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published'))
  );

create policy "read published" on public.gradings for select to anon, authenticated
  using (
    public.is_staff()
    or (status = 'published'
        and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published'))
  );

create policy "read published" on public.hadith_narrators for select to anon, authenticated
  using (
    public.is_staff()
    or exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );

create policy "read published" on public.hadith_categories for select to anon, authenticated
  using (
    public.is_staff()
    or exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );

create policy "staff read" on public.review_log for select to authenticated using (public.is_staff());

-- Own rows only.
create policy "own profile read"   on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "own profile insert" on public.profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own profile delete" on public.profiles for delete to authenticated using (user_id = (select auth.uid()));

create policy "own bookmarks read"   on public.bookmarks for select to authenticated using (user_id = (select auth.uid()));
create policy "own bookmarks insert" on public.bookmarks for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );
create policy "own bookmarks delete" on public.bookmarks for delete to authenticated using (user_id = (select auth.uid()));

create policy "own history read"   on public.reading_history for select to authenticated using (user_id = (select auth.uid()));
create policy "own history insert" on public.reading_history for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.hadiths h where h.id = hadith_id and h.status = 'published')
  );
create policy "own history update" on public.reading_history for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own history delete" on public.reading_history for delete to authenticated using (user_id = (select auth.uid()));

create policy "own roles read" on public.user_roles for select to authenticated using (user_id = (select auth.uid()));

-- Table privileges (RLS still applies on top).
revoke all on public.collections, public.books, public.chapters, public.categories, public.narrators,
              public.hadiths, public.hadith_narrators, public.hadith_categories, public.translations,
              public.gradings, public.review_log, public.profiles, public.bookmarks,
              public.reading_history, public.user_roles
  from anon, authenticated;

grant select on public.collections, public.books, public.chapters, public.categories, public.narrators,
                public.hadiths, public.hadith_narrators, public.hadith_categories, public.translations,
                public.gradings
  to anon, authenticated;
grant select on public.review_log, public.user_roles to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, delete on public.bookmarks to authenticated;
grant select, insert, update, delete on public.reading_history to authenticated;
