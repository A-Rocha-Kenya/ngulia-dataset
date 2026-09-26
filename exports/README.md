# Exports and publication

This folder holds regenerable delivery files. The folder README and both Zenodo documentation files are tracked in Git; generated CSVs and archives are local. Run export scripts from the repository root after rebuilding the curated tables and reviewing QA results.

| Folder | Contents |
| --- | --- |
| `website/` | JSON files consumed by the separate Ngulia website. |
| `zenodo/` | Five dataset CSVs, including a narrow recovery view, a compact README, and a versioned data dictionary, ready to upload from this folder. The builder overwrites these files. |
| `gbif/` | Darwin Core Archive and its event, occurrence, measurement, and metadata files. |

## Build and review

1. Rebuild the four curated tables using the [scripts README](../scripts/README.md) and review the [QA outputs](../outputs/README.md), especially ring-event corrections, coverage evidence, and recoveries.
2. Run the dataset overview scripts in `scripts/exploration/dataset_overview/` and check their summaries and figures.
3. Run `Rscript scripts/exports/00_build_citation.R`, `Rscript scripts/exports/02_build_zenodo_package.R`, and `Rscript scripts/exports/03_build_gbif_export.R`.
4. Review the five CSVs, `README.md`, and `DATA_DICTIONARY.md` directly in `zenodo/`, plus `gbif/ngulia_gbif_dwca.zip`. Confirm that the files and definitions match the intended version. Enter title, creators, license, coverage, and related identifiers in the Zenodo record metadata.

## Current record status

The latest documented record checks were on **2026-09-25**. The export builders prepare files but do not publish them.

- **Zenodo:** No resolving concept DOI is recorded. The former `10.5281/zenodo.21395879` value did not resolve at that check and was removed from publication metadata. The seven files to upload can be generated locally.
- **GBIF:** No Ngulia dataset was returned for the configured A Rocha Kenya publisher at that check. The Darwin Core Archive can be generated locally; registration and ingestion remain pending.

A local export file or an identifier in metadata does not establish that a public record is live.

## Publication order

1. Create the Zenodo dataset record with the seven files in `exports/zenodo/`, using [`config/publication/dataset_metadata.yml`](../config/publication/dataset_metadata.yml) for record metadata. Record the **version DOI**, concept DOI, version number, publication date, and Git commit. Analyses should cite a fixed version DOI.
2. Add the verified concept DOI to [`config/publication/dataset_metadata.yml`](../config/publication/dataset_metadata.yml) and rebuild the GBIF archive. Publish it through an IPT account associated with A Rocha Kenya, or host the archive at a stable public URL and request manual registration through the GBIF Help Desk. GBIF contains the ringing-event subset; Zenodo contains the broader research dataset. An archive file alone does not create a GBIF record.
3. Once both records resolve, add their links and a short dataset guide to the existing [Ngulia website](https://a-rocha-kenya.github.io/ngulia-website/). The website is the public project entry point and hosts the interactive science dashboard; the separate [forecast](https://a-rocha-kenya.github.io/ngulia-forcast/) hosts its operational dashboard. Question-specific research belongs in [ngulia-analysis](https://github.com/A-Rocha-Kenya/ngulia-analysis).

## Website export

`01_build_website_exports.R` reads curated daily counts, the manually curated recovery table, and taxonomy mappings, then writes JSON to `website/`. For local syncing, point the website preprocessing configuration to `exports/website/`.

The local recovery outputs are [`website/recoveries.json`](website/recoveries.json) for the dashboard and [`zenodo/recoveries.csv`](zenodo/recoveries.csv) for the data package. Both were rebuilt from the 269-row canonical table after the September 2026 duplicate review; generated files are excluded from Git.

## GBIF archive

The GBIF export uses confirmed capture dates as the Event core, individual ringing records as the Occurrence extension, and biometric and moult observations as bird-level ExtendedMeasurementOrFact rows. Resolved `ringer_name` values become Darwin Core `recordedBy`. Daily species counts and environmental variables are excluded; the EML description links to the broader Zenodo research dataset.
