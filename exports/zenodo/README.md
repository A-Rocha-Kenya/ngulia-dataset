# Data files

This archive contains 5 UTF-8 CSV files with header rows. Empty cells mean a value is unavailable, unresolved, or inapplicable. `DATA_DICTIONARY.md` defines the fields and codes in this dataset version.

| File | Description |
| --- | --- |
| `taxonomy.csv` | Recorded taxonomic concepts, with shared names, classification, external identifiers, and ringing, daily-count, and recovery statistics. |
| `ring_events.csv` | One cleaned ringing event per row, including biometrics, mapped ringer name, and moult fields when recorded. |
| `daily_counts.csv` | Positive species-day counts from the selected source. |
| `daily_coverage.csv` | Season calendar and count coverage, netting/playback observations, observed weather, modeled mist probabilities, DJP team size, moon estimates, and ERA5 weather. |
| `recoveries.csv` | Curated recovery and control movements involving Ngulia, with standardized dates, locations, and encounter outcomes. |

## How the tables relate

- `taxonomy.csv` has one row per `avibase_id`. Join `ring_events.csv`, `daily_counts.csv`, and `recoveries.csv` by `avibase_id`; join an explicitly resolved ring-event subspecies through `subspecies_avibase_id` to the same table. Common names remain in the observation files for readability. eBird codes, classification, and source-specific observation totals are held in `taxonomy.csv`. Only recorded taxa are included; species totals include identified subspecies, so totals across taxonomy rows are not additive.
- `ring_events.csv` records individual captures. `daily_counts.csv` gives positive species-day totals from DJP summaries for seasons 1969–2014 and from ring events for 2015–2023. The two tables need not have identical daily totals.
- `daily_coverage.csv` has one row per date in the season calendar and contains daily covariates rather than bird totals. Calculate counts from `daily_counts.csv` and join by `ringing_date` and `season`. When no species rows exist, `count_status` distinguishes `recorded_zero` from `missing`; `recorded_positive` includes swallow-only catches. Neither status nor a calendar row proves that nets operated.
- Daily netting, playback, and weather observations reconcile DJP metadata with dated reviewed sources. Source codes, evidence identifiers, and diagnostic fields remain in the richer internal table and the project repository. `mist_modeled_*` values are probabilities constrained by observed mist.
- `recoveries.csv` records separately curated movements involving Ngulia and is not keyed to `ring_event_id`.

`season` names the year in which an October–January season starts. `ringing_date` is the analysis date; captures from 20:00 onward normally belong to the next ringing day, subject to the source workbook's date convention.

Recorded catch reflects both bird passage and changing capture conditions. The recovery table is a curated set of known movements, not a complete detection history. Interpret blank dates and modeled weather using the field definitions before comparing seasons.

## Documentation

For the reproducible build, QA, and updated project documentation, see the [GitHub repository](https://github.com/A-Rocha-Kenya/ngulia-dataset). The archived `DATA_DICTIONARY.md` describes these files without requiring GitHub.
