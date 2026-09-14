# Process — PDF to wired DFA

## 0. Folders

```text
DFA_From_PDF/          (or your project root)
  <Form Name>/
    sources/             PDF and/or numbered screenshots
    FORM_SPEC.json
    RUN_STEPS.md
    SQL/
      01_precheck.sql
      02_globalcodes.sql   (only if picklists are needed)
      03_apply_form.sql
      04_postcheck.sql
```

## 1. Capture the form

- Put the PDF or screenshots in `sources/`.
- Decide the staff-facing **document name** and a `CustomDocument*` **table name**.
- Note major headers (those become **FormSections**).
- Circles on paper ≈ radios; squares ≈ checkboxes (confirm with the requester).

## 2. Draft `FORM_SPEC.json`

See [FORM_SPEC.md](FORM_SPEC.md) and [examples/FORM_SPEC_EXAMPLE.json](examples/FORM_SPEC_EXAMPLE.json).

Have the AI agent draft the first pass from the PDF, then you confirm ambiguous labels and picklist values.

## 3. Generate SQL

Use the public starter (stdlib Python):

```powershell
python "starter\generate_dfa_sql.py" --spec "path\to\FORM_SPEC.json"
```

See [starter/README.md](starter/README.md). Or use your own generator. It should emit:

| Script | Mutates? | Role |
|--------|----------|------|
| `01_precheck.sql` | No | Object missing? GUIDs free? |
| `02_globalcodes.sql` | Yes | `X*` categories + codes when needed |
| `03_apply_form.sql` | Yes | Table + Forms/Items + DocumentCodes + Screens |
| `04_postcheck.sql` | No | Counts and wiring PASS/FAIL |

Persist GUIDs **into the spec** on first generate. Keep them on later regenerations.

## 4. Human applies (SSMS)

**Do not test in Prod.**

1. Select the target SmartCare database in SSMS (or use a portable `USE` you control locally — public packs often omit `USE`).
2. F5 **whole** `01_precheck.sql`. Paste grids back to the agent if you use one.
3. If present: F5 `02_globalcodes.sql`.
4. F5 `03_apply_form.sql` once. Do not re-F5 after postcheck PASS on that environment.
5. F5 `04_postcheck.sql`.

## 5. After apply

1. Administration → Shared Tables → **Refresh**.
2. Log out and back in.
3. Client → **New** document → this form → save, sign, PDF.
4. Prefer a **new** document version after metadata changes (old drafts can look stale).

## 6. Default product wiring (typical clinical DFA)

| Setting | Usual value |
|---------|-------------|
| Open path | Client Documents → New Document |
| `ServiceNote` | `N` (unless you explicitly want a service note) |
| `RequiresSignature` | `Y` |
| View RDL | `RDLDFACommonReport` |
| Document GET SP | `ssp_GetDFADocumentsData` (not an RDL `*Text` proc) |
| `Screens.CustomFieldFormId` | **NULL** for standard DFA + grids |
| Left-nav `Banners` | Omit unless you asked for them |
| Paper signature lines | Do **not** model as FormItems when `RequiresSignature = Y` |

## 7. Who does what with an AI agent

| Agent | Human |
|-------|--------|
| Draft spec from PDF | Confirm names / grain |
| Run generator | — |
| Read-only precheck/postcheck when allowed | F5 mutating `02` / `03` |
| Interpret paste-back; next step | UI UAT |
| Record lessons | Approve Prod promotion later |

See [AI/Working_With_Cursor/](../../AI/Working_With_Cursor/).
