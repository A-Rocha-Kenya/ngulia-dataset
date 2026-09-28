# Historical Isabelline Shrike identifications

Reviewed 2026-09-28 against the local eBird/Clements 2025 checklist, the source workbooks, and Avibase taxonomic concepts.

The historical AFRING code `2288` / Ngulia code `10` / abbreviation `LANISA` includes both current Red-tailed and Isabelline Shrikes. It must map to `avibase-959151D9`, **Red-tailed/Isabelline Shrike** (`Lanius phoenicuroides/isabellinus`, checklist category `slash`), unless an explicit race/form note resolves the individual. The slash entry has no single parent species; its observations must not be included in either species' totals.

## Findings and changes

The publication validation found **291** events with `avibase_id = avibase-97166F72` (Isabelline Shrike) and `subspecies_avibase_id = avibase-EE7915A2`. The latter ID represents the current **Red-tailed Shrike species**, not an Isabelline Shrike subspecies. `add_taxonomy()` previously joined the historical species code independently from the race note and never reconciled the two. The source correction restoring `phoen.` to the race/form field at `1993.xls`, `1993 All`, row `14310` is consistent with the source identification; removing that correction would conceal a mapping error.

The recent removal of subspecies absent from Clements also discarded useful split-species evidence. In particular, the documentation incorrectly retained *karelini* under Isabelline Shrike. Avibase treats [*karelini*](https://avibase.bsc-eoc.org/species.jsp?avibaseid=215A6FEA) as a synonym/form of *Lanius phoenicuroides*, and [*speculigerus*](https://avibase.bsc-eoc.org/species.jsp?avibaseid=A5FEB966) as a synonym of *Lanius isabellinus*. Retired IDs are replaced by recognized current concepts rather than simply cleared.

| Historical note | Current species ID | Published lower-rank ID |
| --- | --- | --- |
| `phoenicuroides` and the explicitly reviewed spelling/abbreviation variants | `avibase-EE7915A2` (Red-tailed Shrike) | Empty: current species is monotypic |
| `karelini`, `karel` | `avibase-EE7915A2` (Red-tailed Shrike) | Empty: retired synonym/form |
| `speculigerus`, `specul.`, `specul`, `specu.` | `avibase-97166F72` (Isabelline Shrike) | `avibase-E40C1C33` (Daurian, checklist `group (monotypic)`) |
| `isabellinus` and existing reviewed variants | `avibase-97166F72` (Isabelline Shrike) | Empty: historical usage does not establish the modern subspecies |
| `arenarius` | `avibase-97166F72` (Isabelline Shrike) | `avibase-20A6541A` |
| No diagnostic note, uncertain note, or descriptive plumage text alone | `avibase-959151D9` (Red-tailed/Isabelline Shrike) | Empty |

The name *isabellinus* was historically used for a different subspecies concept before the nomenclatural change involving *speculigerus* and *arenarius*. It still identifies the current Isabelline species in this two-species split, but the current Daurian subspecies/group must not be inferred from that name alone. See the taxonomic history in [Avibase's Daurian concept](https://avibase.bsc-eoc.org/species.jsp?avibaseid=E40C1C33) and [Panov (2009)](https://www.osme.org/wp-content/uploads/2019/10/12-Panov_C_pp163-170_31_2_Sandgrouse.pdf).

`subspecies_lookup.csv` retains its legacy column name `subspecies_avibase_id` as the note-to-concept configuration key. The resolver checks the current checklist rank: species concepts resolve the event's main `avibase_id`; only recognized lower ranks populate the public `subspecies_avibase_id`. Promotion from a source slash entry uses the recognized concept's parent species. Source notes are retained verbatim and no distribution or biometric inference is used.

## Counts and other observation tables

Before this review, all **2,246** historical 2288 ring events were published as Isabelline Shrike, including 291 with Red-tailed species IDs in the subspecies column. The revised mapping yields:

- **307 Red-tailed Shrike events**: 291 existing *phoenicuroides* mappings plus 16 *karelini/karel* events.
- **75 Isabelline Shrike events**: 55 *isabellinus* variants, 19 *speculigerus* variants, and one *arenarius* event. Only the latter 20 have resolved lower-rank IDs.
- **1,864 Red-tailed/Isabelline Shrike events**, retaining the unresolved historical identification.

DJP daily summaries provide species-code totals without individual race/form evidence. Historical code 2288 totals therefore use the slash entry. Ring-derived daily counts use the resolved event IDs. Rebuild `daily_counts.csv` and recorded `taxonomy.csv` after rebuilding ring events; the total number of birds is unchanged.

Recovery records `NGREC-0029` / `A27566` and `NGREC-0030` / `A27841` were checked against `Recoveries and Controls.xls`, sheet `Sheet1`. Both original entries give only `LANISA`, without race/form evidence. The manually curated canonical recovery table now uses the slash ID and records this reason in `curation_notes`. Their Kuwait localities do not establish either species.

## Source conflicts requiring further evidence

The initial review identified three events with Red-backed Shrike source codes but notes identifying a different shrike:

| Event ID | Ingestion workbook / sheet / internal `source_row` | Source species | Source note |
| --- | --- | --- | --- |
| `3479244__20001121` | `2000.xls`, `Sheet1`, `24741`; also combined 1993–2005 workbook, `Ngulia Data 1993-2005`, `33442` | `LANCOL` in both workbooks | `phoenicuroides` in 2000; `phoen` in combined workbook |
| `3501533__20031126` | Combined 1993–2005 workbook, `Ngulia Data 1993-2005`, `43662` | `LANCOL` | `isabellinus` |
| `3548834__20121121` | `2012.xls`, `Sheet1`, `5872` | Ngulia `8`, `L. collurio` | `phoen` |

These are separate species-code/race-note conflicts, not historical code 2288 records. They are now published as Unknown with no subspecies assignment, with both source identifications preserved in the taxonomy note audit. A note alone does not establish whether the code or the race field was entered incorrectly; consult the original field/logbook evidence before making a row correction. Uncertain annotations such as `isab?`, `?karelini`, and `phoen/karelini?` remain unresolved rather than being matched by a broad prefix rule.


### Direct check of earlier source spreadsheets

On 2026-09-28 the earlier DJP book-entry files were inspected, including surrounding rows, merged cells, cell notes, and font formatting. All three conflicts already exist in these earlier files. There are no comments, struck-out species labels, or distinct cell formatting establishing a superseding identification on the target rows. These spreadsheet versions are derived copies, so repetition of a value is not independent confirmation of the bird's identity.

| Ring | Earlier workbook | Sheet and actual Excel cells | Recorded contradiction |
| --- | --- | --- | --- |
| `3479244` | `data/01_raw/external/ngulia_djp/From DJP 2017/RINGS 2000/NGULIA 00 REST.xls` | `Sheet1`, `F44 = LANCOL`, `G44 = 3479244`, `O44 = phoenicuroides` | Red-backed species code and Red-tailed form name |
| `3501533` | `data/01_raw/external/ngulia_djp/From DJP 2017/RINGS 2001-2007, processed/Rings 2003.xls` | `Sheet3`, `G316 = LANCOL`, `H316 = 3501533`, `Q316 = isabellinus` | Red-backed species code and Isabelline form name |
| `3548834` | `data/01_raw/external/ngulia_djp/From DJP 2017/RINGS 2012/Books 1-4.xls` | `Sheet1`, `A5873 = 3548834`, `B5873 = 8`, `C5873 = L. collurio`, `R5873 = phoen` | Red-backed numeric code and name, but Red-tailed form name |

The equivalent combined/processed copies retain the same contradictions. In `2000.xls`, the actual Excel row is `24740`; in the combined 1993–2005 XLSX, the actual rows are `33441` and `43661`; in `2012.xls`, the actual row is `5873`. The ingestion `source_row` values in the earlier table are pipeline identifiers and should not be assumed to equal Excel row numbers.

Nearby rows do not settle which field is wrong:

- The 2000 entry is followed immediately by ring `3479245`, coded `LANISA` with an empty remarks field. A species-code error and a displaced remark are both possible.
- The 2003 entry is preceded by ring `3501532`, explicitly coded `LANISA` with `phoenicuroides`; ring `3501533` itself has `isabellinus`. The sheet does distinguish the forms, but that does not prove whether the target's code or annotation is wrong.
- The 2012 entry is preceded by ring `3548833`, coded `10` / `L. isabellinus` with `phoen`. The target also has `phoen` despite code `8` / `L. collurio`. This is compatible with a species-code error, but copying a note remains possible.

The curated records contain no additional capture of these ring numbers providing a consistent identification. Wing/weight values are not decisive for these taxa. If the explicit form notes are trusted, the implied species are Red-tailed, Isabelline, and Red-tailed respectively; this remains a curation assumption, not a recovered unambiguous identification. The source spreadsheets therefore do not justify a definitive species/subspecies correction on their own. The resolver publishes these records as Unknown and retains both identifications in the audit. Original field-book pages, identifiable photographs, or confirmation from the recorders would be needed to adjudicate the conflicts.

## General consistency rule

The historical-lump rule applies to `LANISA` / AFRING `2288` / Ngulia `10`: unresolved records retain the two-species slash, and reviewed race/form notes resolve current species. `LANCOL` / AFRING `708` / Ngulia `8` is a separate Red-backed identification. These source workbooks explicitly distinguish both codes, including on adjacent rows. A blanket conversion of code 708 to the two-species slash would discard the recorded Red-backed identifications.

For **every species**, a recognized diagnostic note is checked against the source taxon's current species parent. A slash entry accepts only a note whose parent is one of the slash's species members. A compatible note can resolve a historical split or supply a valid subspecies. A contradictory note maps the entire event to `avibase-AF0D818A` / Unknown and clears `subspecies_avibase_id`; neither the source species code nor the note is assumed correct. Multiple contradictory species or lower-rank note identifications also produce Unknown rather than selecting the first match. Unmapped prose or uncertain annotations alone are not evidence of a contradiction.

The note lookup records the taxonomic meaning of a diagnostic annotation even when that meaning conflicts with the species code. This makes the contradiction detectable; it does **not** authorize replacing the species with the note's candidate identification. No raw spreadsheet cells or row-level species corrections were changed.

The wider audit also identified these two shrike conflicts:

| Event ID | Direct workbook evidence |
| --- | --- |
| `3637071__20201114` | `2020.xlsx`, `Ring Data`, `D7570 = 708`, `N7570 = phon`; the species name cell is a lookup formula driven by code 708 |
| `3636550__20221119` | `2022.xlsx`, `2022 All Pal Data`, `D830 = 708`, `E830 = Red-backed Shrike`, `N830 = Turk` |

`phon` and `Turk` are interpreted as Red-tailed-form annotations for conflict detection. Both events become Unknown, not Red-tailed. Other recognized contradictions in the lookup are Thrush Nightingale or White-throated Robin with `africana` (a Common Nightingale annotation), Marsh Warbler or Greater Whitethroat with `yakutensis` (a Willow Warbler annotation), and River Warbler with `icterops` (a Greater Whitethroat annotation). Candidate IDs describe the annotation for QA and do not establish which bird was caught.

The rebuilt dataset contains 15 conflicting events: five Red-backed Shrikes, five Thrush Nightingales, two Marsh Warblers, one White-throated Robin, one Greater Whitethroat and one River Warbler. All are Unknown with no subspecies assignment. The historical code 2288 split resolution remains unchanged: 307 Red-tailed, 75 Isabelline and 1,864 unresolved slash events.

`data/03_intermediate/ring_events/qa/taxonomy_note_audit.csv` retains one row per recognized diagnostic note, including the event ID, source workbook/sheet/internal row references, AFRING code, source species ID/name, original full note, matched note token and candidate ID/name, compatibility, event-level conflict flag, final species/subspecies IDs and action. Filter `taxonomy_conflict = TRUE` for the logbook review queue. Each conflict is also included in the main CSV/Markdown issue log as `species_subspecies_conflict` with action `replace_taxon_unknown`.

## Validation

`tests/testthat/test-shrike-taxonomy.R` checks the reviewed configuration, split-species resolution, slash defaults, species-versus-lower-rank handling, preserved notes, final common names, and all five Red-backed source conflicts. `tests/testthat/test-taxonomy-consistency.R` checks the rule for arbitrary species and subspecies, valid slash membership, repeated compatible notes, unmapped prose and contradictory multiple notes. The complete Zenodo suite checks event/subspecies membership and recomputes the taxonomy summaries and ring-derived daily counts.
