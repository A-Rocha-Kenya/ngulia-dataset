# Scripts

Run scripts from the repository root so `here::here()` resolves this project. The R workflow is linear and exposes intermediate objects for interactive inspection.

| Folder | Role |
| --- | --- |
| `curated/` | Build the canonical CSV tables from source material. |
| `intermediate/` | Assemble daily context, model mist, and stage geolocator paths. |
| `diagnostics/` | Inspect source reconciliation and data quality without altering curated tables. |
| `exploration/` | Describe the dataset without fitting question-specific models. |
| `exports/` | Build citation, website, Zenodo, and GBIF deliveries. |
| `helpers/` | Shared code sourced by runnable scripts. |
| `setup/` | Install declared R dependencies. |

Question-specific modeling is maintained in [ngulia-analysis](https://github.com/A-Rocha-Kenya/ngulia-analysis). Generated results are described in [`outputs/`](../outputs/README.md) and [`exports/`](../exports/README.md).

## Before running

The repository does not include raw or curated data. Obtain the source archive from the project custodian and place it under the paths in the [data README](../data/README.md#local-sources-and-staging-files). In particular, the annual ringing workbooks and DJP daily-summary workbook must be present. Preserve the manually curated `data/04_curated/recoveries.csv`: the recovery script updates its classifications in place and cannot recreate it from raw documents.

The DJP metadata extractor also needs Python 3 with only standard-library modules. Install the required R packages from the project root:

```r
source("scripts/setup/01_install_dependencies.R")
```

The ERA5 weather script reuses a matching cached hourly CSV or ZIP under `data/01_raw/weather/`. Otherwise it requests the needed time series through `ecmwfr`, which requires working Climate Data Store access. The request range is derived from the count and metadata dates.

## Run the pipeline

Run scripts from the project root, in this order.

```r
# Curated data ------------------------------------------------------------
source("scripts/curated/01_build_ring_events.R")
source("scripts/curated/02_extract_djp_daily_counts.R")
source("scripts/curated/03_build_daily_counts.R")
source("scripts/curated/04_build_era5_daily_weather.R")
source("scripts/intermediate/01_build_daily_context.R")
source("scripts/intermediate/02_build_mist_model.R")
source("scripts/curated/05_build_daily_coverage.R")
source("scripts/curated/06_standardize_recovery_encounters.R")

# Documentation -----------------------------------------------------------
source("scripts/exports/00_build_citation.R")

# Dataset exploration -----------------------------------------------------
source("scripts/exploration/dataset_overview/00_summarize_datasets.R")
source("scripts/exploration/dataset_overview/01_plot_daily_rings_by_season.R")

# Exports -----------------------------------------------------------------
source("scripts/exports/01_build_website_exports.R")
source("scripts/exports/02_build_zenodo_package.R")
source("scripts/exports/03_build_gbif_export.R")
```

| Step                                                  | Purpose                                                                                                                                                                                                                                                              | Main outputs                                                                |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `01_build_ring_events.R`                              | Imports, cleans, and validates annual ringing workbooks.                                                                                                                                                                                                             | `ring_events.csv`, ring-event QA                                            |
| `02_extract_djp_daily_counts.R`                       | Stages DJP species-day counts and metadata.                                                                                                                                                                                                                          | `data/03_intermediate/daily_counts/`                                        |
| `03_build_daily_counts.R`                             | Selects the preferred count source by season. DJP is preferred when available for a whole season.                                                                                                                                                                    | `daily_counts.csv`                                                          |
| `04_build_era5_daily_weather.R`                       | Produces 00:00-08:00 local ERA5 daily weather.                                                                                                                                                                                                                       | `era5_daily_weather.csv`                                                    |
| `01_build_daily_context.R`                            | Assembles source-specific daily observations, moon fields, and ERA5 weather.                                                                                                                                                                                         | `data/03_intermediate/daily_context/daily_context.csv`                      |
| `02_build_mist_model.R`                               | Builds one three-state mist model from observed classifications and ERA5.                                                                                                                                                                                            | `data/03_intermediate/mist_model/`                                          |
| `05_build_daily_coverage.R`                           | Builds the canonical daily catch, coverage/effort, and covariate table.                                                                                                                                                                                              | `data/04_curated/daily_coverage.csv`                                        |
| `06_standardize_recovery_encounters.R`                | Applies deterministic encounter and mortality labels to the manually curated recovery table.                                                                                                                                                                         | Updated canonical `recoveries.csv`                                                    |
| `00_build_citation.R`                                 | Builds the GitHub README and citation file from shared metadata and authored prose.                                                                                                                                                                                  | `README.md`, `CITATION.cff`                                                 |
| `dataset_overview/00_summarize_datasets.R`            | Creates descriptive dataset summaries. | `outputs/exploration/dataset_overview/` |
| `dataset_overview/01_plot_daily_rings_by_season.R`    | Plots daily capture totals by day within each ringing season. | `outputs/exploration/dataset_overview/figures/daily_rings_by_season.png` |
| `01_build_website_exports.R`                          | Creates website JSON exports.                                                                                                                                                                                                                                        | `exports/website/`                                                          |
| `02_build_zenodo_package.R`                           | Copies four dataset CSVs, selects the 18 public recovery fields, and writes a compact file guide plus the versioned data dictionary for Zenodo.                                                                                                                                                         | `exports/zenodo/`                                                           |
| `03_build_gbif_export.R`                              | Builds the sampling-event Darwin Core Archive with daily events, individual captures, and bird-level measurements.                                                                                                                                                   | `exports/gbif/`                                                             |

The export commands prepare local files; they do not publish a Zenodo or GBIF record. Review the [QA outputs](../outputs/README.md) before building them, then follow the [exports README](../exports/README.md) for publication. `scripts/intermediate/03_extract_geolocator_paths.R` is optional website support and is not required for the four curated tables.

## Processing and standardization

### How ring events are built

`scripts/curated/01_build_ring_events.R` is the main ingestion and cleaning script. It converts heterogeneous annual workbooks from `data/01_raw/ring_events/` into a consistent event table while preserving source references in the QA outputs.

The script applies these steps in order:

1. **Read source-specific workbook regions.** `config/ring_events/file_specs.csv` identifies the file, sheet, header and final rows, expected years, and source-specific column conventions. It also controls exceptional date/time handling, swapped age and sex columns, retrap-code use, and fat scale.
2. **Apply explicit source corrections.** `config/ring_events/corrections.csv` records known row or row-range corrections to dates, species fields, measurements, and shifted columns. `config/ring_events/ring_number_review.csv` separately applies audited ring-number replacements or appends warnings for unresolved values. Both remain separate from the raw workbooks.
3. **Construct dates and seasons.** Raw date and time fields are parsed into `datetime`; `ringing_date` is constructed using the source date convention and 20:00 rollover rule; `season` is then derived from `ringing_date` using the June 1 boundary defined in the [data README](../data/README.md#key-definitions).
4. **Resolve species identity.** `species_lookup.csv` maps accepted numeric codes, Ngulia codes, abbreviations, and names to AFRING numbers. `species_reference.csv` adds project-standard common names, Avibase IDs, and website species codes. Missing, unmatched, or conflicting species identities are retained as AFRING number `0`. If a provisional ring history contains different species across events, the conflicting values are recorded in `ring_note`.
5. **Clean biological fields.** Age and sex are converted to controlled project values. Fat scores are assigned to `fat_ngulia` or `fat_kaiser` according to the source specification. Wing and weight are parsed and checked against species-specific ranges from `measurement_ranges.csv`; invalid measurements are set to missing and recorded in QA.
6. **Resolve ringer identity.** Source columns named `Init`, `Initial`, `Initials`, `Ringer`, `Ringed by`, or `Observer` produce three internal lookup keys: a three-digit code with trailing punctuation removed, an uppercase alphanumeric initial, and a normalized full-name key. `config/ring_events/ringer_lookup.csv` maps these values to the canonical `ringer_name`. A row with `source_file` filled applies only to that workbook and takes precedence; a blank `source_file` is the default mapping for every workbook. Only the full name is exported.
7. **Handle repeated rings.** Records with the same ring number on the same `ringing_date` are merged into one event. Separate provisional ring-history groups distinguish new-capture records with the same number from retraps. Both conflicting groups receive `_01` and `_02` suffixes in `ring_number`, and `ring_note` flags the uncertainty. A source code can identify a retrap whose earlier capture is absent from the curated table; this is retained with an explanation in `ring_note`. A new-assignment code that conflicts with earlier history in the same assignment leaves `retrap` missing and records the conflict in QA.
8. **Decode moult.** Source-specific columns and expected sequence lengths are described in `moult_specs.csv`. The pipeline decodes feather and body-moult scores where their structure is sufficiently clear, while retaining unresolved source notation in `moult_note` and the component-specific QA log.
9. **Add taxonomy and subspecies.** Standard species metadata are joined to the cleaned events. When configured, labels extracted from `ring_note` and matched through `subspecies_lookup.csv` add a subspecies Avibase ID.
10. **Export curated and QA products.** The script writes one `ring_events.csv` containing event, biometric, and moult fields, plus the row-level issue logs, the source-file audit, and a source-by-source list of ringer values that remain unmatched.

`ring_number_review.csv` identifies records with `source_file`, `source_sheet`, `source_row`, and optional inclusive `source_row_end`. Its `expected_pattern` is checked against the cleaned source ring before any edit. A nonblank `replacement` is applied as a regular-expression replacement; a nonblank `warning` is appended to `ring_note`. Every rule must provide a replacement or warning. The build stops if a target row is absent, expanded rules overlap, or an expected pattern does not match.

The ringer lookup has six columns: `source_file`, `input_type`, `input_text`, `ringer_name`, `mapping_confidence`, and `mapping_basis`. `input_type` is `ringer_code`, `ringer_initial`, or `ringer_name`. The pipeline first tries a matching row for the current `source_file`, then falls back to the same key with blank `source_file`. This keeps common codes and names global while allowing an ambiguous value such as an initial to mean different people in different workbooks. `mapping_confidence` distinguishes verified register entries from high-, medium-, and low-confidence inferences; `mapping_basis` records the evidence used. These review fields remain in configuration and are not exported with bird records.

Rows need a valid date, allowed October-January event month and source year, ring number, an initial species value after unknown coding, and non-recovery status to enter `ring_events.csv`. A later cross-event ring/species conflict sets `afring_number` to `0` without removing the event. Rows mapping to AFRING code `9999` (`Lost or destroyed ring`) are excluded because they do not represent taxon occurrences. Rows marked with raw retrap code `X` are excluded from `ring_events.csv`; identifiable movement records are curated independently in `recoveries.csv`.

## Diagnostics and additional analysis

Diagnostics are optional and do not alter curated data.

```r
source("scripts/diagnostics/plot_ring_event_measurements.R")
source("scripts/diagnostics/qa_daily_context.R")
source("scripts/diagnostics/compare_daily_count_sources.R")
source("scripts/diagnostics/assess_ring_event_date_modes.R")
source("scripts/diagnostics/plot_daily_coverage_matrices.R")
source("scripts/diagnostics/summarize_daily_covariate_coverage.R")
source("scripts/diagnostics/audit_djp_team_size.R")
source("scripts/diagnostics/validate_mist_model.R")
```

## Rebuilding after changes

| Changed input | Rebuild from |
| --- | --- |
| Ringing workbooks, import rules, corrections, or species reference | Ring events, then daily counts and all dependent daily tables, QA, exploration, and exports. |
| Preferred count source, date convention, or season rule | Daily counts and every downstream table and export; if ring-event dates changed, start with ring events. |
| Reviewed operations history | Daily context, mist model, daily coverage, related QA, and exports. |
| Manually curated `recoveries.csv` | Recovery classifications, then Zenodo and website exports. Preserve the source audit. |
| Website taxonomy crosswalk | Website export and optional geolocator-path extraction. |
| Publication metadata | Citation, Zenodo package, and GBIF export; curated CSVs need no rebuild. |

Record the dataset version or Git commit and curated-file checksums used by downstream analyses.
