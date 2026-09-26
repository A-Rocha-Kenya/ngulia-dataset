library(cli)
library(dplyr)
library(jsonlite)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

# Load paths ----------------------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
paths <- get_data_paths(project_dir)

daily_counts_path <- file.path(paths$curated_dir, "daily_counts.csv")
recoveries_path <- file.path(paths$curated_dir, "recoveries.csv")
species_reference_path <- file.path(paths$ring_events_config_dir, "species_reference.csv")
taxonomy_crosswalk_path <- file.path(paths$website_config_dir, "ngulia_taxonomy_crosswalk.csv")
clements_taxonomy_path <- file.path(paths$reference_dir, "taxonomy", "ebird_clements_2025_integrated_checklist.csv")

photo_paths <- c(
  "avibase-0D42A253" = "./species-photos/avibase-0D42A253.jpg",
  "avibase-14AFBA82" = "./species-photos/avibase-14AFBA82.jpg",
  "avibase-1EA60B94" = "./species-photos/avibase-1EA60B94.jpg",
  "avibase-2B020CA0" = "./species-photos/avibase-2B020CA0.jpg",
  "avibase-58C502EA" = "./species-photos/avibase-58C502EA.jpg",
  "avibase-6EC66752" = "./species-photos/avibase-6EC66752.jpg",
  "avibase-73BD4B29" = "./species-photos/avibase-73BD4B29.jpg",
  "avibase-7451A628" = "./species-photos/avibase-7451A628.jpg",
  "avibase-7AAD57AC" = "./species-photos/avibase-7AAD57AC.jpg",
  "avibase-7C7F0DEE" = "./species-photos/avibase-7C7F0DEE.jpg",
  "avibase-88F4B969" = "./species-photos/avibase-88F4B969.jpg",
  "avibase-97166F72" = "./species-photos/avibase-97166F72.jpg",
  "avibase-A6A4FC63" = "./species-photos/avibase-A6A4FC63.jpg",
  "avibase-B675E006" = "./species-photos/avibase-B675E006.jpg",
  "avibase-EE8206E7" = "./species-photos/avibase-EE8206E7.jpg"
)

species_range_seasonal_types <- list(
  `2` = "breeding",
  `3` = "wintering"
)

ngulia_coords <- list(latitude = -3.0140288001023605, longitude = 38.211134674309974)
ngulia_exclusion_band_km <- 500
km_per_latitude_degree <- 111.32
migration_bounds <- list(west = -12, south = -35, east = 78, north = 62)
migration_grid <- list(width = 90L, height = 96L)

land_polygons <- list(
  matrix(c(-18, 37, -7, 36, 9, 37, 25, 33, 36, 31, 51, 13, 50, -7, 42, -35, 18, -35, 8, -18, -6, -6, -17, 14), ncol = 2, byrow = TRUE),
  matrix(c(-12, 39, 6, 42, 16, 46, 30, 42, 42, 38, 55, 34, 78, 30, 78, 62, -12, 62), ncol = 2, byrow = TRUE),
  matrix(c(34, 12, 43, 12, 56, 17, 58, 25, 48, 31, 39, 29, 34, 20), ncol = 2, byrow = TRUE),
  matrix(c(57, 5, 78, 6, 78, 31, 61, 31, 55, 24, 58, 14), ncol = 2, byrow = TRUE),
  matrix(c(43, -26, 51, -26, 51, -12, 46, -11, 43, -17), ncol = 2, byrow = TRUE)
)

water_holes <- list(
  matrix(c(-6, 31, 35, 31, 35, 39, -6, 39), ncol = 2, byrow = TRUE),
  matrix(c(27, 40, 42, 40, 42, 48, 27, 48), ncol = 2, byrow = TRUE),
  matrix(c(47, 36, 55, 36, 55, 48, 47, 48), ncol = 2, byrow = TRUE),
  matrix(c(32, 11, 44, 11, 44, 30, 32, 30), ncol = 2, byrow = TRUE),
  matrix(c(47, 24, 57, 24, 57, 31, 47, 31), ncol = 2, byrow = TRUE),
  matrix(c(39, -35, 53, -35, 53, 5, 46, 5, 43, -10, 41, -18), ncol = 2, byrow = TRUE)
)

# Helpers -------------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) y else x
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

write_json_file <- function(x, path, pretty = TRUE) {
  write_json(
    x = x,
    path = path,
    pretty = pretty,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
}

clean_text <- function(x) {
  str_trim(as.character(x %||% ""))
}

normalize_text <- function(x) {
  x |>
    clean_text() |>
    iconv(to = "ASCII//TRANSLIT") |>
    str_replace_all("[^A-Za-z0-9]+", " ") |>
    str_squish() |>
    str_to_lower()
}

unique_non_empty <- function(x) {
  x <- clean_text(x)
  x[x != ""] |>
    unique()
}

clean_afring_number <- function(x) {
  clean_text(x) |>
    str_replace("\\.0$", "")
}

split_crosswalk_ids <- function(x) {
  text <- clean_text(x)
  if (text == "") {
    return(character())
  }
  unique_non_empty(str_split(text, "\\s*;\\s*", simplify = FALSE)[[1]])
}

parse_bool_field <- function(value, field_name, row_label) {
  text <- str_to_upper(clean_text(value))
  if (text %in% c("TRUE", "T", "1", "YES")) {
    return(TRUE)
  }
  if (text %in% c("FALSE", "F", "0", "NO")) {
    return(FALSE)
  }
  cli_abort("Invalid boolean {.val {value}} for {.field {field_name}} in taxonomy row {.val {row_label}}.")
}

string_date_to_iso <- function(x) {
  text <- clean_text(x)
  if (text == "") {
    return(NULL)
  }

  if (str_detect(text, "^\\d{1,2}[.\\-/]\\d{1,2}[.\\-/]\\d{2,4}$")) {
    pieces <- str_split(text, "[.\\-/]", simplify = TRUE)
    day <- pieces[1]
    month <- pieces[2]
    year <- pieces[3]
    if (nchar(year) == 2) {
      year_num <- as.integer(year)
      year <- ifelse(year_num >= 70, paste0("19", year), paste0("20", year))
    }
    return(sprintf("%s-%02d-%02d", year, as.integer(month), as.integer(day)))
  }

  if (str_detect(text, "^\\d{4}-\\d{1,2}-\\d{1,2}$")) {
    pieces <- str_split(text, "-", simplify = TRUE)
    return(sprintf("%s-%02d-%02d", pieces[1], as.integer(pieces[2]), as.integer(pieces[3])))
  }

  if (str_detect(text, "^\\d{4}$")) {
    return(paste0(text, "-01-01"))
  }

  NULL
}

format_month_day <- function(iso_date) {
  substr(iso_date, 6, 10)
}

canonical_day_of_year <- function(month_day) {
  if (month_day == "02-29") {
    cli_abort("Phenology export does not support 02-29 because the website season axis uses a non-leap calendar.")
  }
  as.POSIXlt(as.Date(paste0("2001-", month_day)))$yday + 1L
}

first_or_empty <- function(x) {
  if (!length(x)) {
    return("")
  }
  x[[1]]
}

build_species_links <- function(avibase_id, cornell_species_code, birdlife_id, kbt_seq, abap_ids) {
  avibase_short_id <- str_replace(avibase_id %||% "", "^avibase-", "")
  list(
    birdsOfTheWorld = if (cornell_species_code != "") sprintf("https://birdsoftheworld.org/bow/species/%s", cornell_species_code) else "",
    eBird = if (cornell_species_code != "") sprintf("https://ebird.org/species/%s", cornell_species_code) else "",
    birdLifeFactsheet = if (birdlife_id != "") sprintf("https://datazone.birdlife.org/species/factsheet/%s", birdlife_id) else "",
    kenyaBirdTrends = if (kbt_seq != "") sprintf("https://kenyabirdtrends.co.ke/?mode=Species&species=%s", kbt_seq) else "",
    avibase = if (avibase_short_id != "") sprintf("https://avibase.bsc-eoc.org/species.jsp?avibaseid=%s", avibase_short_id) else "",
    kbm = map(abap_ids, ~ list(id = .x, url = sprintf("https://kenya.birdmap.africa/species/%s", .x))),
    safring = map(abap_ids, ~ list(id = .x, url = sprintf("https://safring.ringing.africa/species/%s", .x)))
  )
}

read_csv_rows <- function(path) {
  read_csv(path, show_col_types = FALSE, name_repair = "minimal") |>
    rename_with(~ str_remove(.x, "^\ufeff")) |>
    mutate(across(everything(), clean_text))
}

point_in_polygon <- function(lng, lat, polygon) {
  inside <- FALSE
  j <- nrow(polygon)
  for (i in seq_len(nrow(polygon))) {
    xi <- polygon[i, 1]
    yi <- polygon[i, 2]
    xj <- polygon[j, 1]
    yj <- polygon[j, 2]
    intersects <- ((yi > lat) != (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
    if (intersects) {
      inside <- !inside
    }
    j <- i
  }
  inside
}

is_land <- function(lng, lat) {
  inside_land <- any(map_lgl(land_polygons, \(polygon) point_in_polygon(lng, lat, polygon)))
  inside_water <- any(map_lgl(water_holes, \(polygon) point_in_polygon(lng, lat, polygon)))
  inside_land && !inside_water
}

grid_centers <- function() {
  dx <- (migration_bounds$east - migration_bounds$west) / migration_grid$width
  dy <- (migration_bounds$north - migration_bounds$south) / migration_grid$height

  crossing(
    y = seq_len(migration_grid$height) - 1L,
    x = seq_len(migration_grid$width) - 1L
  ) |>
    mutate(
      index = y * migration_grid$width + x,
      longitude = migration_bounds$west + (x + 0.5) * dx,
      latitude = migration_bounds$south + (y + 0.5) * dy,
      land = map2_lgl(longitude, latitude, is_land)
    )
}

normalize_surface <- function(values) {
  total <- sum(values)
  if (total <= 0) {
    return(rep(0, length(values)))
  }
  round(values / total, 9)
}

gaussian_surface <- function(points, cells, sigma_lng, sigma_lat, min_lat = NULL, max_lat = NULL) {
  values <- numeric(nrow(cells))
  for (i in seq_len(nrow(cells))) {
    cell <- cells[i, ]
    if (
      !cell$land ||
        (!is.null(min_lat) && cell$latitude <= min_lat) ||
        (!is.null(max_lat) && cell$latitude > max_lat)
    ) {
      next
    }

    density <- 0
    for (point in points) {
      density <- density + exp(
        -0.5 * (((cell$longitude - point$longitude) / sigma_lng)^2 + ((cell$latitude - point$latitude) / sigma_lat)^2)
      )
    }
    values[[i]] <- density
  }
  normalize_surface(values)
}

corridor_surface <- function(cells) {
  values <- numeric(nrow(cells))
  for (i in seq_len(nrow(cells))) {
    cell <- cells[i, ]
    if (!cell$land) {
      next
    }

    corridor_lng <- ngulia_coords$longitude + 0.12 * (cell$latitude - ngulia_coords$latitude)
    lateral <- exp(-0.5 * ((cell$longitude - corridor_lng) / 8.5)^2)
    north_south <- 0.35 + 0.65 * exp(-0.5 * ((cell$longitude - ngulia_coords$longitude) / 18)^2)
    values[[i]] <- lateral * north_south
  }
  normalize_surface(values)
}

outside_ngulia_latitude_band <- function(latitude) {
  latitude_band <- ngulia_exclusion_band_km / km_per_latitude_degree
  abs(latitude - ngulia_coords$latitude) > latitude_band
}

landing_cell_is_land <- function(latitude, longitude, land) {
  if (!land) {
    return(FALSE)
  }
  if (latitude < ngulia_coords$latitude && longitude > 37.5) {
    return(FALSE)
  }
  TRUE
}

# Taxonomy ------------------------------------------------------------------

cli_alert_info("Reading website taxonomy metadata")

taxonomy_rows <- read_csv_rows(taxonomy_crosswalk_path) |>
  mutate(
    include_processing = map2_lgl(include_processing, raw_label, parse_bool_field, field_name = "include_processing"),
    include_recovery = map2_lgl(include_recovery, raw_label, parse_bool_field, field_name = "include_recovery")
  )

taxonomy_errors <- character()

if (any(duplicated(taxonomy_rows$raw_label))) {
  taxonomy_errors <- c(
    taxonomy_errors,
    paste0("Duplicate raw_label entries: ", paste(unique(taxonomy_rows$raw_label[duplicated(taxonomy_rows$raw_label)]), collapse = ", "))
  )
}

included_taxonomy_rows <- taxonomy_rows |>
  filter(include_processing | include_recovery)

append_error_values <- function(values, prefix) {
  values <- values[!is.na(values) & values != ""]
  if (!length(values)) {
    return(character())
  }
  paste(prefix, paste(values, collapse = ", "))
}

taxonomy_errors <- c(
  taxonomy_errors,
  append_error_values(included_taxonomy_rows |> filter(avibase_id == "") |> pull(raw_label), "Included rows with blank avibase_id:"),
  append_error_values(included_taxonomy_rows |> filter(avilist_english_name == "") |> pull(raw_label), "Included rows with blank avilist_english_name:"),
  append_error_values(included_taxonomy_rows |> filter(avilist_scientific_name == "") |> pull(raw_label), "Included rows with blank avilist_scientific_name:"),
  append_error_values(taxonomy_rows |> filter(include_recovery & !include_processing) |> pull(raw_label), "Rows with include_recovery=TRUE and include_processing=FALSE:"),
  append_error_values(taxonomy_rows |> filter(include_recovery & birdlife_id == "") |> pull(raw_label), "Recovery rows with blank birdlife_id:")
)

code_conflicts <- taxonomy_rows |>
  filter(latin_abbreviation != "") |>
  distinct(latin_abbreviation, avibase_id) |>
  count(latin_abbreviation) |>
  filter(n > 1) |>
  pull(latin_abbreviation)

if (length(code_conflicts)) {
  taxonomy_errors <- c(taxonomy_errors, paste("Duplicate latin_abbreviation mapped to different avibase_id values:", paste(code_conflicts, collapse = ", ")))
}

species_by_id <- taxonomy_rows |>
  filter(include_processing, avibase_id != "") |>
  group_by(avibase_id) |>
  summarise(
    id = first(avibase_id),
    name_values = list(unique_non_empty(avilist_english_name)),
    latin_values = list(unique_non_empty(avilist_scientific_name)),
    birdlife_values = list(unique_non_empty(birdlife_id)),
    cornell_values = list(unique_non_empty(cornell_species_code)),
    kbt_values = list(unique_non_empty(kbt_seq)),
    abap_ids = list(unique_non_empty(unlist(map(abap_ids, split_crosswalk_ids)))),
    latin_abbreviations = list(unique_non_empty(latin_abbreviation)),
    ngulia_abbreviations = list(unique_non_empty(ngulia_abbreviation)),
    includeRecovery = any(include_recovery),
    rawLabels = list(unique_non_empty(raw_label)),
    .groups = "drop"
  ) |>
  rowwise() |>
  mutate(
    group_error = list(c(
      if (length(name_values) != 1) sprintf("Avibase group %s has inconsistent avilist_english_name values.", id),
      if (length(latin_values) != 1) sprintf("Avibase group %s has inconsistent avilist_scientific_name values.", id),
      if (length(birdlife_values) > 1) sprintf("Avibase group %s has inconsistent birdlife_id values.", id),
      if (length(cornell_values) > 1) sprintf("Avibase group %s has inconsistent cornell_species_code values.", id),
      if (length(kbt_values) > 1) sprintf("Avibase group %s has inconsistent kbt_seq values.", id)
    )),
    name = first_or_empty(name_values),
    latin = first_or_empty(latin_values),
    code = if (length(latin_abbreviations) == 1) latin_abbreviations[[1]] else paste(latin_abbreviations, collapse = "; "),
    nguliaCode = if (length(ngulia_abbreviations) == 1) ngulia_abbreviations[[1]] else paste(ngulia_abbreviations, collapse = "; "),
    birdlifeId = first_or_empty(birdlife_values),
    cornellSpeciesCode = first_or_empty(cornell_values),
    kbtSeq = first_or_empty(kbt_values),
    links = list(build_species_links(id, cornellSpeciesCode, birdlifeId, kbtSeq, abap_ids))
  ) |>
  ungroup()

group_errors <- unlist(species_by_id$group_error)
group_errors <- group_errors[group_errors != ""]
if (length(group_errors)) {
  taxonomy_errors <- c(taxonomy_errors, group_errors)
}

taxonomy_errors <- taxonomy_errors[!is.na(taxonomy_errors) & taxonomy_errors != ""]
if (length(taxonomy_errors)) {
  cli_abort(c("Invalid taxonomy crosswalk", set_names(taxonomy_errors, rep("x", length(taxonomy_errors)))))
}

species_by_id_lookup <- split(species_by_id, species_by_id$id)
species_by_id_lookup <- map(species_by_id_lookup, \(row) {
  row <- row[1, ]
  list(
    id = row$id,
    name = row$name,
    latin = row$latin,
    code = row$code,
    nguliaCode = row$nguliaCode,
    birdlifeId = row$birdlifeId,
    cornellSpeciesCode = row$cornellSpeciesCode,
    kbtSeq = row$kbtSeq,
    abapIds = row$abap_ids[[1]],
    includeRecovery = row$includeRecovery,
    rawLabels = row$rawLabels[[1]],
    links = row$links[[1]]
  )
})

species_reference <- read_csv_rows(species_reference_path)
clements_taxonomy <- read_csv_rows(clements_taxonomy_path)
clements_lookup <- split(clements_taxonomy, clements_taxonomy$`taxon concept ID`)
clements_lookup <- map(clements_lookup, \(row) as.list(row[1, ]))

afring_taxonomy <- species_reference |>
  mutate(afring_number = clean_afring_number(afring_number)) |>
  filter(afring_number != "")

afring_taxonomy <- pmap_dfr(
  as.list(afring_taxonomy),
  function(afring_number, latin_abbreviation, ngulia_number, avibase_id, common_name, scientific_name, ...) {
    avibase_id_value <- clean_text(avibase_id)
    species_meta <- species_by_id_lookup[[avibase_id_value]] %||% list()
    clements_row <- clements_lookup[[avibase_id_value]] %||% list()
    name <- clements_row$`English name` %||% common_name %||% species_meta$name %||% afring_number
    latin <- clements_row$`scientific name` %||% scientific_name %||% species_meta$latin %||% ""
    cornell_species_code <- clements_row$species_code %||% species_meta$cornellSpeciesCode %||% ""

    tibble(
      afring_number = afring_number,
      id = if (avibase_id_value != "") avibase_id_value else paste0("afring-", afring_number),
      name = name,
      latin = latin,
      code = latin_abbreviation %||% species_meta$code %||% cornell_species_code,
      nguliaCode = ngulia_number %||% species_meta$nguliaCode %||% "",
      birdlifeId = species_meta$birdlifeId %||% "",
      cornellSpeciesCode = cornell_species_code,
      kbtSeq = species_meta$kbtSeq %||% "",
      abapIds = list(species_meta$abapIds %||% character()),
      includeRecovery = species_meta$includeRecovery %||% FALSE,
      rawLabels = list(species_meta$rawLabels %||% c(name)),
      links = list(species_meta$links %||% build_species_links(avibase_id_value, cornell_species_code, "", "", character()))
    )
  }
)

avibase_taxonomy_lookup <- split(afring_taxonomy, afring_taxonomy$id)

# Dashboard -----------------------------------------------------------------

cli_alert_info("Building website dashboard exports")

unlink(file.path(paths$website_export_dir, c("dashboard.json", "recoveries.json", "migration-probabilities.json", "species-ranges-index.json")), force = TRUE)
unlink(file.path(paths$website_export_dir, c("photos", "species-ranges", "publications.json")), recursive = TRUE, force = TRUE)
ensure_dir(paths$website_export_dir)

daily_counts <- read_csv(daily_counts_path, show_col_types = FALSE) |>
  rename(date = ringing_date) |>
  mutate(
    avibase_id = clean_text(avibase_id),
    species_row = avibase_taxonomy_lookup[avibase_id]
  )

missing_avibase_ids <- daily_counts |>
  filter(map_lgl(species_row, is.null)) |>
  distinct(avibase_id) |>
  pull(avibase_id)

if (length(missing_avibase_ids)) {
  cli_abort(
    c(
      "Missing species reference rows.",
      set_names(
        paste("avibase_id", missing_avibase_ids, "missing from", species_reference_path),
        rep("x", length(missing_avibase_ids))
      )
    )
  )
}

daily_counts_enriched <- daily_counts |>
  mutate(
    count = as.integer(n_records),
    iso_date = map_chr(date, ~ string_date_to_iso(.x) %||% ""),
    year = if_else(season != "" & !is.na(as.integer(season)), as.integer(season), as.integer(substr(iso_date, 1, 4))),
    species_id = map_chr(species_row, ~ .x$id[[1]]),
    afring_number = map_chr(species_row, ~ .x$afring_number[[1]]),
    species_name = map_chr(species_row, ~ .x$name[[1]]),
    species_latin = map_chr(species_row, ~ .x$latin[[1]]),
    species_code = map_chr(species_row, ~ .x$code[[1]]),
    nguliaCode = map_chr(species_row, ~ .x$nguliaCode[[1]]),
    birdlifeId = map_chr(species_row, ~ .x$birdlifeId[[1]]),
    cornellSpeciesCode = map_chr(species_row, ~ .x$cornellSpeciesCode[[1]]),
    kbtSeq = map_chr(species_row, ~ .x$kbtSeq[[1]]),
    abapIds = map(species_row, ~ .x$abapIds[[1]]),
    includeRecovery = map_lgl(species_row, ~ .x$includeRecovery[[1]]),
    rawLabels = map(species_row, ~ .x$rawLabels[[1]]),
    links = map(species_row, ~ .x$links[[1]])
  ) |>
  filter(count > 0, !is.na(year), year > 0)

yearly <- daily_counts_enriched |>
  group_by(year) |>
  summarise(
    totalRings = sum(count),
    totalSpecies = n_distinct(species_id),
    .groups = "drop"
  ) |>
  arrange(year)

phenology_total <- daily_counts_enriched |>
  filter(iso_date != "") |>
  mutate(label = map_chr(iso_date, format_month_day), dayOfYear = map_int(label, canonical_day_of_year)) |>
  group_by(dayOfYear, label) |>
  summarise(count = sum(count), effortYears = n_distinct(year), .groups = "drop") |>
  arrange(dayOfYear)

species_annual <- daily_counts_enriched |>
  group_by(species_id, year) |>
  summarise(count = sum(count), .groups = "drop")

species_phenology <- daily_counts_enriched |>
  filter(iso_date != "") |>
  mutate(label = map_chr(iso_date, format_month_day), dayOfYear = map_int(label, canonical_day_of_year)) |>
  group_by(species_id, dayOfYear, label) |>
  summarise(count = sum(count), effortYears = n_distinct(year), .groups = "drop")

species_totals <- daily_counts_enriched |>
  group_by(species_id) |>
  summarise(
    afringNumber = first(afring_number),
    name = first(species_name),
    latin = first(species_latin),
    code = first(species_code),
    nguliaCode = first(nguliaCode),
    birdlifeId = first(birdlifeId),
    cornellSpeciesCode = first(cornellSpeciesCode),
    kbtSeq = first(kbtSeq),
    abapIds = list(first(abapIds)),
    includeRecovery = first(includeRecovery),
    rawLabels = list(first(rawLabels)),
    links = list(first(links)),
    total = sum(count),
    .groups = "drop"
  ) |>
  arrange(desc(total))

species_list <- pmap(
  species_totals,
  function(species_id, afringNumber, name, latin, code, nguliaCode, birdlifeId, cornellSpeciesCode, kbtSeq, abapIds, includeRecovery, rawLabels, links, total) {
    current_species_id <- species_id

    annual <- species_annual |>
      filter(species_id == current_species_id) |>
      arrange(year) |>
      transmute(year = as.integer(year), count = as.integer(count)) |>
      pmap(\(year, count) list(year = year, count = count)) |>
      unname()

    phenology <- species_phenology |>
      filter(species_id == current_species_id) |>
      arrange(dayOfYear) |>
      transmute(dayOfYear = as.integer(dayOfYear), label = label, count = as.integer(count), effortYears = as.integer(effortYears)) |>
      pmap(\(dayOfYear, label, count, effortYears) list(dayOfYear = dayOfYear, label = label, count = count, effortYears = effortYears)) |>
      unname()

    list(
      id = species_id,
      afringNumber = afringNumber,
      name = name,
      latin = latin,
      code = code,
      nguliaCode = nguliaCode,
      birdlifeId = birdlifeId,
      cornellSpeciesCode = cornellSpeciesCode,
      kbtSeq = kbtSeq,
      abapIds = abapIds,
      includeRecovery = includeRecovery,
      rawLabels = rawLabels,
      links = links,
      total = as.integer(total),
      annual = annual,
      phenology = phenology,
      photo = unname(photo_paths[species_id]) %||% NULL
    )
  }
) |>
  unname()

# Recoveries ----------------------------------------------------------------

cli_alert_info("Reading curated recoveries")

recoveries_table <- read_csv(
  recoveries_path,
  show_col_types = FALSE,
  col_types = cols(
    .default = col_character(),
    other_latitude = col_double(),
    other_longitude = col_double(),
    duration_days = col_double(),
    distance_km = col_double()
  )
)

recoveries_items <- pmap(
  recoveries_table,
  function(recovery_id, direction, encounter_type, avibase_id, common_name, ring_scheme, ring_number, ringing_date, encounter_date_edtf, report_date, other_site, other_region, other_country, other_latitude, other_longitude, coordinate_source, encounter_method, encounter_condition, mortality_cause_class, duration_days, distance_km, curation_status, curation_notes, ...) {
    species_meta <- species_by_id_lookup[[avibase_id]] %||% list()
    from_ngulia <- direction == "from_ngulia"

    list(
      id = recovery_id,
      status = if (from_ngulia) "ringed" else "controlled",
      direction = direction,
      encounterType = encounter_type,
      speciesId = avibase_id,
      speciesCode = species_meta$code %||% "",
      speciesName = common_name,
      speciesLatin = species_meta$latin %||% "",
      ringScheme = ring_scheme,
      ringNumber = ring_number,
      ringDate = ringing_date,
      ringDatePrecision = if (is.na(ringing_date)) "unknown" else "day",
      ringSite = if (from_ngulia) "Ngulia" else other_site,
      ringProvince = if (from_ngulia) "Tsavo West National Park" else other_region,
      ringCountry = if (from_ngulia) "Kenya" else other_country,
      method = encounter_method,
      encounterCondition = encounter_condition,
      mortalityCauseClass = mortality_cause_class,
      recoverDate = encounter_date_edtf,
      recoverDatePrecision = if (is.na(encounter_date_edtf)) "unknown" else if (grepl("/", encounter_date_edtf, fixed = TRUE)) "range" else c(`4` = "year", `7` = "month", `10` = "day")[[as.character(nchar(encounter_date_edtf))]],
      reportDate = report_date,
      recoverySite = if (from_ngulia) other_site else "Ngulia",
      recoveryProvince = if (from_ngulia) other_region else "Tsavo West National Park",
      recoveryCountry = if (from_ngulia) other_country else "Kenya",
      recoverSite = other_site,
      recoverProvince = other_region,
      recoverCountry = other_country,
      latitude = other_latitude,
      longitude = other_longitude,
      coordinateSource = if (is.na(coordinate_source)) "unknown" else coordinate_source,
      durationDays = if (is.na(duration_days)) NULL else duration_days,
      distanceKm = if (is.na(distance_km)) NULL else distance_km,
      curationStatus = curation_status,
      curationNotes = curation_notes
    )
  }
) |>
  unname()

recovery_countries <- recoveries_items |>
  map_chr("recoverCountry") |>
  unique_non_empty() |>
  sort()

farthest_recovery <- recoveries_items |>
  keep(~ !is.null(.x$distanceKm)) |>
  (\(x) if (length(x)) x[[which.max(map_dbl(x, "distanceKm"))]] else NULL)()

recoveries_by_species_id <- split(recoveries_items, map_chr(recoveries_items, "speciesId"))

recoveries <- list(
  summary = list(
    totalRecoveries = length(recoveries_items),
    totalCountries = length(recovery_countries),
    countries = recovery_countries,
    farthestRecovery = if (is.null(farthest_recovery)) NULL else list(
      speciesName = farthest_recovery$speciesName,
      country = farthest_recovery$recoverCountry,
      distanceKm = farthest_recovery$distanceKm
    )
  ),
  items = recoveries_items,
  bySpeciesId = map(recoveries_by_species_id, unname)
)

dashboard <- list(
  summary = list(
    totalBirds = as.integer(sum(daily_counts_enriched$count)),
    totalSpecies = length(species_list),
    yearStart = yearly$year[[1]],
    yearEnd = yearly$year[[nrow(yearly)]],
    totalRecoveries = recoveries$summary$totalRecoveries,
    recoveryCountries = recoveries$summary$totalCountries
  ),
  yearly = yearly |>
    pmap(\(year, totalRings, totalSpecies) list(year = as.integer(year), totalRings = as.integer(totalRings), totalSpecies = as.integer(totalSpecies))) |>
    unname(),
  phenology = phenology_total |>
    pmap(\(dayOfYear, label, count, effortYears) list(dayOfYear = as.integer(dayOfYear), label = label, count = as.integer(count), effortYears = as.integer(effortYears))) |>
    unname(),
  topSpecies = map(species_list[seq_len(min(15, length(species_list)))], \(species) {
    list(
      id = species$id,
      name = species$name,
      latin = species$latin,
      code = species$code,
      links = species$links,
      total = species$total,
      photo = species$photo
    )
  }) |>
    unname(),
  speciesExplorer = map(
    species_list,
    \(species) c(species, list(recoveries = unname(recoveries$bySpeciesId[[species$id]] %||% list())))
  ) |>
    unname()
)

# Species ranges ------------------------------------------------------------

species_ranges <- list(
  metadata = list(
    source = "Not generated by the research data pipeline",
    seasonalTypes = species_range_seasonal_types
  ),
  summary = list(
    totalSpecies = length(species_list),
    matchedSpecies = 0L,
    availableSpecies = 0L
  ),
  species = set_names(
    map(species_list, \(species) {
      list(
        id = species$id,
        name = species$name,
        latin = species$latin,
        birdlifeId = species$birdlifeId,
        available = FALSE,
        missingReason = "not-exported"
      )
    }),
    map_chr(species_list, "id")
  )
)

# Migration probabilities ---------------------------------------------------

cli_alert_info("Building migration probability export")

cells <- grid_centers()
landing_cells <- cells |>
  mutate(land = pmap_lgl(list(latitude, longitude, land), landing_cell_is_land))

recovery_points <- recoveries_items |>
  keep(~ .x$coordinateSource != "unknown" && .x$latitude >= -35 && .x$latitude <= 62 && .x$longitude >= -12 && .x$longitude <= 78)

northern_items <- recovery_points |>
  keep(~ .x$latitude > ngulia_coords$latitude && outside_ngulia_latitude_band(.x$latitude))

southern_items <- recovery_points |>
  keep(~ .x$latitude < ngulia_coords$latitude && outside_ngulia_latitude_band(.x$latitude))

departure_points <- northern_items |>
  keep(~ is_land(.x$longitude, .x$latitude)) |>
  map(~ list(latitude = .x$latitude, longitude = .x$longitude))
if (!length(departure_points)) {
  departure_points <- list(list(latitude = 42, longitude = 42))
}

landing_points <- southern_items |>
  keep(~ is_land(.x$longitude, .x$latitude)) |>
  map(~ list(latitude = .x$latitude, longitude = .x$longitude))
if (!length(landing_points)) {
  landing_points <- list(list(latitude = -15, longitude = 35))
}

migration_probabilities <- list(
  metadata = list(
    description = "Browser-sampled migration probability grids for the Ngulia home-page deck.gl prototype.",
    crs = "EPSG:4326",
    site = list(name = "Ngulia", latitude = ngulia_coords$latitude, longitude = ngulia_coords$longitude),
    normalization = "Each values array sums to one and can be sampled as a discrete probability distribution.",
    source = "Departure densities are smoothed from recoveries north of Ngulia; landing densities are smoothed from recoveries south of Ngulia.",
    landMask = "Coarse in-script land polygons with broad water holes for rapid prototype iteration.",
    exclusionBandKm = ngulia_exclusion_band_km
  ),
  bounds = migration_bounds,
  grid = migration_grid,
  landMask = as.list(cells$land),
  departure = list(
    label = "Northern departure probability",
    recordCount = length(northern_items),
    values = as.list(gaussian_surface(departure_points, cells, sigma_lng = 5.2, sigma_lat = 4.5, min_lat = ngulia_coords$latitude))
  ),
  landing = list(
    label = "Southern landing probability",
    recordCount = length(southern_items),
    values = as.list(gaussian_surface(landing_points, landing_cells, sigma_lng = 5.2, sigma_lat = 4.5, max_lat = ngulia_coords$latitude))
  ),
  movementSuitability = list(
    label = "Broad north-south corridor prior",
    values = as.list(corridor_surface(cells))
  )
)

# Write outputs -------------------------------------------------------------

write_json_file(dashboard, file.path(paths$website_export_dir, "dashboard.json"))
write_json_file(recoveries, file.path(paths$website_export_dir, "recoveries.json"))
write_json_file(species_ranges, file.path(paths$website_export_dir, "species-ranges-index.json"))
write_json_file(migration_probabilities, file.path(paths$website_export_dir, "migration-probabilities.json"), pretty = FALSE)

cli_alert_success("Website exports written to {.file {paths$website_export_dir}}")
cli_alert_info("{length(dashboard$speciesExplorer)} species, {recoveries$summary$totalRecoveries} recoveries")
