# Return the project data and configuration directories used across scripts.
get_data_paths <- function(project_dir = here::here()) {
  data_dir <- file.path(project_dir, "data")
  config_dir <- file.path(project_dir, "config")

  raw_dir <- file.path(data_dir, "01_raw")
  reference_dir <- file.path(data_dir, "02_reference")
  intermediate_dir <- file.path(data_dir, "03_intermediate")
  curated_dir <- file.path(data_dir, "04_curated")
  outputs_dir <- file.path(project_dir, "outputs")
  exports_dir <- file.path(project_dir, "exports")

  list(
    reference_dir = reference_dir,
    curated_dir = curated_dir,
    outputs_dir = outputs_dir,
    analysis_output_dir = file.path(outputs_dir, "analysis"),
    exploration_output_dir = file.path(outputs_dir, "exploration"),
    qa_output_dir = file.path(outputs_dir, "qa"),
    publication_output_dir = file.path(outputs_dir, "publications"),
    exports_dir = exports_dir,
    website_export_dir = file.path(exports_dir, "website"),
    zenodo_export_dir = file.path(exports_dir, "zenodo"),
    gbif_export_dir = file.path(exports_dir, "gbif"),
    external_dir = file.path(raw_dir, "external"),
    ring_events_raw_dir = file.path(raw_dir, "ring_events"),
    daily_counts_raw_dir = file.path(raw_dir, "daily_counts"),
    weather_raw_dir = file.path(raw_dir, "weather"),
    ring_events_config_dir = file.path(config_dir, "ring_events"),
    website_config_dir = file.path(config_dir, "website"),
    ring_events_intermediate_dir = file.path(intermediate_dir, "ring_events"),
    daily_counts_intermediate_dir = file.path(intermediate_dir, "daily_counts"),
    weather_intermediate_dir = file.path(intermediate_dir, "weather"),
    daily_context_intermediate_dir = file.path(intermediate_dir, "daily_context"),
    mist_intermediate_dir = file.path(intermediate_dir, "mist_model"),
    taxonomy_intermediate_dir = file.path(intermediate_dir, "taxonomy")
  )
}
