# CIWA-Ar live total (portable pattern)

Show a running CIWA-Ar total on a DFA as staff change the symptom dropdowns.

This pack is a **pattern**. Replace table name, column names, and label wiring for **your** CIWA document. It does not include a site DocumentCode id or a site-specific RDL proc.

**Do not test in Prod.**

## Clinical bands (standard CIWA-Ar)

| Total | Band text (example) |
|-------|---------------------|
| 0–9 | absent or minimal withdrawal |
| 10–19 | mild to moderate withdrawal |
| >20 | severe withdrawal |

Confirm bands against your clinical policy and printed report.

## Important product detail

If symptom dropdowns use **DropdownType G**, the control value is often a **GlobalCodeId**, not the point value. Read points from the option label / `GlobalCodes.Code`, not `parseInt(val)` of an 8-digit id.

## Files

| File | Purpose |
|------|---------|
| [examples/ciwa_ar_live_total.js](examples/ciwa_ar_live_total.js) | Client script template |
| [sql/SC_wire_FormJavascript_template_COMMIT.sql](sql/SC_wire_FormJavascript_template_COMMIT.sql) | Wire `Forms.FormJavascript` by TableName |

## After apply

Shared Tables → Refresh. Log out / in. Open a **new** document and change a symptom dropdown.
