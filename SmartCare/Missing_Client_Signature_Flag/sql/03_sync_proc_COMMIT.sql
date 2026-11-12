/*======================================================================================================================
File: 03_sync_proc_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Deploy dbo.ssp_AGENCYID_MissingClientSignatureFlags
  Syncs ClientNotes for configured DocumentCodes (staff signed, client pad open).
  1) Find/replace AGENCYID with your site prefix (object name + @Cfg stamps).
  2) Edit @Cfg to match 02_flagtypes FlagType names and Code stamps.
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y (DDL; EXEC separately to write ClientNotes)
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.ssp_AGENCYID_MissingClientSignatureFlags
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NoteLevelId INT;
    DECLARE @AsOf DATE = CAST(GETDATE() AS DATE);
    DECLARE @Inserted INT = 0;
    DECLARE @Cleared INT = 0;
    DECLARE @Updated INT = 0;

    SELECT TOP (1)
        @NoteLevelId = gc.GlobalCodeId
    FROM dbo.GlobalCodes AS gc
    WHERE RTRIM(LTRIM(gc.Category)) = N'CLIENTNOTELEVEL'
      AND gc.CodeName = N'Warning'
      AND gc.Active = N'Y'
      AND ISNULL(gc.RecordDeleted, N'N') = N'N';

    IF @NoteLevelId IS NULL
    BEGIN
        RAISERROR(N'CLIENTNOTELEVEL Warning missing.', 16, 1);
        RETURN;
    END;

    /* Config: FlagType name must match FlagTypes.FlagType. Stamp = ClientNotes.CreatedBy. */
    DECLARE @Cfg TABLE (
        DocumentCodeId INT NOT NULL PRIMARY KEY,
        FlagTypeName   VARCHAR(250) NOT NULL,
        Stamp          VARCHAR(30) NOT NULL
    );

    /* ---- edit: must match 02_flagtypes ---- */
    INSERT INTO @Cfg (DocumentCodeId, FlagTypeName, Stamp) VALUES
        (10001, N'Example Form A needs client signature', N'AGENCYID_FormAClientSig'),
        (10002, N'Example Form B needs client signature', N'AGENCYID_FormBClientSig');

    /*
      Explicit #Due schema. Do not SELECT INTO — a leftover #Due in the SSMS
      session makes CREATE OR ALTER resolve against the wrong columns.
    */
    IF OBJECT_ID(N'tempdb..#Due') IS NOT NULL
        DROP TABLE #Due;

    CREATE TABLE #Due (
        DocumentCodeId INT NOT NULL,
        FlagTypeId     INT NOT NULL,
        Stamp          VARCHAR(30) NOT NULL,
        FlagTypeName   VARCHAR(250) NOT NULL,
        ClientId       INT NOT NULL,
        DocumentId     INT NOT NULL,
        EffectiveDate  DATETIME NULL,
        NoteText       VARCHAR(max) NOT NULL
    );

    ;WITH LiveFlags AS (
        SELECT
            c.DocumentCodeId,
            c.FlagTypeName,
            c.Stamp,
            ft.FlagTypeId
        FROM @Cfg AS c
        INNER JOIN dbo.FlagTypes AS ft
            ON ft.FlagType = c.FlagTypeName
           AND ft.Active = N'Y'
           AND ISNULL(ft.RecordDeleted, N'N') = N'N'
    ),
    Cur AS (
        SELECT
            lf.DocumentCodeId,
            lf.FlagTypeId,
            lf.Stamp,
            lf.FlagTypeName,
            d.ClientId,
            d.DocumentId,
            d.CurrentDocumentVersionId,
            d.EffectiveDate,
            d.SignedByAuthor
        FROM LiveFlags AS lf
        INNER JOIN dbo.Documents AS d
            ON d.DocumentCodeId = lf.DocumentCodeId
           AND ISNULL(d.RecordDeleted, N'N') = N'N'
           AND d.CurrentDocumentVersionId IS NOT NULL
           AND d.ClientId IS NOT NULL
    ),
    Marked AS (
        SELECT
            c.DocumentCodeId,
            c.FlagTypeId,
            c.Stamp,
            c.FlagTypeName,
            c.ClientId,
            c.DocumentId,
            c.EffectiveDate,
            StaffSigned = CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.DocumentSignatures AS ds
                    WHERE ds.SignedDocumentVersionId = c.CurrentDocumentVersionId
                      AND ISNULL(ds.RecordDeleted, N'N') = N'N'
                      AND ISNULL(ds.IsClient, N'N') = N'N'
                      AND ds.SignatureDate IS NOT NULL
                ) THEN 1
                WHEN c.SignedByAuthor = N'Y' THEN 1
                ELSE 0
            END,
            ClientSigned = CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.DocumentSignatures AS ds
                    WHERE ds.SignedDocumentVersionId = c.CurrentDocumentVersionId
                      AND ISNULL(ds.RecordDeleted, N'N') = N'N'
                      AND ISNULL(ds.IsClient, N'N') = N'Y'
                      AND (
                            ds.SignatureDate IS NOT NULL
                            OR ISNULL(ds.ClientSignedPaper, N'N') = N'Y'
                            OR ISNULL(ds.DeclinedSignature, N'N') = N'Y'
                          )
                ) THEN 1
                ELSE 0
            END
        FROM Cur AS c
    ),
    Gaps AS (
        SELECT
            m.DocumentCodeId,
            m.FlagTypeId,
            m.Stamp,
            m.FlagTypeName,
            m.ClientId,
            m.DocumentId,
            m.EffectiveDate,
            rn = ROW_NUMBER() OVER (
                PARTITION BY m.FlagTypeId, m.ClientId
                ORDER BY m.EffectiveDate DESC, m.DocumentId DESC
            )
        FROM Marked AS m
        WHERE m.StaffSigned = 1
          AND m.ClientSigned = 0
    )
    INSERT INTO #Due (
        DocumentCodeId,
        FlagTypeId,
        Stamp,
        FlagTypeName,
        ClientId,
        DocumentId,
        EffectiveDate,
        NoteText
    )
    SELECT
        g.DocumentCodeId,
        g.FlagTypeId,
        g.Stamp,
        g.FlagTypeName,
        g.ClientId,
        g.DocumentId,
        g.EffectiveDate,
        CONCAT(
            g.FlagTypeName,
            N' (DocumentId ',
            CAST(g.DocumentId AS VARCHAR(20)),
            CASE
                WHEN g.EffectiveDate IS NULL THEN N')'
                ELSE CONCAT(N', effective ', CONVERT(VARCHAR(10), g.EffectiveDate, 101), N')')
            END
        )
    FROM Gaps AS g
    WHERE g.rn = 1;

    DECLARE @DueClients INT = (SELECT COUNT(*) FROM #Due);

    UPDATE cn
    SET
        Note = d.NoteText,
        DueDate = ISNULL(d.EffectiveDate, CAST(@AsOf AS DATETIME)),
        NoteLevel = @NoteLevelId,
        FlagLinkTo = N'D',
        DocumentCodeId = d.DocumentCodeId,
        DocumentId = d.DocumentId,
        ModifiedBy = d.Stamp,
        ModifiedDate = GETDATE()
    FROM dbo.ClientNotes AS cn
    INNER JOIN #Due AS d
        ON d.ClientId = cn.ClientId
       AND d.FlagTypeId = cn.NoteType
    WHERE cn.Active = N'Y'
      AND ISNULL(cn.RecordDeleted, N'N') = N'N'
      AND cn.CreatedBy = d.Stamp
      AND (
            ISNULL(cn.Note, N'') <> d.NoteText
            OR cn.NoteLevel <> @NoteLevelId
            OR ISNULL(cn.FlagLinkTo, N'') <> N'D'
            OR ISNULL(cn.DocumentCodeId, 0) <> d.DocumentCodeId
            OR ISNULL(cn.DocumentId, 0) <> d.DocumentId
          );

    SET @Updated = @@ROWCOUNT;

    INSERT INTO dbo.ClientNotes (
        ClientId,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate,
        NoteType,
        NoteLevel,
        Note,
        Active,
        StartDate,
        OpenDate,
        DueDate,
        EndDate,
        AssignedTo,
        FlagLinkTo,
        DocumentCodeId,
        DocumentId
    )
    SELECT
        d.ClientId,
        d.Stamp,
        GETDATE(),
        d.Stamp,
        GETDATE(),
        d.FlagTypeId,
        @NoteLevelId,
        d.NoteText,
        N'Y',
        CAST(@AsOf AS DATETIME),
        CAST(@AsOf AS DATETIME),
        ISNULL(d.EffectiveDate, CAST(@AsOf AS DATETIME)),
        NULL,
        NULL,
        N'D',
        d.DocumentCodeId,
        d.DocumentId
    FROM #Due AS d
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.ClientNotes AS cn
        WHERE cn.ClientId = d.ClientId
          AND cn.NoteType = d.FlagTypeId
          AND cn.Active = N'Y'
          AND ISNULL(cn.RecordDeleted, N'N') = N'N'
    );

    SET @Inserted = @@ROWCOUNT;

    /* Clear only stamped rows whose FlagType+Client is no longer due. */
    UPDATE cn
    SET
        Active = N'N',
        EndDate = CAST(@AsOf AS DATETIME),
        ModifiedBy = cfg.Stamp,
        ModifiedDate = GETDATE()
    FROM dbo.ClientNotes AS cn
    INNER JOIN @Cfg AS cfg
        ON cfg.Stamp = cn.CreatedBy
    INNER JOIN dbo.FlagTypes AS ft
        ON ft.FlagType = cfg.FlagTypeName
       AND ft.FlagTypeId = cn.NoteType
       AND ISNULL(ft.RecordDeleted, N'N') = N'N'
    WHERE cn.Active = N'Y'
      AND ISNULL(cn.RecordDeleted, N'N') = N'N'
      AND NOT EXISTS (
            SELECT 1
            FROM #Due AS d
            WHERE d.ClientId = cn.ClientId
              AND d.FlagTypeId = cn.NoteType
          );

    SET @Cleared = @@ROWCOUNT;

    DROP TABLE #Due;

    SELECT
        StatusText = N'OK',
        Detail = N'sync complete',
        Inserted = @Inserted,
        Cleared = @Cleared,
        Updated = @Updated,
        DueClients = @DueClients;
END;
GO

SELECT
    N'SUCCESS' AS [Status],
    OBJECT_ID(N'dbo.ssp_AGENCYID_MissingClientSignatureFlags', N'P') AS [ObjectId],
    N'ssp_AGENCYID_MissingClientSignatureFlags' AS [ProcName];
GO

/* Optional first sync — uncomment after Flag Types exist and you accept ClientNotes writes:
EXEC dbo.ssp_AGENCYID_MissingClientSignatureFlags;
GO
*/
