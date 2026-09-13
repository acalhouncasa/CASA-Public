# Ad-hoc reporting — custom SQL pattern

SmartCare’s Ad-hoc builder is limited. For joins and logic the GUI cannot express:

1. Put the SQL in an **`Adhoc` schema view** (flat columns).
2. Register the view in **Billing / Clinical / MCO** `dbo.Catalogs.CatalogXML` as a Table + Entity.
3. Create `dbo.CatalogReports` with **ENTATTR-only** XML (no raw SQL in the report XML).
4. Set **ShareReport = Y** and a publisher **StaffId**.
5. Administration → Shared Tables → **Refresh**.

**Do not test in Prod.**

## Forbidden

| Do not | Why |
|--------|-----|
| Put `Expr class="SQL"` / raw SELECT in `CatalogReportXML` | Report lists but designer pane stays blank |
| Leave StaffId NULL if you expect it in the list | Often missing from the left list |

## After changes

| Change | Refresh |
|--------|---------|
| CatalogXML entity | Shared Tables Refresh (or re-login) |
| View-only ALTER | Update result is usually enough |

## Naming

Prefer a clear agency prefix on view names if your site uses one. Avoid publishing PHI in view definitions.

This folder ships the **method** only. Site-specific views and reports stay private.
