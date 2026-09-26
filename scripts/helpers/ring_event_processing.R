clean_ring_number <- function(x) {
  blank_to_na(x) |>
    str_to_upper() |>
    str_replace_all("\\s+", "") |>
    str_replace_all("[^A-Z0-9/-]", "")
}

standardize_retrap_code <- function(x) {
  blank_to_na(x) |>
    str_to_upper()
}

standardize_ringer_code <- function(x) {
  x_clean <- blank_to_na(x) |>
    str_to_upper() |>
    str_remove("[[:punct:]]+$")

  if_else(str_detect(x_clean, "^[0-9]{3}$"), x_clean, NA_character_)
}

standardize_ringer_initial <- function(x) {
  blank_to_na(x) |>
    str_to_upper() |>
    str_remove_all("[^A-Z0-9]+")
}

is_restorable_same_day_ignore <- function(x) {
  clean_key(x) %in% c(
    "values differ kept first row arbitrarily",
    "exact duplicate kept first row",
    "only date raw differs kept row with 2008 date"
  )
}

standardize_sex <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  case_when(
    is.na(x_clean) ~ NA_character_,
    x_clean %in% c("0", "?", "Unknown") ~ NA_character_,
    x_clean %in% c("1", "M", "m", "Male") ~ "M",
    x_clean %in% c("2", "F", "f", "Female") ~ "F",
    x_clean %in% c("3", "(M)", "Male?") ~ "M?",
    x_clean %in% c("4", "(F)", "Female?") ~ "F?",
    TRUE ~ NA_character_
  )
}

is_valid_sex_value <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  is.na(x_clean) |
    x_clean %in%
      c(
        "0",
        "1",
        "2",
        "3",
        "4",
        "?",
        "Unknown",
        "Male",
        "Female",
        "Male?",
        "Female?",
        "M",
        "m",
        "F",
        "f",
        "(M)",
        "(F)"
      )
}

is_uncertain_age_value <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish() |> str_remove_all("\\s+")
  x_clean %in% c("2(3)", "2(4)", "3(2)", "3?", "?3")
}

is_unusual_age_value <- function(x) {
  blank_to_na(x) |> str_squish() %in% c("7", "9")
}

standardize_age <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  # EURING age is plumage-based and rolls over on 1 January.
  # In practice this means code 5 can appear for birds that would have been
  # coded 3 before year-end, and code 6 for birds that would have been coded 4.
  valid_age <- as.character(0:9)
  case_when(
    is.na(x_clean) ~ "0",
    is_uncertain_age_value(x_clean) ~ "2",
    x_clean %in% valid_age ~ x_clean,
    TRUE ~ "0"
  )
}

is_valid_age_value <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  valid_age <- as.character(0:9)
  is.na(x_clean) | is_uncertain_age_value(x_clean) | x_clean %in% valid_age
}

standardize_fat_kaiser <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  x_clean <- str_replace(x_clean, ",", ".")
  numeric_x <- suppressWarnings(as.numeric(x_clean))
  numeric_is_integer <- !is.na(numeric_x) & abs(numeric_x - round(numeric_x)) < 1e-8
  mapped_integer <- if_else(
    numeric_is_integer,
    as.character(as.integer(round(numeric_x))),
    NA_character_
  )

  case_when(
    is.na(x_clean) ~ NA_character_,
    x_clean %in% as.character(0:8) ~ x_clean,
    x_clean %in% c("?", "Unknown") ~ NA_character_,
    mapped_integer %in% as.character(0:8) ~ mapped_integer,
    TRUE ~ NA_character_
  )
}

is_valid_fat_kaiser_value <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  x_clean <- str_replace(x_clean, ",", ".")
  numeric_x <- suppressWarnings(as.numeric(x_clean))
  numeric_is_integer <- !is.na(numeric_x) & abs(numeric_x - round(numeric_x)) < 1e-8
  mapped_integer <- if_else(
    numeric_is_integer,
    as.character(as.integer(round(numeric_x))),
    NA_character_
  )

  is.na(x_clean) |
    x_clean %in% c("?", "Unknown", as.character(0:8)) |
    mapped_integer %in% as.character(0:8)
}

standardize_fat_ngulia <- function(x) {
  fat_ngulia <- standardize_fat_kaiser(x)
  if_else(fat_ngulia %in% as.character(0:4), fat_ngulia, NA_character_)
}

is_valid_fat_ngulia_value <- function(x) {
  x_clean <- blank_to_na(x) |> str_squish()
  is.na(x_clean) | x_clean %in% c("?", "Unknown") | !is.na(standardize_fat_ngulia(x))
}

parse_measurement <- function(x) {
  x_clean <- blank_to_na(x)
  decimal_comma <- !is.na(x_clean) & str_detect(x_clean, "^[0-9]+,[0-9]+$")
  x_clean[decimal_comma] <- str_replace(x_clean[decimal_comma], ",", ".")
  suppressWarnings(as.numeric(x_clean))
}

add_measurement_validation <- function(data, measurement_ranges) {
  global_ranges <- measurement_ranges |>
    filter(afring_number == "all") |>
    select(wing_min, wing_max, weight_min, weight_max)

  species_ranges <- measurement_ranges |>
    filter(afring_number != "all") |>
    select(afring_number, wing_min, wing_max, weight_min, weight_max)

  data |>
    left_join(species_ranges, by = "afring_number") |>
    mutate(
      wing_min = coalesce(wing_min, global_ranges$wing_min),
      wing_max = coalesce(wing_max, global_ranges$wing_max),
      weight_min = coalesce(weight_min, global_ranges$weight_min),
      weight_max = coalesce(weight_max, global_ranges$weight_max),
      wing_value = parse_measurement(wing_raw),
      weight_value = parse_measurement(weight_raw),
      fat_ngulia_valid = is_valid_fat_ngulia_value(fat_ngulia_raw),
      fat_ngulia_value = standardize_fat_ngulia(fat_ngulia_raw),
      fat_kaiser_valid = is_valid_fat_kaiser_value(fat_kaiser_raw),
      fat_kaiser_value = standardize_fat_kaiser(fat_kaiser_raw),
      wing_not_numeric = !is.na(blank_to_na(wing_raw)) & is.na(wing_value),
      weight_not_numeric = !is.na(blank_to_na(weight_raw)) & is.na(weight_value),
      wing_out_of_range = !is.na(wing_value) &
        !between(wing_value, wing_min, wing_max),
      weight_out_of_range = !is.na(weight_value) &
        !between(weight_value, weight_min, weight_max),
      fat_ngulia_invalid = !is.na(blank_to_na(fat_ngulia_raw)) & !fat_ngulia_valid,
      fat_kaiser_invalid = !is.na(blank_to_na(fat_kaiser_raw)) & !fat_kaiser_valid,
      wing = if_else(
        wing_not_numeric | wing_out_of_range,
        NA_character_,
        as.character(wing_value)
      ),
      weight = if_else(
        weight_not_numeric | weight_out_of_range,
        NA_character_,
        as.character(weight_value)
      ),
      fat_ngulia = if_else(fat_ngulia_invalid, NA_character_, as.character(fat_ngulia_value)),
      fat_kaiser = if_else(fat_kaiser_invalid, NA_character_, as.character(fat_kaiser_value))
    )
}

match_single_type <- function(row_keys, lookup, input_type) {
  keys <- row_keys |>
    filter(!is.na(key_clean), key_clean != "") |>
    distinct(key_clean)
  if (nrow(keys) == 0) {
    return(
      row_keys |>
        transmute(
          row_id,
          afring_number = NA_character_
        )
    )
  }

  key_matches <- keys |>
    left_join(
      filter(lookup, input_type == !!input_type) |>
        select(input_text, afring_number),
      by = c("key_clean" = "input_text")
    )

  row_keys |>
    left_join(key_matches, by = "key_clean") |>
    transmute(row_id, afring_number)
}

match_label_stage <- function(label_rows, lookup, input_type) {
  labels <- label_rows |>
    filter(!is.na(label_key), label_key != "") |>
    distinct(label_key)
  if (nrow(labels) == 0) {
    return(
      label_rows |>
        transmute(
          row_id,
          label_afring_number = NA_character_,
          label_match_key_type = NA_character_
        )
    )
  }

  label_matches <- labels |>
    left_join(
      filter(lookup, input_type == !!input_type) |>
        select(input_text, afring_number),
      by = c("label_key" = "input_text")
    )

  label_rows |>
    left_join(label_matches, by = "label_key") |>
    transmute(
      row_id,
      label_afring_number = afring_number,
      label_match_key_type = if_else(
        !is.na(afring_number),
        input_type,
        NA_character_
      )
    )
}

match_species <- function(data, species_lookup) {
  species_no_matches <- match_single_type(
    data |>
      transmute(row_id, key_clean = clean_number_key(species_no_raw)),
    species_lookup,
    "afring_number"
  ) |>
    rename(matched_species_no_raw = afring_number)

  species_ngulia_number_matches <- match_single_type(
    data |>
      transmute(row_id, key_clean = clean_number_key(species_ngulia_raw)),
    species_lookup,
    "ngulia_number"
  ) |>
    rename(matched_species_ngulia_number_raw = afring_number)

  ngulia_text_matches <- data |>
    transmute(
      row_id,
      label_key = clean_key(species_ngulia_raw),
      label_afring_number = NA_character_,
      label_match_key_type = NA_character_
    )

  label_matches <- data |>
    transmute(
      row_id,
      label_key = clean_key(species_label_raw),
      label_afring_number = NA_character_,
      label_match_key_type = NA_character_
    )

  label_key_types <- c(
    "latin_abbreviation",
    "ngulia_abbreviation",
    "ngulia_abbreviation_2",
    "english",
    "scientific_name",
    "english_avilist"
  )

  ngulia_text_key_types <- c(
    "ngulia_abbreviation",
    "ngulia_abbreviation_2",
    "latin_abbreviation",
    "english",
    "scientific_name",
    "english_avilist"
  )

  for (input_type in ngulia_text_key_types) {
    unresolved_rows <- ngulia_text_matches |>
      filter(
        is.na(label_afring_number),
        !is.na(label_key),
        label_key != ""
      )
    if (nrow(unresolved_rows) == 0) {
      break
    }

    stage_matches <- match_label_stage(
      unresolved_rows |>
        select(row_id, label_key),
      species_lookup,
      input_type
    )

    ngulia_text_matches <- ngulia_text_matches |>
      left_join(
        rename_with(stage_matches, ~ paste0(.x, "_stage"), -row_id),
        by = "row_id"
      ) |>
      mutate(
        label_afring_number = coalesce(
          label_afring_number,
          label_afring_number_stage
        ),
        label_match_key_type = coalesce(
          label_match_key_type,
          label_match_key_type_stage
        )
      ) |>
      select(
        -label_afring_number_stage,
        -label_match_key_type_stage
      )
  }

  for (input_type in label_key_types) {
    unresolved_rows <- label_matches |>
      filter(
        is.na(label_afring_number),
        !is.na(label_key),
        label_key != ""
      )
    if (nrow(unresolved_rows) == 0) {
      break
    }

    stage_matches <- match_label_stage(
      unresolved_rows |>
        select(row_id, label_key),
      species_lookup,
      input_type
    )

    label_matches <- label_matches |>
      left_join(
        rename_with(stage_matches, ~ paste0(.x, "_stage"), -row_id),
        by = "row_id"
      ) |>
      mutate(
        label_afring_number = coalesce(
          label_afring_number,
          label_afring_number_stage
        ),
        label_match_key_type = coalesce(
          label_match_key_type,
          label_match_key_type_stage
        )
      ) |>
      select(
        -label_afring_number_stage,
        -label_match_key_type_stage
      )
  }

  data |>
    left_join(species_no_matches, by = "row_id") |>
    left_join(species_ngulia_number_matches, by = "row_id") |>
    left_join(
      ngulia_text_matches |>
        transmute(
          row_id,
          matched_species_ngulia_text_raw = label_afring_number,
          matched_species_ngulia_text_raw_key_type = label_match_key_type
        ),
      by = "row_id"
    ) |>
    left_join(
      label_matches |>
        transmute(
          row_id,
          matched_species_label_raw = label_afring_number,
          matched_species_label_raw_key_type = label_match_key_type
        ),
      by = "row_id"
    ) |>
    mutate(
      afring_number = case_when(
        !is.na(matched_species_no_raw) ~ matched_species_no_raw,
        !is.na(matched_species_ngulia_number_raw) ~
          matched_species_ngulia_number_raw,
        !is.na(matched_species_ngulia_text_raw) ~
          matched_species_ngulia_text_raw,
        !is.na(matched_species_label_raw) ~ matched_species_label_raw,
        TRUE ~ NA_character_
      ),
      species_match_key_type = case_when(
        !is.na(matched_species_no_raw) ~ "afring_number",
        !is.na(matched_species_ngulia_number_raw) ~ "ngulia_number",
        !is.na(matched_species_ngulia_text_raw) ~
          matched_species_ngulia_text_raw_key_type,
        !is.na(matched_species_label_raw) ~ matched_species_label_raw_key_type,
        TRUE ~ NA_character_
      ),
      species_sources_used_n = (!is.na(matched_species_no_raw)) +
        (!is.na(coalesce(
          matched_species_ngulia_number_raw,
          matched_species_ngulia_text_raw
        ))) +
        (!is.na(matched_species_label_raw)),
      species_disagreement_n = purrr::pmap_int(
        list(
          matched_species_no_raw,
          coalesce(
            matched_species_ngulia_number_raw,
            matched_species_ngulia_text_raw
          ),
          matched_species_label_raw
        ),
        \(species_no_value, species_ngulia_value, species_label_value) {
          values <- c(
            species_no_value,
            species_ngulia_value,
            species_label_value
          )
          n_distinct(values[!is.na(values)])
        }
      ),
      species_disagreement_flag = species_sources_used_n >= 2 &
        species_disagreement_n > 1,
      species_used_note = case_when(
        species_match_key_type == "afring_number" ~ "Used species_no_raw",
        species_match_key_type == "ngulia_number" ~ "Used species_ngulia_raw",
        species_match_key_type %in% ngulia_text_key_types ~ paste0(
          "Used species_ngulia_raw via ",
          species_match_key_type
        ),
        species_match_key_type %in% label_key_types ~ paste0(
          "Used species_label_raw via ",
          species_match_key_type
        ),
        TRUE ~ NA_character_
      )
    ) |>
    select(-species_disagreement_n, -species_sources_used_n)
}

join_note_parts <- function(parts) {
  parts <- blank_to_na(parts)
  parts <- parts[!is.na(parts)]
  parts <- parts[!duplicated(parts)]
  if (length(parts) == 0) {
    return(NA_character_)
  }
  paste(parts, collapse = "|")
}

merge_same_day_value <- function(values) {
  values <- blank_to_na(values)
  non_missing <- values[!is.na(values)]
  unique_non_missing <- unique(non_missing)

  if (length(unique_non_missing) == 0) {
    return(list(value = NA_character_, disagreement = NA_character_))
  }

  if (length(unique_non_missing) == 1) {
    return(list(value = unique_non_missing[[1]], disagreement = NA_character_))
  }

  list(
    value = non_missing[[1]],
    disagreement = paste(unique_non_missing, collapse = " vs ")
  )
}

format_source_rows <- function(data) {
  paste(
    paste0(data$source_file, "/", data$source_sheet, "/", data$source_row),
    collapse = ", "
  )
}

restore_same_day_ignored_rows <- function(data) {
  annotated <- data |>
    mutate(
      ignored_flag = coalesce(
        str_to_lower(blank_to_na(row_action)) == "ignore",
        FALSE
      ),
      restorable_ignore = ignored_flag & is_restorable_same_day_ignore(row_action_note)
    )

  restorable_groups <- annotated |>
    filter(
      clean_required,
      !is.na(ringNumber),
      !is.na(ringing_date)
    ) |>
    group_by(ringNumber, ringing_date) |>
    summarise(
      group_n = n(),
      restorable_ignored_n = sum(restorable_ignore, na.rm = TRUE),
      .groups = "drop"
    ) |>
    filter(group_n > 1, restorable_ignored_n > 0) |>
    transmute(
      ringNumber,
      ringing_date,
      restore_ignore_group = TRUE
    )

  annotated |>
    left_join(restorable_groups, by = c("ringNumber", "ringing_date")) |>
    mutate(
      restore_ignore_group = coalesce(restore_ignore_group, FALSE),
      include_row = !ignored_flag | (restorable_ignore & restore_ignore_group)
    ) |>
    filter(include_row) |>
    mutate(clean_required = clean_required & include_row) |>
    select(-include_row)
}

build_same_day_group_summary <- function(data) {
  group_rows <- data |>
    filter(
      clean_required,
      !is.na(ringNumber),
      !is.na(ringing_date)
    ) |>
    arrange(ringNumber, ringing_date, datetime, source_file, source_sheet, source_row) |>
    add_count(ringNumber, ringing_date, name = "same_day_group_n") |>
    filter(same_day_group_n > 1) |>
    group_by(ringNumber, ringing_date) |>
    mutate(same_day_group_row_rank = row_number()) |>
    ungroup()

  if (nrow(group_rows) == 0) {
    return(tibble())
  }

  group_rows |>
    group_by(ringNumber, ringing_date) |>
    summarise(
      same_day_group_n = first(same_day_group_n),
      same_day_group_id = paste0(first(ringNumber), "__", first(ringing_date)),
      merged_row_id = first(row_id),
      merged_source_file = first(source_file),
      merged_source_sheet = first(source_sheet),
      merged_source_row = first(source_row),
      merged_year = first(year),
      same_day_group_source_rows = format_source_rows(
        pick(source_file, source_sheet, source_row)
      ),
      same_day_group_species_values = paste(sort(unique(afring_number)), collapse = "|"),
      same_day_group_species_n = n_distinct(afring_number),
      same_day_group_retrap_values = paste(
        sort(unique(standardize_retrap_code(retrap_code_raw)[!is.na(standardize_retrap_code(retrap_code_raw))])),
        collapse = "|"
      ),
      .groups = "drop"
    ) |>
    filter(same_day_group_n > 1)
}

collapse_same_day_retraps <- function(data, same_day_groups) {
  if (nrow(same_day_groups) == 0) {
    return(data)
  }

  grouped_keys <- same_day_groups |>
    select(ringNumber, ringing_date)

  grouped_rows <- data |>
    semi_join(
      grouped_keys,
      by = c("ringNumber", "ringing_date")
    ) |>
    filter(clean_required) |>
    arrange(ringNumber, ringing_date, datetime, source_file, source_sheet, source_row)

  merged_rows <- grouped_rows |>
    group_by(ringNumber, ringing_date) |>
    group_modify(\(.x, .y) {
      merged <- .x[1, ]
      disagreement_notes <- character()

      for (field in c(
        "afring_number",
        "age",
        "sex",
        "wing",
        "weight",
        "fat_ngulia",
        "fat_kaiser",
        "retrap_code_raw",
        "plumage_raw",
        "race_form_raw"
      )) {
        merged_value <- merge_same_day_value(.x[[field]])
        merged[[field]] <- merged_value$value
        if (!is.na(merged_value$disagreement) && field != "note_raw") {
          disagreement_notes <- c(
            disagreement_notes,
            paste0(
              field,
              " disagreement within same-day retrap group; kept first value (",
              merged_value$disagreement,
              ")"
            )
          )
        }
      }

      merged$note_raw <- join_note_parts(c(.x$note_raw, disagreement_notes))
      merged
    }) |>
    ungroup()

  data |>
    filter(!clean_required) |>
    bind_rows(
      data |>
        anti_join(grouped_keys, by = c("ringNumber", "ringing_date"))
    ) |>
    bind_rows(merged_rows) |>
    arrange(source_file, source_sheet, source_row)
}

add_retrap_history_flags <- function(data, same_day_groups) {
  retrap_candidates <- data |>
    filter(
      clean_required,
      !is.na(ringNumber),
      !is.na(ringing_date)
    ) |>
    select(
      row_id,
      ringNumber,
      ringing_date,
      datetime,
      source_file,
      source_sheet,
      source_row,
      retrap_code_raw,
      ring_history_action
    ) |>
    arrange(ringNumber, ringing_date, datetime, source_file, source_sheet, source_row) |>
    mutate(
      retrap_code_clean = standardize_retrap_code(retrap_code_raw),
      retrap_code_is_retrap = coalesce(retrap_code_clean == "2", FALSE),
      retrap_code_is_new = case_when(
        ring_history_action == "new_assignment" ~ TRUE,
        ring_history_action == "same_assignment" ~ FALSE,
        TRUE ~ !is.na(retrap_code_clean) &
          !retrap_code_clean %in% c("2", "X")
      ),
      ring_history_basis = case_when(
        !is.na(ring_history_action) ~ paste0("review:", ring_history_action),
        retrap_code_is_new ~ paste0("raw_code:", retrap_code_clean),
        TRUE ~ "ring_history"
      )
    ) |>
    group_by(ringNumber) |>
    mutate(
      has_prior_ring_number_history = row_number() > 1L,
      ring_number_collision = retrap_code_is_new & has_prior_ring_number_history,
      ring_history_group_number = cumsum(row_number() == 1L | retrap_code_is_new),
      ring_history_group_id = paste0(
        ringNumber,
        "__A",
        str_pad(ring_history_group_number, width = 2L, pad = "0")
      )
    ) |>
    ungroup() |>
    group_by(ring_history_group_id) |>
    mutate(
      prior_ringing_date = lag(ringing_date),
      has_prior_ring_history = row_number() > 1L,
      retrap_without_prior_event = retrap_code_is_retrap &
        !has_prior_ring_history,
      retrap = has_prior_ring_history | retrap_code_is_retrap,
      retrap_code_inconsistent = retrap_code_is_new & retrap
    ) |>
    ungroup() |>
    select(
      row_id,
      ring_history_group_id,
      ring_history_group_number,
      ring_history_basis,
      prior_ringing_date,
      has_prior_ring_history,
      has_prior_ring_number_history,
      ring_number_collision,
      retrap_without_prior_event,
      retrap,
      retrap_code_clean,
      retrap_code_inconsistent
    )

  data |>
    left_join(
      same_day_groups |>
        transmute(
          row_id = merged_row_id,
          same_day_group_source_rows,
          same_day_group_retrap_values
        ),
      by = "row_id"
    ) |>
    left_join(retrap_candidates, by = "row_id") |>
    mutate(
      has_prior_ring_history = coalesce(has_prior_ring_history, FALSE),
      has_prior_ring_number_history = coalesce(
        has_prior_ring_number_history,
        FALSE
      ),
      ring_number_collision = coalesce(ring_number_collision, FALSE),
      retrap_without_prior_event = coalesce(
        retrap_without_prior_event,
        FALSE
      ),
      retrap = coalesce(retrap, FALSE),
      retrap_code_inconsistent = coalesce(retrap_code_inconsistent, FALSE)
    )
}

add_ring_species_conflict_flags <- function(data) {
  conflict_rings <- data |>
    filter(
      keep_year,
      clean_required,
      !is.na(ring_history_group_id),
      !is.na(afring_number)
    ) |>
    distinct(ring_history_group_id, afring_number) |>
    group_by(ring_history_group_id) |>
    summarise(
      ring_species_values = paste(sort(unique(afring_number)), collapse = "|"),
      ring_species_n = n(),
      .groups = "drop"
    ) |>
    filter(ring_species_n > 1) |>
    transmute(
      ring_history_group_id,
      ring_species_conflict = TRUE,
      ring_species_values
    )

  data |>
    left_join(conflict_rings, by = "ring_history_group_id") |>
    mutate(ring_species_conflict = coalesce(ring_species_conflict, FALSE))
}

clean_data <- function(raw_data, species_lookup, measurement_ranges) {
  cli_alert_info("Cleaning {nrow(raw_data)} imported rows")
  cleaned <- raw_data |>
    mutate(
      row_id = row_number(),
      parsed_date = parse_date_vector(date_raw, day_raw, month_raw, year_raw),
      parsed_time = parse_time_vector(time_raw),
      datetime_precision = if_else(is.na(parsed_time), "date", "datetime"),
      datetime_text = case_when(
        is.na(parsed_date) ~ NA_character_,
        is.na(parsed_time) ~ paste(parsed_date, "00:00"),
        TRUE ~ paste(parsed_date, parsed_time)
      ),
      datetime = suppressWarnings(ymd_hm(datetime_text, tz = "UTC")),
      datetime = if_else(
        overwrite_year & !is.na(datetime),
        update(datetime, year = year_min),
        datetime
      ),
      parsed_date = if_else(
        !is.na(datetime),
        as.Date(datetime),
        parsed_date
      ),
      datetime = if_else(
        raw_date_is_ringing_date &
          !is.na(datetime) &
          !is.na(parsed_time) &
          hour(datetime) >= 20L,
        datetime - days(1),
        datetime
      ),
      ringing_date = if_else(
        raw_date_is_ringing_date,
        parsed_date,
        assign_daily_count_date(datetime)
      ),
      parsed_year = year(datetime),
      year = year(ringing_date),
      month = month(ringing_date),
      age_valid = is_valid_age_value(age_raw),
      age = standardize_age(age_raw),
      sex_valid = is_valid_sex_value(sex_raw),
      sex = standardize_sex(sex_raw),
      ringNumber = clean_ring_number(ringNumber_raw)
    ) |>
    match_species(species_lookup) |>
    add_measurement_validation(measurement_ranges) |>
    mutate(
      afring_number_matched = afring_number,
      species_missing_flag = is.na(species_raw),
      species_unmatched_flag = !species_missing_flag &
        is.na(afring_number_matched),
      species_export_unknown_flag = species_missing_flag |
        species_unmatched_flag |
        species_disagreement_flag,
      afring_number = if_else(
        species_export_unknown_flag,
        "0",
        afring_number_matched
      ),
      exclude_lost_or_destroyed_ring_flag = coalesce(
        afring_number_matched == "9999",
        FALSE
      ),
      exclude_recovery_flag = coalesce(standardize_retrap_code(retrap_code_raw) == "X", FALSE),
      valid_month = month %in% c(10L, 11L, 12L, 1L),
      valid_year = !is.na(year) &
        ((year >= year_min & year <= year_max) |
          (month == 1L & year >= year_min + 1L & year <= year_max + 1L)),
      season = assign_season_from_date(ringing_date),
      keep_year = (is.na(keep_year_min) | year >= keep_year_min) &
        (is.na(keep_year_max) | year <= keep_year_max),
      clean_required = !is.na(datetime) &
        valid_month &
        valid_year &
        keep_year &
        !is.na(afring_number) &
        !is.na(ringNumber) &
        !exclude_lost_or_destroyed_ring_flag &
        !exclude_recovery_flag
    )
  temp_species_numbers <- suppressWarnings(as.integer(cleaned$afring_number))
  temp_species_n <- sum(
    !is.na(temp_species_numbers) & temp_species_numbers < 0,
    na.rm = TRUE
  )
  if (temp_species_n > 0) {
    cli_warn(
      "{temp_species_n} rows matched a temporary AFRING number. The true AFRING number is still missing."
    )
  }
  cli_alert_success("Finished cleaning data")
  cleaned
}
