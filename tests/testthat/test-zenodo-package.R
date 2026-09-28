source(here::here("scripts/helpers/data_paths.R"))
source(here::here("scripts/helpers/publication_metadata.R"))

metadata <- read_publication_metadata()
paths <- get_data_paths()
zenodo_dir <- paths$zenodo_export_dir
tables <- setNames(lapply(zenodo_files, function(file) read_zenodo_csv(file.path(zenodo_dir, file))), zenodo_files)
excluded_ids <- read_zenodo_csv(here::here("config/daily_counts/targeted_capture_groups.csv"))$avibase_id
table_issues <- setNames(lapply(zenodo_files, function(file) validate_zenodo_table(tables[[file]], file)), zenodo_files)
structural_issues <- bind_rows(table_issues) |>
  filter(rule %in% c("column_schema", "required") | startsWith(rule, "type_"))
relation_issues <- if (nrow(structural_issues)) bind_rows(table_issues)[0, ] else
  validate_zenodo_relations(tables, excluded_ids, ring_seasons = 2015:2023)
qa_dir <- file.path(paths$qa_output_dir, "zenodo")
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(bind_rows(c(table_issues, list(relation_issues))), file.path(qa_dir, "violations.csv"), na = "")

test_that("the package has exactly the declared resources and documentation", {
  declared <- vapply(metadata$files, function(file) file$name, character(1))
  expect_setequal(declared, zenodo_files)
  expect_setequal(list.files(zenodo_dir, recursive = TRUE), c(declared, "README.md", "DATA_DICTIONARY.md"))
  readme <- read_file(file.path(zenodo_dir, "README.md"))
  expect_true(validUTF8(readme))
  expect_match(readme, paste0("This archive contains ", length(declared), " UTF-8 CSV files"))
  quote <- intToUtf8(96L)
  listed <- regmatches(readme, gregexpr(paste0("(?<=\\| ", quote, ")[^", quote, "]+\\.csv(?=", quote, " \\|)"), readme, perl = TRUE))[[1L]]
  expect_setequal(listed, declared)
})

test_that("every published column is documented in both dictionaries", {
  archived <- readLines(file.path(zenodo_dir, "DATA_DICTIONARY.md"), warn = FALSE, encoding = "UTF-8")
  current <- readLines(here::here("data/README.md"), warn = FALSE, encoding = "UTF-8")
  expect_true(all(validUTF8(archived)))
  for (file in zenodo_files) {
    expect_equal(sort(dictionary_columns(archived, file)), sort(names(tables[[file]])), info = paste(file, "archived dictionary"))
    expect_equal(sort(dictionary_columns(current, file)), sort(names(tables[[file]])), info = paste(file, "current dictionary"))
  }
})

test_that("the biometric contract matches the configured conservative limits", {
  limits <- read_zenodo_csv(here::here("config/ring_events/measurement_ranges.csv")) |>
    filter(afring_number == "all")
  for (column in c("wing", "weight")) {
    spec <- filter(zenodo_schema, file == "ring_events.csv", .data$column == .env$column)
    expect_equal(spec$minimum, as.numeric(limits[[paste0(column, "_min")]]))
    expect_equal(spec$maximum, as.numeric(limits[[paste0(column, "_max")]]))
  }
})

for (file in zenodo_files) {
  test_that(paste(file, "has valid CSV structure, columns, values and row relationships"), {
    expect_equal(nrow(problems(tables[[file]])), 0L, info = file)
    expect_true(nrow(tables[[file]]) > 0L, info = file)
    expect_no_zenodo_issues(table_issues[[file]])
  })
}

test_that("table links, the season calendar and all published summaries agree", {
  if (nrow(structural_issues)) skip("Resolve column, type and required-value errors before checking relationships.")
  expect_no_zenodo_issues(relation_issues)
})

test_that("internal operation evidence remains traceable to the reviewed source register", {
  register <- read_zenodo_csv(here::here("config/daily_covariates/operations_history.csv"))
  expect_equal(anyDuplicated(register$evidence_id), 0L)
  coverage <- read_zenodo_csv(file.path(paths$curated_dir, "daily_coverage.csv")) |>
    filter(!is.na(operations_evidence_ids)) |>
    tidyr::separate_longer_delim(operations_evidence_ids, ";")
  matched <- match(coverage$operations_evidence_ids, register$evidence_id)
  expect_false(anyNA(matched), info = paste(coverage$operations_evidence_ids[is.na(matched)], collapse = ", "))
  expect_true(all(!is.na(register$daily_values[matched])))
  expect_true(all(coverage$ringing_date >= register$daily_start_date[matched] &
    coverage$ringing_date <= register$daily_end_date[matched]))
  decisions <- register |> filter(!is.na(daily_values)) |>
    tidyr::separate_longer_delim(daily_values, ";") |>
    tidyr::separate_wider_delim(daily_values, "=", names = c("field", "expected"))
  observed <- coverage |> select(ringing_date, operations_evidence_ids,
    mist_observation, rain_observed, net_sites_observed, playback_nocturnal_observed, night_net_operation, dawn_net_operation) |>
    tidyr::pivot_longer(-c(ringing_date, operations_evidence_ids), names_to = "field", values_to = "actual") |>
    inner_join(select(decisions, evidence_id, field, expected), by = c("operations_evidence_ids" = "evidence_id", "field"))
  expect_true(all(same_or_missing(observed$actual, observed$expected)), info = paste(observed$ringing_date[!same_or_missing(observed$actual, observed$expected)], collapse = ", "))
})

test_that("public recorded zeros retain internal workbook evidence", {
  internal <- read_zenodo_csv(file.path(paths$curated_dir, "daily_coverage.csv"))
  public <- tables[["daily_coverage.csv"]]
  matched <- match(public$ringing_date, internal$ringing_date)
  zero <- public$count_status == "recorded_zero"
  expect_true(all(internal$djp_reported_total[matched[zero]] %in% "0"))
  expect_true(all(!is.na(internal$djp_source_row[matched[zero]])))
  expect_equal(sum(zero), sum(internal$daily_count_status == "zero_in_daily_summary"))
  expect_equal(sum(public$count_status == "missing"), sum(internal$daily_count_status == "missing"))
})

test_that("public team size is the sum of explicitly numbered participants", {
  internal <- read_zenodo_csv(file.path(paths$curated_dir, "daily_coverage.csv"))
  public <- tables[["daily_coverage.csv"]]
  base <- as.numeric(stringr::str_extract(internal$djp_pax, "^[0-9]+"))
  extra <- as.numeric(stringr::str_match(internal$djp_pax, "_plus_([0-9]+)EW$")[, 2])
  minimum <- base + coalesce(extra, 0)
  matched <- match(public$ringing_date, internal$ringing_date)
  expect_equal(as.numeric(public$djp_team_size), minimum[matched])
})

test_that("exported values remain faithful to the canonical sources", {
  for (file in metadata$files) {
    source_path <- if (!is.null(file$path)) here::here(file$path) else file.path(paths$curated_dir, file$name)
    expected <- read_zenodo_csv(source_path)
    if (file$name == "ring_events.csv") expected <- select(expected, -any_of("recorded_ring_number"))
    if (file$name == "recoveries.csv") expected <- select(expected, all_of(filter(zenodo_schema, file == "recoveries.csv")$column))
    if (file$name == "daily_coverage.csv") {
      expected_status <- ifelse(!is.na(expected$all_birds_ringed) & as.numeric(expected$all_birds_ringed) > 0,
        "recorded_positive", ifelse(expected$djp_reported_total %in% "0", "recorded_zero", "missing"))
      expected <- select(expected, all_of(c(
        "ringing_date", "season", "season_day", "daily_count_status",
        "net_sites_observed", "night_net_operation", "dawn_net_operation", "playback_nocturnal_observed",
        "mist_observation", "rain_observed", "mist_probability_none", "mist_probability_light_patchy",
        "mist_probability_good", "djp_team_size_minimum", "moon_days_from_new_moon", "moon_illumination_fraction",
        "total_cloud_cover_mean", "cloud_base_height_mean_m", "total_precipitation_00_08_mm", "wind_u_10m_mean_ms",
        "wind_v_10m_mean_ms", "wind_speed_10m_mean_ms", "temperature_2m_mean_c", "relative_humidity_mean_pct",
        "surface_pressure_mean_hpa"
      )))
      names(expected) <- filter(zenodo_schema, file == "daily_coverage.csv")$column
      expected$count_status <- expected_status
      expected$mist_observed <- c(none = "none", light_patchy = "present_light_patchy",
        good = "present_sustained", present_unspecified = "present_unspecified")[expected$mist_observed]
      expected$rain_observed <- c(none = "none", showers = "present_showers",
        heavy_rain = "present_heavy", rain_unspecified = "present_unspecified")[expected$rain_observed]
    }
    actual <- tables[[file$name]]
    # The recovery builder parses coordinates before writing; compare numeric values.
    if (file$name == "recoveries.csv") {
      expected <- mutate(expected, across(c(other_latitude, other_longitude), as.numeric))
      actual <- mutate(actual, across(c(other_latitude, other_longitude), as.numeric))
    }
    expect_equal(as.data.frame(actual), as.data.frame(expected), info = file$name)
  }
})

test_that("taxonomic contradictions remain traceable and are published as Unknown", {
  audit <- read_zenodo_csv(file.path(paths$ring_events_intermediate_dir, "qa", "taxonomy_note_audit.csv")) |>
    filter(taxonomy_conflict == "TRUE")
  events <- tables[["ring_events.csv"]]
  matched <- match(audit$ring_event_id, events$ring_event_id)
  expect_false(anyNA(matched))
  expect_true(all(events$avibase_id[matched] == "avibase-AF0D818A"))
  expect_true(all(is.na(events$subspecies_avibase_id[matched])))
  expect_equal(events$ring_note[matched], audit$ring_note)
  expect_true(all(!is.na(audit$source_file) & !is.na(audit$source_sheet) & !is.na(audit$source_row)))
  expect_true(all(!is.na(audit$source_avibase_id) & !is.na(audit$note_avibase_id)))
  expect_true(all(audit$action == "replace_taxon_unknown"))
})
