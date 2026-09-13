# FormItems vs physical columns

Find truncation and wrong-control bugs by comparing `FormItems` to `sys.columns` on the custom document table(s).

**Do not test in Prod** (this script is read-only, but keep the habit).

## Files

| File | Purpose |
|------|---------|
| [SC_discovery_FormItems_vs_columns.sql](SC_discovery_FormItems_vs_columns.sql) | Set `@DocumentCodeId`; F5 |

Also: [AI/Agent_Rules/formitem-column-alignment.md](../../AI/Agent_Rules/formitem-column-alignment.md).
