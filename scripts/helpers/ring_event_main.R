match_ringer_lookup <- function(
  source_file,
  input_type,
  input_text,
  ringer_lookup,
  field = "ringer_name"
) {
  source_lookup <- ringer_lookup[!is.na(ringer_lookup$source_file), ]
  default_lookup <- ringer_lookup[is.na(ringer_lookup$source_file), ]

  coalesce(
    source_lookup[[field]][match(
      paste(source_file, input_type, input_text, sep = "\r"),
      paste(
        source_lookup$source_file,
        source_lookup$input_type,
        source_lookup$input_text,
        sep = "\r"
      )
    )],
    default_lookup[[field]][match(
      paste(input_type, input_text, sep = "\r"),
      paste(default_lookup$input_type, default_lookup$input_text, sep = "\r")
    )]
  )
}

resolve_ringer_field <- function(
  source_file,
  ringer_value,
  ringer_lookup,
  field
) {
  ringer_code <- standardize_ringer_code(ringer_value)
  ringer_initial <- standardize_ringer_initial(ringer_value)
  ringer_name_key <- clean_key(ringer_value)

  coalesce(
    match_ringer_lookup(
      source_file,
      "ringer_code",
      ringer_code,
      ringer_lookup,
      field
    ),
    match_ringer_lookup(
      source_file,
      "ringer_initial",
      ringer_initial,
      ringer_lookup,
      field
    ),
    match_ringer_lookup(
      source_file,
      "ringer_name",
      ringer_name_key,
      ringer_lookup,
      field
    ),
    ringer_lookup[[field]][match(
      ringer_name_key,
      clean_key(ringer_lookup$ringer_name)
    )]
  )
}

resolve_ringer_name <- function(source_file, ringer_value, ringer_lookup) {
  resolve_ringer_field(
    source_file,
    ringer_value,
    ringer_lookup,
    "ringer_name"
  )
}

build_ringer_lookup_audit <- function(data, ringer_lookup) {
  data |>
    mutate(
      ringer_value = blank_to_na(ringer_raw),
      ringer_code = standardize_ringer_code(ringer_value),
      ringer_initial = standardize_ringer_initial(ringer_value),
      ringer_name = resolve_ringer_name(
        source_file,
        ringer_value,
        ringer_lookup
      ),
      mapping_confidence = resolve_ringer_field(
        source_file,
        ringer_value,
        ringer_lookup,
        "mapping_confidence"
      ),
      mapping_basis = resolve_ringer_field(
        source_file,
        ringer_value,
        ringer_lookup,
        "mapping_basis"
      )
    ) |>
    filter(!is.na(ringer_value)) |>
    group_by(
      source_file,
      source_sheet,
      ringer_value,
      ringer_code,
      ringer_initial,
      ringer_name,
      mapping_confidence,
      mapping_basis
    ) |>
    summarise(
      n_rows = n(),
      n_exportable_rows = sum(clean_required, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(source_file, source_sheet, desc(n_rows), ringer_value)
}

build_ringer_unmatched <- function(ringer_lookup_audit) {
  ringer_lookup_audit |>
    filter(is.na(ringer_name)) |>
    select(
      source_file,
      source_sheet,
      ringer_value,
      ringer_code,
      ringer_initial,
      n_rows,
      n_exportable_rows
    )
}

build_ringer_audit <- function(data, ringer_lookup) {
  data |>
    mutate(
      ringer_value = blank_to_na(ringer_raw),
      ringer_name = resolve_ringer_name(
        source_file,
        ringer_value,
        ringer_lookup
      )
    ) |>
    group_by(source_file, source_sheet) |>
    summarise(
      n_rows_with_ringer_value = sum(!is.na(ringer_value)),
      n_rows_with_ringer_name = sum(!is.na(ringer_name)),
      pct_ringer_mapped = if_else(
        n_rows_with_ringer_value > 0,
        n_rows_with_ringer_name / n_rows_with_ringer_value,
        NA_real_
      ),
      .groups = "drop"
    )
}

build_clean_output <- function(data, ringer_lookup) {
  data |>
    assign_ring_event_ids() |>
    filter(clean_required) |>
    group_by(ringNumber) |>
    mutate(has_ring_number_collision = n_distinct(ring_history_group_id) > 1L) |>
    ungroup() |>
    mutate(
      ringer_name = resolve_ringer_name(
        source_file,
        ringer_raw,
        ringer_lookup
      ),
      # Internal UTC-tagged values preserve source wall time; export the Ngulia offset.
      datetime = if_else(
        datetime_precision == "date",
        format(parsed_date, "%Y-%m-%d"),
        paste0(format(datetime, "%Y-%m-%dT%H:%M:%S", tz = "UTC"), "+03:00")
      ),
      note_race_plumage = case_when(
        !is.na(race_form_raw) &
          !is.na(plumage_raw) &
          race_form_raw != plumage_raw ~
          paste(race_form_raw, plumage_raw, sep = ", "),
        TRUE ~ coalesce(race_form_raw, plumage_raw)
      ),
      note_clean = case_when(
        !is.na(note_raw) &
          !is.na(note_race_plumage) &
          note_raw != note_race_plumage ~
          paste(note_raw, note_race_plumage, sep = "|"),
        TRUE ~ coalesce(note_raw, note_race_plumage)
      ),
      retrap_issue_note = case_when(
        retrap_without_prior_event ~
          "retrap source only: raw code '2' but no earlier event exists in the curated data",
        retrap_code_inconsistent & retrap ~ paste0(
          "retrap inconsistency: earlier event on ",
          prior_ringing_date,
          " but raw retrap code is '",
          retrap_code_clean,
          "'"
        ),
        retrap_code_inconsistent & !retrap ~ paste0(
          "retrap inconsistency: raw retrap code '",
          retrap_code_clean,
          "' but no earlier event exists"
        ),
        TRUE ~ NA_character_
      ),
      ring_conflict_note = if_else(
        has_ring_number_collision,
        paste0(
          "ring number conflict: recorded number ", ringNumber,
          " occurs in separate capture histories; _01/_02 suffixes are provisional pending logbook review"
        ),
        NA_character_
      ),
      species_issue_note = if_else(
        ring_species_conflict,
        paste0(
          "species inconsistency: ring number assigned to AFRING numbers ",
          ring_species_values
        ),
        NA_character_
      ),
      age_issue_note = case_when(
        is_uncertain_age_value(age_raw) ~ paste0(
          "age uncertain: original value '",
          str_squish(age_raw),
          "' standardized to EURING age 2"
        ),
        is_unusual_age_value(age_raw) ~ paste0(
          "age warning: original value '",
          str_squish(age_raw),
          "' is a valid but unusual EURING age code and may be an entry error"
        ),
        TRUE ~ NA_character_
      ),
      issue_note = case_when(
        !is.na(species_issue_note) & !is.na(retrap_issue_note) ~
          paste(species_issue_note, retrap_issue_note, sep = "|"),
        TRUE ~ coalesce(species_issue_note, retrap_issue_note)
      ),
      issue_note = case_when(
        !is.na(issue_note) & !is.na(ring_conflict_note) ~
          paste(issue_note, ring_conflict_note, sep = "|"),
        TRUE ~ coalesce(issue_note, ring_conflict_note)
      ),
      issue_note = case_when(
        !is.na(issue_note) & !is.na(age_issue_note) ~
          paste(issue_note, age_issue_note, sep = "|"),
        TRUE ~ coalesce(issue_note, age_issue_note)
      )
    ) |>
    transmute(
      ring_event_id,
      season,
      ringing_date = format(ringing_date, "%Y-%m-%d"),
      datetime,
      recorded_ring_number = if_else(has_ring_number_collision, ringNumber, NA_character_),
      ringNumber = if_else(
        has_ring_number_collision,
        paste0(ringNumber, "_", str_pad(ring_history_group_number, 2L, pad = "0")),
        ringNumber
      ),
      ringer_name,
      afring_number = if_else(ring_species_conflict, "0", afring_number),
      age,
      sex,
      wing = parse_measurement(wing),
      weight = round(parse_measurement(weight), 1),
      fat_ngulia = as.integer(fat_ngulia),
      fat_kaiser = as.integer(fat_kaiser),
      retrap = if_else(retrap_code_inconsistent, NA, retrap),
      ring_note = case_when(
        !is.na(note_clean) & !is.na(issue_note) ~
          paste(note_clean, issue_note, sep = "|"),
        TRUE ~ coalesce(note_clean, issue_note)
      )
    )
}

process_ring_records <- function(
  data,
  species_lookup,
  measurement_ranges,
  ringer_lookup,
  issues_output_path = NA_character_,
  file_audit_output_path = NA_character_,
  ringer_lookup_audit_output_path = NA_character_,
  ringer_unmatched_output_path = NA_character_,
  ring_history_audit_output_path = NA_character_,
  issues_markdown_output_path = NA_character_,
  file_specs = NULL,
  raw_dir = NULL
) {
  working_raw <- clean_data(data, species_lookup, measurement_ranges) |>
    restore_same_day_ignored_rows()
  same_day_groups <- build_same_day_group_summary(working_raw)
  working_merged <- working_raw |>
    collapse_same_day_retraps(same_day_groups) |>
    add_retrap_history_flags(same_day_groups) |>
    assign_ring_event_ids() |>
    add_ring_species_conflict_flags()
  moult_results <- build_moult_output(working_raw, working_merged, same_day_groups)
  issues <- build_issues(working_raw, working_merged, same_day_groups) |>
    bind_rows(moult_results$issues)
  ringer_audit <- build_ringer_audit(working_raw, ringer_lookup)
  file_audit <- build_file_audit(working_raw, working_merged, same_day_groups) |>
    left_join(ringer_audit, by = c("source_file", "source_sheet")) |>
    left_join(moult_results$audit, by = c("source_file", "source_sheet")) |>
    mutate(
      n_rows_with_moult_data = coalesce(n_rows_with_moult_data, 0L),
      n_rows_decoded_moult = coalesce(n_rows_decoded_moult, 0L),
      n_rows_invalid_moult = coalesce(n_rows_invalid_moult, 0L)
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
      n_rows_with_ringer_value,
      n_rows_with_ringer_name,
      pct_ringer_mapped,
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
      n_rows_invalid_fat_kaiser,
      n_rows_with_moult_data,
      n_rows_decoded_moult,
      n_rows_invalid_moult
    )
  clean <- build_clean_output(working_merged, ringer_lookup)
  ringer_lookup_audit <- build_ringer_lookup_audit(
    working_raw,
    ringer_lookup
  )
  ringer_unmatched <- build_ringer_unmatched(ringer_lookup_audit)
  ring_history_audit <- build_ring_history_audit(working_merged)

  if (nrow(issues) > 0) {
    cli_alert_warning("Found {nrow(issues)} issues")
  } else {
    cli_alert_success("No issues found")
  }

  if (!is.na(issues_output_path)) {
    write_csv(issues, issues_output_path, na = "")
    cli_alert_info("Wrote {nrow(issues)} rows to {issues_output_path}")
  }

  if (!is.na(issues_markdown_output_path)) {
    write_issue_markdown(
      issues,
      issues_markdown_output_path,
      file_specs = file_specs,
      raw_dir = raw_dir
    )
    cli_alert_info("Wrote issue log to {issues_markdown_output_path}")
  }

  if (!is.na(file_audit_output_path)) {
    write_csv(file_audit, file_audit_output_path, na = "")
    cli_alert_info(
      "Wrote {nrow(file_audit)} file audit rows to {file_audit_output_path}"
    )
  }

  if (!is.na(ringer_unmatched_output_path)) {
    write_csv(ringer_unmatched, ringer_unmatched_output_path, na = "")
    cli_alert_info(
      "Wrote {nrow(ringer_unmatched)} unmatched ringer values to {ringer_unmatched_output_path}"
    )
  }

  if (!is.na(ringer_lookup_audit_output_path)) {
    write_csv(
      ringer_lookup_audit,
      ringer_lookup_audit_output_path,
      na = ""
    )
    cli_alert_info(
      "Wrote {nrow(ringer_lookup_audit)} ringer lookup audit rows to {ringer_lookup_audit_output_path}"
    )
  }

  if (!is.na(ring_history_audit_output_path)) {
    write_csv(ring_history_audit, ring_history_audit_output_path, na = "")
    cli_alert_info(
      "Wrote {nrow(ring_history_audit)} repeated-ring audit rows to {ring_history_audit_output_path}"
    )
  }

  list(
    ring_events = clean,
    moult = moult_results$moult,
    ring_history_audit = ring_history_audit
  )
}

build_subspecies_lookup <- function(processed_data, subspecies_lookup) {
  note_candidates <- processed_data |>
    filter(!is.na(ring_note), ring_note != "") |>
    transmute(
      afring_number,
      note = str_split(ring_note, fixed("|"))
    ) |>
    unnest(note) |>
    mutate(note = str_squish(note)) |>
    filter(
      note != "",
      str_detect(note, "^[A-Za-z][A-Za-z .'-]*$")
    ) |>
    count(afring_number, note, name = "n_records", sort = TRUE)

  for (col in c(
    "afring_number",
    "note",
    "subspecies_avibase_id",
    "n_records"
  )) {
    if (!col %in% names(subspecies_lookup)) {
      subspecies_lookup[[col]] <- NA_character_
    }
  }

  subspecies_lookup |>
    mutate(
      afring_number = clean_number_key(afring_number),
      note = blank_to_na(note),
      subspecies_avibase_id = blank_to_na(subspecies_avibase_id),
      n_records = suppressWarnings(as.integer(n_records))
    ) |>
    full_join(
      note_candidates,
      by = c("afring_number", "note"),
      suffix = c("", "_current")
    ) |>
    mutate(n_records = coalesce(n_records_current, n_records)) |>
    select(afring_number, note, subspecies_avibase_id, n_records) |>
    arrange(desc(n_records), afring_number, note)
}

add_taxonomy <- function(
  processed_data,
  species_reference,
  subspecies_lookup,
  taxonomy_columns = c(
    "avibase_id",
    "common_name",
    "species_code",
    "subspecies_avibase_id"
  )
) {
  taxonomy_columns <- unique(taxonomy_columns)
  species_output_columns <- taxonomy_columns[
    !str_starts(taxonomy_columns, "subspecies_")
  ]
  subspecies_output_columns <- taxonomy_columns[str_starts(
    taxonomy_columns,
    "subspecies_"
  )]
  species_value_columns <- setdiff(species_output_columns, "avibase_id")
  subspecies_value_columns <- setdiff(
    str_remove(subspecies_output_columns, "^subspecies_"),
    "avibase_id"
  )
  taxonomy_value_columns <- unique(c(
    species_value_columns,
    subspecies_value_columns
  ))

  ebird_reference <- auk::ebird_taxonomy |>
    transmute(
      avibase_id = taxon_concept_id,
      !!!rlang::syms(taxonomy_value_columns)
    ) |>
    filter(!is.na(avibase_id)) |>
    distinct(avibase_id, .keep_all = TRUE)

  used_species_reference <- processed_data |>
    distinct(afring_number) |>
    left_join(species_reference, by = "afring_number")

  missing_species_avibase_ids <- used_species_reference |>
    filter(!is.na(avibase_id), !avibase_id %in% ebird_reference$avibase_id) |>
    distinct(avibase_id) |>
    pull(avibase_id) |>
    sort()

  if (length(missing_species_avibase_ids) > 0) {
    cli_alert_warning("Species Avibase IDs not found in auk taxonomy:")
    cli_ul(missing_species_avibase_ids)
  }

  used_subspecies_reference <- processed_data |>
    mutate(note_token = str_split(coalesce(ring_note, ""), fixed("|"))) |>
    unnest(note_token, keep_empty = TRUE) |>
    mutate(note_token = str_squish(note_token)) |>
    left_join(
      subspecies_lookup |>
        select(afring_number, note, subspecies_avibase_id),
      by = c("afring_number", "note_token" = "note")
    )

  missing_subspecies_avibase_ids <- used_subspecies_reference |>
    filter(
      !is.na(subspecies_avibase_id),
      !subspecies_avibase_id %in% ebird_reference$avibase_id
    ) |>
    distinct(subspecies_avibase_id) |>
    pull(subspecies_avibase_id) |>
    sort()

  if (length(missing_subspecies_avibase_ids) > 0) {
    cli_alert_warning("Subspecies Avibase IDs not found in auk taxonomy:")
    cli_ul(missing_subspecies_avibase_ids)
  }

  species_reference_columns <- intersect(
    species_value_columns,
    names(species_reference)
  )
  species_column_map <- setNames(
    lapply(species_output_columns, function(col) {
      if (col == "avibase_id") {
        return(rlang::expr(avibase_id))
      }
      if (col %in% species_reference_columns) {
        return(
          rlang::expr(coalesce(
            !!rlang::sym(paste0(col, "_reference")),
            !!rlang::sym(col)
          ))
        )
      }
      rlang::sym(col)
    }),
    species_output_columns
  )

  species_reference_mapped <- species_reference |>
    rename_with(
      ~ paste0(.x, "_reference"),
      all_of(species_reference_columns)
    ) |>
    left_join(
      ebird_reference,
      by = "avibase_id",
      na_matches = "never"
    ) |>
    transmute(
      afring_number,
      !!!species_column_map
    )

  subspecies_reference <- subspecies_lookup |>
    left_join(
      ebird_reference |>
        rename(subspecies_avibase_id = avibase_id) |>
        rename_with(~ paste0("subspecies_", .x), -subspecies_avibase_id),
      by = "subspecies_avibase_id",
      na_matches = "never"
    )

  processed_subspecies <- processed_data |>
    mutate(
      row_id = row_number(),
      note_token = str_split(coalesce(ring_note, ""), fixed("|"))
    ) |>
    unnest(note_token, keep_empty = TRUE) |>
    mutate(note_token = str_squish(note_token)) |>
    left_join(
      subspecies_reference |>
        select(
          afring_number,
          note,
          any_of(subspecies_output_columns)
        ),
      by = c("afring_number", "note_token" = "note")
    ) |>
    group_by(row_id) |>
    summarise(
      across(
        all_of(subspecies_output_columns),
        \(x) first(stats::na.omit(x), default = NA_character_)
      ),
      .groups = "drop"
    )

  processed_data |>
    mutate(row_id = row_number()) |>
    left_join(
      species_reference_mapped,
      by = "afring_number",
      na_matches = "never"
    ) |>
    left_join(processed_subspecies, by = "row_id") |>
    select(-row_id)
}
