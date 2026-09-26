# Data

The local pipeline runs from source material to four curated CSV tables. Raw, reference, intermediate, and curated files are excluded from Git.

| Folder | Role |
| --- | --- |
| `01_raw/` | Original workbooks, count sources, weather archives, and external inputs; do not edit in place. |
| `02_reference/` | Taxonomy, publications, reports, ranges, and supporting material. |
| `03_intermediate/` | Regenerable staging tables and machine-readable curation audits. |
| `04_curated/` | Canonical `ring_events.csv`, `daily_counts.csv`, `daily_coverage.csv`, and `recoveries.csv`. |

The [scripts README](../scripts/README.md) gives the build order and processing workflow. The [outputs README](../outputs/README.md) explains QA results. Interpretation limits are in [data limitations](../docs/data_limitations.md); publication status is in the [exports README](../exports/README.md).

## Local sources and staging files

The Git repository does not contain the source archive or generated CSVs. Keep the original inputs under the paths below, without editing them in place. `02_reference/` also holds publications, reports, photographs, and range material that support review or website work; those collections are not all required to build the four curated tables.

| Path | Role |
| --- | --- |
| `01_raw/ring_events/` | Annual ringing workbooks selected by `config/ring_events/file_specs.csv`. |
| `01_raw/external/rsea/00_RSEA recoveries database.xlsx` | Original RSEA recovery workbook, including national records outside the Ngulia movement table. |
| `01_raw/daily_counts/djp_daily_and_annual_summaries_1969_2012.xlsx` | DJP species-day summaries and daily metadata. |
| `01_raw/weather/era5_hourly_single_levels_timeseries/` | Cached ERA5 hourly CSV or ZIP; the weather script requests the required period if its cache is absent. |
| `02_reference/taxonomy/ebird_clements_2025_integrated_checklist.csv` | Optional name fallback when building daily counts. |
| `02_reference/publications/references.bib` | Bibliography used for GBIF metadata and publication review. |
| `03_intermediate/daily_counts/` | Extracted DJP counts, metadata, and source-comparison audits. |
| `03_intermediate/weather/era5_daily_weather.csv` | ERA5 weather summarized for each date. |
| `03_intermediate/daily_context/daily_context.csv` | Joined daily observations and reviewed operations evidence before mist modeling. |
| `03_intermediate/mist_model/` | Fitted mist model, validation, and per-day state probabilities. |
| `03_intermediate/ring_events/qa/` | Source-row issues, file audits, and review queues from ring-event import. |
| `03_intermediate/recoveries/recoveries_audit.md` | One-off consolidation and validation record for the manually curated recoveries. |
| `04_curated/recoveries.csv` | Manually curated input to the recovery-classification script; preserve it when rebuilding. |

`03_intermediate/geolocator_paths/` and some external reference collections support optional website or exploration exports. They are not inputs to the four curated tables.

## Public dataset files

The four public tables have canonical versions in `data/04_curated/`; the Zenodo `recoveries.csv` is a narrower view of its canonical version. The operations evidence register is maintained in the repository and is not part of the Zenodo deposit.

| File                 | One row represents                                          | Main role                                                                                           |
| -------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `ring_events.csv`    | One cleaned capture event for an individually marked bird.  | Canonical individual ringing observations, biometrics, and moult information.                       |
| `daily_counts.csv`   | One species with a positive count on one date.              | Selected daily species totals for count-based analyses.                                             |
| `daily_coverage.csv` | One calendar date within a ringing season window.           | Canonical daily catch, coverage/effort evidence, observed metadata, modeled mist, and ERA5 weather. |
| `recoveries.csv`     | One distinct recovery or control movement involving Ngulia. | Curated movements between Ngulia and another ringing or recovery location.                          |

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

Detailed interpretation limits and analysis assumptions are in [data limitations](../docs/data_limitations.md).

## Data dictionary

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
| `afring_number`             | integer code     | AFRING taxon code. `0` represents an unresolved identity; negative project codes represent explicitly mapped hybrid labels.                                                                                                              |
| `avibase_id`                | text identifier  | Avibase identifier for the resolved taxon; empty when unresolved.                                                                                                                                                                        |
| `subspecies_avibase_id`     | text identifier  | Avibase identifier for an explicitly resolved subspecies or subspecies group derived from mapped note text; otherwise empty.                                                                                                             |
| `common_name`               | text             | Project-standard English taxon name.                                                                                                                                                                                                     |
| `species_code`              | text identifier  | eBird/Clements species or subspecies code associated with the Avibase identifier.                                                                                                                                                        |
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
| `avibase_id`    | text identifier | Avibase identifier for the resolved taxon, used to align daily summaries and ring-event-derived counts. |
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

One row represents one movement encounter involving Ngulia. The Zenodo file is a narrow view of the [canonical recovery file](../docs/recoveries_canonical.md), which retains raw wording, source locators, measurements, and audit fields. Ordinary retraps at Ngulia are excluded. The `other_*` fields describe the non-Ngulia endpoint.

| Column | Type / unit | Description |
| --- | --- | --- |
| `avibase_id` | text identifier | Standardized Avibase taxon identifier. |
| `common_name` | text | Standardized English species name. |
| `ring_scheme` | text | Ringing scheme or centre. |
| `ring_number` | text identifier | Normalized ring inscription; leading zeroes matter. |
| `ringing_age_code` | EURING code | Age code recorded at ringing; see **Age codes**. |
| `direction` | controlled text | `from_ngulia` or `to_ngulia`, indicating which event took place at Ngulia. |
| `ringing_date` | ISO date | Date of the original ringing event; empty when unknown. |
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

### `operations_history.csv`

Each row records one source-linked historical statement or reviewed daily decision. Daily metadata is the first source for observed conditions; dated, reviewed evidence can validate or correct the canonical daily fields. A missing report entry does not imply that a condition was absent. Broad periods provide context; only records with `daily_values` are applied to `daily_coverage.csv`.

| Column | Type / unit | Description |
| --- | --- | --- |
| `start_date`, `end_date` | ISO dates | Interval described by the source, at the precision indicated by `temporal_scope`. |
| `covariate` | controlled text | Topic, such as light configuration, net sites, playback, capacity, or weather observation. |
| `value` | text | The reported state or event; interpretation depends on `covariate` and the cited source. |
| `evidence_class` | controlled text | Kind of source, such as an annual report, field diary, or daily summary workbook. |
| `temporal_scope` | controlled text | Precision of the statement, such as an event date, reported session, or broad period. |
| `source_path`, `source_page` | text | Project-relative source location and page or entry locator; the source archive is not part of the Zenodo deposit. |
| `note` | text | Curation explanation, uncertainty, or conflict. |
| `evidence_id` | text identifier | Stable key referenced by `daily_coverage.csv` in `operations_evidence_ids` when a decision was applied. |
| `daily_start_date`, `daily_end_date` | ISO dates | Ringing-date interval to which a reviewed daily assignment applies; empty for contextual records. |
| `daily_values` | semicolon-separated text | Reviewed `field=value` assignments. Only supported observed daily fields are applied to `daily_coverage.csv`; empty means context only. |
| `daily_review` | controlled text | Review decision and date convention, distinguishing applied daily evidence from contextual statements. |

## Processing overview

Annual ringing workbooks are imported using reviewed source specifications and row-level corrections. DJP daily counts are preferred for a whole season when available; otherwise the selected daily totals come from curated ring events. Daily coverage combines the season calendar, counts, operational evidence, observed metadata, modeled mist state, and ERA5 weather. Recoveries were consolidated and curated separately; the recovery script standardizes labels in that table rather than rebuilding its source inventory.

The run order and ring-event build steps are in the [scripts README](../scripts/README.md).

## How encoded values are parsed and standardized

Explicit row-level fixes in `config/ring_events/corrections.csv` and audited ring-number rules in `config/ring_events/ring_number_review.csv` are applied before the general rules below. They document recoverable entry errors without editing the raw Excel workbooks.

| Field            | Source parsing and standardized output                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Date and time    | Excel dates and common year-month-day, day-month-year, and month-day-year text are parsed. Times may be Excel fractions, decimal hours, four-digit `HHMM`, or clock text. A missing time produces date precision rather than an invented event time. `ringing_date` and `season` are then derived as described under **Key definitions**.                                                                                                                                                                                                                                                                                                                                                |
| Ring number | Text is uppercased, whitespace is removed, and characters other than letters, digits, `/`, and `-` are discarded. Reviewed rules replace matching values where a correction is known. When one cleaned number occurs in separate capture histories, provisional `_01` and `_02` suffixes distinguish them and `ring_note` flags the uncertainty. Other unresolved values retain a `ring_number_warning=...` note. A missing result excludes the row. |
| Ringer identity  | Source `Init`, `Ringer`, and `Observer` values can be matched as a three-digit code, an uppercase alphanumeric initial, or a normalized full name through `ringer_lookup.csv`. Source-specific matches take precedence over blank-`source_file` defaults. Only the canonical `ringer_name` is exported.                                                                                                                                                                                                                                                                                                                                                                                  |
| Event identifier | `ring_event_id` normally combines the cleaned ring number and `ringing_date` as `RING__YYYYMMDD`. If that base is not unique, the cleaned timestamp is used instead.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Species          | Numeric AFRING and Ngulia codes are normalized as numbers; text labels are lowercased and punctuation is ignored for matching. Matching priority is explicit AFRING number, Ngulia number, Ngulia text, then the general species label. Text may match a configured Latin abbreviation, Ngulia abbreviation, English name, scientific name, or AviList English name in `species_lookup.csv`. Missing, unmatched, or disagreeing species identities produce `afring_number = 0`; configured `-1` values identify unresolved _Lanius_ hybrid labels whose true AFRING number is not available. Conflicting values across events carrying the same ring number are retained in `ring_note`. |
| Taxonomy         | `avibase_id`, `common_name`, and `species_code` are joined through `species_reference.csv` and the `auk` taxonomy rather than parsed independently from each workbook. Retired AFRING code `962` maps to European/African Red-rumped Swallow for unresolved historical records; two source-reviewed European birds use current SAFRING code `14935` through row corrections and `species_lookup.csv`. Pipe-separated `ring_note` tokens can add `subspecies_avibase_id` only when the species-and-note combination is explicitly mapped in `subspecies_lookup.csv`. |
| Age              | Source values are standardized to the numeric EURING subset `0`-`9`; details are given below. The pipeline does not calculate a bird's age from an earlier capture.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Sex              | `1`, `M`, `m`, and `Male` become `M`; `2`, `F`, `f`, and `Female` become `F`; `3`, `(M)`, and `Male?` become `M?`; `4`, `(F)`, and `Female?` become `F?`. Blank, `0`, `?`, and `Unknown` become missing. Any other value also becomes missing and is reported in QA.                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Wing and weight  | Decimal commas are converted to decimal points and the result is parsed numerically. Values outside the configured species range, or the global fallback range when no species range exists, become missing and are reported in QA. Weight is exported to one decimal place.                                                                                                                                                                                                                                                                                                                                                                                                             |
| Fat              | The source file specification determines whether a column uses the Ngulia or Kaiser scale. Integer-like values such as `3`, `3.0`, or `3,0` are accepted. `?` and `Unknown` become missing. Ngulia accepts `0`-`4`; Kaiser accepts `0`-`8`; out-of-range or nonnumeric values become missing and are reported in QA. The scales are never converted into one another.                                                                                                                                                                                                                                                                                                                    |
| Retrap | The final `retrap` value combines history within each provisional ring-history group with any source retrap code. Source code `2` can mark a retrap even if its earlier capture is absent from the curated table; this is explained in `ring_note`. Code `X` marks a recovery row that is excluded from `ring_events.csv`. A new-capture code that conflicts with earlier history in the same group leaves `retrap` missing, with the disagreement retained in `ring_note` and QA. |

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

### Source mapping and processing

`config/ring_events/moult_specs.csv` assigns each workbook its source columns, expected primary length, overall-status scheme, and feather-score scheme. The processing then follows these rules:

1. Source columns are read and combined in their original order. Empty positions in pipe-separated sequences are retained so that later scores are not shifted to the wrong feather.
2. Legacy Ngulia feather codes use the documented `0`-`5` progression. Source `O` maps to `0`, `N` maps to `5`, and `9` or `S` maps to exported `S`.
3. The 2020-2023 SAFRING-style sheets retain `0`-`5` and SAFRING code `8`. Legacy `O`, `N`, `9`, and `S` aliases are not applied to these sheets.
4. Exact structural variants are normalized only when positions remain unambiguous: scalar primary `0` becomes an all-zero sequence; an 11-character sequence containing one repeated score is reduced to ten positions; combined primary, secondary, and tertial strings are split using their configured lengths; and a nine-character secondary-plus-tertial string is split into six secondary and three tertial positions when no separate tertial value exists.
5. Structured note text such as `S1=...`, `1.1=...`, `T1=...`, or `1.2=...` can fill otherwise empty secondary or tertial positions. If a note conflicts with a dedicated score column, the conflicting component is left missing and both representations are retained in `moult_note` and QA.
6. Historical Ngulia overall-status codes map as `0 = old`, `1 = active`, `2 = suspended`, and `5 = complete`. Other summary codes remain unresolved unless a complete primary sequence supplies the status.
7. A complete primary sequence containing only `0`-`5` determines `primary_moult_status`: any score `1`-`4` means `active`; all `0` means `old`; all `5` means `complete`; and a mixture of only `0` and `5` means `suspended`. This sequence-derived status takes precedence over a conflicting historical summary, with the disagreement recorded in `moult_note` and QA.
8. Unsupported codes are not guessed. If sequence positions are clear, valid positions are retained and only unsupported positions are missing. If positions cannot be established, the whole affected component remains missing. The original notation and the action taken are retained in `moult_note` and the component-specific QA issue.

The pipeline does not apply an assumed EURING crosswalk: `V`, `X`, and other unsupported letters remain unresolved unless a source-specific meaning is documented later. The implemented mappings are based on the coding notes embedded in the 2006-2007 Ngulia workbook, the primary-moult states described in the 2014 main report, and the documented SAFRING feather-score definitions.

## Data quality

Invalid or unresolved source values are recorded in machine-readable audits under `data/03_intermediate/`; invalid measurements are left missing while the event is retained. Ring-event QA records the source file and row, affected value, issue, and action taken. Source-file summaries and ringer-lookup audits make import and identity decisions reviewable.

The [outputs README](../outputs/README.md) explains the full set of ring-event checks and diagnostic files.
