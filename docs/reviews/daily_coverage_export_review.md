# Daily coverage export: proposed simplification

Review date: 28 September 2026. **Implemented in the Zenodo exporter. The richer internal daily table is retained.**

The current Zenodo table has 4,707 dates, 45 columns, and 55 seasons (1969–2023). Dates run from 1969-10-20 to 2024-01-12. The proposed main table below has **25 columns**, ordered by theme. Source-specific evidence stays in the reproducible repository; a separate public evidence table would be useful if the deposit must support source audits without the repository.

Current documentation: [published dictionary](../../exports/zenodo/DATA_DICTIONARY.md#daily_coveragecsv), [working dictionary](../../data/README.md#daily_coveragecsv), and [daily evidence guide](../daily_covariates.md).

## Recommendations

1. Group fields as calendar → count coverage → netting/playback observations → observed weather → modeled mist → DJP team → moon → ERA5 weather.
2. Remove all bird-count columns and count-source text from daily coverage. Users calculate counts from `daily_counts.csv`. Retain only `count_status`, because a recorded zero cannot be distinguished from a missing day using that positive-count table alone.
3. Remove `effort_status` and `operations_evidence_ids` from the public table. Keep the source register and reconciliation audit in the repository for reproducibility.
4. Use direct operation names (`night_nets_operated`, `dawn_nets_operated`, `nocturnal_playback_used`) rather than an `effort_` prefix. These are observations/codes, not measurements of effort.
5. Keep `djp_*` for DJP-only information and add `era5_*` to all nine reanalysis fields. Reconciled weather remains `mist_observed` and `rain_observed`: these fields also include reviewed reports and diaries, so labeling them DJP would misstate their sources.
6. Use coherent presence categories and explicitly document source-code mapping. Replace mist `good` with `present_sustained`, reflecting the DJP 2-hour-plus convention without inventing a measured density. Keep `present_unspecified` distinct from blank.
7. Rename the three mist probabilities to `mist_modeled_*`; describe them as probabilities constrained by observations. Remove absolute moon distance, phase labels, source-code duplicates, and historical period classifications.

The existing exporter copies the curated daily table directly. Implement the smaller public view in the export script while retaining the richer curated table for diagnostics. The proposed category changes are publication mappings; they need not change the internal model's class labels.

## Findings in the current export

These are checks of the current CSV, not assumptions about future builds.

| Finding | Consequence / proposed response |
| --- | --- |
| 1,242 positive non-swallow count dates, 120 source-recorded zero dates, and 3,345 missing-count dates. | Calendar coverage is much broader than observed catch coverage. Explain blanks and scaffold dates before the field dictionary. |
| Every missing-count date has `swallow_birds_ringed = 0` and `ringing_happened = FALSE`. | These values can look like measured absence. Remove the totals and flag from the public table; retain only the status distinguishing zero from missing. |
| On all 1,362 dates with counts, `total_birds_ringed = all_birds_ringed - swallow_birds_ringed`. | Remove all three public daily totals. Sum species rows in `daily_counts.csv`; use its taxon identifiers if an excluded-group total is needed. |
| Five DJP daily-total cells disagree with the selected species sum. | They are alternative source evidence, not interchangeable totals. Retain the discrepancy in an audit rather than presenting competing totals in the main table. |
| Compared with initial DJP decoding, reconciled mist differs on 3 DJP dates and adds 20 dates; rain differs on 1 and adds 6; sites differ on 17. | Keep the reconciled observations as the analysis fields. Preserve original source evidence separately. Differences include filling unknown values, not just correcting known ones. |
| `night_net_configuration` is only `established` or blank; `bush_net_configuration` is determined by season. | Move both period assumptions to documentation. They are not deployment measurements. |
| `djp_team_size_total` is available on 1,147 dates; minimum-known team size on 1,195. | One minimum-known team-size number preserves the extra 48 uncertain dates. Explain its selection in the definition rather than exporting a separate type column. |
| Mist probabilities are available on 4,703 dates; observed mist on 1,221. | Do not describe modeled coverage as observation coverage. Four dates have no distribution. |
| Reviewed evidence identifiers occur on 62 dates, but the supporting register is absent from Zenodo. | Remove this column from the main export as requested; retain the supporting register and audits in the repository. |

The five total discrepancies are:

| Date | DJP reported total | Selected all-species sum | DJP minus sum |
| --- | ---: | ---: | ---: |
| 2010-12-01 | 1,683 | 1,682 | +1 |
| 2010-12-03 | 1,730 | 1,731 | −1 |
| 2010-12-07 | 391 | 390 | +1 |
| 2010-12-08 | 782 | 783 | −1 |
| 2013-11-26 | 182 | 186 | −4 |

The five differences are unresolved by this review. Do not silently replace either source value.

## Proposed user-facing introduction

One row represents a calendar date within an October–January season window at Ngulia. A row does not mean nets operated or birds were caught. The season window begins on 20 October, ends no earlier than 12 January, and extends to later January source dates when present. `season` is the year in which the season starts. Join to `daily_counts.csv` using `ringing_date` and `season`.

Empty cells mean unavailable information, not zero or absence. Calculate bird counts by summing `n_records` in `daily_counts.csv`. That table contains positive species-day counts only. If no species rows exist on a date, use `count_status` to distinguish a recorded daily zero from unavailable counts. Operation fields describe evidence of operation; none measures net-hours or standardizes catches for effort.

`djp_*` fields come only from the historical DJP daily-summary workbook (D. J. Pearson; see the dataset attribution). `mist_observed`, `rain_observed`, and the operation observations combine its decoded records with dated, reviewed historical evidence. `era5_*` fields summarize reanalysis at the requested grid point (3.00° S, 38.25° E), rather than weather measured at the nets. `mist_modeled_*` fields combine ERA5 predictions with constraints from observed mist. `moon_*` fields are approximate lunar calculations, not measured illumination at the nets.

The dictionary below defines the **proposed** names and semantics. Renames alone are distinguished from the few proposed changes in interpretation.

## Proposed dictionary, in export order

### Calendar (3 columns)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `ringing_date` | unchanged | ISO date | Canonical ringing and analysis date. Captures from 20:00 onward normally belong to the next ringing day, subject to the source workbook's date convention. A calendar row does not establish operation. |
| `season` | unchanged | integer year | Year in which the October–January season starts. The processing assigns seasons using a June administrative boundary. |
| `season_day` | unchanged | integer days | One-based day relative to 20 October: 20 October is 1. This is calendar position, not the number of days on which ringing occurred. |

### Count coverage (1 column)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `count_status` | `daily_count_status` | controlled text | **Proposed simplification:** `recorded_positive` when selected species-day counts exist (including dates with only excluded swallow/martin taxa); `recorded_zero` when the DJP daily-total cell explicitly records zero and there are no selected species counts; `missing` when neither is available. This is coverage of counts, not evidence that nets operated. |

Mapping: `positive_count_recorded` and `zero_after_swallow_exclusion` → `recorded_positive`; `zero_in_daily_summary` → `recorded_zero`; `missing` → `missing`. The first state is recoverable from `daily_counts.csv`, but the distinction between the other two is not: the current export has 120 recorded-zero dates and 3,345 missing dates, all without species rows. Keeping one complete status column makes that distinction usable.

Count source selection is documented once in the methods: currently DJP supplies species-day counts for seasons 1969–2014, ring events for 2015–2023; selection is by season, not date. Users choose their own taxon inclusion when summarizing `daily_counts.csv`.

### Netting and playback observations (4 columns)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `net_sites_observed` | unchanged | comma-separated text | Reconciled site labels: `back_bush`, `front_bush`, `outside_night_nets`, `lodge_veranda`, or `swallow_nets`, possibly in combination. `none` is an explicit no-site record; blank is unknown. |
| `night_nets_operated` | `night_net_operation` | integer 0/1 | Night nets coded as operating (`1`) or not operating (`0`) from DJP site combinations or reviewed dated evidence. These values can be derived from site coding rather than an independent deployment record. Blank means unknown. |
| `dawn_nets_operated` | `dawn_net_operation` | integer 0/1 | Dawn/bush nets coded as operating (`1`) or not operating (`0`) from DJP back/front-bush labels or reviewed dated evidence. This does not establish operating duration. Blank means unknown. |
| `nocturnal_playback_used` | `playback_nocturnal_observed` | integer 0/1 | Nocturnal playback coded as used (`1`) or unused (`0`). DJP tape locations are converted to use/absence; blank tape cells within DJP metadata mean no use under the workbook convention. Outside that coverage, blank means unknown unless reviewed evidence supplies a value. This does not describe diurnal lures, species, volume, or timing. |

These four fields include DJP decoding and dated historical decisions, so they also should not have a `djp_` prefix. The binary net fields overlap the site labels, but some reviewed records establish operation without specifying a site combination. Retain them as directly usable operation indicators.

### Observed weather (2 columns)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `mist_observed` | `mist_observation` | controlled text | Reconciled mist observation: `none`, `present_light_patchy`, `present_sustained`, or `present_unspecified`; blank when occurrence is unknown. DJP symbols supply most observations; dated reviewed reports, diaries, and weather notes may fill or correct them. |
| `rain_observed` | unchanged | controlled text | Reconciled rain observation: `none`, `present_showers`, `present_heavy`, or `present_unspecified`; blank when occurrence is unknown. DJP symbols supply most observations; dated reviewed sources may fill or correct them. These are qualitative historical classes, not measured rainfall amounts. |

**Why these are not `djp_*`:** the current export includes 20 mist observations and 6 rain observations outside DJP workbook metadata. Compared with initial decoding, reviewed decisions also change/fill mist on 3 DJP dates and rain on 1. A strictly DJP-only export could use `djp_mist`/`djp_rain`, but would discard those other observations; this proposal keeps the reconciled fields.

#### Mist mapping

| DJP input / current reconciled value | Proposed value | Meaning and mapping |
| --- | --- | --- |
| `M` → `good_mist_2h_plus` → `good` | `present_sustained` | Historical uppercase mist class, described as good mist lasting at least 2 hours. “Sustained” names that source class; it is not a measured density or proof of continuous mist throughout the night. |
| `m` → `light_or_patchy_mist_1h_plus` → `light_patchy` | `present_light_patchy` | Historical light or patchy mist class lasting at least 1 hour. “Patchy” and “sustained” are source categories, not mutually exclusive physical properties. |
| `l`, `c`, `o` → `low_cloud`, `high_cloud`, `clear` → `none` | `none` | Source cloud/clear conditions mapped to no mist under the current decoding convention. |
| Reviewed observation `present_unspecified` | `present_unspecified` | Mist explicitly reported, but no supported detailed class. |
| `?`, `X`, blank/unknown weather code, or no observation | blank | Unknown whether mist occurred, unless dated evidence supplies a reconciled observation. |

Trailing `R`/`r` in a combined weather code is removed before mist decoding and interpreted separately as rain: for example, `mR` means light/patchy mist plus heavy rain. Reviewed dated decisions are applied after decoding; a reviewed `good` maps to `present_sustained` and a reviewed `light_patchy` to `present_light_patchy`, but the workbook duration thresholds should not be imposed on a narrative report that does not state duration.

#### Rain mapping

| DJP input / current reconciled value | Proposed value | Meaning and mapping |
| --- | --- | --- |
| `R` → `heavy_rain_1h_plus` → `heavy_rain` | `present_heavy` | Heavy rain, at least 1 hour under the DJP code convention. Reviewed heavy-rain reports map to the same class without inventing a duration. |
| `r` → `light_or_heavy_showers` → `showers` | `present_showers` | Showers that may be light or heavy. This cannot be relabeled `present_light`: the source explicitly permits heavy showers. |
| `rain_noted_in_weather_code` → `rain_unspecified`, or reviewed `rain_unspecified` | `present_unspecified` | Rain explicitly reported, but no supported detailed class. The legacy decoded category is supported by the recoding; the current decoder resolves combined `MR` through its uppercase `R` suffix to heavy rain. |
| No rain code/suffix within a DJP metadata row → `none`, or reviewed `none` | `none` | No rain under the workbook coding convention, or a reviewed absence record. |
| No DJP metadata and no reviewed rain observation | blank | Unknown whether rain occurred. |

A separate rain code takes precedence over an `R`/`r` suffix embedded in the weather field. Dated reviewed decisions then take precedence over the initial decoding.

**Keep `present_unspecified`:** it records known presence, not merely an unmentioned class. Currently there are 14 such mist dates and 1 rain date. Dropping them into blanks would merge documented presence with unknown occurrence. A shorter value `present` could replace the label, but would carry the same meaning; `present_unspecified` is clearer beside the detailed presence classes. Silence in a report remains blank. Blank rain cells inside DJP metadata are the specific workbook-convention exception described above.

### Modeled mist (3 columns)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `mist_modeled_none` | `mist_probability_none` | probability 0–1 | Probability of no mist in the unified observed/ERA5 distribution. |
| `mist_modeled_light_patchy` | `mist_probability_light_patchy` | probability 0–1 | Probability of the `present_light_patchy` mist class in the same distribution. |
| `mist_modeled_sustained` | `mist_probability_good` | probability 0–1 | Probability of the renamed `present_sustained` mist class (internally `good`) in the same distribution. |

The values are probabilities, not binary modeled states. The three sum to 1 when available; all are blank when there is no prediction. Exact observed classes set the corresponding probability to 1 and the others to 0. `present_unspecified` sets the no-mist probability to 0 and renormalizes the two remaining states. Elsewhere a multinomial model calibrated against observed mist predicts from ERA5. There is no fourth unspecified model state: unspecified observed presence constrains the detailed-state distribution. The new names change labels only, not the fitted model or probabilities.

### DJP team size (1 column)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `djp_team_size` | `djp_team_size_minimum` | integer people | Minimum known number of ringers and others in the DJP team code. Use the recorded numeric count and add any explicitly numbered Earthwatch participants. When all numbers are provided this equals the exact total; when extra Earthwatch participants are mentioned without a number, retain only the known base count. No maximum or unspecified participant count is estimated. Blank if no numeric size can be decoded or no DJP metadata exists. It does not distinguish skilled ringers from other participants. |

Examples: `8` becomes 8; `8_plus_6EW` becomes 14; `8_plus_EW` becomes 8, because the additional participants are not numbered. All three follow the same rule: retain the minimum supported by the recorded numbers. The export has no separate size-type column, so users should treat this field consistently as a minimum known team size, which can underestimate actual participation.

### Moon (2 columns)

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `moon_days_from_new_moon` | unchanged | signed integer days | Approximate signed phase position: positive in the waxing half-cycle and negative in the waning half-cycle, rounded to whole days (−15 to +15). Zero is near new moon. Computed at 12:00 UTC from a fixed reference new moon and a constant 29.530588853-day cycle. |
| `moon_illumination_fraction` | unchanged | fraction 0–1 | Approximate illuminated fraction of the lunar disc from a cosine of the same constant-cycle phase, rounded to three decimals. It does not account for moonrise/set, cloud, topography, or actual light at the nets. |

Both fields are computed from a constant-cycle approximation. For each `ringing_date`, evaluate the elapsed days at **12:00 UTC** since the reference new moon on **6 January 2000 at 18:14 UTC**. Take the remainder after division by **29.530588853 days** to obtain lunar age `a` within the cycle. For `moon_days_from_new_moon`, use `a` in the first half-cycle and `a - 29.530588853` in the second, then round to whole days. For illumination, compute `0.5 × (1 − cos(2πa / 29.530588853))` and round to three decimal places.

This approximates phase using a fixed mean lunar cycle; it does not use a date-specific astronomical ephemeris. Illumination uses the unrounded lunar age, so it cannot be reproduced exactly from the exported integer phase day. Neither field measures light reaching the nets or accounts for whether the moon is above the horizon.

### ERA5 weather (9 columns)

The query requests **ERA5 hourly single-level point time series** from the Copernicus Climate Data Store (`reanalysis-era5-single-levels-timeseries`) at **3.00° S, 38.25° E**, the requested 0.25° grid point nearest the project coordinates at Ngulia. It covers the full calendar interval **20 October 1969–12 January 2024** for this export, including dates outside the seasonal rows. The requested variables are total cloud cover, cloud-base height, total precipitation, the eastward and northward 10 m wind components, 2 m temperature, 2 m dew-point temperature, and surface pressure. Wind speed and relative humidity are derived from those hourly variables before daily aggregation.

All fields below use hourly timestamps **00:00 through 08:00 inclusive** in `Africa/Nairobi` (UTC+3) on `ringing_date`: normally nine hourly values. The wording should specify the timestamps, particularly for precipitation; the current code selects and sums the supplied hourly precipitation values without redefining their accumulation intervals. The requested ERA5 point is −3.00°, 38.25°. Means ignore unavailable values. No daily valid-hour count is currently exported.

| Proposed column | Current column | Type / unit | Definition for users |
| --- | --- | --- | --- |
| `era5_total_cloud_cover_mean` | `total_cloud_cover_mean` | fraction 0–1 | Mean hourly total cloud cover over the defined local timestamps. |
| `era5_cloud_base_height_mean_m` | `cloud_base_height_mean_m` | metres | Mean hourly ERA5 cloud-base height over the defined timestamps. Blank if unavailable. This is a reanalysis variable, not a measured height of mist above the nets. |
| `era5_total_precipitation_00_08_mm` | `total_precipitation_00_08_mm` | millimetres | Sum of supplied hourly precipitation values at the defined timestamps, converted from metres to millimetres. |
| `era5_wind_u_10m_mean_ms` | `wind_u_10m_mean_ms` | metres/second | Mean hourly eastward component of wind at 10 m; negative means westward. |
| `era5_wind_v_10m_mean_ms` | `wind_v_10m_mean_ms` | metres/second | Mean hourly northward component of wind at 10 m; negative means southward. |
| `era5_wind_speed_10m_mean_ms` | `wind_speed_10m_mean_ms` | metres/second | Mean of hourly 10 m wind magnitudes, calculated before averaging. It generally differs from the magnitude of the daily mean vector. |
| `era5_temperature_2m_mean_c` | `temperature_2m_mean_c` | degrees Celsius | Mean hourly air temperature at 2 m, converted from kelvin. |
| `era5_relative_humidity_mean_pct` | `relative_humidity_mean_pct` | percent | Mean hourly relative humidity, calculated from ERA5 2 m temperature and dew point using the build's vapour-pressure formula and bounded to 0–100%. |
| `era5_surface_pressure_mean_hpa` | `surface_pressure_mean_hpa` | hectopascals | Mean hourly surface pressure, converted from pascals. |

## Current fields omitted from the proposed main table (20 columns)

Omission from the public analysis view should not delete source evidence from the working pipeline.

| Current column | Current meaning | Proposed handling / reason |
| --- | --- | --- |
| `total_birds_ringed` | Selected non-swallow daily total, including explicit recorded zeros. | Calculate the chosen species total from `daily_counts.csv`; use `count_status` when species rows are absent. |
| `swallow_birds_ringed` | Selected excluded-group count, filled with zero even on missing-count dates. | Calculate from species-day rows with an explicit taxon filter. |
| `daily_count_source` | Filename for positive counts, workbook cell locator for recorded zeros. | Remove from the public daily table; explain season-level source selection in methods. |
| `effort_status` | Combined catch/operation evidence summary. | Remove as requested; users can inspect the direct operation fields. |
| `operations_evidence_ids` | Identifiers of dated reviewed decisions applied to daily observations. | Remove from the public daily table; keep reconciliation provenance in the repository. |
| `all_birds_ringed` | Selected species sum before targeted-group exclusion; explicit DJP zeros also retained. | Calculate from the species-day table; retain no bird totals in the daily coverage export. |
| `ringing_happened` | Positive non-swallow catch flag; FALSE also includes unknown counts. | Remove. Use `count_status`; this name overstates what catch evidence establishes. |
| `djp_reported_total` | Workbook column BS daily total, including explicit zeros. | Keep in source/audit evidence, with the five discrepancies documented. Positive source totals do not override the species sum. |
| `djp_source_row` | Source workbook Sheet1 row used for DJP metadata and reported total. | Keep with workbook evidence rather than an analysis covariate. |
| `moon_distance_from_new_moon` | Absolute value of the rounded signed phase day. | Derive as `abs(moon_days_from_new_moon)`. |
| `moon_phase_name` | Eight phase categories from unrounded approximate lunar age. | Omit for a lean numeric analysis table; retain classification thresholds in methods. If phase labels are wanted, keep this column: exact labels cannot always be recovered from the rounded signed day. |
| `djp_weather` | Decoded good/light mist, cloud, clear, or unknown source code. | Keep source evidence separately; use reconciled `mist_observed`. This source field contains cloud distinctions lost in the mist recoding, so omission is a deliberate scope choice, not a claim of exact duplication. |
| `djp_rain` | Decoded source rain class; blank rain code within a metadata row maps to none. | Keep source evidence separately; use reconciled `rain_observed`. |
| `djp_site` | Decoded source site combination, none, or unknown. | Keep source evidence separately; use reconciled site field. |
| `djp_tape` | Decoded source front/behind-lodge tape locations or none. | Keep source evidence separately; main table retains nocturnal use only. Locations are useful if playback location becomes an analysis question. |
| `djp_pax` | Normalized source team code, including Earthwatch notation or unknown. | Keep source evidence separately; main table retains one minimum-known size with the selection rule in its definition. It is normalized text, not the untouched workbook cell. |
| `djp_team_size_total` | Exact total only, blank when extra Earthwatch participation is unspecified. | Replace the numeric pair with one minimum-known size. |
| `djp_team_size_interpretation` | Parsing states distinguishing exact totals, unspecified Earthwatch additions, unknown codes, and absent metadata. | Omit as requested; explain the minimum-known selection rule in the `djp_team_size` definition. |
| `bush_net_configuration` | Season-based back bush (1977–1993), transition (1994–1995), front bush (1996 onward); blank before 1977. | Document as a historical period assumption, not a daily operation field. |
| `night_net_configuration` | Established from 1977, blank earlier. | Document the period assumption. The historical account also discusses night netting from 1976 and disputed 1974 observations; this field is not an establishment-date finding. |

## Remaining naming choices

- The proposal now has **25 columns**, including one count-status column and one team-size column, with no daily totals, effort summary, or evidence identifiers.
- `present_sustained` replaces the source's “good” mist class. It avoids suggesting measured density; its historical definition is explicit above. The class is still a historical category rather than a standardized intensity scale.
- `present_unspecified` is retained to preserve known occurrence. It can be shortened to `present` if preferred, but should not be turned into a blank.
- `mist_observed` and `rain_observed` describe the reconciled source coverage accurately. Keep `djp_*` for the DJP-only team-size field and `era5_*` for reanalysis.

## Implementation scope after review

Define the Zenodo selection, column order, renames, and category mappings once in `scripts/exports/02_build_zenodo_package.R`. Keep richer internal fields and existing mist model labels for reproducibility. Update the source dictionary in `data/README.md` so rebuilding the published dictionary preserves the agreed definitions; distinguish public fields from internal diagnostic fields. Align `tests/zenodo-schema.csv` and export tests. Verify that status still preserves all 120 recorded-zero dates and 3,345 missing dates, category recoding preserves known presence, and the observational values and modeled probabilities otherwise remain unchanged. The public CSV and documentation have been rebuilt with these mappings. Internal fields and model labels remain unchanged.

Reviewed files: the current Zenodo CSV and dictionaries, `scripts/curated/05_build_daily_coverage.R`, `scripts/intermediate/01_build_daily_context.R`, `scripts/intermediate/02_build_mist_model.R`, `scripts/curated/04_build_era5_daily_weather.R`, `scripts/curated/03_build_daily_counts.R`, the mist/season helpers, and the targeted-capture taxon configuration. The broader pipeline was not rebuilt for this review.
