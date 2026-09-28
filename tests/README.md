# Zenodo validation

Run from the repository root after building the curated tables and Zenodo files:

```sh
Rscript tests/testthat.R
```

Install dependencies with `scripts/setup/01_install_dependencies.R`. The complete suite uses the local, ignored CSVs in `data/04_curated/` and `exports/zenodo/`, plus the reviewed capture-group and operations configuration. It reads all records and does not modify the curated data. The integration tests write column, row and relationship violations to `outputs/qa/zenodo/violations.csv`, with the file, rule, CSV record number, column and offending values. File, documentation, provenance and source-fidelity failures are reported in the test output. A record number includes the header; a quoted multiline field may occupy several physical lines.

The generated CSVs are not required to run the small example and mutation tests:

```sh
Rscript -e 'testthat::test_dir("tests/testthat", filter = "zenodo-edge", reporter = "summary")'
```

## What is enforced

`zenodo-schema.csv` is the explicit contract for all 123 public columns. It specifies column order, lexical type, required values, inclusive bounds, allowed codes and identifier patterns. CSV values are first read as text, preserving ring inscriptions and distinguishing empty cells from literal text such as `NA`. Numeric-looking feather scores remain text because `S` is also valid.

The integration checks cover:

- The exact delivery file list, valid CSV structure and UTF-8 text.
- Agreement between column names and both the current and archived data dictionaries.
- Required and unique keys, taxon references, common names, parent species and subspecies membership.
- Recognized species/note contradictions recorded in the taxonomy audit must be Unknown with no subspecies, while preserving the original note and both candidate identifications. Small taxonomy tests cover compatible notes, historical slash membership and contradictory multiple notes.
- Calendar dates, timestamps with `+03:00`, June-boundary season labels and permissible clock rollover, including source ringing-day labels.
- Positive integer species-day counts, public count coverage against species-day records, and recorded-zero evidence in the richer internal table.
- Probability bounds, complete-or-missing probability triplets, sums within `1e-8` and observed mist constraints.
- Public site tokens, season position, mean wind magnitude, and minimum-known team size against the internal participant codes.
- Conservative biometric limits matching the configured fallback, measurement precision, score vocabularies, complete primary-sequence status, geographic coordinate pairs and recovery outcome/chronology rules.
- An uninterrupted October 20–January 12 season calendar, allowing documented extensions through January.
- Positive count status for all dates with delivered species rows, including swallow-only dates.
- Every taxonomy count, season count and first/last date recomputed from the delivered observations, including species rollups without double-counting.
- Exact species-day agreement with ring events for the documented ring-derived seasons, 2015–2023. Earlier DJP seasons may differ.
- Internal operations evidence IDs, date intervals and daily values against the reviewed source register.
- Fidelity to the canonical files, including the narrowed recovery and daily-coverage views, presence-category mappings, unchanged model probabilities, and numeric coordinate serialization.

The small reference package and mutations exercise missing/duplicate keys, missing/extra/reordered columns, all declared types and bounds, unknown codes, broken links, stale summaries, leap days, year changes, malformed intervals, coordinate boundaries, partial dates, quoted multiline text, leading zeroes, nonfinite numbers, probability rounding and legitimate zero/unknown states.

## Interpretation limits

Recovery dates support the documented EDTF subset: year, year-month, full date, or an ordered interval with those endpoints. Partial dates are compared through their possible bounds, so an uncertain date is not treated as a known day. Original recovery age notation such as `2(4)` is retained; cleaned ring-event ages are integers.

A missing `p10` cannot establish whether a sequence uses nine positions or is an incomplete ten-position sequence. The standalone status check therefore applies to ten populated positions using only `0`–`5`; other sequences retain vocabulary and source-fidelity checks.

Biometric bounds in the public contract use the conservative global fallback. The tighter source-species bounds remain part of ingestion QA because the public events do not retain their original AFRING codes.

These rules establish internal consistency. They do not establish that a historical identification, recovery location or source statement is factually correct. A newly failing rule should be resolved through the documented curation process, with the evidence preserved.
