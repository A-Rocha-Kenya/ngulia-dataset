"""Build a standalone, searchable review of the current ring-event QA CSV."""

import csv
import html
from collections import Counter
from datetime import datetime
from pathlib import Path


root = Path(__file__).resolve().parents[2]
qa_dir = root / "data/03_intermediate/ring_events/qa"
source = qa_dir / "ring_events_issues.csv"
output = qa_dir / "ring_events_issues.html"
rows = list(csv.DictReader(source.open(encoding="utf-8-sig", newline="")))

# The QA source_row counts the first imported record as row 2. These offsets
# were checked against ring numbers in the original workbooks. In particular,
# the 1995 and 2009–2013/2015 imports do not use the usual one-row offset.
excel_row_offset = {name: -1 for name in {
    "1991_A.xls", "1991_B.xls", "1991_C.xls", "1992_A.xls", "1992_B.xls",
    "1993.xls", "1994.xls", "1996.xls", "1997.xls", "1998.xls", "1999.xls",
    "2000.xls", "2001-2005_Processed(1993-2000 present too).xlsx",
    "2008_Processed.xlsx", "2014.xls", "2016.xlsx", "2017.xlsx",
    "2018.xlsx", "2019.xlsx", "2020.xlsx", "2021.xlsx", "2022.xlsx",
    "2023.xlsx",
}}
excel_row_offset.update({"1995.xls": 0, "2006-2007_Processed.xls": 4})
excel_row_offset.update({f"{year}.xls": 1 for year in (2009, 2010, 2011, 2012, 2013, 2015)})
assert {row["source_file"] for row in rows} == set(excel_row_offset)


def esc(value):
    return html.escape(str(value or ""), quote=True)


counts = Counter(row["issue_type"] for row in rows)
files = sorted({row["source_file"] for row in rows})
issues = [name for name, _ in counts.most_common()]
options = lambda values: "".join(f'<option value="{esc(value)}">{esc(value)}</option>' for value in values)

table_rows = []
for row in rows:
    excel_row = int(row["source_row"]) + excel_row_offset[row["source_file"]]
    detail = f'{row["detail"]} {row["action_detail"]}'.strip()
    table_rows.append(
        f'<tr data-file="{esc(row["source_file"])}" data-issue="{esc(row["issue_type"])}">'
        f'<td>{esc(row["source_file"])}</td><td>{esc(row["source_sheet"])}</td>'
        f'<td class="number">{excel_row}</td><td>{esc(row["ringNumber"])}</td>'
        f'<td>{esc(row["datetime"])}</td><td>{esc(row["issue_type"])}</td>'
        f'<td>{esc(row["field"])}</td><td>{esc(row["value"])}</td>'
        f'<td>{esc(row["action"])}</td>'
        f'<td><details><summary>Details</summary>{esc(detail)}</details></td></tr>'
    )

summary_rows = "".join(
    f'<tr><td>{esc(issue)}</td><td class="number">{counts[issue]:,}</td></tr>'
    for issue in issues
)
generated = datetime.now().astimezone().strftime("%d %B %Y, %H:%M %Z")
html_text = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ngulia ring-event review</title>
<style>
:root {{ color-scheme: light; font-family: system-ui, -apple-system, sans-serif; color: #1b2730; background: #f5f7f6; }}
body {{ margin: 0; }} main {{ max-width: 1240px; margin: auto; padding: 2rem 1.2rem 4rem; }}
h1 {{ font-size: 2rem; margin-bottom: .3rem; }} h2 {{ margin-top: 2.5rem; }}
p {{ line-height: 1.5; }} .muted {{ color: #52616b; }}
.panel {{ background: white; border: 1px solid #d8e1de; border-radius: 10px; padding: 1.1rem 1.3rem; margin: 1rem 0; }}
.question {{ border-left: 4px solid #347966; }} .question h3 {{ margin: 0 0 .45rem; }}
.reference {{ font-family: ui-monospace, SFMono-Regular, monospace; font-size: .93em; background: #eef3f1; padding: .35rem .5rem; border-radius: 4px; display: inline-block; }}
.toolbar {{ display: flex; gap: .6rem; flex-wrap: wrap; margin: 1rem 0; }}
input, select {{ font: inherit; padding: .55rem .65rem; border: 1px solid #9caeaa; border-radius: 5px; background: white; }}
input {{ min-width: 18rem; flex: 2; }} select {{ max-width: 23rem; flex: 1; }}
.scroll {{ overflow: auto; max-height: 75vh; border: 1px solid #d8e1de; border-radius: 7px; background: white; }}
table {{ border-collapse: collapse; width: 100%; font-size: .87rem; }}
th, td {{ padding: .52rem .6rem; border-bottom: 1px solid #e5ebe8; text-align: left; vertical-align: top; }}
th {{ position: sticky; top: 0; background: #eaf1ee; z-index: 1; white-space: nowrap; }}
tbody tr:nth-child(even) {{ background: #fafcfb; }} .number {{ text-align: right; font-variant-numeric: tabular-nums; }}
td:nth-child(1), td:nth-child(2), td:nth-child(4) {{ white-space: nowrap; }}
td:nth-child(8) {{ min-width: 12rem; max-width: 22rem; overflow-wrap: anywhere; }}
details {{ min-width: 5rem; max-width: 21rem; }} summary {{ color: #186c56; cursor: pointer; }}
.summary {{ columns: 2; max-width: 700px; }} .summary table {{ break-inside: avoid; }}
@media (max-width: 700px) {{ .summary {{ columns: 1; }} input, select {{ min-width: 100%; }} }}
</style>
</head>
<body><main>
<h1>Ngulia ring-event review</h1>
<p class="muted">Updated {esc(generated)} · {len(rows):,} QA flags across {len(files)} source workbooks</p>
<p>This is a guide to questions in the original logbooks. A flag does not necessarily mean the source entry is wrong. The table shows how each entry is currently handled in the converted data. The Excel row numbers below refer to the visible row numbers in the original workbook.</p>

<h2>General questions about the source files</h2>
<p>These would help interpret groups of entries. The examples are starting points; the questions concern the notation used across the indicated files.</p>
<div class="panel question"><h3>1. Dates and capture sessions in the early logbooks</h3>
<p>For the 1991–2000 files, how were dates assigned to sessions that ran through the night? Is the written day the calendar date of capture, the evening when the session started, or something else? This matters when a time is around or after midnight.</p>
<span class="reference">1992_B.xls · Sheet1 · Excel row 29 · BC39858 · DAY 20, MONTH 11, YEAR 92, TIME 23</span></div>
<div class="panel question"><h3>2. Overall moult status versus feather scores</h3>
<p>In the 1995 file, what does MOULT = 0 mean when individual primary scores appear to show moult? Does zero mean “no moult”, “not recorded”, or something else? We currently derive the status from a complete feather sequence and preserve the original status in a note.</p>
<span class="reference">1995.xls · Sheet1 · Excel row 105 · BG99580 · MOULT 0; primary scores include 5, 5, 5, 2, 0</span></div>
<div class="panel question"><h3>3. Letter codes in moult sequences</h3>
<p>Do the letters in feather scores have defined meanings, and do those meanings change between years or templates? We currently leave unresolved sequences missing while retaining the original notation.</p>
<span class="reference">1995.xls · Sheet1 · Excel row 18379 · 2KG54035 · sec = 5E0E05</span><br>
<span class="reference">2021.xlsx · Ringing data · Excel row 2761 · XA74736 · Primary Moult = BBBBB00000</span></div>
<div class="panel question"><h3>4. Two-digit age entries</h3>
<p>Are values such as 34 and 43 meaningful age notation, or are they entry errors? Our current age mapping cannot interpret them, so they become unknown ages.</p>
<span class="reference">1991_B.xls · Sheet1 · Excel row 1213 · BA62597 · AGE 34</span><br>
<span class="reference">1997.xls · Sheet1 · Excel row 11378 · 2KJ25439 · AGE 43</span></div>

<h2>Individual records and other QA flags</h2>
<p>The table below includes duplicate ring histories, species conflicts, unusual measurements and entries that were excluded or kept provisionally. Duplicate rings are included for reference because we have already asked about them separately. Search for a ring number or workbook, or filter by issue type. “Excel row” is the row to open in Colin’s original spreadsheet.</p>
<div class="panel"><strong>Examples of individual checks</strong><p>Ring <strong>2KE98603</strong> appears with conflicting species in <span class="reference">1993.xls · 1993 All · Excel rows 12592 and 13996</span>. Ring <strong>BS82081</strong> appears twice as an original ringing in <span class="reference">2001-2005_Processed(1993-2000 present too).xlsx · Ngulia Data 1993-2005 · Excel rows 37114 and 37176</span>. Search either ring below for the recorded handling and related flags.</p></div>
<div class="panel"><strong>Issue counts</strong><div class="summary"><table><thead><tr><th>Issue</th><th>Flags</th></tr></thead><tbody>{summary_rows}</tbody></table></div></div>
<div class="toolbar"><input id="search" type="search" placeholder="Search ring, workbook, value, or note" aria-label="Search issues">
<select id="file"><option value="">All workbooks</option>{options(files)}</select>
<select id="issue"><option value="">All issue types</option>{options(issues)}</select></div>
<p id="shown" class="muted" aria-live="polite"></p>
<div class="scroll"><table id="issues"><thead><tr><th>Workbook</th><th>Sheet</th><th>Excel row</th><th>Ring</th><th>Date</th><th>Issue</th><th>Field</th><th>Flagged value</th><th>Current handling</th><th>Explanation</th></tr></thead><tbody>{''.join(table_rows)}</tbody></table></div>
<p class="muted">Source: current <code>ring_events_issues.csv</code>. This HTML contains its data and styling, so it can be sent as one file.</p>
</main><script>
const search = document.getElementById('search');
const file = document.getElementById('file');
const issue = document.getElementById('issue');
const rows = [...document.querySelectorAll('#issues tbody tr')];
const shown = document.getElementById('shown');
const params = new URLSearchParams(location.search);
if (params.has('ring')) search.value = params.get('ring');
function filterRows() {{
  const term = search.value.trim().toLowerCase();
  let count = 0;
  for (const row of rows) {{
    const visible = (!file.value || row.dataset.file === file.value) &&
      (!issue.value || row.dataset.issue === issue.value) &&
      (!term || row.textContent.toLowerCase().includes(term));
    row.hidden = !visible;
    if (visible) count++;
  }}
  shown.textContent = `${{count.toLocaleString()}} of ${{rows.length.toLocaleString()}} flags shown`;
}}
for (const control of [search, file, issue]) control.addEventListener('input', filterRows);
filterRows();
</script></body></html>'''
output.write_text(html_text, encoding="utf-8")
print(f"Wrote {output} ({len(rows)} issues, {len(files)} workbooks)")
