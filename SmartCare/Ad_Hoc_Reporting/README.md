# Ad-hoc reporting — custom SQL pattern

SmartCare’s Ad-hoc builder is limited. For joins and logic the GUI cannot express:

1. Put the SQL in an **`Adhoc` schema view** (flat columns).
2. Register the view in **Billing / Clinical / MCO** `dbo.Catalogs.CatalogXML` as a Table + Entity.
3. Create `dbo.CatalogReports` with **ENTATTR-only** XML (no raw SQL in the report XML).
4. Set **ShareReport = Y** and a publisher **StaffId**.
5. Administration → Shared Tables → **Refresh**.

**Do not test in Prod.**

## Files

| File | Purpose |
|------|---------|
| [sql/01_discovery_catalogs.sql](sql/01_discovery_catalogs.sql) | Read-only catalogs / Adhoc views / reports |
| [sql/02_create_adhoc_view_template_COMMIT.sql](sql/02_create_adhoc_view_template_COMMIT.sql) | `Adhoc.vw_AGENCYID_ExampleDocumentList` |
| [sql/03_register_catalog_report_template_COMMIT.sql](sql/03_register_catalog_report_template_COMMIT.sql) | CatalogReports insert/update template |

Replace **`AGENCYID`**. Edit the view SELECT and CatalogXML entity wiring for your site before Prod.

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

Prefer **`AGENCYID`** (or your prefix) on view and report names. Avoid publishing PHI in view definitions.

CatalogXML Table/Entity markup differs by SmartCare build — discovery first; do not paste another agency’s full CatalogXML.
