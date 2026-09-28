# A small, independently specified package with rollups, repeated recoveries,
# positive catch, swallow-only catch, a recorded zero and unknown dates.
zenodo_fixture <- function() {
  tables <- setNames(lapply(zenodo_files, function(file) {
    columns <- filter(zenodo_schema, .data$file == .env$file)$column
    n <- switch(file, taxonomy.csv = 3L, ring_events.csv = 5L, daily_counts.csv = 3L,
      daily_coverage.csv = 85L, recoveries.csv = 2L)
    as_tibble(setNames(rep(list(rep(NA_character_, n)), length(columns)), columns))
  }), zenodo_files)
  taxonomy <- tables[["taxonomy.csv"]]
  taxonomy$avibase_id <- c("avibase-11111111", "avibase-22222222", "avibase-33333333")
  taxonomy$common_name <- c("Species", "Subspecies", "Swallow")
  taxonomy$category <- c("species", "subspecies", "species")
  taxonomy$species_avibase_id <- c("avibase-11111111", "avibase-11111111", "avibase-33333333")
  taxonomy$n_ring_events <- c("2", "1", "3")
  taxonomy$n_ring_seasons <- rep("1", 3)
  taxonomy$first_ring_date <- rep("2023-10-20", 3)
  taxonomy$last_ring_date <- c("2023-10-20", "2023-10-20", "2023-10-21")
  taxonomy$total_daily_count <- c("2", "0", "3")
  taxonomy$n_count_days <- c("1", "0", "2")
  taxonomy$n_count_seasons <- c("1", "0", "1")
  taxonomy$first_count_date <- c("2023-10-20", NA, "2023-10-20")
  taxonomy$last_count_date <- c("2023-10-20", NA, "2023-10-21")
  taxonomy$n_recoveries <- c("2", "0", "0")
  tables[["taxonomy.csv"]] <- taxonomy

  events <- tables[["ring_events.csv"]]
  events$ring_event_id <- paste0("000", 1:5, "__202310", c(20, 20, 20, 21, 21))
  events$ring_number <- paste0("000", 1:5)
  events$ringing_date <- c(rep("2023-10-20", 3), rep("2023-10-21", 2))
  events$season <- rep("2023", 5)
  events$datetime <- events$ringing_date
  events$retrap <- rep("FALSE", 5)
  events$avibase_id <- c(rep("avibase-11111111", 2), rep("avibase-33333333", 3))
  events$subspecies_avibase_id[2] <- "avibase-22222222"
  events$common_name <- c(rep("Species", 2), rep("Swallow", 3))
  events$age <- rep("3", 5)
  tables[["ring_events.csv"]] <- events

  counts <- tables[["daily_counts.csv"]]
  counts$ringing_date <- c("2023-10-20", "2023-10-20", "2023-10-21")
  counts$season <- rep("2023", 3)
  counts$avibase_id <- c("avibase-11111111", rep("avibase-33333333", 2))
  counts$common_name <- c("Species", "Swallow", "Swallow")
  counts$n_records <- c("2", "1", "2")
  tables[["daily_counts.csv"]] <- counts

  coverage <- tables[["daily_coverage.csv"]]
  coverage$ringing_date <- as.character(seq(as.Date("2023-10-20"), as.Date("2024-01-12"), by = "day"))
  coverage$season <- rep("2023", 85)
  coverage$season_day <- as.character(1:85)
  coverage$count_status <- rep("missing", 85)
  coverage$count_status[1:3] <- c("recorded_positive", "recorded_positive", "recorded_zero")
  coverage$moon_days_from_new_moon <- rep("0", 85)
  coverage$moon_illumination_fraction <- rep("0", 85)
  coverage$dawn_nets_operated[4] <- "1"
  coverage$net_sites_observed[5] <- "none"
  coverage$mist_observed[2:5] <- c("none", "present_light_patchy", "present_sustained", "present_unspecified")
  coverage$mist_modeled_none[1:5] <- c("0.2", "1", "0", "0", "0")
  coverage$mist_modeled_light_patchy[1:5] <- c("0.3", "0", "1", "0", "0.5")
  coverage$mist_modeled_sustained[1:5] <- c("0.5", "0", "0", "1", "0.5")
  tables[["daily_coverage.csv"]] <- coverage

  recoveries <- tables[["recoveries.csv"]]
  recoveries$avibase_id <- rep("avibase-11111111", 2)
  recoveries$common_name <- rep("Species", 2)
  recoveries$ring_scheme <- rep("Scheme", 2)
  recoveries$ring_number <- rep("0001", 2)
  recoveries$direction <- rep("from_ngulia", 2)
  recoveries$ringing_date <- rep("2023-10-20", 2)
  recoveries$encounter_date_edtf <- c("2024", "2025-02/2025-03")
  recoveries$encounter_type <- rep("control", 2)
  recoveries$encounter_condition <- rep("alive", 2)
  tables[["recoveries.csv"]] <- recoveries
  tables
}

fixture_excluded_ids <- "avibase-33333333"

expect_zenodo_rule <- function(issues, rule, column = NULL) {
  found <- issues$rule == rule
  if (!is.null(column)) found <- found & issues$column == column
  testthat::expect_true(any(found), info = paste("Expected", rule, column, "but found", paste(unique(issues$rule), collapse = ", ")))
}
