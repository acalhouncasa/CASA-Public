# Change impact scan

Before you hide or move a DocumentCode, Screen, form, table, or Ad-hoc view, scan everything that still points at it.

Full rule: [AI/Agent_Rules/change-impact-scan.md](../../AI/Agent_Rules/change-impact-scan.md).

**Do not test in Prod.**

## Files

| File | Purpose |
|------|---------|
| [sql/01_scan_documentcode_consumers.sql](sql/01_scan_documentcode_consumers.sql) | Read-only consumers for one DocumentCodeId |

## Quick checklist

1. Run the discovery script with your DocumentCodeId.
2. Search Adhoc views and CatalogReports / CatalogXML (script covers text hits).
3. Search jobs, validations, triggers, flags, RDLs (script covers common tables + `sys.sql_modules`).
4. If a consumer breaks, retarget it in the **same** change.
