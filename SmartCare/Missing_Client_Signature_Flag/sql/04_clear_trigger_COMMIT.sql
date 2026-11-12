/*======================================================================================================================
File: 04_clear_trigger_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  AFTER INSERT/UPDATE on dbo.DocumentSignatures: clear Active ClientNotes when
  the client pad completes for configured DocumentCodes.
  UPDATE ClientNotes only — never INSERT (no SignatureId / identity steal).
  1) Find/replace AGENCYID.
  2) Edit @Cfg to match 02/03.
  Requires ssp_AGENCYID_MissingClientSignatureFlags already deployed.
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y (DDL + catch-up EXEC)
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
GO

CREATE OR ALTER TRIGGER dbo.tr_DocumentSignatures_AGENCYID_MissClientSigClear
ON dbo.DocumentSignatures
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Clear only. Never INSERT ClientNotes here (ClientNoteId is IDENTITY). */
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @AsOf DATETIME = GETDATE();

    DECLARE @Cfg TABLE (
        DocumentCodeId INT NOT NULL PRIMARY KEY,
        FlagTypeName   VARCHAR(250) NOT NULL,
        Stamp          VARCHAR(30) NOT NULL
    );

    /* ---- edit: must match 02_flagtypes / 03_sync_proc ---- */
    INSERT INTO @Cfg (DocumentCodeId, FlagTypeName, Stamp) VALUES
        (10001, N'Example Form A needs client signature', N'AGENCYID_FormAClientSig'),
        (10002, N'Example Form B needs client signature', N'AGENCYID_FormBClientSig');

    ;WITH ClientDone AS (
        SELECT DISTINCT
            d.ClientId,
            cfg.DocumentCodeId,
            cfg.Stamp,
            ft.FlagTypeId
        FROM inserted AS i
        INNER JOIN dbo.Documents AS d
            ON d.CurrentDocumentVersionId = i.SignedDocumentVersionId
           AND ISNULL(d.RecordDeleted, N'N') = N'N'
           AND d.ClientId IS NOT NULL
        INNER JOIN @Cfg AS cfg
            ON cfg.DocumentCodeId = d.DocumentCodeId
        INNER JOIN dbo.FlagTypes AS ft
            ON ft.FlagType = cfg.FlagTypeName
           AND ft.Active = N'Y'
           AND ISNULL(ft.RecordDeleted, N'N') = N'N'
        WHERE ISNULL(i.RecordDeleted, N'N') = N'N'
          AND ISNULL(i.IsClient, N'N') = N'Y'
          AND (
                i.SignatureDate IS NOT NULL
                OR ISNULL(i.ClientSignedPaper, N'N') = N'Y'
                OR ISNULL(i.DeclinedSignature, N'N') = N'Y'
              )
    ),
    StillDue AS (
        SELECT
            d.ClientId,
            cfg.DocumentCodeId
        FROM dbo.Documents AS d
        INNER JOIN @Cfg AS cfg
            ON cfg.DocumentCodeId = d.DocumentCodeId
        WHERE ISNULL(d.RecordDeleted, N'N') = N'N'
          AND d.CurrentDocumentVersionId IS NOT NULL
          AND d.ClientId IS NOT NULL
          AND EXISTS (
                SELECT 1
                FROM ClientDone AS cd
                WHERE cd.ClientId = d.ClientId
                  AND cd.DocumentCodeId = cfg.DocumentCodeId
              )
          AND (
                EXISTS (
                    SELECT 1
                    FROM dbo.DocumentSignatures AS ds
                    WHERE ds.SignedDocumentVersionId = d.CurrentDocumentVersionId
                      AND ISNULL(ds.RecordDeleted, N'N') = N'N'
                      AND ISNULL(ds.IsClient, N'N') = N'N'
                      AND ds.SignatureDate IS NOT NULL
                )
                OR d.SignedByAuthor = N'Y'
              )
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.DocumentSignatures AS ds
                WHERE ds.SignedDocumentVersionId = d.CurrentDocumentVersionId
                  AND ISNULL(ds.RecordDeleted, N'N') = N'N'
                  AND ISNULL(ds.IsClient, N'N') = N'Y'
                  AND (
                        ds.SignatureDate IS NOT NULL
                        OR ISNULL(ds.ClientSignedPaper, N'N') = N'Y'
                        OR ISNULL(ds.DeclinedSignature, N'N') = N'Y'
                      )
              )
    )
    UPDATE cn
    SET
        Active = N'N',
        EndDate = @AsOf,
        ModifiedBy = cd.Stamp,
        ModifiedDate = @AsOf
    FROM dbo.ClientNotes AS cn
    INNER JOIN ClientDone AS cd
        ON cd.ClientId = cn.ClientId
       AND cd.FlagTypeId = cn.NoteType
       AND cd.Stamp = cn.CreatedBy
    WHERE cn.Active = N'Y'
      AND ISNULL(cn.RecordDeleted, N'N') = N'N'
      AND NOT EXISTS (
            SELECT 1
            FROM StillDue AS sd
            WHERE sd.ClientId = cn.ClientId
              AND sd.DocumentCodeId = cd.DocumentCodeId
        );
END;
GO

SELECT
    N'SUCCESS' AS [Status],
    N'tr_DocumentSignatures_AGENCYID_MissClientSigClear' AS [TriggerName],
    OBJECT_ID(N'dbo.tr_DocumentSignatures_AGENCYID_MissClientSigClear', N'TR') AS [ObjectId];
GO

/* Catch-up for anyone who signed before the trigger existed */
EXEC dbo.ssp_AGENCYID_MissingClientSignatureFlags;
GO
