test_that("the small reference package passes every table and relationship rule", {
  fixture <- zenodo_fixture()
  for (file in zenodo_files) expect_no_zenodo_issues(validate_zenodo_table(fixture[[file]], file))
  expect_no_zenodo_issues(validate_zenodo_relations(fixture, fixture_excluded_ids))
})

test_that("missing, extra, repeated and reordered headers are rejected", {
  data <- zenodo_fixture()[["daily_counts.csv"]]
  expect_zenodo_rule(validate_zenodo_table(select(data, -season), "daily_counts.csv"), "column_schema")
  expect_zenodo_rule(validate_zenodo_table(mutate(data, extra = "x"), "daily_counts.csv"), "column_schema")
  names(data)[2] <- names(data)[1]
  expect_zenodo_rule(validate_zenodo_table(data, "daily_counts.csv"), "column_schema")
  data <- zenodo_fixture()[["daily_counts.csv"]]
  expect_zenodo_rule(validate_zenodo_table(data[rev(names(data))], "daily_counts.csv"), "column_schema")
})

test_that("every required column rejects missing and whitespace-only values", {
  fixture <- zenodo_fixture()
  for (file in zenodo_files) {
    required <- filter(zenodo_schema, .data$file == .env$file, required)$column
    for (missing in c(NA_character_, "   ")) {
      data <- fixture[[file]][1, ]
      data[required] <- missing
      issues <- validate_zenodo_table(data, file)
      expect_setequal(filter(issues, rule == "required")$column, required)
    }
  }
})

test_that("all integer, numeric, boolean and date columns enforce their declared types", {
  fixture <- zenodo_fixture()
  bad <- c(integer = "1.5", number = "Inf", boolean = "true", date = "2023-02-29",
    datetime = "2023-10-20T23:00:00Z", partial_date = "2024-13", edtf = "2025/2024")
  for (file in zenodo_files) {
    data <- fixture[[file]][1, ]
    schema <- filter(zenodo_schema, .data$file == .env$file, type != "text")
    for (i in seq_len(nrow(schema))) data[[schema$column[i]]] <- bad[[schema$type[i]]]
    issues <- validate_zenodo_table(data, file)
    for (i in seq_len(nrow(schema))) expect_zenodo_rule(issues, paste0("type_", schema$type[i]), schema$column[i])
  }
})

test_that("every controlled vocabulary rejects an unknown code", {
  fixture <- zenodo_fixture()
  for (file in zenodo_files) {
    columns <- filter(zenodo_schema, .data$file == .env$file, !is.na(values))$column
    data <- fixture[[file]][1, ]
    data[columns] <- "__invalid__"
    issues <- validate_zenodo_table(data, file)
    expect_setequal(filter(issues, rule == "allowed_values")$column, columns)
  }
})

test_that("all declared numeric bounds are enforced and inclusive", {
  fixture <- zenodo_fixture()
  for (i in which(!is.na(zenodo_schema$minimum) | !is.na(zenodo_schema$maximum))) {
    spec <- zenodo_schema[i, ]
    data <- fixture[[spec$file]][1, ]
    for (bound in c("minimum", "maximum")) {
      limit <- spec[[bound]]
      if (is.na(limit)) next
      data[[spec$column]] <- as.character(limit + if (bound == "minimum") -1 else 1)
      expect_zenodo_rule(validate_zenodo_table(data, spec$file), bound, spec$column)
      data[[spec$column]] <- as.character(limit)
      issues <- validate_zenodo_table(data, spec$file)
      expect_false(any(issues$rule == bound & issues$column == spec$column), info = paste(spec$file, spec$column, bound))
    }
  }
})

test_that("nullable fields remain nullable without silently permitting missing keys", {
  fixture <- zenodo_fixture()
  for (file in zenodo_files) {
    optional <- filter(zenodo_schema, .data$file == .env$file, !required)$column
    data <- fixture[[file]][1, ]
    data[optional] <- NA_character_
    issues <- validate_zenodo_table(data, file)
    expect_false(any(issues$rule == "required" & issues$column %in% optional))
    expect_false(any(startsWith(issues$rule, "type_") & issues$column %in% optional))
    expect_no_zenodo_issues(validate_zenodo_table(data[0, ], file))
  }
})

test_that("calendar validation handles leap years and rejects impossible dates", {
  expect_true(all(valid_csv_value(c("2000-02-29", "2024-02-29", "2023-12-31"), "date")))
  expect_false(any(valid_csv_value(c("1900-02-29", "2023-02-29", "2024-04-31", "2024-00-01",
    "2024-01-00", "2024-1-01", "0000-01-01", "2024-01-01garbage"), "date")))
  expect_equal(nrow(partial_date_bounds(character())), 0L)
  expect_false(any(partial_date_bounds(c(NA_character_, "", "NA", "not a date"))$valid))
  expect_true(all(valid_csv_value(c("2024", "2024-02", "2024-02-29"), "partial_date")))
  expect_equal(as.character(partial_date_bounds("2024-02")$upper), "2024-02-29")
  expect_true(all(valid_csv_value(c("1995/1996", "2024-02/2024-03", "2024/2024", "2024-02-29"), "edtf")))
  expect_false(any(valid_csv_value(c("1996/1995", "2024-03/2024-02", "/2024", "2024/", "2024//2025",
    "2024/2025/2026", "2023-02-29/2024", "2024-13"), "edtf")))
})

test_that("timestamps require real dates, clock times and the documented offset", {
  expect_true(all(valid_csv_value(c("2023-10-20", "2023-10-20T00:00:00+03:00", "2023-10-20T23:59:59+03:00"), "datetime")))
  expect_false(any(valid_csv_value(c("2023-02-29T12:00:00+03:00", "2023-10-20T24:00:00+03:00",
    "2023-10-20T12:60:00+03:00", "2023-10-20T12:00:60+03:00", "2023-10-20T12:00:00+02:00"), "datetime")))
})

test_that("numeric fields reject nonfinite values and partial numeric strings", {
  expect_true(all(valid_csv_value(c("0", "-1.5", "1e-3", ".25", "+2"), "number")))
  expect_false(any(valid_csv_value(c("Inf", "-Inf", "NaN", "1e999", "1 bird", "1,000", " 1", ""), "number")))
  expect_false(any(valid_csv_value(c("1.0", "1e2", "2x"), "integer")))
})

test_that("CSV reading preserves ring inscriptions, UTF-8 and quoted text", {
  path <- tempfile(fileext = ".csv")
  original <- tibble(ring_number = c("000123", "NA"), note = c("Côte d'Ivoire, first line\nsecond line", NA_character_))
  write_csv(original, path, na = "")
  read <- read_zenodo_csv(path)
  expect_equal(as.data.frame(read), as.data.frame(original))
  expect_equal(nrow(problems(read)), 0L)
  writeLines(c("a,b", "1,2,3"), path)
  broken <- suppressWarnings(read_zenodo_csv(path))
  expect_gt(nrow(problems(broken)), 0L)
  unlink(path)
})

test_that("duplicate primary keys fail while different encounters of the same ring pass", {
  fixture <- zenodo_fixture()
  for (file in setdiff(zenodo_files, "recoveries.csv")) {
    data <- bind_rows(fixture[[file]], fixture[[file]][1, ])
    expect_zenodo_rule(validate_zenodo_table(data, file), "unique_key")
  }
  expect_no_zenodo_issues(validate_zenodo_table(fixture[["recoveries.csv"]], "recoveries.csv"))
  data <- bind_rows(fixture[["recoveries.csv"]], fixture[["recoveries.csv"]][1, ])
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "duplicate_encounter")
})

test_that("season labels use the June boundary and survive the January year change", {
  data <- zenodo_fixture()[["daily_counts.csv"]][rep(1, 4), ]
  data$ringing_date <- c("2023-05-31", "2023-06-01", "2023-12-31", "2024-01-01")
  data$season <- c("2022", "2023", "2023", "2023")
  expect_false(any(validate_zenodo_table(data, "daily_counts.csv")$rule == "date_season"))
  data$season[4] <- "2024"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_counts.csv"), "date_season")
})

test_that("feather codes remain text and incomplete scores do not invent a moult status", {
  data <- zenodo_fixture()[["ring_events.csv"]][1, ]
  data$p1 <- "S"
  data$p2 <- "8"
  expect_no_zenodo_issues(validate_zenodo_table(data, "ring_events.csv"))
  data$p1 <- "7"
  expect_zenodo_rule(validate_zenodo_table(data, "ring_events.csv"), "allowed_values", "p1")
  for (status in c("old", "active", "suspended", "complete")) {
    scores <- switch(status, old = rep("0", 10), active = c("2", rep("0", 9)),
      suspended = c("5", rep("0", 9)), complete = rep("5", 10))
    data[paste0("p", 1:10)] <- as.list(scores)
    data$primary_moult_status <- status
    expect_no_zenodo_issues(validate_zenodo_table(data, "ring_events.csv"))
    data$primary_moult_status <- if (status == "old") "complete" else "old"
    expect_zenodo_rule(validate_zenodo_table(data, "ring_events.csv"), "primary_status")
  }
  data$p10 <- NA_character_
  expect_false(any(validate_zenodo_table(data, "ring_events.csv")$rule == "primary_status"))
})

test_that("probabilities enforce completeness, normalization and observed states", {
  data <- zenodo_fixture()[["daily_coverage.csv"]][1, ]
  data$mist_modeled_none <- "0.4"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "probability_sum")
  data$mist_modeled_none <- NA_character_
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "probability_missingness")
  columns <- c("mist_modeled_none", "mist_modeled_light_patchy", "mist_modeled_sustained")
  data[columns] <- NA_character_
  expect_no_zenodo_issues(validate_zenodo_table(data, "daily_coverage.csv"))
  data[columns] <- as.list(c("0.2", "0.3", "0.500000005"))
  expect_no_zenodo_issues(validate_zenodo_table(data, "daily_coverage.csv"))
  data$mist_observed <- "present_sustained"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "observed_mist")
  data$mist_observed <- "present_unspecified"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "present_mist")
})

test_that("recorded zero and missing counts differ from positive species-day records", {
  tables <- zenodo_fixture()
  expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids))
  # The second date has only swallow rows; its status is still positive.
  expect_equal(tables[["daily_coverage.csv"]]$count_status[1:4],
    c("recorded_positive", "recorded_positive", "recorded_zero", "missing"))
  tables[["daily_coverage.csv"]]$count_status[2] <- "recorded_zero"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "count_status")
  tables <- zenodo_fixture()
  tables[["daily_coverage.csv"]]$count_status[4] <- "recorded_positive"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "count_status")
})

test_that("net site combinations distinguish explicit absence and valid sites", {
  data <- zenodo_fixture()[["daily_coverage.csv"]]
  data$net_sites_observed[1] <- "none"
  expect_no_zenodo_issues(validate_zenodo_table(data, "daily_coverage.csv"))
  data$net_sites_observed[1] <- "none,front_bush"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "site_tokens")
  data$net_sites_observed[1] <- "front_bush,"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "site_tokens")
})

test_that("season position and mean wind magnitude remain coherent", {
  data <- zenodo_fixture()[["daily_coverage.csv"]][1, ]
  for (season in c(1976L, 1977L, 1993L, 1994L, 1995L, 1996L)) {
    data$season <- as.character(season)
    data$ringing_date <- paste0(season, "-10-20")
    expect_no_zenodo_issues(validate_zenodo_table(data, "daily_coverage.csv"))
  }
  data$season_day <- "2"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "season_day")
  data$era5_wind_u_10m_mean_ms <- "3"
  data$era5_wind_v_10m_mean_ms <- "4"
  data$era5_wind_speed_10m_mean_ms <- "4"
  expect_zenodo_rule(validate_zenodo_table(data, "daily_coverage.csv"), "wind_magnitude")
})

test_that("recovery dates respect partial precision rather than assuming exact days", {
  data <- zenodo_fixture()[["recoveries.csv"]][1, ]
  data$ringing_age_code <- "2(4)"
  data$ringing_date <- "2024-12-31"
  data$encounter_date_edtf <- "2024"
  data$report_date <- "2024"
  expect_no_zenodo_issues(validate_zenodo_table(data, "recoveries.csv"))
  data$encounter_date_edtf <- "2023"
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "recovery_chronology")
  data$encounter_date_edtf <- "2025-01"
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "report_chronology")
})

test_that("coordinates and mortality classes are meaningful together", {
  data <- zenodo_fixture()[["recoveries.csv"]][1, ]
  data$other_latitude <- "0"
  data$other_longitude <- "0"
  expect_no_zenodo_issues(validate_zenodo_table(data, "recoveries.csv"))
  data$other_longitude <- NA_character_
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "coordinate_pair")
  data$mortality_cause_class <- "unknown"
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "mortality_condition")
  data$encounter_condition <- "dead"
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "control_condition")
})

test_that("taxon references, names, parents and subspecies cannot silently diverge", {
  for (file in c("ring_events.csv", "daily_counts.csv", "recoveries.csv")) {
    tables <- zenodo_fixture()
    tables[[file]]$avibase_id[1] <- "avibase-FFFFFFFF"
    expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "taxon_link")
    tables <- zenodo_fixture()
    tables[[file]]$common_name[1] <- "Wrong name"
    expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "taxon_name")
  }
  tables <- zenodo_fixture()
  tables[["ring_events.csv"]]$subspecies_avibase_id[2] <- "avibase-FFFFFFFF"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "subspecies_link")
  tables[["ring_events.csv"]]$subspecies_avibase_id[2] <- "avibase-33333333"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "subspecies_parent")
  tables <- zenodo_fixture()
  tables[["taxonomy.csv"]]$species_avibase_id[2] <- "avibase-FFFFFFFF"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "parent_link")
  tables <- zenodo_fixture()
  tables[["taxonomy.csv"]]$species_avibase_id[1] <- "avibase-22222222"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "parent_species")
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "species_self_link")
})

test_that("calendar gaps, missing observation dates and wrong count coverage are caught", {
  tables <- zenodo_fixture()
  tables[["daily_coverage.csv"]] <- tables[["daily_coverage.csv"]][-1, ]
  issues <- validate_zenodo_relations(tables, fixture_excluded_ids)
  expect_zenodo_rule(issues, "coverage_link")
  expect_zenodo_rule(issues, "calendar_window")
  tables <- zenodo_fixture()
  tables[["daily_coverage.csv"]]$count_status[1] <- "missing"
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "count_status")
})

test_that("every taxonomy summary detects stale values and counts each event only once", {
  tables <- zenodo_fixture()
  columns <- c("n_ring_events", "n_ring_seasons", "first_ring_date", "last_ring_date", "total_daily_count",
    "n_count_days", "n_count_seasons", "first_count_date", "last_count_date", "n_recoveries")
  for (column in columns) {
    bad <- tables
    bad[["taxonomy.csv"]][[column]][1] <- if (grepl("date", column)) "1999-01-01" else "999"
    expect_zenodo_rule(validate_zenodo_relations(bad, fixture_excluded_ids), paste0("summary_", column))
  }
  # Two species events include one explicitly identified subspecies: the species
  # has two events, not three; the subspecies has one. Repeated recoveries count twice.
  expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids))
})

test_that("the dictionary parser expands columns and skips code-mapping tables", {
  quote <- intToUtf8(96L)
  lines <- c(paste0("### ", quote, "example.csv", quote),
    "| Column | Type | Description |", "| --- | --- | --- |",
    paste0("| ", quote, "p1", quote, "–", quote, "p3", quote, " | text | Scores |"),
    paste0("| ", quote, "a", quote, ", ", quote, "b", quote, " | text | Labels |"),
    "", "#### Mapping", "| Code | Value | Meaning |", "| --- | --- | --- |",
    paste0("| ", quote, "M", quote, " | present | Mist |"),
    "### Another section")
  expect_identical(dictionary_columns(lines, "example.csv"), c("p1", "p2", "p3", "a", "b"))
  expect_identical(dictionary_columns(lines, "absent.csv"), character())
})

test_that("clock rollover allows declared ringing-day labels and rejects impossible shifts", {
  data <- zenodo_fixture()[["ring_events.csv"]][1, ]
  data$datetime <- "2023-10-19T20:00:00+03:00"
  expect_no_zenodo_issues(validate_zenodo_table(data, "ring_events.csv"))
  data$datetime <- "2023-10-20T23:59:59+03:00"
  expect_no_zenodo_issues(validate_zenodo_table(data, "ring_events.csv"))
  for (datetime in c("2023-10-19T19:59:59+03:00", "2023-10-18T23:00:00+03:00", "2023-10-19")) {
    data$datetime <- datetime
    expect_zenodo_rule(validate_zenodo_table(data, "ring_events.csv"), "date_rollover")
  }
  data$ringing_date <- "2024-01-01"
  data$datetime <- "2023-12-31T20:00:00+03:00"
  expect_no_zenodo_issues(validate_zenodo_table(data, "ring_events.csv"))
})

test_that("an extended January calendar is valid but an internal gap is not", {
  tables <- zenodo_fixture()
  extra <- tail(tables[["daily_coverage.csv"]], 1)
  extra$ringing_date <- "2024-01-13"
  extra$season_day <- "86"
  tables[["daily_coverage.csv"]] <- bind_rows(tables[["daily_coverage.csv"]], extra)
  expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids))
  tables[["daily_coverage.csv"]] <- tables[["daily_coverage.csv"]][-30, ]
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids), "calendar_window")
})

test_that("count source policy enforces ring-derived seasons without equating all sources", {
  tables <- zenodo_fixture()
  expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids, ring_seasons = 2023L))
  tables[["daily_counts.csv"]]$n_records[1] <- "7"
  tables[["taxonomy.csv"]]$total_daily_count[1] <- "7"
  # The package remains coherent when this season uses an independent count source.
  expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids, ring_seasons = 2000L))
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids, ring_seasons = 2023L), "ring_source_count")
  tables <- zenodo_fixture()
  tables[["daily_counts.csv"]] <- tables[["daily_counts.csv"]][-1, ]
  expect_zenodo_rule(validate_zenodo_relations(tables, fixture_excluded_ids, ring_seasons = 2023L), "ring_source_missing")
})

test_that("unknown birds and ambiguous concepts can retain their own statistics without a species parent", {
  for (category in c("spuh", "hybrid")) {
    tables <- zenodo_fixture()
    tables[["taxonomy.csv"]] <- tables[["taxonomy.csv"]][-2, ]
    tables[["taxonomy.csv"]]$category[1] <- category
    tables[["taxonomy.csv"]]$species_avibase_id[1] <- NA_character_
    tables[["ring_events.csv"]]$subspecies_avibase_id <- NA_character_
    if (category == "spuh") {
      tables[["taxonomy.csv"]]$scientific_name[1] <- "Aves"
      for (file in c("taxonomy.csv", "ring_events.csv", "daily_counts.csv", "recoveries.csv")) {
        rows <- tables[[file]]$avibase_id == "avibase-11111111"
        tables[[file]]$avibase_id[rows] <- "avibase-AF0D818A"
        tables[[file]]$common_name[rows] <- "Unknown"
      }
    }
    for (file in zenodo_files) expect_no_zenodo_issues(validate_zenodo_table(tables[[file]], file))
    expect_no_zenodo_issues(validate_zenodo_relations(tables, fixture_excluded_ids))
  }
  data <- tables[["taxonomy.csv"]]
  data$n_ring_seasons[1] <- "3"
  expect_zenodo_rule(validate_zenodo_table(data, "taxonomy.csv"), "ring_summary_fields")
  data$n_count_days[1] <- "0"
  expect_zenodo_rule(validate_zenodo_table(data, "taxonomy.csv"), "count_summary_fields")
})

test_that("invalid UTF-8 and contradictory unknown-bird labels are rejected", {
  data <- zenodo_fixture()[["ring_events.csv"]][1, ]
  data$ring_note <- rawToChar(as.raw(255))
  expect_zenodo_rule(validate_zenodo_table(data, "ring_events.csv"), "type_text", "ring_note")
  data <- zenodo_fixture()[["taxonomy.csv"]][1, ]
  data$avibase_id <- "avibase-AF0D818A"
  expect_zenodo_rule(validate_zenodo_table(data, "taxonomy.csv"), "unknown_identity")
})

test_that("partial original ringing dates are preserved and reports cannot predate ringing", {
  data <- zenodo_fixture()[["recoveries.csv"]][1, ]
  data$ringing_date <- "2024-02"
  data$encounter_date_edtf <- "2024-02-01"
  expect_no_zenodo_issues(validate_zenodo_table(data, "recoveries.csv"))
  data$encounter_date_edtf <- NA_character_
  data$report_date <- "2023"
  expect_zenodo_rule(validate_zenodo_table(data, "recoveries.csv"), "report_ringing_chronology")
})

test_that("diagnostics retain the file, column, offending value and CSV row", {
  data <- zenodo_fixture()[["daily_counts.csv"]]
  data$n_records[2] <- "1.5"
  issues <- validate_zenodo_table(data, "daily_counts.csv")
  problem <- filter(issues, rule == "type_integer", column == "n_records")
  expect_identical(problem$file, "daily_counts.csv")
  expect_identical(problem$row, 3L)
  expect_identical(problem$value, "n_records=1.5")
})

test_that("every identifier and coded-list format rejects malformed strings", {
  fixture <- zenodo_fixture()
  for (file in zenodo_files) {
    columns <- filter(zenodo_schema, .data$file == .env$file, !is.na(pattern))$column
    data <- fixture[[file]][1, ]
    data[columns] <- "__invalid__"
    issues <- validate_zenodo_table(data, file)
    expect_setequal(filter(issues, rule == "format")$column, columns)
  }
  data <- fixture[["taxonomy.csv"]][1, ]
  data$afring_numbers <- "-1;0;607"
  expect_no_zenodo_issues(validate_zenodo_table(data, "taxonomy.csv"))
  data$afring_numbers <- "607;"
  expect_zenodo_rule(validate_zenodo_table(data, "taxonomy.csv"), "format", "afring_numbers")
})
