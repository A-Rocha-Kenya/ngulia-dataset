# Data

The local pipeline runs from source material to five curated CSV tables. Raw, reference, intermediate, and curated files are excluded from Git.

| Folder | Role |
| --- | --- |
| `01_raw/` | Original workbooks, count sources, weather archives, and external inputs; do not edit in place. |
| `02_reference/` | Taxonomy, publications, reports, photographs, and supporting material. |
| `03_intermediate/` | Regenerable staging tables and machine-readable curation audits. |
| `04_curated/` | Canonical `taxonomy.csv`, `ring_events.csv`, `daily_counts.csv`, `daily_coverage.csv`, and `recoveries.csv`. |

The [scripts README](../scripts/README.md) gives the build order and processing workflow. The [outputs README](../outputs/README.md) explains QA results. Interpretation limits are in [data limitations](../docs/data_limitations.md); publication status is in the [exports README](../exports/README.md).

## Local sources and staging files

The Git repository does not contain the source archive or generated CSVs. Keep the original inputs under the paths below, without editing them in place. `02_reference/` also holds publications, reports, and photographs that support source review; those collections are not all required to build the five curated tables. Website range assets are maintained in `ngulia-website`.

| Path | Role |
| --- | --- |
| `01_raw/ring_events/` | Annual ringing workbooks selected by `config/ring_events/file_specs.csv`. |
| `01_raw/external/rsea/00_RSEA recoveries database.xlsx` | Original RSEA recovery workbook, including national records outside the Ngulia movement table. |
| `01_raw/daily_counts/djp_daily_and_annual_summaries_1969_2012.xlsx` | DJP species-day summaries and daily metadata. |
| `01_raw/weather/era5_hourly_single_levels_timeseries/` | Cached ERA5 hourly CSV or ZIP; the weather script requests the required period if its cache is absent. |
| `02_reference/taxonomy/ebird_clements_2025_integrated_checklist.csv` | Required eBird/Clements 2025 backbone for the shared taxonomy. |
| `02_reference/taxonomy/avilist_2025_11jun_extended.xlsx` | Required AviList 2025 names, rank, conservation fields, and BirdLife links for matched concepts. |
| `02_reference/publications/references.bib` | Bibliography used for GBIF metadata and publication review. |
| `03_intermediate/taxonomy/taxonomy_reference.csv` | Full shared reference built before observations; the final recorded list and statistics are produced after observations. |
| `03_intermediate/daily_counts/` | Extracted DJP counts, metadata, and source-comparison audits. |
| `03_intermediate/weather/era5_daily_weather.csv` | ERA5 weather summarized for each date. |
| `03_intermediate/daily_context/daily_context.csv` | Joined daily observations and reviewed operations evidence before mist modeling. |
| `03_intermediate/mist_model/` | Fitted mist model, validation, and per-day state probabilities. |
| `03_intermediate/ring_events/qa/` | Source-row issues, file audits, and review queues from ring-event import. |
| `03_intermediate/recoveries/recoveries_audit.md` | One-off consolidation and validation record for the manually curated recoveries. |
| `04_curated/recoveries.csv` | Manually curated input to the recovery-classification script; preserve it when rebuilding. |

`03_intermediate/geolocator_paths/` and some external reference collections support optional research exploration. They are not inputs to the five curated tables.

## Public dataset files

The five public tables have canonical versions in `data/04_curated/`; the Zenodo `recoveries.csv` and `daily_coverage.csv` are narrower views of their canonical versions. The operations evidence register is maintained in the repository and is not part of the Zenodo deposit.

| File                 | One row represents                                          | Main role                                                                                           |
| -------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `taxonomy.csv` | One taxonomic concept or project special entry. | Shared names, classification, identifiers, project codes, and links. |
| `ring_events.csv`    | One cleaned capture event for an individually marked bird.  | Canonical individual ringing observations, biometrics, and moult information.                       |
| `daily_counts.csv`   | One taxon with a positive count on one date.              | Selected daily taxon totals for count-based analyses.                                             |
| `daily_coverage.csv` | One calendar date within a ringing season window.           | Count coverage, netting/playback observations, observed weather, modeled mist, and ERA5 weather. |
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
- `daily_coverage.csv` is a calendar scaffold, not evidence that ringing occurred. `count_status` distinguishes recorded positive counts (including swallow-only catches), recorded zeros, and missing counts. Its default window starts on October 20 and extends beyond January 12 when source data do.

Detailed interpretation limits and analysis assumptions are in [data limitations](../docs/data_limitations.md).

## Data dictionary

### `taxonomy.csv`

One row represents a recorded taxonomic concept, including resolved subspecies and their species. The table uses the eBird/Clements 2025 checklist, with AviList 2025 and reviewed project mappings for additional names and links. Concepts without ringing events, daily counts, or recoveries are omitted. Checklist updates do not reinterpret historical identifications.

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

One row represents a date within the October–January season scaffold, not proof of net operation. Join to `daily_counts.csv` by `ringing_date` and `season` for bird totals. Empty covariates mean unknown or unavailable, not absence.

#### Calendar (3 columns)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `ringing_date` | ISO date | Canonical ringing and analysis date. Captures from 20:00 onward normally belong to the next ringing day, subject to the source workbook's date convention. A calendar row does not establish operation. |
| `season` | integer year | Year in which the October–January season starts. The processing assigns seasons using a June administrative boundary. |
| `season_day` | integer days | One-based day relative to 20 October: 20 October is 1. This is calendar position, not the number of days on which ringing occurred. |

#### Count coverage (1 column)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `count_status` | controlled text | `recorded_positive` when selected species-day counts exist (including dates with only excluded swallow/martin taxa); `recorded_zero` when the DJP daily-total cell explicitly records zero and there are no selected species counts; `missing` when neither is available. This is coverage of counts, not evidence that nets operated. |

#### Netting and playback observations (4 columns)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `net_sites_observed` | comma-separated text | Reconciled site labels: `back_bush`, `front_bush`, `outside_night_nets`, `lodge_veranda`, or `swallow_nets`, possibly in combination. `none` is an explicit no-site record; blank is unknown. |
| `night_nets_operated` | integer 0/1 | Night nets coded as operating (`1`) or not operating (`0`) from DJP site combinations or reviewed dated evidence. These values can be derived from site coding rather than an independent deployment record. Blank means unknown. |
| `dawn_nets_operated` | integer 0/1 | Dawn/bush nets coded as operating (`1`) or not operating (`0`) from DJP back/front-bush labels or reviewed dated evidence. This does not establish operating duration. Blank means unknown. |
| `nocturnal_playback_used` | integer 0/1 | Nocturnal playback coded as used (`1`) or unused (`0`). DJP tape locations are converted to use/absence; blank tape cells within DJP metadata mean no use under the workbook convention. Outside that coverage, blank means unknown unless reviewed evidence supplies a value. This does not describe diurnal lures, species, volume, or timing. |

#### Observed weather (2 columns)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `mist_observed` | controlled text | Reconciled mist observation: `none`, `present_light_patchy`, `present_sustained`, or `present_unspecified`; blank when occurrence is unknown. DJP symbols supply most observations; dated reviewed reports, diaries, and weather notes may fill or correct them. |
| `rain_observed` | controlled text | Reconciled rain observation: `none`, `present_showers`, `present_heavy`, or `present_unspecified`; blank when occurrence is unknown. DJP symbols supply most observations; dated reviewed sources may fill or correct them. These are qualitative historical classes, not measured rainfall amounts. |

`present_unspecified` means presence is known but its detailed class is not; blank means occurrence is unknown. In DJP metadata, `present_sustained` maps from the historical good-mist class (at least two hours) and `present_light_patchy` from the light/patchy class (at least one hour). Reviewed narrative observations may lack a duration.

#### Modeled mist (3 columns)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `mist_modeled_none` | probability 0–1 | Probability of no mist in the unified observed/ERA5 distribution. |
| `mist_modeled_light_patchy` | probability 0–1 | Probability of the `present_light_patchy` mist class in the same distribution. |
| `mist_modeled_sustained` | probability 0–1 | Probability of the `present_sustained` mist class in the same distribution. |

The three probabilities sum to 1 when available. Exact observed classes set one probability to 1; `present_unspecified` constrains the no-mist probability to 0. Otherwise the values come from the ERA5-calibrated model. All three are blank when no prediction is available.

#### DJP team size (1 column)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `djp_team_size` | integer people | Minimum known number of ringers and others in the DJP team code, including explicitly numbered Earthwatch participants. Unnumbered additional participants are not estimated. Blank if no numeric size can be decoded or no DJP metadata exists. |

#### Moon (2 columns)

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `moon_days_from_new_moon` | signed integer days | Approximate days from new moon, positive while waxing and negative while waning, rounded to whole days (−15 to +15). Zero is near new moon. |
| `moon_illumination_fraction` | fraction 0–1 | Approximate illuminated fraction of the lunar disc, calculated from a constant lunar cycle and rounded to three decimals. |

These are approximate lunar phase indicators, not measurements of light at the nets.

#### ERA5 weather (9 columns)

ERA5 fields summarize hourly values at 3.00° S, 38.25° E from 00:00 through 08:00 inclusive in East Africa Time on each `ringing_date`. Means ignore unavailable values; precipitation sums the supplied hourly values. These are regional reanalysis estimates, not measurements at the nets.

| Column | Type / unit | Definition for users |
| --- | --- | --- |
| `era5_total_cloud_cover_mean` | fraction 0–1 | Mean hourly total cloud cover over the defined local timestamps. |
| `era5_cloud_base_height_mean_m` | metres | Mean hourly ERA5 cloud-base height over the defined timestamps. Blank if unavailable. This is a reanalysis variable, not a measured height of mist above the nets. |
| `era5_total_precipitation_00_08_mm` | millimetres | Sum of supplied hourly precipitation values at the defined timestamps, converted from metres to millimetres. |
| `era5_wind_u_10m_mean_ms` | metres/second | Mean hourly eastward component of wind at 10 m; negative means westward. |
| `era5_wind_v_10m_mean_ms` | metres/second | Mean hourly northward component of wind at 10 m; negative means southward. |
| `era5_wind_speed_10m_mean_ms` | metres/second | Mean of hourly 10 m wind magnitudes, calculated before averaging. It generally differs from the magnitude of the daily mean vector. |
| `era5_temperature_2m_mean_c` | degrees Celsius | Mean hourly air temperature at 2 m, converted from kelvin. |
| `era5_relative_humidity_mean_pct` | percent | Mean hourly relative humidity, calculated from ERA5 2 m temperature and dew point using the build's vapour-pressure formula and bounded to 0–100%. |
| `era5_surface_pressure_mean_hpa` | hectopascals | Mean hourly surface pressure, converted from pascals. |

### `recoveries.csv`

One row represents one movement encounter involving Ngulia. The Zenodo file is a narrow view of the [canonical recovery file](../docs/recoveries_canonical.md), which retains raw wording, source locators, measurements, and audit fields. Ordinary retraps at Ngulia are excluded. The `other_*` fields describe the non-Ngulia endpoint.

| Column | Type / unit | Description |
| --- | --- | --- |
| `avibase_id` | text identifier | Avibase concept ID joining to `taxonomy.csv`; unknown birds use `avibase-AF0D818A`. |
| `common_name` | text | Standardized English species name. |
| `ring_scheme` | text | Ringing scheme or centre. |
| `ring_number` | text identifier | Normalized ring inscription; leading zeroes matter. |
| `ringing_age_code` | source EURING notation | Age code recorded at ringing; see **Age codes**. Unlike cleaned ring-event ages, recoveries retain a parenthesized source alternative such as `2(4)` when present. |
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

Published coordinates are approximate locality positions, not point-level encounter locations. [EDTF](https://www.loc.gov/standards/datetime/edtf.html) defines the encounter-date notation.

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
| `evidence_id` | text identifier | Stable key referenced by the internal daily table in `operations_evidence_ids` when a decision was applied; omitted from the public view. |
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
| Taxonomy | Source species labels map through `species_lookup.csv` and `species_reference.csv` to `avibase_id`. Names come from the shared `taxonomy.csv`; eBird codes are held in that table. Retired AFRING code `962` retains European/African Red-rumped Swallow for unresolved historical records; two source-reviewed European birds use current SAFRING code `14935` through row corrections. Historical AFRING `2288` retains Red-tailed/Isabelline Shrike when unresolved; explicitly mapped race/form notes resolve the split species. Pipe-separated `ring_note` tokens identify current concepts through `subspecies_lookup.csv`; only recognized lower ranks populate `subspecies_avibase_id`. For every species, contradictory species/diagnostic-note identifications become Unknown with no subspecies; both identifications are retained in `03_intermediate/ring_events/qa/taxonomy_note_audit.csv` and flagged in the issue log. See the [shrike taxonomy review](../docs/reviews/shrike_taxonomy_review.md). |
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

### Feather scores

The positioned feather columns in `ring_events.csv` use this exported vocabulary:

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

The feather columns contain numeric-looking scores and `S`, so import them as text.

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
