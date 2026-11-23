# Database tests (catalogue v2)

| File | Run as | Checks |
|---|---|---|
| `v2_security_test.sql` | `postgres` | review workflow, locking, anon/user visibility, own bookmarks, normalization |
| `v2_integrity_test.sql` | `postgres` | foreign keys, unique constraints, required fields, duplicate detection, provenance columns, RLS on every table, grants, cascade on user delete |
| `v2_api_role_test.sql` | `authenticator` | what API requests can do: secret key (service_role) cannot verify/publish, no impersonating reviewers, anon/user limits |

Every file runs in one transaction and ends with `ROLLBACK` — no rows are left.
Test rows contain only the placeholder `TEST ONLY` (never hadith text).

## Run on an isolated local Postgres (recommended, no Supabase needed)

Uses the PostgreSQL 16 install on this machine; creates a throwaway cluster on
port 54329 that is separate from any other database.

```powershell
$pg = 'C:\Program Files\PostgreSQL\16\bin'
$dir = "$env:TEMP\xadiis_pgtest"
& "$pg\initdb.exe" -D $dir -U postgres --auth=trust -E UTF8 --locale=C
& "$pg\pg_ctl.exe" -D $dir -o "-p 54329" -l "$dir.log" -w start
& "$pg\psql.exe" -p 54329 -U postgres -c "create database xadiis_test"
$env:PGCLIENTENCODING = 'UTF8'
& "$pg\psql.exe" -p 54329 -U postgres -d xadiis_test -v ON_ERROR_STOP=1 -f supabase\tests\local_supabase_shim.sql
Get-ChildItem supabase\migrations\*.sql | Sort-Object Name | ForEach-Object {
  & "$pg\psql.exe" -p 54329 -U postgres -d xadiis_test -v ON_ERROR_STOP=1 -q -f $_.FullName }
& "$pg\psql.exe" -p 54329 -U postgres      -d xadiis_test -v ON_ERROR_STOP=1 -f supabase\tests\v2_security_test.sql
& "$pg\psql.exe" -p 54329 -U postgres      -d xadiis_test -v ON_ERROR_STOP=1 -f supabase\tests\v2_integrity_test.sql
& "$pg\psql.exe" -p 54329 -U authenticator -d xadiis_test -v ON_ERROR_STOP=1 -f supabase\tests\v2_api_role_test.sql
# when finished:
& "$pg\pg_ctl.exe" -D $dir stop
Remove-Item -Recurse -Force $dir
```

`local_supabase_shim.sql` is **test-only**: it creates the Supabase roles
(`anon`, `authenticated`, `service_role`, `authenticator`), `auth.users`,
`auth.uid()` and Supabase's default grants. Never run it on a Supabase project.

## Run on a Supabase dev branch / dev project

After applying the migrations there, paste `v2_security_test.sql` and
`v2_integrity_test.sql` into the SQL editor. `v2_api_role_test.sql` needs an
`authenticator` login, which Supabase does not give you; instead confirm via the
API that `POST /rest/v1/rpc/review_record` is refused with the secret key.
