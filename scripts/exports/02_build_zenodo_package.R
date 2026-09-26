library(cli)
library(glue)

source(here::here("scripts/helpers/data_paths.R"))
source(here::here("scripts/helpers/publication_metadata.R"))

# Prepare Zenodo files ----------------------------------------------------

metadata <- read_publication_metadata()
output_dir <- get_data_paths()$zenodo_export_dir
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source_files <- vapply(metadata$files, \(file) {
  here::here(if (!is.null(file$path)) file$path else file.path("data", "04_curated", file$name))
}, character(1))
file_names <- vapply(metadata$files, `[[`, character(1), "name")
other_files <- file_names != "recoveries.csv"
stopifnot(all(file.copy(source_files[other_files], file.path(output_dir, file_names[other_files]), overwrite = TRUE)))

# Publish the interpretable recovery fields; retain source evidence in the curated file.
recovery_columns <- c(
  "avibase_id", "common_name", "ring_scheme", "ring_number", "ringing_age_code",
  "direction", "ringing_date", "encounter_date_edtf", "report_date",
  "other_site", "other_region", "other_country", "other_latitude", "other_longitude",
  "encounter_type", "encounter_condition", "mortality_cause_class", "curation_notes"
)
recoveries <- readr::read_csv(
  source_files[file_names == "recoveries.csv"], show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character(), other_latitude = readr::col_double(), other_longitude = readr::col_double())
)
readr::write_csv(dplyr::select(recoveries, dplyr::all_of(recovery_columns)), file.path(output_dir, "recoveries.csv"), na = "")

# Archive the definitions and limits used for this dataset version --------

data_lines <- readLines(here::here("data/README.md"), warn = FALSE)
limitations_lines <- readLines(here::here("docs/data_limitations.md"), warn = FALSE)
limits <- limitations_lines[match("## Counts and missing dates", limitations_lines):length(limitations_lines)]
limits <- sub("^## ", "### ", limits)
dictionary_lines <- c(
  "# Data dictionary and interpretation",
  "",
  data_lines[match("## Public dataset files", data_lines):(match("## Processing overview", data_lines) - 1L)],
  data_lines[match("### Age codes", data_lines):(match("### Source mapping and processing", data_lines) - 1L)],
  "## Interpretation limits",
  "",
  limits
)
dictionary_lines <- dictionary_lines[!grepl("^Better dated records|^Detailed interpretation limits and analysis assumptions", dictionary_lines)]
dictionary <- paste(dictionary_lines, collapse = "\n")
dictionary <- sub(
  "The first four files have canonical versions in `data/04_curated/`; the Zenodo `recoveries.csv` is a narrower view of its canonical version. The deposit also includes the source-linked operations register from `config/daily_covariates/`.",
  "The four public tables and the source-linked operations register are included in this deposit; the recovery table is a narrower view of the repository's canonical file.",
  dictionary,
  fixed = TRUE
)
dictionary <- gsub("\\[([^]]+)\\]\\((?!https?://|#)[^)]+\\)", "\\1", dictionary, perl = TRUE)
dictionary <- gsub("\n{3,}", "\n\n", dictionary)
dictionary <- sub("\n+$", "", dictionary)
writeLines(dictionary, file.path(output_dir, "DATA_DICTIONARY.md"))

readme <- glue(
  "# Data files\n\n",
  "This archive contains {length(metadata$files)} UTF-8 CSV files with header rows. Empty cells mean a value is unavailable, unresolved, or inapplicable. `DATA_DICTIONARY.md` provides the field definitions, code meanings, and interpretation limits preserved with this dataset version.\n\n",
  "{publication_file_table(metadata$files)}\n\n",
  "## How the tables relate\n\n",
  "- `ring_events.csv` records individual captures. `daily_counts.csv` gives positive species-day totals from DJP summaries for seasons 1969–2014 and from ring events for 2015–2023. The two tables need not have identical daily totals.\n",
  "- `daily_coverage.csv` has one row per date in the season calendar. Join it to `daily_counts.csv` by `ringing_date` and `season`. An absent species row or an empty daily total is not automatically a zero-catch day; use `daily_count_status` and `effort_status` to distinguish recorded zeros, missing counts, and operation evidence. `ringing_happened` reflects a positive catch after targeted swallow and martin catches are excluded.\n",
  "- `operations_history.csv` records dated sources for station operations. `operations_evidence_ids` in `daily_coverage.csv` points to applied evidence; broad historical periods are context rather than daily measurements.\n",
  "- `recoveries.csv` records separately curated movements involving Ngulia and is not keyed to `ring_event_id`.\n\n",
  "`season` names the year in which an October–January season starts. `ringing_date` is the analysis date; captures from 20:00 onward normally belong to the next ringing day, subject to the source workbook's date convention.\n\n",
  "## Documentation\n\n",
  "For the reproducible build, QA, and updated project documentation, see the ",
  "[GitHub repository]({metadata$repository$url}). The archived `DATA_DICTIONARY.md` describes these files without requiring GitHub.\n"
)
writeLines(readme, file.path(output_dir, "README.md"))

unlink(file.path(output_dir, c("upload", "zenodo_form.md", "upload_manifest.csv")), recursive = TRUE)
cli_alert_success("Wrote two documentation files and {length(metadata$files)} CSV files directly to {output_dir}.")
