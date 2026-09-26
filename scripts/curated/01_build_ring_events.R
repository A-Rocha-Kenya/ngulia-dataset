library(readxl)
library(dplyr)
library(readr)
library(stringr)
library(lubridate)
library(tidyr)
library(cli)

# Set paths ---------------------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
paths <- get_data_paths(project_dir)

raw_dir <- paths$ring_events_raw_dir
config_dir <- paths$ring_events_config_dir
qa_dir <- file.path(paths$ring_events_intermediate_dir, "qa")
curated_dir <- paths$curated_dir
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(curated_dir, recursive = TRUE, showWarnings = FALSE)
processed_output_path <- file.path(
  curated_dir,
  "ring_events.csv"
)
legacy_moult_output_path <- file.path(
  curated_dir,
  "ring_event_moult.csv"
)
issues_output_path <- file.path(
  qa_dir,
  "ring_events_issues.csv"
)
issues_markdown_output_path <- file.path(
  qa_dir,
  "ring_events_issues.md"
)
file_audit_output_path <- file.path(
  qa_dir,
  "source_file_audit.csv"
)
ringer_lookup_audit_output_path <- file.path(
  qa_dir,
  "ringer_lookup_audit.csv"
)
ringer_unmatched_output_path <- file.path(
  qa_dir,
  "ringer_lookup_unmatched.csv"
)
ring_history_audit_output_path <- file.path(
  qa_dir,
  "ring_history_audit.csv"
)

file_specs_path <- file.path(config_dir, "file_specs.csv")
corrections_path <- file.path(config_dir, "corrections.csv")
ring_number_review_path <- file.path(config_dir, "ring_number_review.csv")
ring_history_review_path <- file.path(config_dir, "ring_history_review.csv")
species_lookup_path <- file.path(config_dir, "species_lookup.csv")
species_reference_path <- file.path(config_dir, "species_reference.csv")
ringer_lookup_path <- file.path(config_dir, "ringer_lookup.csv")
subspecies_lookup_path <- file.path(config_dir, "subspecies_lookup.csv")
measurement_ranges_path <- file.path(config_dir, "measurement_ranges.csv")
moult_specs_path <- file.path(config_dir, "moult_specs.csv")

source(file.path(project_dir, "scripts", "helpers", "ring_event_helpers.R"))

# Read files ------------------------------------------------------------

cli_h1("Build Ngulia ring events")

file_specs <- load_file_specs(file_specs_path)
corrections <- load_corrections(corrections_path)
ring_number_review <- load_ring_number_review(ring_number_review_path)
ring_history_review <- load_ring_history_review(ring_history_review_path)
species_lookup <- load_species_lookup(species_lookup_path)
species_reference <- load_species_reference(species_reference_path)
ringer_lookup <- load_ringer_lookup(ringer_lookup_path)
subspecies_lookup <- load_subspecies_lookup(subspecies_lookup_path)
measurement_ranges <- load_measurement_ranges(measurement_ranges_path)
moult_specs <- load_moult_specs(moult_specs_path)

# Read files ------------------------------------------------------------
raw_data <- list()
cli_alert_info("Reading {nrow(file_specs)} source files")
for (i_file in seq_len(nrow(file_specs))) {
  cli_alert_info(
    "[{i_file}/{nrow(file_specs)}] {file_specs$source_file[i_file]}"
  )
  raw_data[[i_file]] <- read_spec(
    file_specs[i_file, ],
    moult_specs |>
      filter(
        source_file == file_specs$source_file[i_file],
        source_sheet == file_specs$source_sheet[i_file]
      )
  )
}
raw_data <- bind_rows(raw_data)

# Correct data ------------------------------------------------------------
corrected_data <- apply_corrections(raw_data, corrections) |>
  apply_ring_number_review(ring_number_review) |>
  apply_ring_history_review(ring_history_review)

# Process data ------------------------------------------------------------
results <- process_ring_records(
  corrected_data,
  species_lookup,
  measurement_ranges,
  ringer_lookup,
  issues_output_path = issues_output_path,
  file_audit_output_path = file_audit_output_path,
  ringer_lookup_audit_output_path = ringer_lookup_audit_output_path,
  ringer_unmatched_output_path = ringer_unmatched_output_path,
  ring_history_audit_output_path = ring_history_audit_output_path,
  issues_markdown_output_path = issues_markdown_output_path,
  file_specs = file_specs,
  raw_dir = raw_dir
)
processed <- results$ring_events
moult <- results$moult

# Add species and subspecies information ----------------------------------
processed <- add_taxonomy(
  processed,
  species_reference,
  subspecies_lookup
) |>
  select(
    ring_event_id,
    season,
    ringing_date,
    datetime,
    ringNumber,
    ringer_name,
    retrap,
    afring_number,
    avibase_id,
    subspecies_avibase_id,
    common_name,
    species_code,
    age,
    sex,
    wing,
    weight,
    fat_ngulia,
    fat_kaiser,
    ring_note
  ) |>
  rename(ring_number = ringNumber)

moult <- moult |>
  rename_with(str_to_lower, matches("^(P|S|T|Tail)\\d+$"))

# Export data -------------------------------------------------------------
processed <- processed |>
  left_join(moult, by = "ring_event_id", relationship = "one-to-one")

write_csv(processed, processed_output_path, na = "")
cli_alert_success("Wrote {nrow(processed)} rows to {processed_output_path}")

if (file.exists(legacy_moult_output_path)) {
  unlink(legacy_moult_output_path)
  cli_alert_info("Removed legacy output {legacy_moult_output_path}")
}
