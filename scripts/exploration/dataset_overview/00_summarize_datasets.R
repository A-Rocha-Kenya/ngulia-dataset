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

curated_dir <- paths$curated_dir
summary_dir <- file.path(paths$exploration_output_dir, "dataset_overview", "tables")

ring_events_path <- file.path(curated_dir, "ring_events.csv")
daily_counts_path <- file.path(curated_dir, "daily_counts.csv")
summary_by_species_path <- file.path(
  summary_dir,
  "ring_events_by_species.csv"
)
summary_by_season_path <- file.path(
  summary_dir,
  "ring_events_by_season.csv"
)
summary_by_day_path <- file.path(
  summary_dir,
  "ring_events_by_day.csv"
)
species_by_season_wide_path <- file.path(
  summary_dir,
  "ring_events_species_by_season_wide.csv"
)
daily_counts_by_season_path <- file.path(
  summary_dir,
  "daily_counts_by_season.csv"
)

dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(project_dir, "scripts", "helpers", "ring_event_helpers.R"))

order_by_existing <- function(data, columns) {
  present_columns <- intersect(columns, names(data))
  if (length(present_columns) == 0) {
    return(data)
  }
  arrange(data, across(all_of(present_columns)))
}

# Read data ---------------------------------------------------------------

cli_h1("Summarize Ngulia datasets")

ring_events <- read_csv(
  ring_events_path,
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
) |>
  rename(ringNumber = ring_number) |>
  mutate(
    ringing_date = as.Date(ringing_date),
    season = assign_season_from_date(ringing_date)
  )

taxonomy <- read_csv(file.path(curated_dir, "taxonomy.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
ring_events <- ring_events |>
  left_join(taxonomy |> select(avibase_id, scientific_name, species_code, category), by = "avibase_id", relationship = "many-to-one")

# Summarize by species ----------------------------------------------------

species_counts_by_season <- ring_events |>
  count(avibase_id, season, name = "season_count")

summary_by_species <- ring_events |>
  select(
    avibase_id,
    any_of(c("scientific_name", "common_name", "species_code", "category"))
  ) |>
  distinct() |>
  left_join(
    species_counts_by_season |>
      group_by(avibase_id) |>
      summarise(
        n_records = sum(season_count),
        first_season = min(season),
        last_season = max(season),
        n_seasons_present = n(),
        mean_records_per_season = mean(season_count),
        min_season_count = min(season_count),
        max_season_count = max(season_count),
        .groups = "drop"
      ),
    by = "avibase_id"
  ) |>
  mutate(pct_of_all_records = n_records / nrow(ring_events)) |>
  arrange(desc(n_records), common_name)

species_by_season_wide <- species_counts_by_season |>
  left_join(
    ring_events |>
      select(
        avibase_id,
        any_of(c("scientific_name", "common_name"))
      ) |>
      distinct(),
    by = "avibase_id"
  ) |>
  select(
    avibase_id,
    any_of(c("scientific_name", "common_name")),
    season,
    season_count
  ) |>
  pivot_wider(
    names_from = season,
    names_prefix = "season_",
    names_sort = TRUE,
    values_from = season_count,
    values_fill = 0
  ) |>
  order_by_existing(c("common_name", "scientific_name", "avibase_id"))

# Summarize by season -----------------------------------------------------

summary_by_season <- ring_events |>
  group_by(season) |>
  summarise(
    n_species = n_distinct(avibase_id),
    first_date = min(ringing_date, na.rm = TRUE),
    last_date = max(ringing_date, na.rm = TRUE),
    n_records = n(),
    n_unique_ring_numbers = n_distinct(ringNumber),
    pct_unique_ring_numbers = n_unique_ring_numbers / n_records,
    .groups = "drop"
  ) |>
  select(
    season,
    n_species,
    first_date,
    last_date,
    n_records,
    n_unique_ring_numbers,
    pct_unique_ring_numbers
  ) |>
  arrange(season)

# Summarize by day --------------------------------------------------------

summary_by_day <- ring_events |>
  mutate(
    season = assign_season_from_date(ringing_date)
  ) |>
  group_by(season, ringing_date, avibase_id) |>
  summarise(
    n_records = n(),
    n_unique_ring_numbers = n_distinct(ringNumber),
    .groups = "drop"
  ) |>
  arrange(ringing_date, avibase_id)

# Daily count summaries ---------------------------------------------------

daily_counts_by_season <- read_csv(
  daily_counts_path,
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
) |>
  rename(date = ringing_date) |>
  mutate(
    season = as.integer(season),
    n_records = as.integer(n_records)
  ) |>
  group_by(season) |>
  summarise(
    n_species = n_distinct(avibase_id),
    first_date = min(date),
    last_date = max(date),
    n_records = sum(n_records),
    .groups = "drop"
  ) |>
  arrange(season)

# Write outputs -----------------------------------------------------------

write_csv(summary_by_species, summary_by_species_path, na = "")
write_csv(summary_by_season, summary_by_season_path, na = "")
write_csv(summary_by_day, summary_by_day_path, na = "")
write_csv(species_by_season_wide, species_by_season_wide_path, na = "")
write_csv(daily_counts_by_season, daily_counts_by_season_path, na = "")

cli_alert_success(
  "Wrote {nrow(summary_by_species)} species rows to {summary_by_species_path}"
)
cli_alert_success(
  "Wrote {nrow(summary_by_season)} season rows to {summary_by_season_path}"
)
cli_alert_success(
  "Wrote {nrow(summary_by_day)} day rows to {summary_by_day_path}"
)
cli_alert_success(
  "Wrote {nrow(species_by_season_wide)} species rows to {species_by_season_wide_path}"
)
cli_alert_success(
  "Wrote {nrow(daily_counts_by_season)} daily-count season rows to {daily_counts_by_season_path}"
)
