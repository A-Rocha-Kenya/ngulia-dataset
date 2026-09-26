# Local results and QA

`exploration/` contains descriptive dataset tables and figures; `qa/` contains human-facing curation diagnostics. Local presentation outputs may also be stored here. The generated tree is excluded from Git except for this README.

Recreate these results with the exploration and diagnostic scripts described in [`scripts/`](../scripts/README.md). A reviewed figure intended for the repository README is copied to `assets/generated/`. Generated files are local and may be absent from a fresh Git clone.

## Review order

After rebuilding the dataset, inspect source import and count reconciliation first, then daily evidence and model diagnostics. The most useful starting points are:

| Stage | Review file | Question |
| --- | --- | --- |
| Ring-event import | `data/03_intermediate/ring_events/qa/source_file_audit.csv` and `ring_events_issues.csv` | Which sheets or rows were excluded, corrected, or left unresolved? |
| Count selection | `data/03_intermediate/daily_counts/qa/daily_count_source_comparison_by_day.csv` | Where do DJP and ring-event daily totals disagree? |
| Daily evidence | `qa/daily_covariate_reconciliation/source_decisions.csv` and `qa/daily_effort/tables/effort_evidence_conflicts.csv` | Which observations were reconciled, and where does operation evidence conflict? |
| Mist calibration | `qa/mist_model/mist_model_report.html` and its validation tables | How well does the ERA5-based model reproduce observed mist states? |
| Dataset overview | `exploration/dataset_overview/tables/` and `figures/` | Are season, species, and date patterns plausible before export? |

Use the source paths and row locators in the audits to review a decision. Change the relevant [`config/`](../config/README.md) file and rebuild its downstream tables; do not edit generated audit files.

## Data quality and validation

### Ring-event QA

`01_build_ring_events.R` runs QA while cleaning the source workbooks and writes six complementary outputs to `data/03_intermediate/ring_events/qa/`:

- `ring_events_issues.csv`: machine-readable issues with the source file, sheet, row, affected value, explanation, and action taken.
- `ring_events_issues.md`: the same issues grouped by type for review, including the original spreadsheet-row context.
- `source_file_audit.csv`: one summary row per source sheet, including imported and exported rows, missing dates/times, ringer lookup coverage, same-day merges, invalid fields, and moult decoding results.
- `ringer_lookup_audit.csv`: every distinct nonblank source ringer value, its resolved full name, confidence and evidence basis, with total and exportable-row counts.
- `ringer_lookup_unmatched.csv`: every distinct nonblank ringer value that did not resolve, grouped by source file and sheet with total and exportable-row counts. This is the review queue for extending `ringer_lookup.csv`.
- `ring_history_audit.csv`: repeated ring numbers, provisional history groups, and source evidence used to distinguish retraps from unresolved number collisions.

The `action` column in the issue log records what the pipeline did:

| Action                                        | Meaning                                                                                                                                                                                                   |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `exclude_row`                                 | The row cannot define a valid ring event and is omitted from `ring_events.csv`.                                                                                                                           |
| `replace_species_unknown`                     | The row is retained with `afring_number = 0`; conflicting source values are appended to `ring_note` when applicable.                                                                                      |
| `replace_age_unknown` / `replace_sex_unknown` | The row is retained with age `0` or a missing sex value.                                                                                                                                                  |
| `replace_field_missing`                       | The row is retained, but the invalid measurement or decoded moult field is left missing.                                                                                                                  |
| `replace_status_from_sequence`                | A complete primary-feather sequence supplies the status when the historical overall status is unsupported or conflicts with it; the source value and derived interpretation are retained in `moult_note`. |
| `replace_retrap_missing`                      | The event is retained with `retrap` missing and the inconsistency appended to `ring_note`.                                                                                                                |
| `provisional_ring_number`                    | Separate capture histories share a recorded number; each published number gets a provisional suffix while the original number remains available for review.                                                 |

Checks and consequences are:

| Check                    | What is tested                                                                                                                                                                                                                                                                                  | Result                                                                                                                                                                                                                                                                                            |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Date and source range    | Date parsing, October-January month, and the expected year range for the source file. A missing time is allowed.                                                                                                                                                                                | Invalid-date or out-of-range rows are excluded.                                                                                                                                                                                                                                                   |
| Ring number              | A cleaned ring number is present, and configured reviewed source values match their expected patterns.                                                                                                                                                                                          | Recoverable errors are corrected before histories and event IDs are built; unresolved values are retained with a warning; missing ring numbers are excluded. A missing review target or pattern mismatch stops the build.                                                                         |
| Species identity         | Species is present, matches the lookup, and agrees across source columns.                                                                                                                                                                                                                       | Missing, unmatched, or conflicting identities are retained as AFRING `0`.                                                                                                                                                                                                                         |
| Age and sex              | Age uses numeric EURING codes `0`–`9`; sex uses the accepted source mappings.                                                                                                                                                                                                                   | Invalid age becomes `0`; uncertain historical notation such as `2(3)` or `3?` becomes age `2` with the original value in `ring_note`. Valid but unusual ages `7` and `9` are retained with a warning in `ring_note`. Invalid sex becomes missing.                                                 |
| Wing and weight          | Values are numeric and within the configured species range.                                                                                                                                                                                                                                     | The invalid measurement is set to missing; the event is retained.                                                                                                                                                                                                                                 |
| Fat                      | `fat_ngulia` is 0-4 and `fat_kaiser` is 0-8, according to the configured source scale.                                                                                                                                                                                                          | The invalid score is set to missing; the event is retained. The two scales are not converted.                                                                                                                                                                                                     |
| Moult                    | Overall status, old-primary count, primary, secondary, tertial, tail, and body notation are checked independently against the configured source scheme. Structured text is compared with dedicated score columns, and a complete primary sequence is compared with the reported overall status. | Valid positions and components are retained. Unresolved positions remain missing and raw notation is preserved in `moult_note`. Conflicting duplicate representations are left missing; when only overall status conflicts, the sequence-derived status is used and the disagreement is reported. |
| Same-day records         | The same ring number occurs more than once on one `ringing_date`.                                                                                                                                                                                                                               | Rows are merged into one event; merge counts are reported in the file audit.                                                                                                                                                                                                                      |
| Ring-species consistency | One provisional ring history resolves to more than one species across the dataset.                                                                                                                                                                                                                           | Affected events use `afring_number = 0`; the conflicting values are appended to `ring_note`.                                                                                                                                                                                                      |
| Retrap consistency       | The raw retrap code is compared with earlier records in the same ring history. | A source-coded retrap without an earlier curated event remains `TRUE` and is noted. A new-capture code conflicting with earlier history leaves `retrap` missing and is explained in `ring_note`. |

The separate `assess_ring_event_date_modes.R` diagnostic compares alternative source-date interpretations with DJP daily counts. It supports review of `raw_date_is_ringing_date` settings but does not change curated data automatically.

Dataset exploration scripts write descriptive outputs under `outputs/exploration/`. QA scripts write human-facing diagnostics to `outputs/qa/`; machine-readable curation audits remain beside their staging data in `data/03_intermediate/`.

## Other QA products

The daily-count comparison also writes an overlap-difference matrix under `data/03_intermediate/daily_counts/qa/`. Coverage, team-size, net-site, playback, and covariate-availability summaries are under `qa/` by topic. `qa/daily_coverage/figures/season_matrices/` shows where source metadata and rings occur in each season. These are descriptive checks; they do not add another curated data layer.
