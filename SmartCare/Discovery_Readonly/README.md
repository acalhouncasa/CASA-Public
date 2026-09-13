# Read-only discovery habits

Safe exploration of a SmartCare database:

1. Prefer **SELECT-only** scripts.
2. Select the database in SSMS (portable scripts avoid `USE` of a customer name).
3. Parameterize DocumentCodeId / TableName.
4. **Do not test mutating changes in Prod.**

## Sample scripts

| File | Purpose |
|------|---------|
| [SC_discovery_documentcode_header.sql](SC_discovery_documentcode_header.sql) | DocumentCode + forms in collection |
| [../FormItem_Column_Alignment/SC_discovery_FormItems_vs_columns.sql](../FormItem_Column_Alignment/SC_discovery_FormItems_vs_columns.sql) | Truncation risk |

Do not publish credential helpers, VPN scripts, or private host allow-lists.
