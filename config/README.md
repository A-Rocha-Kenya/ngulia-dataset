# Configuration

These files record how source material is interpreted. They are versioned separately from the original files in `data/01_raw/`. Edit a config file, then rerun the script named below to update its derived data or export.

| Folder | What it controls |
| --- | --- |
| `ring_events/` | Import and curation of historical ringing workbooks. |
| `daily_counts/` | Classification of targeted catches in daily context. |
| `daily_covariates/` | Historical evidence about station operations. |
| `website/` | Reviewed external identifiers used for taxonomy enrichment and geolocator matching. |
| `publication/` | Shared metadata for citation and public data packages. |

## Files

| File | What it contains | How it is used |
| --- | --- | --- |
| [`ring_events/file_specs.csv`](ring_events/file_specs.csv) | One row per source workbook with sheets, headers, year limits, column conventions, and exceptional date or time rules. | `01_build_ring_events.R` uses these settings to read each workbook correctly. The date-mode diagnostic reads them too. |
| [`ring_events/corrections.csv`](ring_events/corrections.csv) | Reviewed fixes tied to specific source rows or row ranges, with reasons. | Applied during ring-event import without changing the original workbooks. |
| [`ring_events/ring_number_review.csv`](ring_events/ring_number_review.csv) | Audited replacements or warnings for unusual ring-number entries. | Applied before ring events are linked and standardized; unresolved numbers retain warnings. |
| [`ring_events/ring_history_review.csv`](ring_events/ring_history_review.csv) | Row-level decisions about apparent ring reuse or collisions. | Tells the ring-event builder whether a record is a new assignment or belongs to an existing ring history. |
| [`ring_events/species_lookup.csv`](ring_events/species_lookup.csv) | Mappings from source species codes and labels to AFRING numbers. | Standardizes species while building ring events; also helps the GBIF export resolve names. |
| [`ring_events/species_reference.csv`](ring_events/species_reference.csv) | The reference table linking AFRING numbers, Ngulia codes, scientific names, common names, and Avibase IDs. | Preserves AFRING-to-Avibase assignments and project label overrides. The taxonomy builder enriches these concepts; observation builders derive `avibase_id` from the mapping. |
| [`ring_events/subspecies_lookup.csv`](ring_events/subspecies_lookup.csv) | Reviewed mappings from source race/form notes to current taxonomic concepts. | The legacy column `subspecies_avibase_id` can identify a current species or lower rank. Diagnostic notes resolve historical slash entries to species; only lower ranks enter the published subspecies column. Empty mappings retain the source taxon. See `docs/reviews/shrike_taxonomy_review.md`. |
| [`ring_events/ringer_lookup.csv`](ring_events/ringer_lookup.csv) | Source codes, initials, and names mapped to a canonical ringer name, with evidence and confidence. | Resolves the ringer field in `ring_events.csv`; workbook-specific mappings take precedence over general ones. |
| [`ring_events/measurement_ranges.csv`](ring_events/measurement_ranges.csv) | General and species-specific plausible wing and mass ranges. | The ring-event builder leaves out-of-range values missing in the curated table and records the source value in QA; diagnostic plots use the same ranges. |
| [`ring_events/moult_specs.csv`](ring_events/moult_specs.csv) | Workbook-specific moult columns, feather counts, and scoring schemes. | Directs the ring-event builder when reading and standardizing moult records. |
| [`daily_counts/targeted_capture_groups.csv`](daily_counts/targeted_capture_groups.csv) | Avibase IDs and reasons for species groups caught through targeted methods. | `01_build_daily_context.R` marks these catches separately when assembling daily evidence. |
| [`daily_covariates/operations_history.csv`](daily_covariates/operations_history.csv) | Dated evidence about nets, lights, and other operations, with source paths, page references, and review status. | `01_build_daily_context.R` applies records with supported daily scope and retains broader historical statements as context. |
| [`website/ngulia_taxonomy_crosswalk.csv`](website/ngulia_taxonomy_crosswalk.csv) | Links among source labels, Ngulia names, Avibase IDs, and other taxonomies, with review flags. | The taxonomy builder adds external identifiers by Avibase ID; the optional geolocator-path script also uses source-label mappings. |
| [`publication/dataset_metadata.yml`](publication/dataset_metadata.yml) | Dataset title, creators, coverage, licenses, references, and Zenodo and GBIF settings. | Citation, Zenodo-package, and GBIF-export scripts read it so those outputs use the same metadata. |

The [scripts README](../scripts/README.md) explains the processing sequence, the [data README](../data/README.md) defines the exported fields, and [daily covariate evidence](../docs/daily_covariates.md) and the [exports README](../exports/README.md) provide longer context.
