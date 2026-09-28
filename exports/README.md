# Exports and publication

This folder holds regenerable delivery files. The folder README and both Zenodo documentation files are tracked in Git; generated CSVs and archives are local. Run export scripts from the repository root after rebuilding the curated tables and reviewing QA results.

| Folder | Contents |
| --- | --- |
| `zenodo/` | Five dataset CSVs, including narrow recovery and daily-coverage views, a compact README, and a versioned data dictionary, ready to upload from this folder. The builder overwrites these files. |
| `gbif/` | Darwin Core Archive and its event, occurrence, measurement, and metadata files. |

## Build and review

The public `daily_coverage.csv` contains 25 calendar and covariate columns. Calculate bird totals from `daily_counts.csv`; use `count_status` to distinguish recorded zeros from missing dates. The internal `data/04_curated/daily_coverage.csv` retains all 45 fields for analyses, diagnostics, and source reconciliation.

1. Rebuild the five curated tables using the [scripts README](../scripts/README.md) and review the [QA outputs](../outputs/README.md), especially ring-event corrections, coverage evidence, and recoveries.
2. Run the dataset overview scripts in `scripts/exploration/dataset_overview/` and check their summaries and figures.
3. Run `Rscript scripts/exports/00_build_citation.R`, `Rscript scripts/exports/02_build_zenodo_package.R`, and `Rscript scripts/exports/03_build_gbif_export.R`.
4. Run `Rscript tests/testthat.R` and resolve any package violations listed in `outputs/qa/zenodo/violations.csv`. The [test guide](../tests/README.md) describes the schema, consistency rules and edge cases.
5. Review the five CSVs, `README.md`, and `DATA_DICTIONARY.md` directly in `zenodo/`, plus `gbif/ngulia_gbif_dwca.zip`. Confirm that the files and definitions match the intended version. Enter title, creators, license, coverage, and related identifiers in the Zenodo record metadata.

## Current record status

The latest documented record checks were on **2026-09-25**. The export builders prepare files but do not publish them.

- **Zenodo:** No resolving concept DOI is recorded. The former `10.5281/zenodo.21395879` value did not resolve at that check and was removed from publication metadata. The seven files to upload can be generated locally.
- **GBIF:** No Ngulia dataset was returned for the configured A Rocha Kenya publisher at that check. The Darwin Core Archive can be generated locally; registration and ingestion remain pending.

A local export file or an identifier in metadata does not establish that a public record is live.

## Publication order

1. Create the Zenodo dataset record with the seven files in `exports/zenodo/`, using [`config/publication/dataset_metadata.yml`](../config/publication/dataset_metadata.yml) for record metadata. Record the **version DOI**, concept DOI, version number, publication date, and Git commit. Analyses should cite a fixed version DOI.
2. Add the verified concept DOI to [`config/publication/dataset_metadata.yml`](../config/publication/dataset_metadata.yml) and rebuild the GBIF archive. Publish it through an IPT account associated with A Rocha Kenya, or host the archive at a stable public URL and request manual registration through the GBIF Help Desk. GBIF contains the ringing-event subset; Zenodo contains the broader research dataset. An archive file alone does not create a GBIF record.
3. Once both records resolve, add their links and a short dataset guide to the existing [Ngulia website](https://a-rocha-kenya.github.io/ngulia-website/). The website is the public project entry point and hosts the interactive science dashboard; the separate [forecast](https://a-rocha-kenya.github.io/ngulia-forcast/) hosts its operational dashboard. Question-specific research belongs in [ngulia-analysis](https://github.com/A-Rocha-Kenya/ngulia-analysis).

## Website resources

Website resource generation lives in [ngulia-website](https://github.com/A-Rocha-Kenya/ngulia-website). Its Python preprocessing downloads the latest published Zenodo package, keeps a complete local copy, and generates dashboard, recovery, migration, and species-range JSON within the website repository.

Until the Zenodo record is published, run `npm run preprocess -- --source-dir /absolute/path/to/ngulia-dataset/exports/zenodo` from the website repository. Rebuild the Zenodo package here before refreshing local website resources. The website uses only the public dataset fields, with taxonomy joined by `avibase_id`; internal research inputs and website JSON are no longer part of this repository's export workflow.

## GBIF archive

The GBIF export reads the Zenodo `ring_events.csv` generated in step 3, so its captures and corrections match the release package. It uses ringing dates as the Event core, individual ringing records as the Occurrence extension, and biometric and moult observations as bird-level ExtendedMeasurementOrFact rows. Resolved `ringer_name` values become Darwin Core `recordedBy`. Daily species counts and environmental variables are excluded; the EML description links to the broader Zenodo research dataset.
