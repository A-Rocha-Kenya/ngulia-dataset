library(yaml)
library(stringr)
library(purrr)
library(glue)
library(cli)

source(here::here("scripts/helpers/publication_metadata.R"))

metadata <- read_publication_metadata()
author_table <- publication_author_table(metadata$authors)

readme <- glue(
  "# {metadata$dataset$title}\n\n",
  "{metadata$dataset$description}\n\n",
  "## Build from local sources\n\n",
  "1. Obtain the local source archive and check the inputs listed in [data/README.md](data/README.md#local-sources-and-staging-files). Raw and generated data are not tracked in Git.\n",
  "2. Install dependencies and run the ordered scripts in [scripts/README.md](scripts/README.md). Review the [QA outputs](outputs/README.md) and [interpretation limits](docs/data_limitations.md).\n",
  "3. Prepare delivery files using [exports/README.md](exports/README.md). The Zenodo and GBIF records are still in preparation.\n\n",
  "## Repository map\n\n",
  "| Folder | What to find |\n| --- | --- |\n",
  "| [data](data/README.md) | Local inputs, five curated tables, field dictionary, and staging products. |\n",
  "| [config](config/README.md) | Reviewed source rules, historical evidence, and publication metadata. |\n",
  "| [scripts](scripts/README.md) | Build order, processing scripts, and diagnostics. |\n",
  "| [outputs](outputs/README.md) | Local QA and descriptive exploration. |\n",
  "| [exports](exports/README.md) | Zenodo and GBIF files and publication steps. |\n",
  "| [assets](assets/README.md) | Reviewed figures shown in this repository. |\n",
  "| [docs](docs/README.md) | Evidence, limitations, credits, and future field proposals. |\n\n",
  "## Dataset overview\n\n",
  "The figure shows recorded daily ringing totals by season. Blank dates are not assumed to be zero-catch days; use the coverage table before interpreting gaps.\n\n",
  "![Daily rings by season](assets/generated/daily_rings_by_season.png)\n\n",
  "Regenerate it with `scripts/exploration/dataset_overview/01_plot_daily_rings_by_season.R` and copy the reviewed result from `outputs/exploration/dataset_overview/figures/` to `assets/generated/`.\n\n",
  "## Dataset creators\n\n",
  "Roles are maintained for this curated dataset; [contributors and acknowledgements](docs/contributors.md) records the wider project community.\n\n",
  "{author_table}\n\n",
  "Question-specific research is maintained in [ngulia-analysis](https://github.com/A-Rocha-Kenya/ngulia-analysis). ",
  "The [Ngulia website](https://a-rocha-kenya.github.io/ngulia-website/) is the public project entry point; ",
  "the [forecast](https://a-rocha-kenya.github.io/ngulia-forcast/) is a separate tool.\n"
)

citation_authors <- if (length(metadata$authors) == 0) {
  list(list(name = "Ngulia Ringing Project contributors"))
} else {
  purrr::map(metadata$authors, \(x) purrr::compact(list(
    `given-names` = x$given_name,
    `family-names` = x$family_name,
    affiliation = x$affiliation,
    orcid = if (!is.null(x$orcid) && nzchar(x$orcid)) paste0("https://orcid.org/", x$orcid)
  )))
}

citation <- purrr::compact(list(
  `cff-version` = "1.2.0",
  message = metadata$repository$citation_message,
  title = metadata$dataset$title,
  type = "software",
  authors = citation_authors,
  url = if (nzchar(metadata$repository$url)) metadata$repository$url
))

writeLines(readme, "README.md")
yaml::write_yaml(citation, "CITATION.cff")

cli::cli_alert_success("Built README.md and CITATION.cff from publication metadata.")
