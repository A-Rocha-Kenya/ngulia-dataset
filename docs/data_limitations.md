# Interpretation limits

The curated tables describe birds recorded at Ngulia and the evidence available for each ringing date. They do not constitute a complete census of migration or a full historical effort log. This note states the limits that apply to any downstream use of the dataset; [data/README.md](../data/README.md) defines the fields.

## Counts and missing dates

`daily_counts.csv` contains positive species-day counts. For each season, the pipeline uses DJP daily summaries if that source has rows for the season; otherwise it summarizes curated ring events. It does not choose the better-looking source separately for each day. In this version DJP supplies seasons 1969–2014 and ring events supply 2015–2023. In `daily_coverage.csv`, `daily_count_source` identifies a positive total from curated `daily_counts.csv` or a source-recorded DJP zero; it does not identify which source was selected upstream for the season. The repository generates a count-source comparison audit, which is not part of the Zenodo deposit.

A species absent from a recorded date can be treated as zero only if that date meets the coverage rule of the analysis. A date absent from `daily_counts.csv` is not a zero-catch day. The DJP daily-total cell provides a separate distinction: a numeric zero is retained as `daily_count_status = zero_in_daily_summary`; a blank remains `missing`. A source-recorded zero does not by itself prove that nets were open.

## Calendar and operation evidence

`season` labels the year in which an October–January season starts; the assignment uses a June 1 administrative boundary. `daily_coverage.csv` starts each season window on October 20, normally runs through January 12, and extends into later January dates when the sources do. A row in this table means the date is in the calendar scaffold, not that ringing took place.

`ringing_happened` is `TRUE` when the selected count source has a positive **non-swallow/martin** total. Targeted swallow and martin catches remain in `all_birds_ringed` and `swallow_birds_ringed` but are excluded from `total_birds_ringed`. A date with only those targeted catches can therefore have recorded birds while `ringing_happened` is `FALSE`.

`effort_status` distinguishes documented operation, operation inferred from positive catch, documented non-operation, conflicts, and unknown dates. The underlying evidence comes from daily metadata and the source-linked [`operations_history.csv`](../config/daily_covariates/operations_history.csv). It is not a measure of net-hours, net length, or processing capacity. Broad historical periods in the operations register are context; they are not filled into every day.

## Catch is an observation process

Recorded catch depends on migration aloft, grounding weather, light attraction, net placement and opening, playback, staffing, and the capacity to process birds. A high catch need not mean high regional abundance; a low catch can reflect weak passage, poor grounding conditions, limited effort, or an unobserved date. Protocol changes across decades, including the introduction and relocation of night and dawn nets, lighting changes, and targeted daytime catching, make raw annual totals difficult to compare as abundance.

The selected daily count source may also differ from the individual ring-event table. Do not assume that summing `ring_events.csv` will reproduce every published daily count. The repository generates a [count-source comparison](../outputs/README.md#other-qa-products) for review.

## Weather and historical covariates

ERA5 supplies regional weather summaries for 00:00–08:00 East Africa Time; it does not directly observe mist at the lodge. The three `mist_probability_*` fields combine direct classifications where available with an ERA5-calibrated model elsewhere. Probabilities are estimates, not three independent observations.

DJP metadata, annual reports, diaries, and the operations register differ in precision. Reviewed daily corrections are applied to canonical fields, while raw `djp_*` fields remain available. Absence of a report entry does not mean normal operation, no playback, or no rain. Specific dated corrections and unresolved conflicts are retained in `operations_history.csv`.

## Recoveries and source coverage

`recoveries.csv` is a manually consolidated set of identifiable movements involving Ngulia, not a complete detection history of every ringed bird. Encounter location and date precision vary by source. The canonical file retains `primary_source`, `supporting_sources`, and `curation_notes`; the narrower Zenodo export includes only the material interpretation notes. The [recovery curation guide](recoveries_canonical.md) documents the fields and remaining gaps. `06_standardize_recovery_encounters.R` updates encounter classifications in the curated file but does not reconstruct it from the original documents.

Some raw workbooks, annual reports, and reference material are available only in the local ignored data tree. The Zenodo delivery files include a narrow recovery table and operations history, not the recovery source archive. Contact the project for source verification where needed.

## Practical use

- State which count source and date-coverage rule an analysis uses.
- Keep unknown dates distinct from documented zero-catch dates and documented non-operation.
- Separate targeted swallow and martin catching when the question concerns the main nocturnal capture process.
- Report the historical period and protocol differences relevant to a comparison.
- Describe results as catch, composition, or condition unless effort and detection are independently addressed.
- Preserve source and curation uncertainty when interpreting ring events and recoveries.

Better dated records of nets, hours, staff, lighting, and closures would improve future analyses. A proposed collection protocol is in [field protocol planning](reviews/field_protocol.md).
