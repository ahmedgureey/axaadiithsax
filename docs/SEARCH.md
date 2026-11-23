# Search, filtering & pagination (STEP 06)

Status (2026-11-23): implemented in code and tested with a fake API. Migration
`20261124000009_search_v2.sql` has **not been applied to any database yet**,
and `supabase/tests/search_v2_test.sql` has **not been run**.

## Normalisation (matching only, the stored text never changes)

The same rules in two places: `normalize_arabic()` in SQL (migration 0009)
and `ArabicNormalizer` in Dart (local search + import tool).

| Rule | Example |
|---|---|
| Remove tashkeel and Quranic marks (U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED) | إِنَّمَا → انما |
| Remove tatweel (U+0640) | ســـلام → سلام |
| Alef variants أ إ آ ٱ → ا | أإآٱ → اااا |
| Alef maqsura ى → ي | الهدى → الهدي |
| Taa marbuta ة → ه | الصلاة → الصلاه |
| Hamza on a carrier ؤ → و, ئ → ي | مؤمن سئل → مومن سيل |
| Persian look-alikes ک → ك, ی → ي | |
| Arabic-Indic / Eastern digits → 0–9 | ١٢ → 12 |
| Collapse whitespace | |
| **Kept:** standalone hamza ء | سماء stays سماء |

Somali (`normalize_somali()` / Dart): lower case, apostrophe variants
’ ‘ ` ´ → ', whitespace collapsed. Somali letters are never merged (x ≠ h).

## Server search: `search_hadiths_v2`

* Text: Arabic (`hadiths.arabic_search`) or published Somali translation
  (`translations.text_norm`), substring match via trigram indexes; at least 2
  characters. Empty text = browse mode (filters only).
* Filters, all in SQL: collections, books (app "chapters"), categories,
  narrators, documented grades (published gradings only), has a published
  Somali translation.
* Order: `rank desc, collection_id, source_position` — deterministic.
* Paging: keyset cursor `(rank, collection_id, source_position)`; limit ≤ 50.
* Security: `SECURITY INVOKER`, reads the published-only view, RLS applies;
  parameters are bound by PostgREST (no SQL built from strings); `LIKE`
  wildcards are escaped.

## App

* `SearchRequest` / `SearchCursor` (`lib/data/remote/catalog_api.dart`),
  `CatalogService.searchPage` → `SearchPage`.
* Search screen: 250 ms debounce, infinite scroll (loads 600 px before the
  end), pull-to-refresh, reset on any query/filter change, one request at a
  time, stale responses dropped (generation counter), duplicates removed by
  id, retry of a failed page with the same cursor.
* Result card: Arabic, Somali (or "tarjumaad lama hayo"), collection,
  original number, narrator line, grade (one grade when the documented
  gradings agree, otherwise "Darajooyin kala duwan"; nothing when none).
* Bookmark filter is applied on the device (bookmarks are private).
* Narrator filter exists in SQL but has no UI yet (no narrator list in the
  app).

## Verifying on dev

1. Apply migrations 0001–0009.
2. Run `supabase/tests/search_v2_test.sql` → "ALL SEARCH V2 CHECKS PASSED".
3. After importing real published data, run `supabase/tests/search_v2_explain.sql`.
