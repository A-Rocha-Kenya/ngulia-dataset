# Ngulia ringing dataset

Research data and reproducible processing workflows for the Ngulia ringing project.

## Build from local sources

1. Obtain the local source archive and check the inputs listed in [data/README.md](data/README.md#local-sources-and-staging-files). Raw and generated data are not tracked in Git.
2. Install dependencies and run the ordered scripts in [scripts/README.md](scripts/README.md). Review the [QA outputs](outputs/README.md) and [interpretation limits](docs/data_limitations.md).
3. Prepare delivery files using [exports/README.md](exports/README.md). The Zenodo and GBIF records are still in preparation.

## Repository map

| Folder | What to find |
| --- | --- |
| [data](data/README.md) | Local inputs, five curated tables, field dictionary, and staging products. |
| [config](config/README.md) | Reviewed source rules, historical evidence, and publication metadata. |
| [scripts](scripts/README.md) | Build order, processing scripts, and diagnostics. |
| [outputs](outputs/README.md) | Local QA and descriptive exploration. |
| [exports](exports/README.md) | Zenodo and GBIF files and publication steps. |
| [assets](assets/README.md) | Reviewed figures shown in this repository. |
| [docs](docs/README.md) | Evidence, limitations, credits, and future field proposals. |

## Dataset overview

The figure shows recorded daily ringing totals by season. Blank dates are not assumed to be zero-catch days; use the coverage table before interpreting gaps.

![Daily rings by season](assets/generated/daily_rings_by_season.png)

Regenerate it with `scripts/exploration/dataset_overview/01_plot_daily_rings_by_season.R` and copy the reviewed result from `outputs/exploration/dataset_overview/figures/` to `assets/generated/`.

## Dataset creators

Roles are maintained for this curated dataset; [contributors and acknowledgements](docs/contributors.md) records the wider project community.

| Creator | Roles |
| --- | --- |
| Colin Jackson | Project leadership; Historical data stewardship; Field data collection; Data validation |
| Raphaël Nussbaumer | Data curation; Software; Methodology; Validation; Documentation |
| Martin Cade | Project coordination; Field data collection; Data validation |
| Graeme C. Backhurst | Founding project leadership; Historical data collection; Methodology |
| David J. Pearson | Founding project leadership; Historical data collection; Methodology |

Question-specific research is maintained in [ngulia-analysis](https://github.com/A-Rocha-Kenya/ngulia-analysis). The [Ngulia website](https://a-rocha-kenya.github.io/ngulia-website/) is the public project entry point; the [forecast](https://a-rocha-kenya.github.io/ngulia-forcast/) is a separate tool.
