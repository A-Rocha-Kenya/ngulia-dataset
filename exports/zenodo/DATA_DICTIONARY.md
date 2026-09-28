# Data dictionary

Field definitions for the five CSV files in this archive. The companion `README.md` explains how the tables join and how to interpret count coverage.

## Tables

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

One row represents one movement encounter involving Ngulia. The Zenodo file is a narrow view of the canonical recovery file, which retains raw wording, source locators, measurements, and audit fields. Ordinary retraps at Ngulia are excluded. The `other_*` fields describe the non-Ngulia endpoint.

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

## Ring-event codes

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
