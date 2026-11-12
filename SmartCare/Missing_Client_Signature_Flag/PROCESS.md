# Process — missing client signature flag

**Do not test in Prod.**

## 0. Decide the rules

For each form you watch, lock:

| Decision | Typical rule in this pack |
|----------|---------------------------|
| Staff signed | Non-client `DocumentSignatures` row with `SignatureDate`, **or** `Documents.SignedByAuthor = Y` |
| Client complete | Client pad with `SignatureDate`, **or** `ClientSignedPaper = Y`, **or** `DeclinedSignature = Y` |
| Grain | One active note per `ClientId` + Flag Type (latest open document wins) |
| Popup | `FlagLinkTo = D`, set **`DocumentId`** (not only `DocumentCodeId`) |

## 1. Discovery (read-only)

1. Open SSMS on a non-Prod database.
2. F5 [sql/01_discovery.sql](sql/01_discovery.sql).
3. Pick DocumentCodeIds that actually use client pads.
4. Note a valid `IconId` (or create an icon in Admin first).
5. Confirm `CLIENTNOTELEVEL` / `Warning` exists.

## 2. Flag Types

1. Edit `@Wanted` in [sql/02_flagtypes_COMMIT.sql](sql/02_flagtypes_COMMIT.sql).
2. Replace `AGENCYID` with your prefix.
3. Set `@IconId`.
4. F5 whole file. Keep the SUCCESS grid (FlagTypeId values).

## 3. Sync procedure

1. Edit `@Cfg` in [sql/03_sync_proc_COMMIT.sql](sql/03_sync_proc_COMMIT.sql) so names/stamps match step 2.
2. Replace `AGENCYID`.
3. F5 whole file. Confirm ObjectId is not NULL.
4. Optionally `EXEC dbo.ssp_AGENCYID_MissingClientSignatureFlags;` once and review Inserted/Cleared/Updated.

Raise path (staff signs → flag appears) can stay on manual EXEC or a SQL Agent job named `{Database} - ssp_AGENCYID_MissingClientSignatureFlags`. Clear path should be the trigger.

## 4. Clear-on-sign trigger

1. Edit `@Cfg` in [sql/04_clear_trigger_COMMIT.sql](sql/04_clear_trigger_COMMIT.sql) to match.
2. Replace `AGENCYID`.
3. F5 whole file (creates trigger, then catch-up EXEC).
4. Confirm trigger ObjectId and sync OK grid.

## 5. UAT

| Test | Expect |
|------|--------|
| Staff-signed, client pad open | Active chart flag; popup opens that **DocumentId** |
| Client signs / paper / decline | Flag clears without a manual sync |
| Header icon sticks | Reopen the chart (Shared Tables refresh is not required for row clears) |
| Second document for same client/code | Still due → flag stays; not due → clears |

## 6. Undo

[sql/99_undo_COMMIT.sql](sql/99_undo_COMMIT.sql) deactivates stamped notes and drops the trigger/proc. Flag Type rows are left unless you uncomment that section.
