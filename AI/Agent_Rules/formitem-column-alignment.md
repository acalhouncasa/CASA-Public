# FormItems vs physical column alignment

When a DFA field misbehaves (wrong control, truncation, save failure), compare **both** layers:

| Layer | Source | Drives |
|-------|--------|--------|
| Metadata | `dbo.FormItems` (`ItemType`, `MaximumLength`, `ItemColumnName`) | Labels, validation hints |
| Physical | `sys.columns` + `sys.types` on `CustomDocument*` | **Actual** control type and storage |

## Checks

1. Join `FormItems.ItemColumnName` → `sys.columns.name` on the form’s custom table.
2. Compare SQL data type (not only MaximumLength vs character max length).
3. Use the portable discovery script in [SmartCare/FormItem_Column_Alignment/](../../SmartCare/FormItem_Column_Alignment/).

## Common mismatches

| FormItems | Physical | Symptom |
|-----------|----------|---------|
| Text box, long max | `date` | Date picker instead of text |
| Long text | `char(1)` / tiny varchar | Truncation on save |
| Multi-select dropdown | `int` | Comma-separated ids are not a valid integer |
| Radio | `varchar(3)` | ExternalCode1 / id truncation — widen (often `varchar(20)`) |
| Phone control | `varchar(10)` | Control may post punctuation; widen |

## After DDL

Refresh Shared Tables. Log out / in. Test on a **new** document version.
