# Extract Ngulia-relevant GeoLocator trajectories --------------------------

library(dplyr)
library(readr)

source_dir <- Sys.getenv("NGULIA_GEOLOCATOR_DIR", unset = here::here("data", "01_raw", "external", "geolocator"))
output_dir <- here::here("data", "03_intermediate", "geolocator_paths")
crosswalk_path <- here::here("config", "taxonomy", "ngulia_taxonomy_crosswalk.csv")

# This bounding box covers Kenya, Ethiopia and their immediate migration corridor.
east_africa <- c(west = 32, east = 48, south = -5, north = 16)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

paths <- read_csv(file.path(source_dir, "paths.csv"), show_col_types = FALSE)
tags <- read_csv(file.path(source_dir, "tags.csv"), show_col_types = FALSE)
packages <- read_csv(file.path(source_dir, "datapackages.csv"), show_col_types = FALSE)
staps <- read_csv(file.path(source_dir, "staps.csv"), show_col_types = FALSE)
crosswalk <- read_csv(crosswalk_path, show_col_types = FALSE)

all_paths <- paths |>
  filter(type == "most_likely") |>
  inner_join(tags |> select(tag_id, scientific_name, datapackage_id), by = "tag_id")

selected_projects <- all_paths |>
  filter(
    !is.na(lat), !is.na(lon),
    between(lon, east_africa[["west"]], east_africa[["east"]]),
    between(lat, east_africa[["south"]], east_africa[["north"]])
  ) |>
  distinct(scientific_name, datapackage_id) |>
  inner_join(
    crosswalk |>
      filter(include_processing, include_recovery) |>
      distinct(avilist_scientific_name) |>
      rename(scientific_name = avilist_scientific_name),
    by = "scientific_name"
  )

ngulia_paths <- all_paths |>
  inner_join(selected_projects, by = c("scientific_name", "datapackage_id")) |>
  left_join(staps |> select(tag_id, stap_id, start, end), by = c("tag_id", "stap_id")) |>
  mutate(
    stopover_days = as.numeric(difftime(as.POSIXct(end, tz = "UTC"), as.POSIXct(start, tz = "UTC"), units = "days"))
  ) |>
  left_join(
    packages |> select(datapackage_id, access_status, embargo, title),
    by = "datapackage_id"
  ) |>
  arrange(scientific_name, datapackage_id, tag_id, stap_id)

write_csv(ngulia_paths, file.path(output_dir, "ngulia_most_likely_paths.csv"))

ngulia_paths |>
  group_by(scientific_name) |>
  group_walk(~ write_csv(.x, file.path(output_dir, paste0(gsub(" ", "_", .y$scientific_name), ".csv"))))

ngulia_paths |>
  distinct(scientific_name, datapackage_id, access_status, embargo, title, tag_id) |>
  count(scientific_name, datapackage_id, access_status, embargo, title, name = "n_tags") |>
  arrange(scientific_name, datapackage_id) |>
  write_csv(file.path(output_dir, "dataset_inventory.csv"))

selected_projects |>
  left_join(
    all_paths |>
      filter(
        !is.na(lat), !is.na(lon),
        between(lon, east_africa[["west"]], east_africa[["east"]]),
        between(lat, east_africa[["south"]], east_africa[["north"]])
      ) |>
      distinct(scientific_name, datapackage_id, tag_id) |>
      count(scientific_name, datapackage_id, name = "n_tags_in_east_africa"),
    by = c("scientific_name", "datapackage_id")
  ) |>
  arrange(scientific_name, datapackage_id) |>
  write_csv(file.path(output_dir, "selection_audit.csv"))
