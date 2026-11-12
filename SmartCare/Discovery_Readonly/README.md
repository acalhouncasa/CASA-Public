# Read-only discovery habits

Safe exploration of a SmartCare database:

1. Prefer **SELECT-only** scripts.
2. Select the database in SSMS (portable scripts avoid `USE` of a customer name).
3. Parameterize DocumentCodeId / TableName.
4. **Do not test mutating changes in Prod.**
5. Never put client names in result exports you share.

## Sample scripts

| File | Purpose |
|------|---------|
| [SC_discovery_documentcode_header.sql](SC_discovery_documentcode_header.sql) | DocumentCode + forms in collection |
| [SC_discovery_clientnotes_active_flags.sql](SC_discovery_clientnotes_active_flags.sql) | Active chart flags by Flag Type (ClientId counts only) |
| [SC_discovery_documentsignatures_grain.sql](SC_discovery_documentsignatures_grain.sql) | Staff vs client signature pads for one DocumentCode |
| [../FormItem_Column_Alignment/SC_discovery_FormItems_vs_columns.sql](../FormItem_Column_Alignment/SC_discovery_FormItems_vs_columns.sql) | Truncation risk |
| [../Missing_Client_Signature_Flag/sql/01_discovery.sql](../Missing_Client_Signature_Flag/sql/01_discovery.sql) | Signature-gap discovery for flag deploy |
| [../Change_Impact_Scan/sql/01_scan_documentcode_consumers.sql](../Change_Impact_Scan/sql/01_scan_documentcode_consumers.sql) | Consumers before hide/relocate |
| [../Ad_Hoc_Reporting/sql/01_discovery_catalogs.sql](../Ad_Hoc_Reporting/sql/01_discovery_catalogs.sql) | Ad-hoc catalogs |

Do not publish credential helpers, VPN scripts, or private host allow-lists.
