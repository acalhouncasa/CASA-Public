# Starter generator — FORM_SPEC → SSMS SQL

Python script that turns a `FORM_SPEC.json` into numbered SmartCare scripts for a **new** (greenfield) DFA.

**Do not test in Prod.**

## Files

| File | Role |
|------|------|
| [generate_dfa_sql.py](generate_dfa_sql.py) | Generator |
| [form_spec.schema.json](form_spec.schema.json) | JSON Schema for the spec |
| [../examples/FORM_SPEC_EXAMPLE.json](../examples/FORM_SPEC_EXAMPLE.json) | Minimal working example |

## Run

```powershell
python generate_dfa_sql.py --spec "..\examples\FORM_SPEC_EXAMPLE.json"
```

Writes next to the spec:

- `SQL/01_precheck.sql` (read-only)
- `SQL/02_globalcodes.sql` (only if the spec defines picklists)
- `SQL/03_apply_form.sql` (mutating)
- `SQL/04_postcheck.sql` (read-only)
- `RUN_STEPS.md`

Optional: `--sql-dir path\to\folder` to send SQL elsewhere.

Set `target_database` in the spec (default placeholder: `YourSmartCareDatabase`). Replace with your non-Prod database name before you F5.

## Portable rules this starter follows

- No `IDENTITY_INSERT` of stolen FormId / DocumentCodeId / ScreenId / FormCollectionId
- Match / upsert by **GUID**
- New `FormCollections` row for greenfield forms
- Same GUIDs when promoting the **same** new form to another environment that does not have it yet
- Radio columns `VARCHAR(20)`; dropdowns `INT`; leave multiline height NULL

Full process: [../PROCESS.md](../PROCESS.md) · pitfalls: [../PITFALLS.md](../PITFALLS.md).

## Requirements

Python 3.10+ (stdlib only).
