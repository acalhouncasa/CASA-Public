# Missing client signature chart flag

Raises a **client chart flag** when a named document is **staff-signed** but the **client signature pad is still open**. Clears the flag when the client signs, signs on paper, or declines.

This is **not** stock Client Tracking due-date protocols. Live alerts use **`dbo.ClientNotes`** (Flag Types), not `ObjectFlags`.

**Do not test in Prod.**

## What you get

| Piece | Role |
|-------|------|
| Flag Type row(s) | One per DocumentCode you watch |
| Sync procedure | INSERT / UPDATE / CLEAR `ClientNotes` for gaps |
| Clear trigger | On `DocumentSignatures` AFTER INSERT/UPDATE — deactivates notes when the client pad completes |
| Discovery SELECTs | Find DocumentCodes, icons, and gap counts before you change anything |

Replace the token **`AGENCYID`** everywhere (object names, stamps, comments) with your site prefix (letters/numbers, keep stamps ≤ 30 characters).

## Files

| File | Purpose |
|------|---------|
| [PROCESS.md](PROCESS.md) | Deploy order and UAT |
| [PITFALLS.md](PITFALLS.md) | Identity steal, `DocumentId`, column names |
| [sql/01_discovery.sql](sql/01_discovery.sql) | Read-only discovery |
| [sql/02_flagtypes_COMMIT.sql](sql/02_flagtypes_COMMIT.sql) | Insert/retag Flag Types |
| [sql/03_sync_proc_COMMIT.sql](sql/03_sync_proc_COMMIT.sql) | `ssp_AGENCYID_MissingClientSignatureFlags` |
| [sql/04_clear_trigger_COMMIT.sql](sql/04_clear_trigger_COMMIT.sql) | `tr_DocumentSignatures_AGENCYID_MissClientSigClear` + catch-up sync |
| [sql/99_undo_COMMIT.sql](sql/99_undo_COMMIT.sql) | Soft-clear notes, drop trigger/proc (Flag Types optional) |

## Customize before F5

1. Find/replace **`AGENCYID`** → your prefix (example `ACME`).
2. Edit the `@Cfg` / `@Wanted` tables: your `DocumentCodeId`, Flag Type display name, and stamp (`CreatedBy` on notes).
3. Confirm `IconId` exists on your database (discovery lists icons).
4. Select the target database in SSMS. Scripts have **no** `USE` of a customer DB name.

## Related

- Method overview: [Client Tracking](../Client_Tracking/README.md)
- List flags already on charts: [Client chart flags report](../Client_Chart_Flags_Report/README.md)
