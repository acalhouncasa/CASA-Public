# Change impact scan

Before you hide or move a DocumentCode, Screen, form, table, or Ad-hoc view, scan everything that still points at it.

Full rule: [AI/Agent_Rules/change-impact-scan.md](../../AI/Agent_Rules/change-impact-scan.md).

## Quick checklist

1. Search Adhoc views and CatalogReports / CatalogXML.
2. Search jobs, validations, triggers, flags, RDLs.
3. If a consumer breaks, retarget it in the **same** change.
4. **Do not test in Prod.**
