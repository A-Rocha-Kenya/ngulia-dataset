# Data dictionary and interpretation

## Public dataset files

The five public tables have canonical versions in `data/04_curated/`; the Zenodo `recoveries.csv` is a narrower view of its canonical version. The operations evidence register is maintained in the repository and is not part of the Zenodo deposit.

| File                 | One row represents                                          | Main role                                                                                           |
| -------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `taxonomy.csv` | One taxonomic concept or project special entry. | Shared names, classification, identifiers, project codes, and links. |
| `ring_events.csv`    | One cleaned capture event for an individually marked bird.  | Canonical individual ringing observations, biometrics, and moult information.                       |
| `daily_counts.csv`   | One species with a positive count on one date.              | Selected daily species totals for count-based analyses.                                             |
| `daily_coverage.csv` | One calendar date within a ringing season window.           | Canonical daily catch, coverage/effort evidence, observed metadata, modeled mist, and ERA5 weather. |
| `recoveries.csv`     | One distinct recovery or control movement involving Ngulia. | Curated movements between Ngulia and another ringing or recovery location.                          |

`ring_events.csv`, `daily_counts.csv`, and `recoveries.csv` join to `taxonomy.csv` by `avibase_id`. Ring-event `subspecies_avibase_id` joins to the same table for a more precise identification. Common names remain in the observation files for readability; AFRING mappings, eBird codes, and classification are held in the taxonomy table. AFRING codes are used internally for source processing and QA; multiple codes can map to one taxonomic concept, so the lookup lists all mapped codes rather than preserving an original code per observation.

`daily_counts.csv` and `daily_coverage.csv` join through `ringing_date` and `season`. The recovery table is independent of the ring-event identifiers because it was curated from separate historical recovery sources.

Empty CSV fields represent unavailable, unresolved, or inapplicable values; field-specific distinctions are documented below. Files are UTF-8 comma-separated text with a header row.

## Key definitions

- `datetime` preserves the cleaned source clock time as `YYYY-MM-DDTHH:MM:SS+03:00`, or just `YYYY-MM-DD` when no time was recorded. Timed values use East Africa Time. A date-only value may be the source's ringing-day label rather than an independently known capture calendar date; `ringing_date` is the analysis date.
- `ringing_date` is the canonical analysis date. Events at or after 20:00 are assigned to the following ringing day, unless a source file declares its raw date to be the ringing day with `raw_date_is_ringing_date`.
- `season` is the year in which the October-January ringing season starts. Dates from June through December use their calendar year; January-May use the previous year. This June 1 administrative boundary keeps the whole ringing season under one label even if its October start shifts slightly between years.
- `fat_ngulia` is the original Ngulia 0-4 fat score, based on the appearance of the furcular pit. `fat_kaiser` is the Kaiser 0-8 score, based on both the furcular pit and abdomen. The scales are retained separately and are not converted or assumed to be numerically equivalent.
- `daily_counts.csv` contains positive counts only. Missing species rows can be reconstructed as zero only for a documented date; a missing date is not automatically a zero-count day.
- In the current files, `daily_counts.csv` uses DJP summary rows for seasons 1969–2014 and ring-event-derived counts for seasons 2015–2023. Source choice is made for a whole season, not day by day.
- `daily_coverage.csv` is a calendar scaffold, not evidence that ringing occurred. `ringing_happened` identifies dates with a positive selected count after targeted swallow and martin catches are excluded. Its default window starts on October 20 and extends beyond January 12 when source data do.

## Data dictionary

### `taxonomy.csv`

The intermediate reference contains the eBird/Clements 2025 integrated checklist and project mapping entries. AviList 2025 supplies missing names or classification for matching concepts and enriches BirdLife links and conservation information. Reviewed project labels take precedence; otherwise the main name fields use Clements, with AviList as a fallback. Checklist versions are recorded here rather than repeated in each row. The published table has one row per recorded `avibase_id`, including resolved subspecies and their species; Unknown birds are included. Species with no recorded ringing events, daily counts, or recoveries are omitted. Checklist updates do not reinterpret historical identifications.

Unknown birds use `avibase-AF0D818A`, labelled `Unknown` with scientific name `Aves`.

| Column | Type / unit | Description |
| --- | --- | --- |
| `avibase_id` | text identifier | Avibase concept ID and unique join key. |
| `common_name` | text | Reviewed project label when supplied, otherwise the checklist English name or a source label. Scientific names or project codes provide readable fallbacks when an English name is unavailable. |
| `scientific_name` | text | Scientific name or taxonomic formula; empty for unresolved mappings without a scientific label. |
| `category` | controlled text | Clements category, such as `species`, `subspecies`, `group (monotypic)`, `group (polytypic)`, `hybrid`, or `spuh`; otherwise AviList rank, project `hybrid`, `unmapped`. |
| `species_avibase_id` | text identifier | Species concept for a Clements species or its subspecies, groups, forms, and intergrades. A species refers to itself; other categories are empty. This relationship follows the selected checklist. |
| `species_code` | text identifier | eBird/Clements 2025 code for this exact concept. Empty when the concept is absent from that checklist. |
| `order` | text | Taxonomic order from Clements 2025. |
| `family` | text | Taxonomic family from Clements 2025, including the English family label where supplied. |
| `afring_numbers` | semicolon-separated codes | All AFRING or project codes mapped to this concept; negative codes identify project hybrid labels. Multiple codes can share one concept. |
| `ngulia_numbers` | semicolon-separated codes | Historical Ngulia numeric codes mapped to this concept. |
| `ngulia_latin_abbr` | semicolon-separated text | Ngulia historical scientific-name abbreviations from the species reference. |
| `source_notes` | semicolon-separated text | Reviewed source-note tokens mapped to this subspecies concept. |
| `birdlife_id` | text identifier | BirdLife identifier extracted from the matched AviList link, otherwise supplied by the reviewed crosswalk. |
| `birdlife_url` | URL | BirdLife species page supplied by AviList or constructed from the reviewed identifier. |
| `iucn_category` | text | Conservation category carried by AviList 2025; this is a release snapshot. |
| `kbt_seq` | semicolon-separated identifiers | Kenya Bird Trends identifiers from the reviewed crosswalk. |
| `abap_ids` | semicolon-separated identifiers | African Bird Atlas Project identifiers from the reviewed crosswalk. |
| `n_ring_events` | integer count | Number of ringing events identifying this concept or a more precise concept belonging to this species. Each event counts once per concept. |
| `n_ring_seasons` | integer count | Number of seasons represented by those ringing events. |
| `first_ring_date` | ISO date | First ringing date for those events; empty when no ringing events identify this concept. |
| `last_ring_date` | ISO date | Last ringing date for those events. |
| `total_daily_count` | integer count | Sum of selected daily counts for this concept or its more precise concepts. This is independent of `n_ring_events`. |
| `n_count_days` | integer count | Number of dates with a positive selected daily count for this concept. |
| `n_count_seasons` | integer count | Number of seasons with a positive selected daily count for this concept. |
| `first_count_date` | ISO date | First date with a positive selected daily count. |
| `last_count_date` | ISO date | Last date with a positive selected daily count. |
| `n_recoveries` | integer count | Number of curated movements identifying this concept or a more precise concept belonging to this species. Each movement counts once per concept. |

Statistics include species rollups based on `species_avibase_id`. An explicitly identified subspecies contributes to its own row and its species row, so totals across taxonomy rows are not additive. Unidentified birds and ambiguous concepts are not assigned to a finer taxon. Zero statistics mean no records in that source.

The reviewed mappings remain in `species_lookup.csv`, `species_reference.csv`, and `subspecies_lookup.csv`. Updating a checklist changes the enrichment table; changes to historical taxon assignments require an explicit mapping review. The taxonomy builder does not resolve old identifications automatically after splits or lumps.

### `ring_events.csv`

| Column                      | Type / unit      | Description                                                                                                                                                                                                                              |
| --------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ring_event_id` | text | Stable event key based on the cleaned source ring number and `ringing_date`; it can retain the unsuffixed number when `ring_number` is provisional. Timestamp information disambiguates rare non-unique base keys. |
| `season`                    | integer year     | Year in which the October–January ringing season starts.                                                                                                                                                                                 |
| `ringing_date`              | ISO date         | Canonical ringing and analysis date after applying the source-specific date convention and night rollover.                                                                                                                               |
| `datetime`                  | ISO date or date-time | Cleaned source date and, when recorded, East Africa Time with a `+03:00` offset. Date-only values preserve missing time precision. |
| `ring_number` | text | Cleaned ring number. If the same number identifies separate capture histories, provisional `_01` and `_02` suffixes distinguish those histories; the suffix is not part of a physical inscription. `ring_note` flags the uncertainty. |
| `ringer_name`               | text             | Full name mapped from the source `Init`, `Ringer`, or `Observer` value through `ringer_lookup.csv`; empty when the source had no ringer value or the entry could not be resolved. Raw initials and numeric identifiers are not exported. |
| `retrap` | boolean | `TRUE` when the same provisional ring history has an earlier event or the source explicitly codes a retrap. `FALSE` indicates a new capture; empty indicates a code/history conflict. |
| `avibase_id` | text identifier | Avibase concept ID joining to `taxonomy.csv`; unknown birds use `avibase-AF0D818A`. |
| `subspecies_avibase_id` | text identifier | Explicitly resolved subspecies or subspecies-group key joining to `taxonomy.csv`, assigned from reviewed source-note mappings; identifications reported at species level leave this empty. |
| `common_name`               | text             | Readable taxon label copied from `taxonomy.csv`. |
| `age`                       | integer code     | EURING age code `0`–`9`; definitions are given under **Age codes**.                                                                                                                                                                      |
| `sex`                       | controlled text  | `M`, `F`, `M?`, or `F?`; empty when unknown or invalid.                                                                                                                                                                                  |
| `wing`                      | millimetres      | Source wing-length measurement after numeric parsing and range validation.                                                                                                                                                               |
| `weight`                    | grams            | Source body-mass measurement after numeric parsing and range validation, exported to one decimal place.                                                                                                                                  |
| `fat_ngulia`                | integer score    | Original Ngulia fat score, `0`–`4`; retained only for sources using that scale.                                                                                                                                                          |
| `fat_kaiser`                | integer score    | Kaiser fat score, `0`–`8`; retained only for sources using that scale.                                                                                                                                                                   |
| `ring_note` | text | Retained source information, uncertainty, corrections, merge details, and QA conflicts. Both sides of an unresolved ring-number collision carry a provisional-suffix note. Other unresolved anomalies may use a `ring_number_warning=...` token. |
| `moult_note`                | text             | Original or normalized unresolved moult notation and any moult-specific QA conflicts.                                                                                                                                                    |
| `primary_moult_status`      | controlled text  | Overall state: `old`, `active`, `suspended`, or `complete`; empty when unresolved.                                                                                                                                                       |
| `n_old_primaries_remaining` | integer count    | Reported number of old primaries remaining, `0`–`10`.                                                                                                                                                                                    |
| `body_moult_head`           | score `0`–`3`    | Positioned source body-moult code for the head; its biological meaning is not inferred.                                                                                                                                                  |
| `body_moult_upperparts`     | score `0`–`3`    | Positioned source body-moult code for the upperparts; its biological meaning is not inferred.                                                                                                                                            |
| `body_moult_underparts`     | score `0`–`3`    | Positioned source body-moult code for the underparts; its biological meaning is not inferred.                                                                                                                                            |
| `p1`–`p10`                  | controlled score | Primary-feather scores in source order. Nine-primary formats leave `p10` empty.                                                                                                                                                          |
| `s1`–`s6`                   | controlled score | Secondary-feather scores in source order.                                                                                                                                                                                                |
| `t1`–`t3`                   | controlled score | Tertial-feather scores in source order.                                                                                                                                                                                                  |
| `tail1`–`tail6`             | controlled score | Tail-feather scores in source order.                                                                                                                                                                                                     |

Feather-score meanings and source-specific interpretation are documented under **Moult fields and standardization**.

### `daily_counts.csv`

| Column          | Type / unit   | Description                                                                              |
| --------------- | ------------- | ---------------------------------------------------------------------------------------- |
| `ringing_date`  | ISO date      | Canonical ringing and analysis date.                                                     |
| `season`        | integer year  | Year in which the October–January ringing season starts.                                 |
| `avibase_id` | text identifier | Avibase concept ID joining to `taxonomy.csv`; unknown birds use `avibase-AF0D818A`. |
| `common_name`   | text          | Project-standard English taxon name.                                                     |
| `n_records`     | integer count | Positive number of birds for the species and date from the season-selected count source. |

### `daily_coverage.csv`

This is the one public daily analysis table. It is assembled from source-specific daily context, the unified observed/ERA5 mist model, and exactly dated operations evidence. ERA5 fields summarize 00:00–08:00 local time at the project grid point. The `djp`-prefixed fields are decoded from the historical daily-summary workbook and are empty outside its coverage.

| Column                                                                            | Type / unit                  | Description                                                                                                                                                                                                                                                                                                               |
| --------------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ringing_date`                                                                    | ISO date                     | Canonical ringing date in the season scaffold.                                                                                                                                                                                                                                                                            |
| `season`                                                                          | integer year                 | Year in which the October–January ringing season starts.                                                                                                                                                                                                                                                                  |
| `all_birds_ringed`                                                                | integer count                | Sum of all species in `daily_counts.csv` before separating targeted swallow and martin catches.                                                                                                                                                                                                                           |
| `swallow_birds_ringed`                                                            | integer count                | Swallow and martin count among recorded daily species totals, kept separate because catches may be targeted. This field is filled with `0` even when the date has no count record; use `daily_count_status` before interpreting a zero. |
| `total_birds_ringed`                                                              | integer count                | `all_birds_ringed - swallow_birds_ringed`, or a source-recorded zero from the DJP workbook daily-total cell. Blank daily-total cells remain empty.                                                                                                                                                                        |
| `ringing_happened`                                                                | boolean                      | `TRUE` when the non-swallow `total_birds_ringed > 0`; this is not a complete effort or documented-coverage indicator.                                                                                                                                                                                                     |
| `daily_count_status`, `daily_count_source`                                        | controlled text and text     | Distinguishes `positive_count_recorded`, `zero_after_swallow_exclusion`, `zero_in_daily_summary`, and `missing`. `daily_count_source` names curated daily counts or a source-recorded DJP zero, not the upstream season source.                                                                                                                                                                                             |
| `djp_reported_total`                                                              | integer count                | Daily total recorded in workbook column `BS`; an explicit numeric zero is retained and a blank cell remains empty.                                                                                                                                                                                                        |
| `djp_source_row`                                                                  | integer row number           | Row in the source workbook `Sheet1` from which the DJP daily metadata and reported total were extracted.                                                                                                                                                                                                                  |
| `moon_days_from_new_moon`                                                         | integer days                 | Astronomically derived signed days from new moon; values after full moon are negative.                                                                                                                                                                                                                                    |
| `season_day`, `moon_distance_from_new_moon`                                       | integer days                 | One-based season day (`1` on 20 October) and absolute distance from new moon.                                                                                                                                                                                                                                                                 |
| `moon_illumination_fraction`                                                      | fraction `0`–`1`             | Astronomically derived illuminated fraction of the lunar disc.                                                                                                                                                                                                                                                            |
| `moon_phase_name`                                                                 | controlled text              | Derived phase: `new_moon`, `waxing_crescent`, `first_quarter`, `waxing_gibbous`, `full_moon`, `waning_gibbous`, `last_quarter`, or `waning_crescent`.                                                                                                                                                                     |
| `djp_weather`                                                                     | controlled text              | Decoded historical mist/cloud condition; unrecognized source text is retained.                                                                                                                                                                                                                                            |
| `djp_rain`                                                                        | controlled text              | Decoded historical rain condition.                                                                                                                                                                                                                                                                                        |
| `djp_site`                                                                        | controlled text              | Comma-separated decoded netting sites: back bush, front bush, outside night nets, lodge veranda, or swallow nets; `none` and `unknown` are explicit values.                                                                                                                                                               |
| `djp_tape`                                                                        | controlled text              | Source playback locations: `front_tapes` (`T`), `behind_lodge_tapes` (`t`), or `none`. The workbook calls this field “Night tape use”; the codes do not identify night-net versus bush-net speakers.                                                                                                                      |
| `bush_net_configuration`                                                          | controlled text              | Historical bush-net position: `back_bush` in 1977–1993, `transition` in 1994–1995, and `front_bush` from 1996. The source says northern use began in 1994 and became routine in 1995, while the workbook retains mixed `B`/`F` codes in 1995. Pre-1977 is missing. This is a period classification, not daily deployment. |
| `night_net_configuration`                                                         | controlled text              | `established` from 1977 onward; pre-1977 is missing for post-transition comparison. Daily operation is recorded separately.                                                                                                                                                                                               |
| `djp_pax`                                                                         | controlled text              | Historical “Team size — Ringers and others” code.                                                                                                                                                                                                                                                                         |
| `djp_team_size_total`, `djp_team_size_minimum`, `djp_team_size_interpretation`    | people and controlled text   | Parsed exact or minimum-known team size, with the interpretation retained.                                                                                                                                                                                                                                                |
| `effort_status`                                                                   | controlled text              | `documented_operation`, `inferred_operation_from_positive_catch`, `documented_no_operation`, `conflicting_positive_catch_and_no_site`, or `unknown`. It is evidence, not quantitative effort.                                                                                                                             |
| `mist_observation`                                                                | controlled text              | Observed mist evidence: `none`, `light_patchy`, `good`, or `present_unspecified`; otherwise empty. The canonical field reconciles DJP codes with reviewed dated sources.                                                                                                                                                  |
| `rain_observed`                                                                   | controlled text              | Canonical observed rain class: `none`, `showers`, `heavy_rain`, or `rain_unspecified`, reconciled with reviewed dated sources.                                                                                                                                                                                            |
| `net_sites_observed`                                                              | controlled text              | Canonical observed net-site combination, retaining the source-specific historical site labels.                                                                                                                                                                                                                            |
| `playback_nocturnal_observed`                                                     | binary                       | Explicit nocturnal playback evidence. Empty means unknown, not absence. Within DJP metadata, blank night-tape cells follow the workbook convention and mean no nocturnal playback.                                                                                                                                        |
| `night_net_operation`, `dawn_net_operation`                                       | binary                       | Explicit evidence that night or dawn nets did (`1`) or did not (`0`) operate; otherwise empty.                                                                                                                                                                                                                            |
| `operations_evidence_ids`                                                         | text identifiers             | Semicolon-separated identifiers for reviewed evidence that contributed values to the model-facing daily fields. Full provenance remains in an internal project register.                                                                                                                                               |
| `mist_probability_none`, `mist_probability_light_patchy`, `mist_probability_good` | probabilities `0`–`1` | Unified three-state mist distribution. The values sum to `1` where available; all three are empty if no prediction is available. Direct observations fix or constrain the state; ERA5 supplies probabilities elsewhere. |
| `total_cloud_cover_mean`                                                          | fraction `0`–`1`             | Mean ERA5 total cloud cover from 00:00–08:00 local time.                                                                                                                                                                                                                                                                  |
| `cloud_base_height_mean_m`                                                        | metres                       | Mean ERA5 cloud-base height from 00:00–08:00 local time.                                                                                                                                                                                                                                                                  |
| `total_precipitation_00_08_mm`                                                    | millimetres                  | Sum of ERA5 precipitation from 00:00–08:00 local time.                                                                                                                                                                                                                                                                    |
| `wind_u_10m_mean_ms`                                                              | metres/second                | Mean eastward ERA5 10-m wind component; negative values point westward.                                                                                                                                                                                                                                                   |
| `wind_v_10m_mean_ms`                                                              | metres/second                | Mean northward ERA5 10-m wind component; negative values point southward.                                                                                                                                                                                                                                                 |
| `wind_speed_10m_mean_ms`                                                          | metres/second                | Mean ERA5 10-m wind-speed magnitude.                                                                                                                                                                                                                                                                                      |
| `temperature_2m_mean_c`                                                           | degrees Celsius              | Mean ERA5 2-m air temperature.                                                                                                                                                                                                                                                                                            |
| `relative_humidity_mean_pct`                                                      | percent                      | Mean relative humidity calculated from ERA5 2-m temperature and dew point.                                                                                                                                                                                                                                                |
| `surface_pressure_mean_hpa`                                                       | hectopascals                 | Mean ERA5 surface pressure.                                                                                                                                                                                                                                                                                               |

### `recoveries.csv`

One row represents one movement encounter involving Ngulia. The Zenodo file is a narrow view of the canonical recovery file, which retains raw wording, source locators, measurements, and audit fields. Ordinary retraps at Ngulia are excluded. The `other_*` fields describe the non-Ngulia endpoint.

| Column | Type / unit | Description |
| --- | --- | --- |
| `avibase_id` | text identifier | Avibase concept ID joining to `taxonomy.csv`; unknown birds use `avibase-AF0D818A`. |
| `common_name` | text | Standardized English species name. |
| `ring_scheme` | text | Ringing scheme or centre. |
| `ring_number` | text identifier | Normalized ring inscription; leading zeroes matter. |
| `ringing_age_code` | EURING code | Age code recorded at ringing; see **Age codes**. |
| `direction` | controlled text | `from_ngulia` or `to_ngulia`, indicating which event took place at Ngulia. |
| `ringing_date` | ISO or partial date | Date of the original ringing event at its recorded precision; empty when unknown. Partial dates are not completed with an invented month or day. |
| `encounter_date_edtf` | EDTF date or interval | Encounter date at its documented precision: `YYYY-MM-DD`, `YYYY-MM`, `YYYY`, or a start/end interval such as `1995/1996`. Empty when the encounter date or defensible bounds are unknown. |
| `report_date` | ISO or partial date | Date the recovery was reported, when documented separately. It may coexist with a partial encounter date and is never substituted for the date the bird was encountered. |
| `other_site` | text | Locality at the non-Ngulia endpoint. |
| `other_region` | text | Region at the non-Ngulia endpoint, when recorded. |
| `other_country` | text | Standardized country at the non-Ngulia endpoint. |
| `other_latitude` | decimal degrees | Latitude of the non-Ngulia locality; negative values are south. |
| `other_longitude` | decimal degrees | Longitude of the non-Ngulia locality; negative values are west. |
| `encounter_type` | controlled text | `control` for a ringing control or recapture, otherwise `recovery`. |
| `encounter_condition` | controlled text | `alive`, `dead`, or `unknown`. |
| `mortality_cause_class` | controlled text | Cause class for dead birds; empty when death was not established. |
| `curation_notes` | text | Material uncertainty or a decision needed to interpret this movement. |

Treat published coordinates as approximate locality positions, including the few records for which exact coordinates were originally reported. The file does not claim point-level encounter accuracy. A great-circle distance can be calculated from these positions and the Ngulia site reference point (`-3.0140288`, `38.2111347`), but will inherit the locality uncertainty. [EDTF](https://www.loc.gov/standards/datetime/edtf.html) defines the date notation. Historical dates in parentheses often identify when a letter was sent, so they belong in `report_date` unless separate evidence establishes the encounter date. The phrase “Autumn 81” has no defensible calendar bounds here, so its date is empty and its source wording is retained in `curation_notes`.

### Age codes

Age is a plumage-based observation following the [EURING Exchange Code](https://euring.org/files/documents/E2020ExchangeCodeV202.pdf), not an age recalculated from the known history of a ring. Codes change at the calendar-year boundary.

| Code | Meaning                                                                                    |
| ---- | ------------------------------------------------------------------------------------------ |
| `0`  | Age unknown or not recorded.                                                               |
| `1`  | Pullus: nestling or chick not yet able to fly freely.                                      |
| `2`  | Full-grown and able to fly freely, but age otherwise unknown.                              |
| `3`  | First calendar year; hatched during the current calendar year.                             |
| `4`  | After first calendar year; hatched before the current calendar year, exact year unknown.   |
| `5`  | Second calendar year; hatched during the previous calendar year.                           |
| `6`  | After second calendar year; hatched before the previous calendar year, exact year unknown. |
| `7`  | Third calendar year; hatched two calendar years earlier.                                   |
| `8`  | After third calendar year; older than code `7`, exact year unknown.                        |
| `9`  | Fourth calendar year; hatched three calendar years earlier.                                |

Blank or invalid age values become `0`. The uncertain source forms `2(3)`, `2(4)`, `3(2)`, `3?`, and `?3` are conservatively standardized to `2`, with the original value retained in `ring_note`. Valid but unusual codes `7` and `9` are retained and receive a warning in `ring_note` and QA. Letter codes for ages above `9` are not currently accepted by this pipeline.

## Moult fields and standardization

Moult notation varies substantially among years. The pipeline therefore uses a source-specific, conservative mapping and stores the decoded or unresolved values as nullable columns in `ring_events.csv`.

### Moult column structure

Every row remains one ring event. Moult columns are empty when the event has no decoded value or unresolved source notation for that field.

| Column                                                              | Content                                                                                                                                                                   |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `moult_note`                                                        | Original or normalized source notation that should not be silently discarded, including unresolved values and QA conflicts. Moult text is kept separate from `ring_note`. |
| `primary_moult_status`                                              | Overall primary-moult state: `old`, `active`, `suspended`, or `complete`.                                                                                                 |
| `n_old_primaries_remaining`                                         | Source count of old primaries, from `0` to `10`, when supplied.                                                                                                           |
| `body_moult_head`, `body_moult_upperparts`, `body_moult_underparts` | The three positioned source body-moult codes, restricted to `0`-`3`. Their biological meanings are not inferred.                                                          |
| `p1`-`p10`                                                          | Primary-feather scores in source order. Nine-primary formats leave `p10` missing.                                                                                         |
| `s1`-`s6`                                                           | Secondary-feather scores in source order.                                                                                                                                 |
| `t1`-`t3`                                                           | Tertial-feather scores in source order.                                                                                                                                   |
| `tail1`-`tail6`                                                     | Tail-feather scores in source order.                                                                                                                                      |

The positioned feather columns use this common exported vocabulary:

| Exported score | Meaning                                                        | Source schemes                          |
| -------------- | -------------------------------------------------------------- | --------------------------------------- |
| `0`            | Old feather.                                                   | Legacy Ngulia and SAFRING-style sheets. |
| `1`            | Feather missing or in pin.                                     | Legacy Ngulia and SAFRING-style sheets. |
| `2`            | New feather grown to at most one third.                        | Legacy Ngulia and SAFRING-style sheets. |
| `3`            | New feather between one and two thirds grown.                  | Legacy Ngulia and SAFRING-style sheets. |
| `4`            | New feather more than two thirds grown, with sheath remaining. | Legacy Ngulia and SAFRING-style sheets. |
| `5`            | Fully grown new feather.                                       | Legacy Ngulia and SAFRING-style sheets. |
| `8`            | Fully grown feather whose age cannot be determined.            | SAFRING-style sheets only.              |
| `S`            | Summer-generation feather.                                     | Legacy Ngulia sheets only.              |

The feather columns must be imported as text because they contain numeric-looking scores plus `S`. With `readr`, import these columns as `col_character()`; convert date and numeric-only columns afterward when needed.

## Interpretation limits

### Counts and missing dates

`daily_counts.csv` contains positive species-day counts. For each season, the pipeline uses DJP daily summaries if that source has rows for the season; otherwise it summarizes curated ring events. It does not choose the better-looking source separately for each day. In this version DJP supplies seasons 1969–2014 and ring events supply 2015–2023. In `daily_coverage.csv`, `daily_count_source` identifies a positive total from curated `daily_counts.csv` or a source-recorded DJP zero; it does not identify which source was selected upstream for the season. The repository generates a count-source comparison audit, which is not part of the Zenodo deposit.

A species absent from a recorded date can be treated as zero only if that date meets the coverage rule of the analysis. A date absent from `daily_counts.csv` is not a zero-catch day. The DJP daily-total cell provides a separate distinction: a numeric zero is retained as `daily_count_status = zero_in_daily_summary`; a blank remains `missing`. A source-recorded zero does not by itself prove that nets were open.

### Calendar and operation evidence

`season` labels the year in which an October–January season starts; the assignment uses a June 1 administrative boundary. `daily_coverage.csv` starts each season window on October 20, normally runs through January 12, and extends into later January dates when the sources do. A row in this table means the date is in the calendar scaffold, not that ringing took place.

`ringing_happened` is `TRUE` when the selected count source has a positive **non-swallow/martin** total. Targeted swallow and martin catches remain in `all_birds_ringed` and `swallow_birds_ringed` but are excluded from `total_birds_ringed`. A date with only those targeted catches can therefore have recorded birds while `ringing_happened` is `FALSE`.

`effort_status` distinguishes documented operation, operation inferred from positive catch, documented non-operation, conflicts, and unknown dates. The underlying evidence comes from daily metadata and reviewed operational evidence maintained in the project repository. It is not a measure of net-hours, net length, or processing capacity. Broad historical periods are context; they are not filled into every day.

### Catch is an observation process

Recorded catch depends on migration aloft, grounding weather, light attraction, net placement and opening, playback, staffing, and the capacity to process birds. A high catch need not mean high regional abundance; a low catch can reflect weak passage, poor grounding conditions, limited effort, or an unobserved date. Protocol changes across decades, including the introduction and relocation of night and dawn nets, lighting changes, and targeted daytime catching, make raw annual totals difficult to compare as abundance.

The selected daily count source may also differ from the individual ring-event table. Do not assume that summing `ring_events.csv` will reproduce every published daily count. The repository generates a count-source comparison for review.

### Weather and historical covariates

ERA5 supplies regional weather summaries for 00:00–08:00 East Africa Time; it does not directly observe mist at the lodge. The three `mist_probability_*` fields combine direct classifications where available with an ERA5-calibrated model elsewhere. Probabilities are estimates, not three independent observations.

DJP metadata, annual reports, diaries, and other operational sources differ in precision. Reviewed daily corrections are applied to canonical fields, while raw `djp_*` fields remain available. Absence of a report entry does not mean normal operation, no playback, or no rain. Specific dated corrections and unresolved conflicts are documented in the project repository.

### Recoveries and source coverage

`recoveries.csv` is a manually consolidated set of identifiable movements involving Ngulia, not a complete detection history of every ringed bird. Encounter location and date precision vary by source. The canonical file retains `primary_source`, `supporting_sources`, and `curation_notes`; the narrower Zenodo export includes only the material interpretation notes. The recovery curation guide documents the fields and remaining gaps. `06_standardize_recovery_encounters.R` updates encounter classifications in the curated file but does not reconstruct it from the original documents.

Some raw workbooks, annual reports, and reference material are available only in the local ignored data tree. The Zenodo delivery files include a narrow recovery table, not the recovery source archive. Contact the project for source verification where needed.

### Practical use

- State which count source and date-coverage rule an analysis uses.
- Keep unknown dates distinct from documented zero-catch dates and documented non-operation.
- Separate targeted swallow and martin catching when the question concerns the main nocturnal capture process.
- Report the historical period and protocol differences relevant to a comparison.
- Describe results as catch, composition, or condition unless effort and detection are independently addressed.
- Preserve source and curation uncertainty when interpreting ring events and recoveries.
