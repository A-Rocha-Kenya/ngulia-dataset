# RSEA recovery workbook reconciliation

The original `00_RSEA recoveries database.xlsx` was copied unchanged to `data/01_raw/external/rsea/` on 2026-09-26. Its SHA-256 is `39c08691704629303381e508e152dc073cd90d2547e026179c026c79a1ee0c94`. The comparison used the `Recoveries` sheet, the canonical `data/04_curated/recoveries.csv`, and the existing source evidence recorded there. The `Species` lookup sheet and `distance calc` example sheet do not contain movement records. Links to original documents below require the local, Git-ignored source archive.

The row-level audit is `data/03_intermediate/recoveries/rsea_row_audit.csv`. It records the source sheet row, key fields, candidate canonical IDs, observed differences, final resolution, and review priority for all **381 populated recovery rows**. It does not treat text inside the workbook as processing instructions.

## Scope and actions

| Source rows | Count | Resolution |
| --- | ---: | --- |
| National records without a Ngulia endpoint | 191 | Outside the canonical Ngulia movement table's scope; no change. This includes row 170, which has a colour flag but no ring number. |
| Identifiable Ngulia records with an existing event match | 115 | RSEA was attached as supporting evidence. Historical master lists, formal notifications, correspondence, or original Ngulia ring-event records kept precedence where the sources disagree. This includes row 223, whose `FRP` ring prefix initially hid a duplicate. |
| Identifiable Ngulia record with a conflicting event date | 1 | Row 215, `CG07010`, was not added as a fourth movement; its 2009-06-19 date conflicts with the official notification supporting the existing 2010-06-06 event. |
| Identifiable Ngulia records absent from the canonical table | 15 | Added under `NGREC-0255`–`NGREC-0270`, preserving existing IDs; `NGREC-0260` was retired after a duplicate check. Seven are August 2026 encounters. Source-derived distances were left blank because the workbook's calculation is unreliable in several checked cases. |
| Ngulia rows with ring number recorded only as `from pdf` | 59 | No new record added. Thirty-nine have a unique exact date-pair match; twenty have a probable match by species, ringing date, country, locality, or a recognizable transcription error. All candidate IDs appear in the row audit; the original PDF needs checking before treating these as independently identified birds. |

For nine existing records, previously empty `duration_days` values were filled because the exact dates in the canonical table and RSEA agree. The existing record notes identify the source row. The RSEA sheet was not used to turn a parenthesized reporting date or an imprecise month into an exact encounter day.

## Important discrepancies to review

| RSEA row | Ring or ID | Difference and action |
| ---: | --- | --- |
| 161 | `2XK0172` | RSEA labels the scheme **Nairobi**. The 2XK series and user confirmation support **Stockholm**, now used in the curated row. |
| 215 | `CG07010` | RSEA gives an uncorroborated 2009-06-19 Kreischa row. Three distinct controls of the same bird are supported on 2008-06-12, 2009-05-17, and 2010-06-06; retain three encounter rows. |
| 223 | `FRP5081578` | Duplicate of `NGREC-0239`, Paris ring `5081578`. The [official notification](<../../data/01_raw/external/ngulia_djp/From DJP 2017/RECOVERIES/Ap%20Paris%205081578[1].pdf>) prints `FRP - ....5081578` and confirms the same species, dates, and places. `NGREC-0260` was removed; RSEA is supporting evidence for the existing encounter. |
| 222 | `CP93456` | RSEA says **Nairobi**; the historical master and full list say **Stockholm**, confirmed by the user. The curated scheme remains Stockholm. |
| 230 | `XA08740` | The original Ngulia ring sheet and historical master support **2012-12-13**. The formatted list and RSEA omit the leading `1`, giving 3 December and 159 days. The curated row now uses **149 days** from the original ringing date; all sources agree on the 2013-05-11 encounter date. |
| 238 | `CD60476` | The contemporaneous 2009 update and RSEA give **2009-07-27**; later compiled lists give 29 July. The curated row now uses 27 July and 1,327 days. No evidence identifies 29 July as a report date. |
| 243 | `XA32558` | The compact longitude **036°02′E** is inconsistent with both the detailed **43°36′02.4″E** and the [Al Qassim locality](https://www.geonames.org/108933/al-qassim-region.html). The curated row now uses the detailed coordinate, 27.362139°N, 43.600667°E. |
| 246 | `CD60362` | RSEA calculates **6,507 km** from Ngulia to Dodoma, while the canonical source reports **405 km**. The spreadsheet formula result was not adopted. Other source-derived distances were also left blank for new records. |
| 255 | `J135563` | The historical source says **Arne, Mount Hermon, Syria**. RSEA drops Arne and labels the mountain **Lebanon**. [The German Archaeological Institute gazetteer](https://gazetteer.dainst.org/doc/2281659.html) identifies Arne/Arnah at 33.36569°N, 35.87761°E, and a [UN map](https://www.ecoi.net/en/file/local/1328611/1228_1199964020_israelsyrien2006.pdf) places Arnah in Syria. The curated row now names Arnah and uses those locality coordinates; country remains Syria. |
| 250, 251, 339 | `from pdf` | These probable duplicate rows contain material date transcription errors, including reversed day/month pairs and an impossible 1991 encounter after a 1998 ringing date. They were not added or used to change canonical dates. |

Existing canonical dates for `B4K7221`, `XA29506`, and `BN58319` also differ from RSEA. The earlier consolidation had already resolved these using an official notification, direct correspondence, or an internally consistent formatted list, respectively. Several apparent species differences are source codes (`ACRPAL`, `LUSLUS`, `SYLCOM`) versus canonical English names, not taxonomic conflicts. Country labels such as “Czech R” versus “Czechia” and small distance rounding differences were not propagated. The RSEA duration and distance calculation columns were treated as derived values, not primary observations.

The 205 `from_ngulia` movements were checked by original ringing date. The curated scheme is Nairobi for 1972–1989 records and predominantly Stockholm from 1990 onward. Two later entries are labelled Nairobi in sources. The contemporary [2007 report](../../data/02_reference/reports/2007.pdf) explicitly identifies Marsh Warbler `K64254` (ringed 2005) as Nairobi, despite listing Stockholm rings nearby. The historical [formatted list](<../../data/01_raw/external/ngulia_djp/From DJP 2017/RECOVERIES/Ngulia 194 R&C.doc>) identifies Harlequin Quail `B33829` (ringed 1995) as Nairobi, but no original ringing record or independent scheme label was found; its scheme remains provisional. No evidence in these records supports a later blanket switch to a scheme named Ngulia. Ringing site and ringing scheme are separate fields.

The `CG07010` rows represent one marked individual, not three individuals. The [2008 report](../../data/02_reference/reports/2008.pdf) documents the first Kreischa control; the [2009 report](<../../data/02_reference/reports/2009 Thanks pq.pdf>) adds the second; the [2010 report](../../data/02_reference/reports/2010.pdf) explicitly names both previous dates and the third control at Thiesewitz. The Hiddensee notification confirms the 2010 date, place, and elapsed time. A table in the 2010 report says “four controls” and prints another internally inconsistent date; it supplies no defensible fourth event. RSEA's 2009-06-19 row was likewise not added without independent evidence.

For `XA08740`, [the original 2012 ring sheet](../../data/01_raw/ring_events/2012.xls), Sheet1 row 10698, gives 13 December (the raw workbook's displayed year is corrected by the 2012 file specification). Adjacent sequential ring numbers carry the same day. The later [formatted recovery list](<../../data/01_raw/external/ngulia_djp/From DJP 2017/RECOVERIES/MAIN LISTS/R&C Full List to Dec 2016.doc>) gives 3 December; RSEA copies that date. For `CD60476`, the [2009 recovery update](<../../data/01_raw/external/ngulia_djp/From DJP 2017/RECOVERIES/Annual update lists/Recs 2009.doc>) gives 27 July, whereas later compiled lists give 29 July. Neither difference is documented as a discovery-versus-report distinction.

## Newly added movements

| IDs | Source rows | Species and direction |
| --- | --- | --- |
| `NGREC-0255`–`NGREC-0257` | 161–163 | Three Thrush Nightingales from Ngulia |
| `NGREC-0258` | 181 | Black Stork colour flag read at Ngulia |
| `NGREC-0259`, `NGREC-0261` | 205, 227 | Two Marsh Warblers controlled at Ngulia |
| `NGREC-0262`–`NGREC-0270` | 235, 236, 240–244, 383–384 | Nine Marsh Warblers from Ngulia |

The RSEA workbook is the only recovery source currently attached to these 15 movements; their original notifications remain to be checked. Record-level notes identify the two material source uncertainties. The existing public exports were not rebuilt as part of this source reconciliation.

## Duplicate recheck

The canonical table now has 269 movement rows and 266 distinct scheme-and-ring keys. Only two rings have more than one encounter: `CG07010` has three controls in Germany on different dates, corroborated by the annual reports and official notification; `1EK16345` has two Finnish controls on 9 and 30 May 2001, both stated in one entry of the historical formatted list. Neither is a duplicate encounter. A second pass compared species, ringing and encounter dates, locality, and ring strings after removing scheme prefixes and punctuation. It found the `FRP5081578` alias described above; no other duplicate encounter was found. Same-day records for Brussels rings `6747983` and `7018243` at Retie have different ring numbers and are retained as separate birds.
