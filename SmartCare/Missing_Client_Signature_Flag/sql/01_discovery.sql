/*======================================================================================================================
File: 01_discovery.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Read-only discovery before deploying missing-client-signature Flag Types.
  Edit @DocumentCodeId list after you know which forms to watch.
  Select the target SmartCare database in SSMS (no USE).

Mutates: N
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;

/* ---- edit: candidate DocumentCodeIds (examples only) ---- */
DECLARE @Codes TABLE (DocumentCodeId INT NOT NULL PRIMARY KEY);
INSERT INTO @Codes (DocumentCodeId) VALUES
    (10001),  /* REPLACE: example form A */
    (10002);  /* REPLACE: example form B */

/* Document header */
SELECT
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.Active,
    dc.RequiresSignature,
    dc.ServiceNote,
    dc.TableList
FROM dbo.DocumentCodes AS dc
INNER JOIN @Codes AS c
    ON c.DocumentCodeId = dc.DocumentCodeId
WHERE ISNULL(dc.RecordDeleted, N'N') = N'N'
ORDER BY dc.DocumentCodeId;

/* Icons you might use on Flag Types */
SELECT TOP (50)
    i.IconId,
    i.IconName,
    i.Class
FROM dbo.Icons AS i
WHERE ISNULL(i.RecordDeleted, N'N') = N'N'
  AND (
        i.Class LIKE N'%signature%'
        OR i.IconName LIKE N'%sign%'
        OR i.Class LIKE N'%flag%'
      )
ORDER BY i.IconId;

/* CLIENTNOTELEVEL Warning (sync proc needs this) */
SELECT
    gc.GlobalCodeId,
    gc.Code,
    gc.CodeName,
    gc.Category,
    gc.Active
FROM dbo.GlobalCodes AS gc
WHERE RTRIM(LTRIM(gc.Category)) = N'CLIENTNOTELEVEL'
  AND gc.Active = N'Y'
  AND ISNULL(gc.RecordDeleted, N'N') = N'N'
ORDER BY gc.SortOrder, gc.CodeName;

/* Existing Flag Types that already link to these DocumentCodes */
SELECT
    ft.FlagTypeId,
    ft.FlagType,
    ft.FlagLinkTo,
    ft.DocumentCodeId,
    ft.Code,
    ft.IconId,
    ft.NeverPopup,
    ft.Active
FROM dbo.FlagTypes AS ft
INNER JOIN @Codes AS c
    ON c.DocumentCodeId = ft.DocumentCodeId
WHERE ISNULL(ft.RecordDeleted, N'N') = N'N'
ORDER BY ft.DocumentCodeId, ft.FlagTypeId;

/* Signature grain sample (no client names) */
SELECT
    d.DocumentCodeId,
    DocumentCount = COUNT(*),
    WithCurrentVersion = SUM(CASE WHEN d.CurrentDocumentVersionId IS NOT NULL THEN 1 ELSE 0 END),
    StaffSigRows = SUM(CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.DocumentSignatures AS ds
            WHERE ds.SignedDocumentVersionId = d.CurrentDocumentVersionId
              AND ISNULL(ds.RecordDeleted, N'N') = N'N'
              AND ISNULL(ds.IsClient, N'N') = N'N'
              AND ds.SignatureDate IS NOT NULL
        ) THEN 1 ELSE 0 END),
    ClientCompleteRows = SUM(CASE
        WHEN EXISTS (
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
        ) THEN 1 ELSE 0 END)
FROM dbo.Documents AS d
INNER JOIN @Codes AS c
    ON c.DocumentCodeId = d.DocumentCodeId
WHERE ISNULL(d.RecordDeleted, N'N') = N'N'
GROUP BY d.DocumentCodeId
ORDER BY d.DocumentCodeId;

/* Gap counts: staff signed, client pad still open (ClientId only — no names) */
;WITH Cur AS (
    SELECT
        d.DocumentCodeId,
        d.ClientId,
        d.DocumentId,
        d.CurrentDocumentVersionId,
        d.EffectiveDate,
        d.SignedByAuthor
    FROM dbo.Documents AS d
    INNER JOIN @Codes AS c
        ON c.DocumentCodeId = d.DocumentCodeId
    WHERE ISNULL(d.RecordDeleted, N'N') = N'N'
      AND d.CurrentDocumentVersionId IS NOT NULL
      AND d.ClientId IS NOT NULL
),
Marked AS (
    SELECT
        c.DocumentCodeId,
        c.ClientId,
        c.DocumentId,
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
)
SELECT
    m.DocumentCodeId,
    GapDocuments = COUNT(*),
    GapClients = COUNT(DISTINCT m.ClientId)
FROM Marked AS m
WHERE m.StaffSigned = 1
  AND m.ClientSigned = 0
GROUP BY m.DocumentCodeId
ORDER BY m.DocumentCodeId;
GO
