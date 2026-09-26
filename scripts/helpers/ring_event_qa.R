make_issue <- function(
  data,
  condition,
  issue_type,
  field,
  value_col,
  detail,
  action,
  action_detail,
  detail_col = NULL
) {
  issues <- data |>
    filter(keep_year, {{ condition }}) |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      datetime = case_when(
        is.na(parsed_date) ~ NA_character_,
        datetime_precision == "date" ~ format(parsed_date, "%Y-%m-%d"),
        TRUE ~ format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      ringNumber,
      issue_type = issue_type,
      field = field,
      value = as_chr(.data[[value_col]]),
      detail = detail,
      action = action,
      action_detail = action_detail
    )

  if (!is.null(detail_col)) {
    issues$detail <- data |>
      filter(keep_year, {{ condition }}) |>
      pull(all_of(detail_col))
  }

  issues
}

build_issues <- function(raw_data, merged_data, same_day_groups) {
  raw_data <- raw_data |>
    mutate(
      wing_range_detail = paste0(
        "Wing value is outside the allowed range ",
        wing_min, "-", wing_max, " mm for AFRING species ", afring_number, "."
      ),
      weight_range_detail = paste0(
        "Weight value is outside the allowed range ",
        weight_min, "-", weight_max, " g for AFRING species ", afring_number, "."
      )
    )

  base_issues <- bind_rows(
    make_issue(
      raw_data,
      is.na(datetime),
      "missing_or_invalid_datetime",
      "datetime",
      "date_raw",
      "Datetime could not be parsed from date/time fields.",
      "exclude_row",
      "Row is excluded from clean output because datetime is required."
    ),
    make_issue(
      raw_data,
      !is.na(datetime) & !valid_month,
      "datetime_month_outside_season",
      "datetime",
      "date_raw",
      "Month is not October, November, December, or January.",
      "exclude_row",
      "Row is excluded from clean output because month is outside the ringing season."
    ),
    make_issue(
      raw_data,
      !is.na(datetime) & !valid_year,
      "datetime_year_outside_file_range",
      "datetime",
      "date_raw",
      "Year does not match file range, allowing January in the following calendar year.",
      "exclude_row",
      "Row is excluded from clean output because year does not match the file range."
    ),
    make_issue(
      raw_data,
      species_missing_flag,
      "missing_species",
      "species",
      "species_raw",
      "No raw species value found.",
      "replace_species_unknown",
      "Row is exported with afring_number = 0."
    ),
    make_issue(
      raw_data,
      species_unmatched_flag,
      "species_unmatched",
      "species",
      "species_raw",
      "Species could not be matched to lookup with AFRING number.",
      "replace_species_unknown",
      "Row is exported with afring_number = 0."
    ),
    make_issue(
      raw_data,
      exclude_lost_or_destroyed_ring_flag,
      "lost_or_destroyed_ring",
      "species",
      "species_raw",
      "Source value maps to AFRING code 9999 (lost or destroyed ring).",
      "exclude_row",
      "Row is excluded because it does not represent a taxon occurrence."
    ),
    make_issue(
      raw_data,
      is.na(ringNumber),
      "missing_ringNumber",
      "ringNumber",
      "ringNumber_raw",
      "No ring number found.",
      "exclude_row",
      "Row is excluded from clean output because ringNumber is required."
    ),
    make_issue(
      raw_data,
      !age_valid,
      "age_invalid",
      "age",
      "age_raw",
      "Age value is not in the allowed age mapping and was replaced with 0.",
      "replace_age_unknown",
      "Row is exported with age = 0."
    ),
    make_issue(
      raw_data,
      is_uncertain_age_value(age_raw),
      "age_uncertain",
      "age",
      "age_raw",
      "Source age notation is uncertain.",
      "standardize_age_unknown",
      "Row is exported with EURING age = 2 and the original value is retained in ring_note."
    ),
    make_issue(
      raw_data,
      is_unusual_age_value(age_raw),
      "age_unusual",
      "age",
      "age_raw",
      "Age is a valid but unusual EURING code for the Ngulia species and may be an entry error.",
      "retain_with_warning",
      "Original age is retained and a warning is appended to ring_note."
    ),
    make_issue(
      raw_data,
      !sex_valid,
      "sex_invalid",
      "sex",
      "sex_raw",
      "Sex value is not in the allowed mapping and was replaced with Unknown.",
      "replace_sex_unknown",
      "Row is exported with sex = Unknown."
    ),
    make_issue(
      raw_data,
      wing_not_numeric,
      "wing_not_numeric",
      "wing",
      "wing_raw",
      "Wing value is not numeric.",
      "replace_field_missing",
      "Row is exported with wing missing."
    ),
    make_issue(
      raw_data,
      wing_out_of_range,
      "wing_out_of_range",
      "wing",
      "wing_raw",
      NA_character_,
      "replace_field_missing",
      "Row is exported with wing missing.",
      detail_col = "wing_range_detail"
    ),
    make_issue(
      raw_data,
      weight_not_numeric,
      "weight_not_numeric",
      "weight",
      "weight_raw",
      "Weight value is not numeric.",
      "replace_field_missing",
      "Row is exported with weight missing."
    ),
    make_issue(
      raw_data,
      weight_out_of_range,
      "weight_out_of_range",
      "weight",
      "weight_raw",
      NA_character_,
      "replace_field_missing",
      "Row is exported with weight missing.",
      detail_col = "weight_range_detail"
    ),
    make_issue(
      raw_data,
      fat_ngulia_invalid,
      "fat_ngulia_invalid",
      "fat_ngulia",
      "fat_ngulia_raw",
      "Ngulia fat score is not in the controlled vocabulary 0-4.",
      "replace_field_missing",
      "Row is exported with fat_ngulia missing."
    ),
    make_issue(
      raw_data,
      fat_kaiser_invalid,
      "fat_kaiser_invalid",
      "fat_kaiser",
      "fat_kaiser_raw",
      "Kaiser fat score is not in the controlled vocabulary 0-8.",
      "replace_field_missing",
      "Row is exported with fat_kaiser missing."
    )
  )

  species_disagreement_issues <- raw_data |>
    filter(keep_year, species_disagreement_flag) |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      datetime = case_when(
        is.na(parsed_date) ~ NA_character_,
        datetime_precision == "date" ~ format(parsed_date, "%Y-%m-%d"),
        TRUE ~ format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      ringNumber,
      issue_type = "species_columns_disagree",
      field = "species",
      value = species_raw,
      detail = purrr::pmap_chr(
        list(
          species_used_note,
          matched_species_no_raw,
          coalesce(
            matched_species_ngulia_number_raw,
            matched_species_ngulia_text_raw
          ),
          matched_species_label_raw
        ),
        \(
          used_note,
          species_no_value,
          species_ngulia_value,
          species_label_value
        ) {
          values <- c(
            species_no_raw = species_no_value,
            species_ngulia_raw = species_ngulia_value,
            species_label_raw = species_label_value
          )
          values <- values[!is.na(values)]
          paste0(
            used_note,
            ". Resolved values: ",
            paste0(names(values), "=", values, collapse = "; "),
            "."
          )
        }
      ),
      action = "replace_species_unknown",
      action_detail = "Row is exported with afring_number = 0."
    )

  ring_species_conflict_rows <- merged_data |>
    filter(
      keep_year,
      clean_required,
      !is.na(ring_history_group_id),
      !is.na(afring_number)
    )

  conflict_rings <- ring_species_conflict_rows |>
    distinct(ring_history_group_id, afring_number) |>
    count(ring_history_group_id, name = "species_n") |>
    filter(species_n > 1)

  ring_species_conflict_issues <- ring_species_conflict_rows |>
    semi_join(conflict_rings, by = "ring_history_group_id") |>
    arrange(ring_history_group_id, datetime, source_file, source_sheet, source_row) |>
    group_by(ring_history_group_id) |>
    summarise(
      ringNumber = first(ringNumber),
      source_file = first(source_file),
      source_sheet = first(source_sheet),
      source_row = first(source_row),
      datetime = case_when(
        first(datetime_precision) == "date" ~ format(first(parsed_date), "%Y-%m-%d"),
        TRUE ~ format(first(datetime), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      species_values = paste(sort(unique(afring_number)), collapse = "|"),
      species_n = n_distinct(afring_number),
      source_rows = format_source_rows(pick(source_file, source_sheet, source_row)),
      .groups = "drop"
    ) |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      datetime,
      ringNumber,
      issue_type = "ring_species_conflict",
      field = "ringNumber",
      value = ringNumber,
      detail = paste0(
        "Ring history group ",
        ring_history_group_id,
        " resolves to conflicting species values (",
        species_values,
        "). Source rows: ",
        source_rows,
        "."
      ),
      action = "replace_species_unknown",
      action_detail = paste0(
        "Events are exported with afring_number = 0 and the conflicting values ",
        species_values,
        " described in ring_note."
      )
    )

  ring_number_conflict_issues <- merged_data |>
    filter(keep_year, clean_required) |>
    group_by(ringNumber) |>
    filter(n_distinct(ring_history_group_id) > 1L) |>
    ungroup() |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      datetime = case_when(
        datetime_precision == "date" ~ format(parsed_date, "%Y-%m-%d"),
        TRUE ~ format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      ringNumber,
      issue_type = "ring_number_collision",
      field = "ringNumber",
      value = ringNumber,
      detail = paste0(
        "Recorded ring number occurs in separate capture histories; the intended ",
        "physical ring number is unresolved (", ring_history_basis, ")."
      ),
      action = "provisional_ring_number",
      action_detail = paste0(
        "Published as ", ringNumber, "_",
        str_pad(ring_history_group_number, 2L, pad = "0"),
        "; recorded_ring_number retains ", ringNumber,
        ". Check the original logbook before replacing the provisional number."
      )
    )

  retrap_code_issues <- merged_data |>
    filter(keep_year, clean_required, retrap_code_inconsistent) |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      action_detail = paste0(
        "Earliest kept datetime: ",
        format(datetime, "%Y-%m-%d %H:%M"),
        ". Event day: ",
        ringing_date,
        if_else(
          !is.na(same_day_group_source_rows),
          paste0(". Source rows: ", same_day_group_source_rows),
          ""
        ),
        if_else(
          !is.na(same_day_group_retrap_values) & same_day_group_retrap_values != "",
          paste0(". Non-missing same-day retrap codes: ", same_day_group_retrap_values),
          ""
        )
      ),
      datetime = case_when(
        datetime_precision == "date" ~ format(parsed_date, "%Y-%m-%d"),
        TRUE ~ format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      ringNumber,
      issue_type = "retrap_code_inconsistent",
      field = "retrap_code",
      value = coalesce(retrap_code_clean, ""),
      detail = case_when(
        retrap & coalesce(retrap_code_clean, "") != "2" ~ paste0(
          "Ring has earlier event-day history (latest prior event day ",
          prior_ringing_date,
          ") so retrap should be TRUE, but raw retrap code is ",
          if_else(is.na(retrap_code_clean), "blank", paste0("'", retrap_code_clean, "'")),
          "."
        ),
        !retrap & retrap_code_clean == "2" ~
          "Ring has no earlier event-day history, but raw retrap code is '2'.",
        TRUE ~ "Raw retrap code does not match ring history."
      ),
      action = "replace_retrap_missing",
      action_detail = paste0(
        action_detail,
        ". Event is exported with retrap missing and the inconsistency described in ring_note."
      )
    )

  retrap_without_prior_issues <- merged_data |>
    filter(keep_year, clean_required, retrap_without_prior_event) |>
    transmute(
      source_file,
      source_sheet,
      source_row,
      datetime = case_when(
        datetime_precision == "date" ~ format(parsed_date, "%Y-%m-%d"),
        TRUE ~ format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      ringNumber,
      issue_type = "retrap_without_prior_event",
      field = "retrap_code",
      value = retrap_code_clean,
      detail = paste0(
        "Raw code '2' identifies a retrap, but no earlier event for ",
        ring_history_group_id,
        " exists in the curated source coverage."
      ),
      action = "retain_source_retrap",
      action_detail = paste0(
        "The event is exported with retrap = TRUE. It cannot be linked to an ",
        "earlier date unless the missing source event is recovered."
      )
    )

  bind_rows(
    base_issues,
    species_disagreement_issues,
    ring_species_conflict_issues,
    ring_number_conflict_issues,
    retrap_code_issues,
    retrap_without_prior_issues
  ) |>
    arrange(source_file, source_sheet, source_row, issue_type)
}

build_ring_history_audit <- function(data) {
  repeated_rings <- data |>
    filter(clean_required, !is.na(ringNumber)) |>
    count(ringNumber, name = "n_ring_events") |>
    filter(n_ring_events > 1L)

  data |>
    filter(clean_required, !is.na(ringNumber)) |>
    semi_join(repeated_rings, by = "ringNumber") |>
    group_by(ringNumber) |>
    mutate(
      n_ring_events = n(),
      n_ring_assignments = n_distinct(ring_history_group_id)
    ) |>
    ungroup() |>
    arrange(ringNumber, ringing_date, datetime, source_file, source_sheet, source_row) |>
    transmute(
      ringNumber,
      ring_history_group_id,
      ring_history_group_number,
      ring_history_basis,
      n_ring_events,
      n_ring_assignments,
      ringing_date,
      season,
      retrap_code_raw = blank_to_na(retrap_code_raw),
      retrap_code_clean,
      retrap,
      prior_ringing_date,
      retrap_without_prior_event,
      has_prior_ring_number_history,
      ring_number_collision,
      afring_number,
      ring_species_conflict,
      source_file,
      source_sheet,
      source_row
    )
}

build_file_audit <- function(raw_data, merged_data, same_day_groups) {
  export_counts <- merged_data |>
    filter(clean_required) |>
    count(source_file, source_sheet, name = "n_rows_exported")

  same_day_counts <- raw_data |>
    filter(clean_required, !is.na(ringNumber), !is.na(ringing_date)) |>
    inner_join(
      same_day_groups |>
        select(ringNumber, ringing_date, same_day_group_id),
      by = c("ringNumber", "ringing_date")
    ) |>
    distinct(source_file, source_sheet, same_day_group_id) |>
    count(source_file, source_sheet, name = "n_same_day_retrap_groups")

  raw_data |>
    group_by(source_file, source_sheet) |>
    summarise(
      n_rows_imported = n(),
      n_rows_missing_datetime = sum(is.na(datetime), na.rm = TRUE),
      n_rows_missing_time = sum(!is.na(parsed_date) & is.na(parsed_time), na.rm = TRUE),
      ratio_time_6am = if_else(
        sum(!is.na(parsed_time), na.rm = TRUE) > 0,
        sum(parsed_time == "06:00", na.rm = TRUE) /
          sum(!is.na(parsed_time), na.rm = TRUE),
        NA_real_
      ),
      n_rows_outside_keep_year = sum(!keep_year, na.rm = TRUE),
      n_rows_missing_species = sum(species_missing_flag, na.rm = TRUE),
      n_rows_species_unmatched = sum(species_unmatched_flag, na.rm = TRUE),
      n_rows_lost_or_destroyed_ring = sum(exclude_lost_or_destroyed_ring_flag, na.rm = TRUE),
      n_rows_missing_ringNumber = sum(is.na(ringNumber), na.rm = TRUE),
      n_rows_invalid_age = sum(!age_valid, na.rm = TRUE),
      n_rows_invalid_sex = sum(!sex_valid, na.rm = TRUE),
      n_rows_invalid_wing = sum(wing_not_numeric | wing_out_of_range, na.rm = TRUE),
      n_rows_invalid_weight = sum(weight_not_numeric | weight_out_of_range, na.rm = TRUE),
      n_rows_invalid_fat_ngulia = sum(fat_ngulia_invalid, na.rm = TRUE),
      n_rows_invalid_fat_kaiser = sum(fat_kaiser_invalid, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(export_counts, by = c("source_file", "source_sheet")) |>
    left_join(same_day_counts, by = c("source_file", "source_sheet")) |>
    mutate(
      n_rows_exported = coalesce(n_rows_exported, 0L),
      n_same_day_retrap_groups = coalesce(n_same_day_retrap_groups, 0L),
      pct_rows_exported = n_rows_exported / n_rows_imported
    ) |>
    select(
      source_file,
      source_sheet,
      n_rows_imported,
      n_rows_exported,
      pct_rows_exported,
      n_rows_missing_datetime,
      n_rows_missing_time,
      ratio_time_6am,
      n_same_day_retrap_groups,
      n_rows_outside_keep_year,
      n_rows_missing_species,
      n_rows_species_unmatched,
      n_rows_lost_or_destroyed_ring,
      n_rows_missing_ringNumber,
      n_rows_invalid_age,
      n_rows_invalid_sex,
      n_rows_invalid_wing,
      n_rows_invalid_weight,
      n_rows_invalid_fat_ngulia,
      n_rows_invalid_fat_kaiser
    ) |>
    arrange(source_file, source_sheet)
}

md_cell <- function(x) {
  x <- as_chr(x)
  x[is.na(x)] <- ""
  x |>
    str_replace_all("\\|", "\\\\|") |>
    str_replace_all("\r?\n", " ") |>
    str_squish()
}

format_markdown_table <- function(data) {
  if (nrow(data) == 0) {
    return(character())
  }

  data <- data |>
    mutate(across(everything(), md_cell))

  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))

  c(header, separator, rows)
}

build_source_row_context <- function(issues, file_specs, raw_dir) {
  if (is.null(file_specs) || is.null(raw_dir) || nrow(issues) == 0) {
    return(issues |> mutate(source_row_context = NA_character_))
  }

  issue_keys <- issues |>
    filter(!is.na(source_file), !is.na(source_sheet), !is.na(source_row)) |>
    distinct(source_file, source_sheet, source_row)

  if (nrow(issue_keys) == 0) {
    return(issues |> mutate(source_row_context = NA_character_))
  }

  contexts <- issue_keys |>
    group_by(source_file, source_sheet) |>
    group_modify(\(.x, .y) {
      spec <- file_specs |>
        filter(
          source_file == .y$source_file,
          source_sheet == .y$source_sheet
        ) |>
        slice(1)

      if (nrow(spec) == 0) {
        return(.x |> mutate(source_row_context = NA_character_))
      }

      source_path <- file.path(raw_dir, .y$source_file)
      if (!file.exists(source_path)) {
        return(.x |> mutate(source_row_context = NA_character_))
      }

      header_row <- if (is.na(spec$header_row) || spec$header_row < 1) 1L else as.integer(spec$header_row)
      raw <- suppressWarnings(read_excel(
        source_path,
        sheet = .y$source_sheet,
        col_names = FALSE,
        .name_repair = "minimal"
      ))

      if (nrow(raw) == 0 || header_row > nrow(raw)) {
        return(.x |> mutate(source_row_context = NA_character_))
      }

      headers <- make_headers(raw[header_row, ])
      .x |>
        mutate(
          spreadsheet_row = source_row + header_row - 2L,
          source_row_context = vapply(spreadsheet_row, function(row_index) {
            if (is.na(row_index) || row_index < 1 || row_index > nrow(raw)) {
              return(NA_character_)
            }

            values <- as_chr(unlist(raw[row_index, seq_len(ncol(raw))], use.names = FALSE))
            values[is.na(values)] <- ""
            paste0(headers, "=", values, collapse = "; ")
          }, character(1))
        )
    }) |>
    ungroup()

  issues |>
    left_join(contexts, by = c("source_file", "source_sheet", "source_row"))
}

write_issue_markdown <- function(issues, path, file_specs = NULL, raw_dir = NULL) {
  issues_with_context <- build_source_row_context(issues, file_specs, raw_dir)

  lines <- c(
    "# Ngulia Ring Event Issues",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    paste0("Total issues: ", nrow(issues)),
    "",
    "## Summary",
    ""
  )

  summary_table <- issues |>
    count(issue_type, action, name = "n", sort = TRUE)

  lines <- c(
    lines,
    format_markdown_table(summary_table),
    ""
  )

  for (issue in unique(issues_with_context$issue_type)) {
    issue_rows <- issues_with_context |>
      filter(issue_type == issue)

    common_detail <- unique(issue_rows$detail)
    common_detail <- common_detail[!is.na(common_detail)]
    common_action <- unique(issue_rows$action_detail)
    common_action <- common_action[!is.na(common_action)]

    show_detail <- length(common_detail) != 1
    show_action_detail <- length(common_action) != 1

    display_rows <- issue_rows |>
      transmute(
        source = paste(source_file, source_sheet, sep = " / "),
        row = source_row,
        spreadsheet_row,
        datetime,
        ring = ringNumber,
        field,
        value,
        detail = if (show_detail) detail else NULL,
        action_detail = if (show_action_detail) action_detail else NULL,
        source_row_context
      )

    section <- c(
      paste0("## ", issue, " (", nrow(issue_rows), ")"),
      ""
    )

    if (!show_detail && length(common_detail) == 1) {
      section <- c(section, paste0("Detail: ", common_detail), "")
    }
    if (!show_action_detail && length(common_action) == 1) {
      section <- c(section, paste0("Action: ", common_action), "")
    }

    lines <- c(
      lines,
      section,
      format_markdown_table(display_rows),
      ""
    )
  }

  writeLines(lines, path)
}
