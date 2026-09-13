# Change impact scan (SmartCare and similar)

Before you hide, retire, relocate, rename, or retarget a **DocumentCode, Screen, Form, table, column, procedure, job, or Ad-hoc view**, scan consumers in the **same change**.

## Scan

Search the object id **and** table/column names in:

| Consumer | Where to look |
|----------|----------------|
| Ad-hoc views | `Adhoc.*`, catalog XML |
| Catalog reports | `CatalogReports`, `CatalogXML` |
| SQL Agent / scheduled jobs | Job steps, proc names |
| Validations | `DocumentValidations`, required FormItems |
| Triggers / procs | `sys.triggers`, `OBJECT_DEFINITION` |
| Flags / tracking | Flag types, tracking protocols |
| RDL / report server | Report catalog, RDL bindings |
| Prefill / BI | Prefill SPs, Power BI queries |

Repo search **and** live database search on the environment being changed. Listing only the current folder is not enough.

## Then

| Finding | Do |
|---------|-----|
| Consumer will break | Retarget or ship a paired fix **in the same change** |
| Consumer unused | Say so explicitly |
| Validations on a hidden document | Say they will **not** fire on the new location |

## Forbidden

- Hide a DocumentCode and leave Ad-hoc INNER JOINed to that id (empty report)
- Treat “new Custom Fields location” as view-only if reports still join the old table
