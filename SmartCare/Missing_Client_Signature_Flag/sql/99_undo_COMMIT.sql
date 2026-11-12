/*======================================================================================================================
File: 99_undo_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Undo missing-client-signature flag deploy:
  - Deactivate ClientNotes created with AGENCYID_* stamps in @Stamps
  - DROP trigger and sync procedure
  Flag Types are left Active unless you uncomment the soft-delete section.
  1) Find/replace AGENCYID.
  2) Edit @Stamps to match your Code values from 02_flagtypes.
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @StampUndo VARCHAR(30) = N'AGENCYID_MissClientSigUndo';
DECLARE @AsOf DATETIME = GETDATE();

DECLARE @Stamps TABLE (Stamp VARCHAR(30) NOT NULL PRIMARY KEY);
INSERT INTO @Stamps (Stamp) VALUES
    (N'AGENCYID_FormAClientSig'),
    (N'AGENCYID_FormBClientSig');

UPDATE cn
SET
    Active = N'N',
    EndDate = @AsOf,
    ModifiedBy = @StampUndo,
    ModifiedDate = @AsOf
FROM dbo.ClientNotes AS cn
INNER JOIN @Stamps AS s
    ON s.Stamp = cn.CreatedBy
WHERE cn.Active = N'Y'
  AND ISNULL(cn.RecordDeleted, N'N') = N'N';

DECLARE @NotesCleared INT = @@ROWCOUNT;

/* Optional: soft-delete Flag Types created by this pack (edit names to match).
UPDATE ft
SET
    RecordDeleted = N'Y',
    DeletedBy = @StampUndo,
    DeletedDate = @AsOf,
    ModifiedBy = @StampUndo,
    ModifiedDate = @AsOf
FROM dbo.FlagTypes AS ft
WHERE ft.FlagType IN (
        N'Example Form A needs client signature',
        N'Example Form B needs client signature'
    )
  AND ISNULL(ft.RecordDeleted, N'N') = N'N';
*/

COMMIT TRANSACTION;
GO

IF OBJECT_ID(N'dbo.tr_DocumentSignatures_AGENCYID_MissClientSigClear', N'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_DocumentSignatures_AGENCYID_MissClientSigClear;
GO

IF OBJECT_ID(N'dbo.ssp_AGENCYID_MissingClientSignatureFlags', N'P') IS NOT NULL
    DROP PROCEDURE dbo.ssp_AGENCYID_MissingClientSignatureFlags;
GO

SELECT
    N'SUCCESS' AS [Status],
    N'Notes deactivated; trigger/proc dropped if present' AS [Detail],
    OBJECT_ID(N'dbo.tr_DocumentSignatures_AGENCYID_MissClientSigClear', N'TR') AS [TriggerObjectId],
    OBJECT_ID(N'dbo.ssp_AGENCYID_MissingClientSignatureFlags', N'P') AS [ProcObjectId];
GO
