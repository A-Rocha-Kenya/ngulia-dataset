library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(cli)

# Set paths ---------------------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "plot_style.R"))
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
paths <- get_data_paths(project_dir)

config_dir <- paths$ring_events_config_dir
summary_dir <- file.path(paths$exploration_output_dir, "dataset_overview", "tables")
daily_counts_dir <- paths$daily_counts_intermediate_dir
qa_dir <- file.path(daily_counts_dir, "qa")
figure_dir <- ngulia_figure_dir(file.path(paths$qa_output_dir, "daily_counts", "figures"))
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(project_dir, "scripts", "helpers", "ring_event_helpers.R"))

ring_summary_path <- file.path(
  summary_dir,
  "ring_events_by_day.csv"
)
djp_summary_path <- file.path(
  daily_counts_dir,
  "djp_daily_counts.csv"
)
species_reference_path <- file.path(
  config_dir,
  "species_reference.csv"
)
comparison_output_path <- file.path(
  qa_dir,
  "overlap_difference_matrix.csv"
)
day_comparison_output_path <- file.path(
  qa_dir,
  "daily_count_source_comparison_by_day.csv"
)
matrix_output_path <- file.path(
  figure_dir,
  "daily_count_source_season_matrix.pdf"
)

# Read data ---------------------------------------------------------------

cli_h1("Compare daily count sources")

species_reference <- load_species_reference(species_reference_path) |>
  select(afring_number, avibase_id)
taxonomy <- read_csv(
  file.path(paths$taxonomy_intermediate_dir, "taxonomy_reference.csv"),
  show_col_types = FALSE, col_types = cols(.default = col_character())
)
ring_summary <- read_csv(ring_summary_path, show_col_types = FALSE) |>
  transmute(date = ringing_date, avibase_id, ring_n_records = n_records)
djp_summary <- read_csv(djp_summary_path, show_col_types = FALSE) |>
  mutate(afring_number = clean_signed_number_key(as.character(afring_number))) |>
  left_join(species_reference, by = "afring_number") |>
  transmute(date, avibase_id, djp_n_records = n_records)

# Build overlap comparison ------------------------------------------------

overlap_start <- max(min(ring_summary$date), min(djp_summary$date))
overlap_end <- min(max(ring_summary$date), max(djp_summary$date))

ring_overlap <- ring_summary |>
  filter(date >= overlap_start, date <= overlap_end) |>
  group_by(date, avibase_id) |>
  summarise(ring_n_records = sum(ring_n_records), .groups = "drop")

djp_overlap <- djp_summary |>
  filter(date >= overlap_start, date <= overlap_end) |>
  group_by(date, avibase_id) |>
  summarise(djp_n_records = sum(djp_n_records), .groups = "drop")

comparison <- full_join(
  ring_overlap,
  djp_overlap,
  by = c("date", "avibase_id")
) |>
  mutate(
    ring_n_records = coalesce(ring_n_records, 0),
    djp_n_records = coalesce(djp_n_records, 0),
    diff_n_records = ring_n_records - djp_n_records,
    abs_diff_n_records = abs(diff_n_records)
  ) |>
  left_join(taxonomy |> select(avibase_id, common_name, scientific_name), by = "avibase_id") |>
  mutate(
    species = coalesce(common_name, scientific_name, "Unknown species"),
    agreement = case_when(
      ring_n_records == djp_n_records ~ "exact",
      ring_n_records == 0 ~ "only_djp",
      djp_n_records == 0 ~ "only_ring",
      TRUE ~ "different"
    )
  ) |>
  arrange(date, desc(abs_diff_n_records), avibase_id)

comparison_export <- comparison |>
  select(date, species, diff_n_records) |>
  group_by(date, species) |>
  summarise(diff_n_records = sum(diff_n_records), .groups = "drop") |>
  arrange(date, species) |>
  pivot_wider(
    names_from = species,
    values_from = diff_n_records,
    values_fill = 0
  ) |>
  mutate(date = as.character(date)) |>
  arrange(date)

day_comparison <- full_join(
  ring_summary |>
    group_by(date) |>
    summarise(ring_n_records = sum(ring_n_records), .groups = "drop"),
  djp_summary |>
    group_by(date) |>
    summarise(djp_n_records = sum(djp_n_records), .groups = "drop"),
  by = "date"
) |>
  mutate(
    ring_n_records = coalesce(ring_n_records, 0),
    djp_n_records = coalesce(djp_n_records, 0)
  ) |>
  summarise(
    min_date = min(date, na.rm = TRUE),
    max_date = max(date, na.rm = TRUE)
  ) |>
  transmute(date = list(seq(min_date, max_date, by = "1 day"))) |>
  unnest(date) |>
  left_join(
    ring_summary |>
      group_by(date) |>
      summarise(ring_n_records = sum(ring_n_records), .groups = "drop"),
    by = "date"
  ) |>
  left_join(
    djp_summary |>
      group_by(date) |>
      summarise(djp_n_records = sum(djp_n_records), .groups = "drop"),
    by = "date"
  ) |>
  mutate(
    ring_n_records = coalesce(ring_n_records, 0),
    djp_n_records = coalesce(djp_n_records, 0),
    diff_n_records = ring_n_records - djp_n_records,
    season = assign_season_from_date(date),
    season_day = as.integer(date - make_date(season, 6L, 1L)) + 1L,
    source_state = case_when(
      ring_n_records > 0 & djp_n_records > 0 & diff_n_records == 0 ~ "both positive, equal",
      ring_n_records > 0 & djp_n_records > 0 & diff_n_records > 0 ~ "both positive, ring_events higher",
      ring_n_records > 0 & djp_n_records > 0 & diff_n_records < 0 ~ "both positive, DJP higher",
      ring_n_records > 0 ~ "ring_events only",
      djp_n_records > 0 ~ "DJP only",
      TRUE ~ "neither positive"
    )
  ) |>
  arrange(date)

season_month_breaks <- tibble(
  month_start = seq(as.Date("2000-06-01"), as.Date("2001-05-01"), by = "1 month")
) |>
  mutate(
    season_day = as.integer(month_start - as.Date("2000-06-01")) + 1L,
    month_label = format(month_start, "%b")
  )

season_day_window <- day_comparison |>
  filter(source_state != "neither positive") |>
  summarise(
    min_season_day = min(season_day),
    max_season_day = max(season_day)
  )

season_month_breaks <- season_month_breaks |>
  filter(
    season_day >= season_day_window$min_season_day,
    season_day <= season_day_window$max_season_day
  )

season_day_labels <- tibble(
  season_day = seq(season_day_window$min_season_day, season_day_window$max_season_day),
  label_date = as.Date("2000-06-01") + season_day - 1L,
  day_label = format(label_date, "%d")
)

day_comparison <- day_comparison |>
  mutate(
    source_state = factor(
      source_state,
      levels = c(
        "neither positive",
        "ring_events only",
        "DJP only",
        "both positive, equal",
        "both positive, ring_events higher",
        "both positive, DJP higher"
      )
    )
  )

day_comparison_plot <- day_comparison |>
  filter(
    season_day >= season_day_window$min_season_day,
    season_day <= season_day_window$max_season_day
  )

matrix_plot <- ggplot(
  day_comparison_plot,
  aes(x = season_day, y = factor(season), fill = source_state)
) +
  geom_tile(width = 0.98, height = 0.98, color = "#d9d9d9", linewidth = 0.15) +
  scale_x_continuous(
    breaks = season_day_labels$season_day,
    labels = season_day_labels$day_label,
    expand = c(0, 0)
  ) +
  scale_fill_manual(
    values = c(
      "neither positive" = "#f1f1f1",
      "ring_events only" = "#5b8ff9",
      "DJP only" = "#f39c34",
      "both positive, equal" = "#1b9e77",
      "both positive, ring_events higher" = "#225ea8",
      "both positive, DJP higher" = "#d95f0e"
    ),
    drop = FALSE
  ) +
  labs(
    title = "Daily ringing totals from ring_events and DJP by season day",
    subtitle = "Each tile is one date in June-May season order. Colors show whether neither, either, or both sources are above zero and which source is higher when they disagree.",
    x = "Day within season (day of month; October to January window)",
    y = "Season",
    fill = "Daily source state"
  ) +
  ngulia_theme(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6),
    legend.position = "bottom"
  )

write_csv(comparison_export, comparison_output_path, na = "")
write_csv(day_comparison, day_comparison_output_path, na = "")
ggsave(matrix_output_path, matrix_plot, width = 13, height = 11)

cli_alert_success("Wrote {nrow(comparison_export)} day rows to {comparison_output_path}")
cli_alert_success("Wrote {nrow(day_comparison)} day rows to {day_comparison_output_path}")
cli_alert_success("Wrote source comparison matrix to {matrix_output_path}")
