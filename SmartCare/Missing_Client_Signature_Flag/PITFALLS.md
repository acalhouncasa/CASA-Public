# Pitfalls — missing client signature flag

## Do

| Do | Why |
|----|-----|
| Live alerts on **`dbo.ClientNotes`** | Many sites have empty `ObjectFlags` |
| Set **`DocumentId`** when `FlagLinkTo = D` | `DocumentCodeId` alone often opens the wrong place |
| Clear trigger: **UPDATE only** on `ClientNotes` | Never INSERT from `DocumentSignatures` AFTER INSERT |
| Client complete includes **`DeclinedSignature`** | Column is not `DeclineSignature` |
| **`CREATE TABLE #Due`** with explicit columns | Do not `SELECT INTO #Due` — leftover `#Due` in the SSMS session breaks `CREATE OR ALTER` |
| Match Flag Type **name** and stamp across FlagTypes / ssp / trigger | Sync joins on name; notes key on `CreatedBy` stamp |
| Keep stamps ≤ **30** characters | `type_CurrentUser` / `type_UserId` width |

## Do not

| Do not | Why |
|--------|-----|
| INSERT `ClientNotes` inside a `DocumentSignatures` trigger | `ClientNoteId` is IDENTITY — steals `@@IDENTITY` / create-path identity for the signature row |
| Rely on sync alone for clear-at-sign | Flag stays until the next EXEC without the trigger |
| Assume every DocumentCode has client pads | Some plans use `RequiresSignature = N` and never write client `DocumentSignatures` |
| Copy another agency’s DocumentCodeId values | IDs differ by customer database |
| Edit vendor `ssp_PostSignatureUpdate*` in place | Prefer your clear trigger + sync ssp |

## Identity steal (short)

`DocumentSignatures` insert path may read identity for the new signature. If your AFTER INSERT trigger inserts another IDENTITY table (`ClientNotes`), the app can store the **note** id as the signature id. Clear by UPDATE only.
