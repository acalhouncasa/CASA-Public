# Process — blank paper from FormItems

**Do not test in Prod.** Run discovery and the builder against Train / Setup / a copy.

## 1. Confirm SmartCare has no blank already

Before building:

- `DocumentCodes.ImageFormat` and related “blank/template” fields are often empty.
- View Document / RDL paths usually need a **saved** `DocumentVersionId` (chart PDF), not a blank handout.
- Reports named “paper” may be claims EOBs, not clinical blanks.

If you only need a blank, FormItems is the usual source of truth for DFAs.

## 2. Identify the document (SSMS)

1. Select your database in SSMS.
2. Run [sql/SC_discovery_document_for_paper.sql](sql/SC_discovery_document_for_paper.sql) with your `@DocumentCodeId`.
3. Note:
   - `DocumentName`, `FormCollectionId`, `RequiresSignature`
   - Tab list from `FormCollectionForms` ordered by **live** `FormOrder`
4. Spot-check one tab with [sql/SC_discovery_formitems_for_paper.sql](sql/SC_discovery_formitems_for_paper.sql).

Do **not** freeze a copy of FormOrder in a spreadsheet and treat it as permanent. Collections change.

## 3. Choose print-only vs fillable

| Choice | Default |
|--------|---------|
| Print PDF (checkboxes as glyphs ☐/○) | **Yes** for new DFA packets |
| AcroForm fillable overlay | Only if your org asks; Playwright marks are not real PDF fields |

## 4. Build

From this folder:

```powershell
$env:SC_SQL_SERVER = "YourServer"
$env:SC_SQL_DATABASE = "YourSmartCareDatabase"
$env:SC_SQL_USER = "YourReadOnlyUser"
$env:SC_SQL_PASSWORD = "…"

python starter/build_blank_paper_from_formitems.py --document-code-id 12345 --out examples/out
```

Optional:

- `--logo path\to\logo.png` — page 1 only
- `--title "Printed title"` — overrides DocumentName
- `--pdf` — Playwright PDF if Playwright is installed
- `--no-signature` — skip the paper signature block even when `RequiresSignature = Y`

Connection uses env vars only. This starter does **not** ship credential files or VPN helpers.

## 5. Review the PDF

Check:

- Labels match the on-screen form (from `ItemLabel`, not storage column names)
- Designer group names (`sec1`, `content`, …) are hidden
- Dates show blank `mm/dd/yyyy`, not today’s date
- Signature (if any) sits on the last content page, not a nearly empty leftover page

## 6. Keep site specifics out of shared repos

Agency DocumentCode ids, logo files with PHI, and filled sample PDFs stay local. Publish only process, SQL templates, and anonymized examples.
