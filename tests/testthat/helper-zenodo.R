library(dplyr)
library(readr)
library(tibble)

zenodo_schema <- read_csv(here::here("tests/zenodo-schema.csv"), show_col_types = FALSE,
  col_types = cols(.default = col_character(), required = col_logical(), minimum = col_double(), maximum = col_double()))
zenodo_files <- unique(zenodo_schema$file)

read_zenodo_csv <- function(path) {
  read_csv(path, col_types = cols(.default = col_character()), na = "", trim_ws = FALSE,
    name_repair = "minimal", show_col_types = FALSE, progress = FALSE)
}

# Keep partial dates as bounds rather than inventing a precise encounter date.
partial_date_bounds <- function(x) {
  if (!length(x)) return(tibble(lower = as.Date(character()), upper = as.Date(character()), valid = logical()))
  if (anyDuplicated(x)) {
    values <- unique(x)
    return(partial_date_bounds(values)[match(x, values), ])
  }
  full <- ifelse(nchar(x) == 4L, paste0(x, "-01-01"), ifelse(nchar(x) == 7L, paste0(x, "-01"), x))
  lower <- suppressWarnings(as.Date(full, format = "%Y-%m-%d"))
  valid <- grepl("^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$", x) &
    substr(x, 1L, 4L) != "0000" & !is.na(lower) & format(lower, "%Y-%m-%d") == full
  valid[is.na(valid)] <- FALSE
  lower[!valid] <- as.Date(NA)
  upper <- lower
  years <- which(valid & nchar(x) == 4L)
  months <- which(valid & nchar(x) == 7L)
  if (length(years)) upper[years] <- as.Date(paste0(x[years], "-12-31"), format = "%Y-%m-%d")
  if (length(months)) upper[months] <- as.Date(lubridate::ceiling_date(lower[months], "month") - 1L)
  tibble(lower, upper, valid)
}

edtf_bounds <- function(x) {
  parts <- strsplit(replace(x, is.na(x), ""), "/", fixed = TRUE)
  start <- vapply(parts, function(part) if (length(part)) part[1L] else NA_character_, character(1))
  end <- vapply(parts, function(part) if (length(part)) tail(part, 1L) else NA_character_, character(1))
  left <- partial_date_bounds(start)
  right <- partial_date_bounds(end)
  valid <- lengths(parts) %in% 1:2 & !grepl("(^/|/$)", x) &
    left$valid & right$valid & left$lower <= right$upper
  valid[is.na(valid)] <- FALSE
  tibble(lower = left$lower, upper = right$upper, valid)
}

valid_csv_value <- function(x, type) {
  if (type %in% c("integer", "number")) number <- suppressWarnings(as.numeric(x))
  switch(type,
    text = validUTF8(x),
    integer = grepl("^-?[0-9]+$", x) & is.finite(number),
    number = grepl("^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$", x) & is.finite(number),
    boolean = x %in% c("TRUE", "FALSE"),
    date = nchar(x) == 10L & partial_date_bounds(x)$valid,
    partial_date = partial_date_bounds(x)$valid,
    edtf = edtf_bounds(x)$valid,
    datetime = partial_date_bounds(substr(x, 1L, 10L))$valid &
      (nchar(x) == 10L | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]\\+03:00$", x))
  )
}

same_or_missing <- function(x, y, tolerance = 0) {
  equal <- if (is.numeric(x) && is.numeric(y)) abs(x - y) <= tolerance else x == y
  (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & equal)
}

# CSV record numbers include the header; quoted multiline text can span physical lines.
row_issues <- function(data, file, rule, columns, valid) {
  rows <- which(!valid %in% TRUE)
  values <- data[rows, columns, drop = FALSE]
  tibble(file, rule, row = rows + 1L, column = paste(columns, collapse = ","),
    value = if (length(rows)) apply(values, 1L, function(x) paste(paste(columns, x, sep = "="), collapse = "; ")) else character())
}

expect_no_zenodo_issues <- function(issues) {
  details <- with(head(issues, 15L), paste(file, paste0("CSV row ", row), rule, value, sep = " | "))
  testthat::expect_equal(nrow(issues), 0L, info = paste(c(paste(nrow(issues), "violations"), details), collapse = "\n"))
}

validate_zenodo_table <- function(data, file) {
  schema <- filter(zenodo_schema, .data$file == .env$file)
  issues <- tibble(file = character(), rule = character(), row = integer(), column = character(), value = character())
  if (!identical(names(data), schema$column)) {
    return(tibble(file, rule = "column_schema", row = 1L, column = "header",
      value = paste("Expected:", paste(schema$column, collapse = ","), "Actual:", paste(names(data), collapse = ","))))
  }
  if (nrow(data) == 0L) return(issues)
  for (i in seq_len(nrow(schema))) {
    column <- schema$column[i]
    x <- data[[column]]
    if (schema$required[i]) {
      present <- !is.na(x) & nzchar(x) & !grepl("^[[:space:]]*$", x, useBytes = TRUE)
      issues <- bind_rows(issues, row_issues(data, file, "required", column, present))
    }
    issues <- bind_rows(issues, row_issues(data, file, paste0("type_", schema$type[i]), column,
      is.na(x) | valid_csv_value(x, schema$type[i])))
    if (!is.na(schema$minimum[i]) || !is.na(schema$maximum[i])) number <- suppressWarnings(as.numeric(x))
    if (!is.na(schema$minimum[i])) {
      issues <- bind_rows(issues, row_issues(data, file, "minimum", column, is.na(x) | number >= schema$minimum[i]))
    }
    if (!is.na(schema$maximum[i])) {
      issues <- bind_rows(issues, row_issues(data, file, "maximum", column, is.na(x) | number <= schema$maximum[i]))
    }
    if (!is.na(schema$values[i])) {
      issues <- bind_rows(issues, row_issues(data, file, "allowed_values", column,
        is.na(x) | x %in% strsplit(schema$values[i], ";", fixed = TRUE)[[1L]]))
    }
    if (!is.na(schema$pattern[i])) {
      issues <- bind_rows(issues, row_issues(data, file, "format", column, is.na(x) | grepl(schema$pattern[i], x, perl = TRUE)))
    }
  }
  keys <- switch(file, taxonomy.csv = "avibase_id", ring_events.csv = "ring_event_id",
    daily_counts.csv = c("ringing_date", "season", "avibase_id"), daily_coverage.csv = "ringing_date", recoveries.csv = NULL)
  if (length(keys)) {
    issues <- bind_rows(issues, row_issues(data, file, "unique_key", keys,
      !duplicated(data[keys]) & !duplicated(data[keys], fromLast = TRUE)))
  }
  if (file %in% c("ring_events.csv", "daily_counts.csv", "daily_coverage.csv")) {
    expected_season <- suppressWarnings(as.integer(substr(data$ringing_date, 1L, 4L))) -
      as.integer(substr(data$ringing_date, 6L, 7L) < "06")
    issues <- bind_rows(issues, row_issues(data, file, "date_season", c("ringing_date", "season"),
      same_or_missing(suppressWarnings(as.numeric(data$season)), expected_season)))
  }
  if (file == "taxonomy.csv") {
    ring_n <- suppressWarnings(as.numeric(data$n_ring_events))
    ring_seasons <- suppressWarnings(as.numeric(data$n_ring_seasons))
    count_n <- suppressWarnings(as.numeric(data$total_daily_count))
    count_days <- suppressWarnings(as.numeric(data$n_count_days))
    count_seasons <- suppressWarnings(as.numeric(data$n_count_seasons))
    issues <- bind_rows(issues,
      row_issues(data, file, "ring_summary_fields", c("n_ring_events", "n_ring_seasons", "first_ring_date", "last_ring_date"),
        ifelse(ring_n == 0, ring_seasons == 0 & is.na(data$first_ring_date) & is.na(data$last_ring_date),
          ring_seasons > 0 & ring_seasons <= ring_n & !is.na(data$first_ring_date) &
            !is.na(data$last_ring_date) & data$first_ring_date <= data$last_ring_date)),
      row_issues(data, file, "count_summary_fields",
        c("total_daily_count", "n_count_days", "n_count_seasons", "first_count_date", "last_count_date"),
        ifelse(count_n == 0, count_days == 0 & count_seasons == 0 & is.na(data$first_count_date) & is.na(data$last_count_date),
          count_days > 0 & count_days <= count_n & count_seasons > 0 & count_seasons <= count_days &
            !is.na(data$first_count_date) & !is.na(data$last_count_date) & data$first_count_date <= data$last_count_date)),
      row_issues(data, file, "unknown_identity", c("avibase_id", "common_name", "scientific_name"),
        !data$avibase_id %in% "avibase-AF0D818A" | (data$common_name == "Unknown" & data$scientific_name == "Aves")))
  }
  if (file == "ring_events.csv") {
    capture_date <- partial_date_bounds(substr(data$datetime, 1L, 10L))$lower
    ringing_date <- partial_date_bounds(data$ringing_date)$lower
    day_shift <- as.numeric(ringing_date - capture_date)
    issues <- bind_rows(issues, row_issues(data, file, "date_rollover", c("datetime", "ringing_date"),
      day_shift == 0 | (day_shift == 1 & nchar(data$datetime) > 10L & substr(data$datetime, 12L, 13L) >= "20")))
    issues <- bind_rows(issues,
      row_issues(data, file, "positive_measurement", "wing", is.na(data$wing) | suppressWarnings(as.numeric(data$wing)) > 0),
      row_issues(data, file, "positive_measurement", "weight", is.na(data$weight) | suppressWarnings(as.numeric(data$weight)) > 0),
      row_issues(data, file, "weight_precision", "weight", is.na(data$weight) |
        abs(suppressWarnings(as.numeric(data$weight)) * 10 - round(suppressWarnings(as.numeric(data$weight)) * 10)) < 1e-8))
    # Ten populated positions establish completeness. A missing p10 can be either
    # a nine-primary format or an incomplete ten-primary format; S and 8 are unresolved.
    primaries <- as.matrix(data[paste0("p", 1:10)])
    complete <- rowSums(!is.na(primaries)) == 10L &
      rowSums(!is.na(primaries) & !primaries %in% as.character(0:5)) == 0L
    active <- rowSums(matrix(primaries %in% as.character(1:4), nrow = nrow(data), ncol = 10L)) > 0L
    old <- rowSums(primaries == "0", na.rm = TRUE) == rowSums(!is.na(primaries))
    new <- rowSums(primaries == "5", na.rm = TRUE) == rowSums(!is.na(primaries))
    expected <- ifelse(active, "active", ifelse(old, "old", ifelse(new, "complete", "suspended")))
    issues <- bind_rows(issues, row_issues(data, file, "primary_status", c("primary_moult_status", paste0("p", 1:10)),
      !complete | same_or_missing(data$primary_moult_status, expected)))
  }
  if (file == "daily_coverage.csv") {
    n <- as.data.frame(lapply(data, function(x) suppressWarnings(as.numeric(x))))
    dates <- partial_date_bounds(data$ringing_date)$lower
    start <- suppressWarnings(as.Date(paste0(data$season, "-10-20"), format = "%Y-%m-%d"))
    probabilities <- as.matrix(n[c("mist_modeled_none", "mist_modeled_light_patchy", "mist_modeled_sustained")])
    available <- rowSums(!is.na(probabilities))
    issues <- bind_rows(issues,
      row_issues(data, file, "season_day", c("ringing_date", "season_day"), same_or_missing(n$season_day, as.numeric(dates - start) + 1)),
      row_issues(data, file, "probability_missingness", colnames(probabilities), available %in% c(0L, 3L)),
      row_issues(data, file, "probability_sum", colnames(probabilities), available == 0L | abs(rowSums(probabilities) - 1) <= 1e-8),
      row_issues(data, file, "wind_magnitude", c("era5_wind_u_10m_mean_ms", "era5_wind_v_10m_mean_ms", "era5_wind_speed_10m_mean_ms"),
        is.na(n$era5_wind_speed_10m_mean_ms) | is.na(n$era5_wind_u_10m_mean_ms) | is.na(n$era5_wind_v_10m_mean_ms) |
          n$era5_wind_speed_10m_mean_ms + 1e-8 >= sqrt(n$era5_wind_u_10m_mean_ms^2 + n$era5_wind_v_10m_mean_ms^2)))
    for (state in c("none", "light_patchy", "sustained")) {
      observed <- if (state == "none") state else paste0("present_", state)
      issues <- bind_rows(issues, row_issues(data, file, "observed_mist", c("mist_observed", colnames(probabilities)),
        !data$mist_observed %in% observed | (available == 3L & abs(probabilities[, paste0("mist_modeled_", state)] - 1) <= 1e-8)))
    }
    issues <- bind_rows(issues, row_issues(data, file, "present_mist", c("mist_observed", "mist_modeled_none"),
      !data$mist_observed %in% "present_unspecified" | (available == 3L & abs(probabilities[, 1L]) <= 1e-8)))
    sites <- strsplit(replace(data$net_sites_observed, is.na(data$net_sites_observed), ""), ",", fixed = TRUE)
    allowed <- c("back_bush", "front_bush", "outside_night_nets", "lodge_veranda", "swallow_nets", "none")
    valid <- vapply(sites, function(x) all(x %in% allowed) && !anyDuplicated(x) &&
      (!"none" %in% x || length(x) == 1L), logical(1))
    issues <- bind_rows(issues, row_issues(data, file, "site_tokens", "net_sites_observed",
      is.na(data$net_sites_observed) | (valid & !grepl("(^,|,$|,,)", data$net_sites_observed))))
  }
  if (file == "recoveries.csv") {
    encounter <- edtf_bounds(data$encounter_date_edtf)
    ringing <- partial_date_bounds(data$ringing_date)
    report <- partial_date_bounds(data$report_date)
    issues <- bind_rows(issues,
      row_issues(data, file, "duplicate_encounter", names(data),
        !duplicated(data) & !duplicated(data, fromLast = TRUE)),
      row_issues(data, file, "coordinate_pair", c("other_latitude", "other_longitude"),
        is.na(data$other_latitude) == is.na(data$other_longitude)),
      row_issues(data, file, "mortality_condition", c("encounter_condition", "mortality_cause_class"),
        ifelse(data$encounter_condition %in% "dead", !is.na(data$mortality_cause_class), is.na(data$mortality_cause_class))),
      row_issues(data, file, "control_condition", c("encounter_type", "encounter_condition"),
        !data$encounter_type %in% "control" | !data$encounter_condition %in% "dead"),
      row_issues(data, file, "recovery_chronology", c("ringing_date", "encounter_date_edtf"),
        is.na(data$ringing_date) | is.na(data$encounter_date_edtf) | encounter$upper >= ringing$lower),
      row_issues(data, file, "report_chronology", c("report_date", "encounter_date_edtf"),
        is.na(data$report_date) | is.na(data$encounter_date_edtf) | report$upper >= encounter$lower),
      row_issues(data, file, "report_ringing_chronology", c("ringing_date", "report_date"),
        is.na(data$ringing_date) | is.na(data$report_date) | report$upper >= ringing$lower))
  }
  issues
}

# Compare links and aggregates using the delivered tables, independently of curation.
validate_zenodo_relations <- function(tables, excluded_ids, ring_seasons = integer()) {
  taxonomy <- tables[["taxonomy.csv"]]
  events <- tables[["ring_events.csv"]]
  counts <- tables[["daily_counts.csv"]]
  coverage <- tables[["daily_coverage.csv"]]
  recoveries <- tables[["recoveries.csv"]]
  issues <- tibble(file = character(), rule = character(), row = integer(), column = character(), value = character())
  for (file in c("ring_events.csv", "daily_counts.csv", "recoveries.csv")) {
    data <- tables[[file]]
    matched <- match(data$avibase_id, taxonomy$avibase_id)
    issues <- bind_rows(issues,
      row_issues(data, file, "taxon_link", "avibase_id", !is.na(matched)),
      row_issues(data, file, "taxon_name", c("avibase_id", "common_name"), same_or_missing(data$common_name, taxonomy$common_name[matched])))
  }
  parent <- taxonomy$species_avibase_id
  matched <- match(parent, taxonomy$avibase_id)
  issues <- bind_rows(issues,
    row_issues(taxonomy, "taxonomy.csv", "parent_link", c("avibase_id", "species_avibase_id"), is.na(parent) | !is.na(matched)),
    row_issues(taxonomy, "taxonomy.csv", "parent_species", c("category", "species_avibase_id"),
      is.na(parent) | taxonomy$category[matched] %in% "species"),
    row_issues(taxonomy, "taxonomy.csv", "species_self_link", c("category", "avibase_id", "species_avibase_id"),
      !taxonomy$category %in% "species" | same_or_missing(taxonomy$avibase_id, parent)),
    row_issues(taxonomy, "taxonomy.csv", "parent_required", c("category", "species_avibase_id"),
      !taxonomy$category %in% c("species", "subspecies", "group (monotypic)", "group (polytypic)", "form", "intergrade") | !is.na(parent)))
  sub <- match(events$subspecies_avibase_id, taxonomy$avibase_id)
  species <- taxonomy$species_avibase_id[match(events$avibase_id, taxonomy$avibase_id)]
  issues <- bind_rows(issues,
    row_issues(events, "ring_events.csv", "subspecies_link", "subspecies_avibase_id",
      is.na(events$subspecies_avibase_id) | !is.na(sub)),
    row_issues(events, "ring_events.csv", "subspecies_parent", c("avibase_id", "subspecies_avibase_id"),
      is.na(events$subspecies_avibase_id) | (!is.na(species) &
        taxonomy$species_avibase_id[sub] == species &
        taxonomy$category[sub] %in% c("subspecies", "group (monotypic)", "group (polytypic)", "form", "intergrade"))))
  coverage_key <- paste(coverage$ringing_date, coverage$season)
  for (file in c("ring_events.csv", "daily_counts.csv")) {
    data <- tables[[file]]
    issues <- bind_rows(issues, row_issues(data, file, "coverage_link", c("ringing_date", "season"),
      paste(data$ringing_date, data$season) %in% coverage_key))
  }
  for (season in unique(coverage$season)) {
    data <- filter(coverage, .data$season == .env$season)
    dates <- sort(partial_date_bounds(data$ringing_date)$lower, na.last = TRUE)
    start <- as.Date(paste0(season, "-10-20"))
    end <- as.Date(paste0(as.integer(season) + 1L, "-01-12"))
    valid <- length(dates) && !anyNA(dates) && min(dates) == start && max(dates) >= end &&
      max(dates) <= as.Date(paste0(as.integer(season) + 1L, "-01-31")) && all(diff(dates) == 1)
    if (!valid) issues <- bind_rows(issues, row_issues(data, "daily_coverage.csv", "calendar_window", c("season", "ringing_date"), rep(FALSE, nrow(data))))
  }
  count_key <- paste(counts$ringing_date, counts$season)
  issues <- bind_rows(issues,
    row_issues(coverage, "daily_coverage.csv", "count_status", c("ringing_date", "count_status"),
      (coverage$count_status %in% "recorded_positive") == (coverage_key %in% count_key)))
  if (length(ring_seasons)) {
    ring_counts <- events |> filter(as.integer(season) %in% ring_seasons) |>
      count(ringing_date, season, avibase_id, name = "expected")
    expected_keys <- paste(ring_counts$ringing_date, ring_counts$season, ring_counts$avibase_id)
    count_keys <- paste(counts$ringing_date, counts$season, counts$avibase_id)
    matched <- match(count_keys, expected_keys)
    issues <- bind_rows(issues, row_issues(counts, "daily_counts.csv", "ring_source_count",
      c("ringing_date", "season", "avibase_id", "n_records"), !as.integer(counts$season) %in% ring_seasons |
        same_or_missing(as.numeric(counts$n_records), ring_counts$expected[matched])))
    missing <- ring_counts[!expected_keys %in% count_keys, ]
    if (nrow(missing)) issues <- bind_rows(issues, tibble(file = "daily_counts.csv", rule = "ring_source_missing",
      row = NA_integer_, column = "ringing_date,season,avibase_id",
      value = paste(missing$ringing_date, missing$season, missing$avibase_id, sep = "; ")))
  }
  # Expand each identification once to its exact concept and once to its species.
  ring_ids <- bind_rows(
    events |> transmute(record = row_number(), avibase_id),
    events |> transmute(record = row_number(), avibase_id = subspecies_avibase_id))
  source_tables <- list(ring = events, count = counts, recovery = recoveries)
  for (source in names(source_tables)) {
    data <- source_tables[[source]]
    ids <- if (source == "ring") ring_ids else data |> transmute(record = row_number(), avibase_id)
    parent <- taxonomy$species_avibase_id[match(ids$avibase_id, taxonomy$avibase_id)]
    ids <- bind_rows(ids, mutate(ids, avibase_id = parent)) |>
      filter(!is.na(avibase_id)) |> distinct(record, avibase_id)
    if (source == "ring") {
      stats <- ids |> mutate(ringing_date = data$ringing_date[record], season = data$season[record]) |>
        group_by(avibase_id) |> summarise(n_ring_events = n(), n_ring_seasons = n_distinct(season),
          first_ring_date = min(ringing_date), last_ring_date = max(ringing_date), .groups = "drop")
    } else if (source == "count") {
      stats <- ids |> mutate(ringing_date = data$ringing_date[record], season = data$season[record], n_records = as.numeric(data$n_records[record])) |>
        group_by(avibase_id) |> summarise(total_daily_count = sum(n_records), n_count_days = n_distinct(ringing_date),
          n_count_seasons = n_distinct(season), first_count_date = min(ringing_date), last_count_date = max(ringing_date), .groups = "drop")
    } else {
      stats <- count(ids, avibase_id, name = "n_recoveries")
    }
    matched <- match(taxonomy$avibase_id, stats$avibase_id)
    for (column in setdiff(names(stats), "avibase_id")) {
      expected <- stats[[column]][matched]
      actual <- taxonomy[[column]]
      if (is.numeric(expected)) {
        expected <- coalesce(expected, 0)
        actual <- as.numeric(actual)
      }
      issues <- bind_rows(issues, row_issues(taxonomy, "taxonomy.csv", paste0("summary_", column), c("avibase_id", column),
        same_or_missing(actual, expected)))
    }
  }
  issues <- bind_rows(issues, row_issues(taxonomy, "taxonomy.csv", "recorded_taxon",
    c("avibase_id", "n_ring_events", "total_daily_count", "n_recoveries"),
    as.numeric(taxonomy$n_ring_events) + as.numeric(taxonomy$total_daily_count) + as.numeric(taxonomy$n_recoveries) > 0))
  issues
}

dictionary_columns <- function(lines, file) {
  quote <- intToUtf8(96L)
  start <- match(paste0("### ", quote, file, quote), lines)
  if (is.na(start)) return(character())
  following <- which(grepl("^###? ", lines) & seq_along(lines) > start)
  end <- if (length(following)) min(following) - 1L else length(lines)
  rows <- character()
  column_table <- FALSE
  for (line in lines[seq.int(start + 1L, end)]) {
    if (!startsWith(line, "|")) column_table <- FALSE
    if (grepl("^\\| Column[[:space:]]*\\|", line)) column_table <- TRUE
    if (column_table && startsWith(line, paste0("| ", quote))) rows <- c(rows, line)
  }
  fields <- lapply(rows, function(row) {
    cell <- strsplit(row, "|", fixed = TRUE)[[1L]][2L]
    if (grepl(paste0(quote, "[a-z]+[0-9]+", quote, "[–-]", quote, "[a-z]+[0-9]+", quote), cell)) {
      tokens <- regmatches(cell, gregexpr("[a-z]+[0-9]+", cell))[[1L]]
      return(paste0(sub("[0-9]+$", "", tokens[1L]),
        seq.int(as.integer(sub("^[a-z]+", "", tokens[1L])), as.integer(sub("^[a-z]+", "", tokens[2L])))))
    }
    gsub(quote, "", regmatches(cell, gregexpr(paste0(quote, "[^", quote, "]+", quote), cell))[[1L]], fixed = TRUE)
  })
  unlist(fields, use.names = FALSE)
}
