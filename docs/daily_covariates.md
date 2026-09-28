# Daily covariate evidence

This note explains how dated observations, source-linked operations history, and modeled weather contribute to `daily_coverage.csv`. It is the evidence guide for [`config/daily_covariates/operations_history.csv`](../config/daily_covariates/operations_history.csv); field definitions are in the [data README](../data/README.md). The general limits on interpreting catch are in [interpretation limits](data_limitations.md).

## Evidence hierarchy

Daily metadata is the first source for an observed condition. A dated, reviewed record in `operations_history.csv` can validate or correct a canonical daily field. Otherwise the condition remains unknown or explicitly inferred. Silence in a report is not evidence that conditions were unchanged.

## Operations history

`operations_history.csv` is an internal evidence register, not a second daily dataset. It records source-linked states and events that may affect catch but are not measured consistently in the daily data, including lights, nets, playback, vegetation, capacity, and interruptions.

Each row has an explicit interval and temporal scope. A broad `period`, `reported_period`, `reported_session`, or `reported_state` is contextual evidence and must not be expanded into a daily zero/one variable. `daily_start_date`, `daily_end_date`, and `daily_values` contain the reviewed application decision for evidence that can validate or correct a daily field. `daily_values` uses auditable `field=value` pairs; an empty value means that the record remains contextual. Sources use verified PDF pages where applicable, or dated entries for field diaries and weather notes.

The table remains separate from `daily_coverage.csv` so unknown conditions are not converted to absence. Continuous variables such as net-hours, illuminance, playback sound level, and vegetation cover must not be reconstructed without direct measurement or an explicit, auditable method.

Its fields are:

| Field | Meaning |
| --- | --- |
| `start_date`, `end_date` | Interval reported by the source. |
| `covariate`, `value` | Historical domain and reported state or event. |
| `evidence_class`, `temporal_scope` | Source type and temporal precision. |
| `source_path`, `source_page`, `note` | Traceable source location and interpretation. |
| `evidence_id` | Stable identifier used by reconciliation QA. |
| `daily_start_date`, `daily_end_date` | Reviewed application interval when a source can be tied to ringing dates. |
| `daily_values` | Reviewed `field=value` assignments; only supported daily fields are materialized in `daily_coverage.csv`. |
| `daily_review` | Date-convention and review decision for the application. |

### Historical interpretation

- Early catching used dawn nets south of the lodge; night nets below the floodlights were added later. Dawn netting moved north of the lights during the mid-1990s and the 1996 back line was optional when catch volume or staff constrained work.
- The curated period fields mark `night_net_configuration` as established from 1977 and `bush_net_configuration` as back bush through 1993, transition in 1994–1995, then front bush from 1996. The synthesis says northern use began in 1994 and became routine in 1995; mixed `B`/`F` workbook codes keep 1995 in the transition. These fields describe physical arrangement; daily operation fields describe use.
- Lighting changed materially over time: early lodge lamps, reduced/faulty output in the 1980s, later project lamps, documented outages, and the 3.5 kW three-lamp configuration in 2013–15. Wattage is not a measurement of bird-effective light dose; do not infer output, spectrum, geometry, or nightly availability from a report’s silence. See [Ngulia light attraction: mechanisms, evidence and measurement](reviews/light_setup.md) for the light-specific review.
- Playback can alter total catch and species composition. `djp_tape` is a daily coded location/use field through 2014, not a record of species, volume, timing, or audibility. Later reports often distinguish nocturnal song playback from diurnal target lures, so these must not be collapsed into one unqualified playback covariate.
- The workbook decodes `T` as tapes at front and `t` as tapes behind lodge, both under “Night tape use.” It does not identify which speaker was at night nets versus bush nets, so those labels remain unresolved. Blank cells in covered DJP metadata mean none; dates outside coverage remain unknown.
- Elephant damage and vegetation recovery plausibly alter holding and netting conditions. Reported habitat states are contextual unless a source documents a particular event date.
- Team size and session length constrain processing capacity but do not measure net-hours. Explicit closures, delays, or short sessions are retained as events; no continuous historical team-size or effort series is inferred.

The decoded `djp_site` field has `outside_night_nets` records on 12 and 14 November 1974, whereas the historical synthesis describes night netting from 1976. No contemporary 1974 source was found to resolve this conflict. Both workbook observations are retained and explicitly flagged in `operations_history.csv`; they should be excluded in a site-history sensitivity analysis.

## Daily-table assembly

`scripts/intermediate/01_build_daily_context.R` retains the source-specific daily observations. `scripts/intermediate/02_build_mist_model.R` fits the unified three-state observed/ERA5 mist model. `scripts/curated/05_build_daily_coverage.R` builds the single external daily table.

The internal `data/04_curated/daily_coverage.csv` includes deterministic season and lunar variables, parsed team-size fields, observed mist evidence and one modeled three-state mist distribution, effort evidence, and reviewed daily observations. Decoded `djp_*` fields are preserved internally; reconciled mist, rain, net sites, night/dawn operation, and nocturnal playback apply explicit source decisions from the history. `operations_evidence_ids` links affected dates back to full provenance in `operations_history.csv`. Qualitative and sparse historical details are not copied into the daily table. Analyses define their own eligibility rules.

The DJP workbook column `BS` is the source daily total. A numeric zero in that cell is retained as `daily_count_status = zero_in_daily_summary`; a blank remains a missing count. Analyses that use an operated zero need separate evidence that ringing took place.

## Reviewing a new historical record

Record its source path and page or dated entry, the reported interval, and the temporal precision. Set `daily_values` only when a specific date and field are supported; leave broader statements as context. After changing the register, rebuild daily context, mist probabilities, daily coverage, and the relevant [QA products](../outputs/README.md#other-qa-products). Check `operations_evidence_ids` and the source-decision audit before using a revised field.

## Source priorities and remaining gaps

The main operational sources are the 1969–2012 synthesis, contemporary early ringing accounts, annual reports, field diaries, and weather notes. The published *Scopus* annual accounts through autumn 1991 are now held in the reference library. The strongest remaining opportunities are original daily notebooks or diaries and privately circulated annual reports, especially for 1992–2003. Individual ringing-book scans are useful only where they contain a complete, legible effort note; bird records or partly completed effort headers must not be used to infer netting activity.

For field protocols and future direct measurement, see the [future field protocol proposal](reviews/field_protocol.md). Dataset field definitions are in the [data README](../data/README.md).

The Zenodo daily table is a 25-column view of that internal table. It omits bird totals, the effort summary, source codes, and evidence identifiers. Its weather observations use coherent presence categories; model probabilities use `mist_modeled_*` names. Public definitions are in the [data dictionary](../data/README.md#daily_coveragecsv); richer internal fields are documented in the [internal dictionary](daily_coverage_internal.md).
