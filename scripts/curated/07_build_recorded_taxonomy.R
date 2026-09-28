library(cli)
library(dplyr)
library(readr)
library(tidyr)

# Read the reference and recorded observations ----------------------------

source(here::here("scripts/helpers/data_paths.R"))
paths <- get_data_paths()
taxonomy <- read_csv(
  file.path(paths$taxonomy_intermediate_dir, "taxonomy_reference.csv"),
  col_types = cols(.default = col_character())
) |>
  select(-taxon_id)
ring_events <- read_csv(
  file.path(paths$curated_dir, "ring_events.csv"),
  col_select = c(ring_event_id, avibase_id, subspecies_avibase_id, ringing_date, season),
  col_types = cols(.default = col_character(), ringing_date = col_date(), season = col_integer())
)
daily_counts <- read_csv(
  file.path(paths$curated_dir, "daily_counts.csv"),
  col_types = cols(.default = col_character(), ringing_date = col_date(), season = col_integer(), n_records = col_double())
)
recoveries <- read_csv(
  file.path(paths$curated_dir, "recoveries.csv"),
  col_select = c(recovery_id, avibase_id), col_types = cols(.default = col_character())
)

# Summarize exact identifications and their species -----------------------

ring_taxa <- bind_rows(
  ring_events |> select(-subspecies_avibase_id),
  ring_events |> filter(!is.na(subspecies_avibase_id)) |>
    select(-avibase_id) |> rename(avibase_id = subspecies_avibase_id)
) |>
  left_join(taxonomy |> select(avibase_id, species_avibase_id), by = "avibase_id", relationship = "many-to-one")
ring_taxa <- bind_rows(ring_taxa, ring_taxa |> mutate(avibase_id = species_avibase_id)) |>
  filter(!is.na(avibase_id)) |>
  distinct(ring_event_id, avibase_id, .keep_all = TRUE)
ring_stats <- ring_taxa |>
  group_by(avibase_id) |>
  summarise(
    n_ring_events = n(), n_ring_seasons = n_distinct(season),
    first_ring_date = min(ringing_date), last_ring_date = max(ringing_date),
    .groups = "drop"
  )

count_taxa <- daily_counts |>
  mutate(count_row = row_number()) |>
  left_join(taxonomy |> select(avibase_id, species_avibase_id), by = "avibase_id", relationship = "many-to-one")
count_taxa <- bind_rows(count_taxa, count_taxa |> mutate(avibase_id = species_avibase_id)) |>
  filter(!is.na(avibase_id)) |>
  distinct(count_row, avibase_id, .keep_all = TRUE)
count_stats <- count_taxa |>
  group_by(avibase_id) |>
  summarise(
    total_daily_count = sum(n_records), n_count_days = n_distinct(ringing_date),
    n_count_seasons = n_distinct(season), first_count_date = min(ringing_date),
    last_count_date = max(ringing_date), .groups = "drop"
  )

recovery_taxa <- recoveries |>
  left_join(taxonomy |> select(avibase_id, species_avibase_id), by = "avibase_id", relationship = "many-to-one")
recovery_stats <- bind_rows(recovery_taxa, recovery_taxa |> mutate(avibase_id = species_avibase_id)) |>
  filter(!is.na(avibase_id)) |>
  distinct(recovery_id, avibase_id) |>
  count(avibase_id, name = "n_recoveries")

# Publish recorded taxa -----------------------

taxonomy <- taxonomy |>
  left_join(ring_stats, by = "avibase_id") |>
  left_join(count_stats, by = "avibase_id") |>
  left_join(recovery_stats, by = "avibase_id") |>
  mutate(across(c(n_ring_events, n_ring_seasons, total_daily_count, n_count_days, n_count_seasons, n_recoveries), ~ replace_na(.x, 0))) |>
  filter(category != "non_taxon", n_ring_events > 0 | total_daily_count > 0 | n_recoveries > 0) |>
  arrange(desc(total_daily_count), desc(n_ring_events), avibase_id)

write_csv(taxonomy, file.path(paths$curated_dir, "taxonomy.csv"), na = "")
cli_alert_success("Wrote {nrow(taxonomy)} recorded taxa with observation totals.")
