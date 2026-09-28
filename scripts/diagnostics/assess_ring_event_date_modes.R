library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(cli)

# Set paths ---------------------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
paths <- get_data_paths(project_dir)

raw_dir <- paths$ring_events_raw_dir
config_dir <- paths$ring_events_config_dir
qa_dir <- file.path(paths$ring_events_intermediate_dir, "qa")
daily_counts_dir <- paths$daily_counts_intermediate_dir
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

file_summary_output_path <- file.path(
  qa_dir,
  "ring_event_date_mode_file_summary.csv"
)
transition_output_path <- file.path(
  qa_dir,
  "ring_event_date_mode_transition_examples.csv"
)
comparison_output_path <- file.path(
  qa_dir,
  "ring_event_date_mode_species_day_comparison.csv"
)

file_specs_path <- file.path(config_dir, "file_specs.csv")
corrections_path <- file.path(config_dir, "corrections.csv")
species_lookup_path <- file.path(config_dir, "species_lookup.csv")
measurement_ranges_path <- file.path(config_dir, "measurement_ranges.csv")
moult_specs_path <- file.path(config_dir, "moult_specs.csv")
djp_daily_counts_path <- file.path(daily_counts_dir, "djp_daily_counts.csv")
taxonomy_path <- file.path(paths$taxonomy_intermediate_dir, "taxonomy_reference.csv")

source(file.path(project_dir, "scripts", "helpers", "ring_event_helpers.R"))

build_candidate_counts <- function(data, date_col) {
  data |>
    mutate(candidate_date = as.Date(.data[[date_col]])) |>
    filter(clean_required, !is.na(candidate_date), !is.na(afring_number)) |>
    transmute(
      source_file,
      source_sheet,
      date = candidate_date,
      afring_number = as.character(afring_number)
    ) |>
    count(source_file, source_sheet, date, afring_number, name = "ring_n")
}

compare_with_djp <- function(candidate_counts, djp_counts) {
  full_join(
    candidate_counts,
    djp_counts,
    by = c("source_file", "source_sheet", "date", "afring_number")
  ) |>
    mutate(
      common_name = common_name,
      ring_n = coalesce(ring_n, 0L),
      djp_n = coalesce(djp_n, 0L),
      abs_diff = abs(ring_n - djp_n)
    ) |>
    select(
      source_file,
      source_sheet,
      date,
      afring_number,
      common_name,
      ring_n,
      djp_n,
      abs_diff
    )
}

classify_mode <- function(within_date_wrap_n, across_date_wrap_n, current_abs_diff, raw_abs_diff) {
  if (!is.na(current_abs_diff) && !is.na(raw_abs_diff) && current_abs_diff != raw_abs_diff) {
    return(if_else(raw_abs_diff < current_abs_diff, "use_raw_date", "shift_ringing_date"))
  }

  if (within_date_wrap_n > 0L && across_date_wrap_n == 0L) {
    return("use_raw_date")
  }

  if (across_date_wrap_n > 0L && within_date_wrap_n == 0L) {
    return("shift_ringing_date")
  }

  "unclear"
}

# Load inputs -------------------------------------------------------------

cli_h1("Assess ring-event date modes")

file_specs <- load_file_specs(file_specs_path)
corrections <- load_corrections(corrections_path)
species_lookup <- load_species_lookup(species_lookup_path)
measurement_ranges <- load_measurement_ranges(measurement_ranges_path)
moult_specs <- load_moult_specs(moult_specs_path)

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
corrected_data <- apply_corrections(raw_data, corrections)
cleaned <- clean_data(corrected_data, species_lookup, measurement_ranges) |>
  mutate(
    parsed_hour = suppressWarnings(as.integer(str_sub(parsed_time, 1, 2))),
    datetime_date = as.Date(datetime),
    ringing_date_shifted = assign_daily_count_date(datetime),
    ringing_date_raw = parsed_date,
    datetime_corrected_if_raw = if_else(
      !is.na(datetime) & !is.na(parsed_hour) & parsed_hour >= 20L,
      datetime - days(1),
      datetime
    )
  )

djp_daily_counts <- read_csv(
  djp_daily_counts_path,
  show_col_types = FALSE
) |>
  mutate(
    date = as.Date(date),
    afring_number = as.character(afring_number),
    season = assign_season_from_date(date)
  )

taxonomy <- read_csv(
  taxonomy_path,
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
)

file_seasons <- cleaned |>
  filter(!is.na(parsed_date)) |>
  transmute(
    source_file,
    source_sheet,
    season = assign_season_from_date(parsed_date)
  ) |>
  distinct()

names_map <- load_species_reference(file.path(config_dir, "species_reference.csv")) |>
  select(afring_number, avibase_id) |>
  left_join(taxonomy |> select(avibase_id, common_name), by = "avibase_id") |>
  select(afring_number, common_name)

djp_with_file <- file_seasons |>
  inner_join(djp_daily_counts, by = "season", relationship = "many-to-many") |>
  left_join(names_map, by = "afring_number") |>
  transmute(
    source_file,
    source_sheet,
    date,
    afring_number,
    common_name,
    djp_n = as.integer(n_records)
  )

# Row-order diagnostics ---------------------------------------------------

row_order <- cleaned |>
  filter(!is.na(parsed_date), !is.na(parsed_hour)) |>
  arrange(source_file, source_sheet, source_row) |>
  group_by(source_file, source_sheet) |>
  mutate(
    prev_source_row = lag(source_row),
    prev_parsed_date = lag(parsed_date),
    prev_parsed_hour = lag(parsed_hour),
    same_date_wrap = !is.na(prev_parsed_date) &
      parsed_date == prev_parsed_date &
      !is.na(prev_parsed_hour) &
      prev_parsed_hour >= 18L &
      parsed_hour <= 8L,
    across_date_wrap = !is.na(prev_parsed_date) &
      parsed_date == prev_parsed_date + 1 &
      !is.na(prev_parsed_hour) &
      prev_parsed_hour >= 18L &
      parsed_hour <= 8L
  ) |>
  ungroup()

transition_examples <- bind_rows(
  row_order |>
    filter(same_date_wrap) |>
    mutate(wrap_type = "same_date_wrap"),
  row_order |>
    filter(across_date_wrap) |>
    mutate(wrap_type = "across_date_wrap")
) |>
  select(
    source_file,
    source_sheet,
    wrap_type,
    prev_source_row,
    source_row,
    prev_parsed_date,
    parsed_date,
    prev_parsed_hour,
    parsed_hour,
    ringNumber,
    afring_number
  )

# Candidate comparisons ---------------------------------------------------

counts_shifted <- build_candidate_counts(cleaned, "ringing_date_shifted")
counts_raw <- build_candidate_counts(cleaned, "ringing_date_raw")

comparison_shifted <- compare_with_djp(counts_shifted, djp_with_file) |>
  mutate(candidate_mode = "shift_ringing_date")
comparison_raw <- compare_with_djp(counts_raw, djp_with_file) |>
  mutate(candidate_mode = "use_raw_date")

comparison_all <- bind_rows(comparison_shifted, comparison_raw) |>
  arrange(source_file, source_sheet, candidate_mode, date, desc(abs_diff), common_name)

all_files <- cleaned |>
  distinct(source_file, source_sheet)

file_summary <- all_files |>
  left_join(
    row_order |>
  group_by(source_file, source_sheet) |>
  summarise(
    n_rows = n(),
    n_timed_rows = sum(!is.na(parsed_hour)),
    within_date_wrap_n = sum(same_date_wrap, na.rm = TRUE),
    across_date_wrap_n = sum(across_date_wrap, na.rm = TRUE),
    .groups = "drop"
  ),
    by = c("source_file", "source_sheet")
  ) |>
  left_join(
    comparison_all |>
      group_by(source_file, source_sheet, candidate_mode) |>
      summarise(
        compared_species_days = n(),
        compared_dates = n_distinct(date),
        total_abs_diff = sum(abs_diff),
        max_abs_diff = max(abs_diff),
        .groups = "drop"
      ) |>
      mutate(
        metric_name = case_when(
          candidate_mode == "shift_ringing_date" ~ "shift",
          TRUE ~ "raw"
        )
      ) |>
      select(-candidate_mode) |>
      pivot_wider(
        names_from = metric_name,
        values_from = c(compared_species_days, compared_dates, total_abs_diff, max_abs_diff),
        names_glue = "{.value}_{metric_name}"
      ),
    by = c("source_file", "source_sheet")
  ) |>
  mutate(
    across(c(n_rows, n_timed_rows, within_date_wrap_n, across_date_wrap_n), ~ coalesce(.x, 0)),
    preferred_mode = purrr::pmap_chr(
      list(within_date_wrap_n, across_date_wrap_n, total_abs_diff_shift, total_abs_diff_raw),
      classify_mode
    ),
    abs_diff_improvement_raw_minus_shift = total_abs_diff_raw - total_abs_diff_shift
  ) |>
  arrange(source_file, source_sheet)

# Export ------------------------------------------------------------------

write_csv(file_summary, file_summary_output_path, na = "")
write_csv(transition_examples, transition_output_path, na = "")
write_csv(comparison_all, comparison_output_path, na = "")

cli_alert_success("Wrote {nrow(file_summary)} file summaries to {file_summary_output_path}")
cli_alert_success("Wrote {nrow(transition_examples)} transition examples to {transition_output_path}")
cli_alert_success("Wrote {nrow(comparison_all)} comparison rows to {comparison_output_path}")
