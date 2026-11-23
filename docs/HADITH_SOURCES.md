# Hadith data sources — evaluation (STEP 05)

Status (2026-11-23): the owner approved a **trial with Nawawi 40** from
fawazahmed0/hadith-api. The edition `ara-nawawi` (git
`df57907be35291c91ad6a6691180e22ca9920784`, SHA-256 of the file
`91f559b9…77465e6`) was downloaded, converted and **validated (dry run): 42
records, 0 errors, 0 warnings**. 10 records contained HTML `<br>` line breaks;
these were converted to new lines and documented per record
(`normalization_notes`); the other 32 texts are byte-identical to the source.
The dataset has **no structured grades and no Somali** for this edition, so
the trial has 0 gradings and 0 translations. **Nothing has been written to
any database** (no project access yet), and nothing is verified or published.

This page records what was checked, what could not be confirmed, and what the
owner must decide. Checking a source's availability is not the
same as verifying its content: every record still goes through human review
(`tool/hadith_import/README.md` §4).

## Findings

| Source | What it offers | Licence / terms | Confirmed? | Use for Xadiith App |
|---|---|---|---|---|
| **fawazahmed0/hadith-api** (GitHub, jsDelivr) | 10 collections: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah, Muwatta Malik, Nawawi 40, Qudsi 40, Dehlawi 40. Two Arabic editions each (one with diacritics removed "for easier searching"); translations in Bengali, English, French, Indonesian, Russian, Tamil, Turkish, Urdu. Grades by named scholars (e.g. al-Albani for Abu Dawud/Nasa'i/Tirmidhi/Ibn Majah; al-Arna'ut; Ahmad Shakir; Bashar 'Awwad Ma'ruf; Salim al-Hilali for Muwatta), referenced to al-maktaba.org book IDs | Repository marked **Unlicense** (read from the repo page; LICENSE file itself not opened) | Editions list read directly. **Not confirmed:** which printed edition the Arabic text comes from; per-record field names; whether the "plain" Arabic edition is fully vowelized | **Best candidate for Arabic text + gradings**, provided reviewers verify each record against a named printed edition (source check) — the dataset does not document its Arabic edition |
| **sunnah.com API** | Arabic text, English translations, grading data (raw JSON per their docs) | API key on request (GitHub issue). Terms page and reproduction rules **could not be read** (HTTP 403) | Not confirmed | Possible, but only after reading the terms and getting a key; English translations belong to their translators |
| **mhashim6/Open-Hadith-Data** | CSV of 9 books, with and without tashkeel | GitHub licence field "other" | Not confirmed | Not recommended until the licence is clarified |
| **AhmedBaset/hadith-json**, **CheeseWithSauce/HadithsJSONFormat** | JSON of several books with grades | MIT on the repo, but data **scraped from sunnah.com** | Licence of underlying data unclear | **Avoid** (scraped; repo licence may not cover the text) |
| Bilingual Bukhari packages (npm/PyPI `sahih-al-bukhari`) | 7,277 hadith Arabic + English | AGPL-3.0 | Not checked in depth | Avoid for an app (copyleft, single collection) |
| **Somali translations** | — | — | **No digital Somali hadith dataset was found** | Must come from a Somali translator/scholar or a published Somali translation **with written permission**; until then records show "tarjumaad lama hayo" |

Sources consulted: github.com/fawazahmed0/hadith-api (README, References.md),
cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions.json, sunnah.com
developer listing (search results only), github.com/mhashim6/Open-Hadith-Data,
github.com/AhmedBaset/hadith-json, github.com/CheeseWithSauce/HadithsJSONFormat.

## Recommendation (needs owner approval)

1. **Arabic + gradings:** fawazahmed0/hadith-api, one collection at a time,
   starting small (e.g. Nawawi 40 → then Bukhari). Record the dataset version
   (git commit) in `provenance.source_edition`. Import gradings exactly as
   attributed (scholar + al-maktaba reference); **do not** derive grades from
   the collection name (Bukhari/Muslim inclusion ≠ a separate grading record).
2. **Printed edition for verification:** choose the edition reviewers will
   check against (e.g. the Fu'ad 'Abd al-Baqi numbering for Muslim/Ibn Majah);
   record it in `numbering_scheme` and in every source-check note.
3. **Somali:** decide who translates or which published translation is used,
   and obtain permission in writing; store translator + source per record.
4. **Reviewers:** name at least one qualified reviewer; create their account
   and grant the `reviewer` role (SQL in `tool/hadith_import/README.md`).

## Licensing notes

* Classical hadith texts are generally out of copyright, but **datasets,
  editions (tashkeel/annotation) and translations can carry rights**. Keep
  the licence or written permission in `provenance.license` for every batch.
* Do not scrape websites. Do not redistribute a translation without the
  translator's or publisher's permission.
* This is not legal advice; confirm with the rights holders.
