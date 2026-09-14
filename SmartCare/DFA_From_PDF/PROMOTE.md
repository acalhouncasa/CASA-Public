# Promote / copy between environments

**Do not test in Prod.** Promote only under your change control.

## Choose the path

| Situation | Method |
|-----------|--------|
| Form **missing** on target (no matching `FormGUID`) | Same greenfield SQL + **same GUIDs**, retarget database. Do **not** vendor-export. |
| Form **already on target** (same FormGUID); you added fields on source | **Merge by GUID** (sections → groups → items, then columns). Do **not** run vendor export (it often INSERTs a second Forms row; collection keeps the old layout). |
| Production document already exists; QA was only a sandbox | Wire extras (for example FormJavascript) onto the **existing** DocumentCode. Do not F5 sandbox `03` as a second document. |

## Merge order (existing form)

1. Diff source vs target: sections, groups, items, GlobalCodes, columns.
2. Copy missing GlobalCodes first if picklists are short.
3. INSERT missing FormSections → FormSectionGroups → FormItems by GUID.
4. UPDATE layout fields that can drift (`NumberOfItemsInRow`, labels).
5. ALTER TABLE for new physical columns.
6. Verify counts / GUIDs, then UI on a **new** document.

## Impact scan

Before you hide or replace an old DocumentCode, scan Ad-hoc views, jobs, validations, and RDLs.

See [../Change_Impact_Scan/](../Change_Impact_Scan/).
