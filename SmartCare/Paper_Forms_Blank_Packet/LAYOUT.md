# Layout defaults (DFA / FormCollection)

These defaults keep packets short and readable. Adjust for your brand; keep the structure.

## Page 1

| Element | Rule |
|---------|------|
| Logo | Optional, **top-left, page 1 only**. Do not repeat on later pages |
| Title | Document or packet title to the right of the logo |
| Client ID strip | Name / DOB / chart # / date / staff — write-in boxes. Flows into the form (no separate cover checklist) |
| Packet checklist | **Do not** add “Sections in this packet (check when complete)” |

## Tabs and sections

| Element | Rule |
|---------|------|
| Tab page breaks | Prefer `page-break-before: auto`. Forcing a new page per tab often leaves sparse leftover sheets |
| Section headers | Use **FormSection** bars only |
| Tab FormName as a third bar | **Do not** wrap every tab in FormName when sections already have titles |
| Designer groups | Hide group names matching `sec1`, `sec2`, `content`, `clientinfo`, `select` (case-insensitive). They are designer placeholders |
| Grid caption | Caption a grid from the first column label **only** when the section name equals the tab name. Otherwise the first column header repeats as a fake section bar |

## Fields

| ItemType (common) | Paper treatment |
|-------------------|-----------------|
| 5361 textbox / 5363 textarea / 5366–5370 / 5375–5376 / 5379 | Write-in **box** (short). Tall box when the label suggests comment / explain / describe / narrative / additional / history |
| 5367 date / 5368 datetime | Blank **`mm/dd/yyyy`**. Do not stamp today’s date |
| 5362 checkbox | ☐ + label; group into check grids when many in a row |
| 5365 radio / 5372 dropdown | ○ options on the question row when Yes/No-like; panels for longer lists |
| **5374** | **Note / instructional text**, not a section bar |
| Address-style groups | Labels that are really write-ins (name, alias, SSN last four) print as **boxes**, even if typed as 5374 in the designer |

## Radios and labels

- Prefer option text from radio/dropdown metadata (`RadioButtonOptionLabel` / GlobalCodes), not storage ids.
- Print the **ItemLabel** HTML (stripped). Do not substitute `ItemColumnName` when a label exists.
- Exception: med-style matrices where ItemLabel is only “Offered:” — derive a readable row title from the column suffix if needed.

## 5374 paired with the next control

Sometimes ItemType **5374** holds the question text and the **next** item in the same group is the Yes/No or write-in with a blank label. Pair the 5374 text onto that next control. Do not humanize a bare `ItemColumnName` into a fake question.

## Signature

| Rule | Why |
|------|-----|
| If `RequiresSignature = Y`, add a compact paper block (sign / date / printed name / credentials) on the **last content page** | Matches chart sign-off without inventing FormItems |
| Do not force `page-break-before: always` on a tall signature cell | Creates an almost-empty leftover page |
| Keep `break-inside: avoid` on the signature block | Avoids splitting mid-block |

## Visual style (suggested)

- Section bars: light gray background, bold navy text, left-aligned
- Extra top margin between sections is intentional
- Cells: `break-inside: avoid` — leave whitespace at the bottom of a page rather than split a write-in
- Footer: page numbers only (no org + DocumentCode header unless policy requires it)
