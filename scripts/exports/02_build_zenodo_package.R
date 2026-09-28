library(cli)
library(glue)

source(here::here("scripts/helpers/data_paths.R"))
source(here::here("scripts/helpers/publication_metadata.R"))

# Prepare Zenodo files ----------------------------------------------------

metadata <- read_publication_metadata()
output_dir <- get_data_paths()$zenodo_export_dir
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(output_dir, "operations_history.csv"))

source_files <- vapply(metadata$files, \(file) {
  here::here(if (!is.null(file$path)) file$path else file.path("data", "04_curated", file$name))
}, character(1))
file_names <- vapply(metadata$files, `[[`, character(1), "name")
other_files <- !file_names %in% c("recoveries.csv", "daily_coverage.csv")
stopifnot(all(file.copy(source_files[other_files], file.path(output_dir, file_names[other_files]), overwrite = TRUE)))

ring_events_path <- file.path(output_dir, "ring_events.csv")
ring_events <- readr::read_csv(
  ring_events_path, show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
if ("recorded_ring_number" %in% names(ring_events)) {
  readr::write_csv(dplyr::select(ring_events, -recorded_ring_number), ring_events_path, na = "")
}

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

# Publish daily covariates; retain counts and source evidence internally ----

daily_coverage <- readr::read_csv(
  source_files[file_names == "daily_coverage.csv"], show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
) |>
  dplyr::transmute(
    ringing_date, season, season_day,
    count_status = dplyr::recode(daily_count_status,
      positive_count_recorded = "recorded_positive", zero_after_swallow_exclusion = "recorded_positive",
      zero_in_daily_summary = "recorded_zero", missing = "missing"),
    net_sites_observed,
    night_nets_operated = night_net_operation,
    dawn_nets_operated = dawn_net_operation,
    nocturnal_playback_used = playback_nocturnal_observed,
    mist_observed = dplyr::recode(mist_observation,
      light_patchy = "present_light_patchy", good = "present_sustained"),
    rain_observed = dplyr::recode(rain_observed,
      showers = "present_showers", heavy_rain = "present_heavy", rain_unspecified = "present_unspecified"),
    mist_modeled_none = mist_probability_none,
    mist_modeled_light_patchy = mist_probability_light_patchy,
    mist_modeled_sustained = mist_probability_good,
    djp_team_size = djp_team_size_minimum,
    moon_days_from_new_moon, moon_illumination_fraction,
    era5_total_cloud_cover_mean = total_cloud_cover_mean,
    era5_cloud_base_height_mean_m = cloud_base_height_mean_m,
    era5_total_precipitation_00_08_mm = total_precipitation_00_08_mm,
    era5_wind_u_10m_mean_ms = wind_u_10m_mean_ms,
    era5_wind_v_10m_mean_ms = wind_v_10m_mean_ms,
    era5_wind_speed_10m_mean_ms = wind_speed_10m_mean_ms,
    era5_temperature_2m_mean_c = temperature_2m_mean_c,
    era5_relative_humidity_mean_pct = relative_humidity_mean_pct,
    era5_surface_pressure_mean_hpa = surface_pressure_mean_hpa
  )
readr::write_csv(daily_coverage, file.path(output_dir, "daily_coverage.csv"), na = "")

# Archive the public field definitions used for this dataset version -------

data_lines <- readLines(here::here("data/README.md"), warn = FALSE)
dictionary_lines <- c(
  "# Data dictionary",
  "",
  "Field definitions for the five CSV files in this archive. The companion `README.md` explains how the tables join and how to interpret count coverage.",
  "",
  "## Tables",
  "",
  data_lines[match("### `taxonomy.csv`", data_lines):(match("### `operations_history.csv`", data_lines) - 1L)],
  "## Ring-event codes",
  "",
  data_lines[match("### Age codes", data_lines):(match("### Source mapping and processing", data_lines) - 1L)]
)
dictionary <- paste(dictionary_lines, collapse = "\n")
dictionary <- gsub("\\[([^]]+)\\]\\((?!https?://|#)[^)]+\\)", "\\1", dictionary, perl = TRUE)
dictionary <- gsub("\n{3,}", "\n\n", dictionary)
dictionary <- sub("\n+$", "", dictionary)
writeLines(dictionary, file.path(output_dir, "DATA_DICTIONARY.md"))

readme <- glue(
  "# Data files\n\n",
  "This archive contains {length(metadata$files)} UTF-8 CSV files with header rows. Empty cells mean a value is unavailable, unresolved, or inapplicable. `DATA_DICTIONARY.md` defines the fields and codes in this dataset version.\n\n",
  "{publication_file_table(metadata$files)}\n\n",
  "## How the tables relate\n\n",
  "- `taxonomy.csv` has one row per `avibase_id`. Join `ring_events.csv`, `daily_counts.csv`, and `recoveries.csv` by `avibase_id`; join an explicitly resolved ring-event subspecies through `subspecies_avibase_id` to the same table. Common names remain in the observation files for readability. eBird codes, classification, and source-specific observation totals are held in `taxonomy.csv`. Only recorded taxa are included; species totals include identified subspecies, so totals across taxonomy rows are not additive.\n",
  "- `ring_events.csv` records individual captures. `daily_counts.csv` gives positive species-day totals from DJP summaries for seasons 1969–2014 and from ring events for 2015–2023. The two tables need not have identical daily totals.\n",
  "- `daily_coverage.csv` has one row per date in the season calendar and contains daily covariates rather than bird totals. Calculate counts from `daily_counts.csv` and join by `ringing_date` and `season`. When no species rows exist, `count_status` distinguishes `recorded_zero` from `missing`; `recorded_positive` includes swallow-only catches. Neither status nor a calendar row proves that nets operated.\n",
  "- Daily netting, playback, and weather observations reconcile DJP metadata with dated reviewed sources. Source codes, evidence identifiers, and diagnostic fields remain in the richer internal table and the project repository. `mist_modeled_*` values are probabilities constrained by observed mist.\n",
  "- `recoveries.csv` records separately curated movements involving Ngulia and is not keyed to `ring_event_id`.\n\n",
  "`season` names the year in which an October–January season starts. `ringing_date` is the analysis date; captures from 20:00 onward normally belong to the next ringing day, subject to the source workbook's date convention.\n\n",
  "Recorded catch reflects both bird passage and changing capture conditions. The recovery table is a curated set of known movements, not a complete detection history. Interpret blank dates and modeled weather using the field definitions before comparing seasons.\n\n",
  "## Documentation\n\n",
  "For the reproducible build, QA, and updated project documentation, see the ",
  "[GitHub repository]({metadata$repository$url}). The archived `DATA_DICTIONARY.md` describes these files without requiring GitHub.\n"
)
writeLines(readme, file.path(output_dir, "README.md"))

unlink(file.path(output_dir, c("upload", "zenodo_form.md", "upload_manifest.csv")), recursive = TRUE)
cli_alert_success("Wrote two documentation files and {length(metadata$files)} CSV files directly to {output_dir}.")
