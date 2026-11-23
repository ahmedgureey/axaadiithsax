# Hadith import tool

Safe, repeatable import of a **checked, licensed** hadith dataset into the v2
database (`supabase/migrations/`). Design: `docs/BACKEND_DESIGN.md` §8.

> Do not import a dataset until you know where it comes from, that it is
> complete, and that you are allowed to use it (licence/permission). Never
> import invented or AI-generated text. Imported records are **not** verified.

## 1. Prepare the file

Copy `TEMPLATE.json`, replace every `<<…>>` (the validator rejects leftovers).
Copy Arabic text exactly from the source — the tool never changes it.
Do not set `status` or `vowelized_verified`: verification happens in review.

## 2. Validate (no network, nothing written)

```bash
dart run tool/hadith_import/hadith_import.dart path/to/data.json
```

Writes `path/to/data.json.report.json` with counts, errors and warnings
(possible duplicate texts, records without a source identifier).

Checks: format, provenance + licence, collection slug and names, numbering
scheme, unique book/chapter/hadith numbers and positions, chapter ∈ book,
non-empty Arabic, URLs, grades in the allowed list (`other` needs the Arabic
label), one primary translation per language, no duplicate
translation/grading, no template placeholders.

## 3. Import into the DEV project

```powershell
$env:SUPABASE_URL = 'https://<dev-ref>.supabase.co'
$env:SUPABASE_SECRET_KEY = '<secret key — do not share or commit>'
dart run tool/hadith_import/hadith_import.dart path\to\data.json --apply --confirm-project=<dev-ref>
```

* `--confirm-project` must equal the project in `SUPABASE_URL`; otherwise the
  tool refuses to write.
* INSERT only: existing records (same collection + numbering scheme + number)
  are skipped, never overwritten. Re-running the same command resumes a broken
  import.
* Translations/gradings/topics are attached only to hadith created in that run.
* Each run creates an `import_batches` row (source, licence, file SHA-256,
  counts, errors); every record points at it.

## 4. Review

Editorial stages (derived, see view `hadith_review_queue.editorial_stage`):

```
imported → pending_source_verification → pending_arabic_review →
pending_translation_review → pending_grading_verification → ready_to_verify
→ verified → published          (+ needs_correction, rejected)
```

Grant a reviewer once (SQL editor):

```sql
insert into public.user_roles (user_id, role) values ('<auth user id>', 'reviewer');
```

A reviewer compares each record with the cited printed edition / source and
records two checks (a note is mandatory; a failed check sends the record to
`needs_correction`):

```sql
select public.record_review_check('<hadith id>', 'source', true, 'Matches <edition>, no. 52, vol 1 p. 20');
select public.record_review_check('<hadith id>', 'arabic', true, 'Wording and tashkeel match <edition>');
```

Translations and gradings are reviewed on their own rows:

```sql
select public.review_record('translation', '<translation id>', 'pending_review');
select public.review_record('translation', '<translation id>', 'verified', 'Meaning checked by <reviewer>');
select public.review_record('translation', '<translation id>', 'published', 'Ready');
select public.review_record('grading', '<grading id>', 'verified', 'Confirmed in <scholar, book, page>');
select public.review_record('grading', '<grading id>', 'published', 'Ready');
```

Then the hadith itself (refused unless both checks passed):

```sql
select public.review_record('hadith', '<hadith id>', 'verified', 'Source + Arabic checks passed');
select public.review_record('hadith', '<hadith id>', 'published', 'Ready');
```

From the SQL editor (no signed-in user) add the reviewer's user id as the last
argument of `record_review_check` / `review_record`. Every status change and
check is kept (`review_log`, `hadith_review_checks`). Only published records
— with only their published translations and gradings — appear in the app.
Automated checks never replace this human review.

## 5. Production

Only after the dev import and review work end-to-end, and with the owner's
explicit go-ahead: repeat step 3 with the production URL/ref.

## Source adapter: fawazahmed0/hadith-api

```powershell
# 1. download from the COMMIT-PINNED url (checksum stays reproducible)
curl -o import_data\src.json https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@<sha>/editions/ara-nawawi.json
# 2. convert (Arabic copied exactly; only structured grades become gradings)
dart run tool/hadith_import/convert_fawazahmed0.dart import_data\src.json import_data\nawawi40.import.json --edition=ara-nawawi --commit=<sha> --collection=nawawi40 "--name-ar=الأربعون النووية" "--name-en=Forty Hadith of an-Nawawi" "--compiler-en=Imam Nawawi" --retrieved=2026-11-23 --br-to-newline
# 3. validate (dry run), then import into DEV (step 3 above)
dart run tool/hadith_import/hadith_import.dart import_data\nawawi40.import.json
```

`--br-to-newline` is the only text change the adapter can make: HTML `<br>`
becomes a new line and the record gets `normalization_notes`. `import_data/`
is git-ignored; decide per licence before committing data.
