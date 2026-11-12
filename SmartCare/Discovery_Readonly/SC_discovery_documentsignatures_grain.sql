/*======================================================================================================================
File: SC_discovery_documentsignatures_grain.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Read-only: DocumentSignatures grain for one DocumentCode (staff vs client pads).
  Set @DocumentCodeId. No client names. Select DB in SSMS (no USE).

Mutates: N
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;

DECLARE @DocumentCodeId INT = 0;  /* REPLACE */

IF @DocumentCodeId IS NULL OR @DocumentCodeId <= 0
BEGIN
    RAISERROR(N'Set @DocumentCodeId before F5.', 16, 1);
    RETURN;
END;

SELECT
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.RequiresSignature
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dc.RecordDeleted, N'N') = N'N';

SELECT
    IsClient = ISNULL(ds.IsClient, N'N'),
    HasSignatureDate = CASE WHEN ds.SignatureDate IS NOT NULL THEN N'Y' ELSE N'N' END,
    ClientSignedPaper = ISNULL(ds.ClientSignedPaper, N'N'),
    DeclinedSignature = ISNULL(ds.DeclinedSignature, N'N'),
    RowCount = COUNT(*)
FROM dbo.Documents AS d
INNER JOIN dbo.DocumentSignatures AS ds
    ON ds.SignedDocumentVersionId = d.CurrentDocumentVersionId
   AND ISNULL(ds.RecordDeleted, N'N') = N'N'
WHERE d.DocumentCodeId = @DocumentCodeId
  AND ISNULL(d.RecordDeleted, N'N') = N'N'
GROUP BY
    ISNULL(ds.IsClient, N'N'),
    CASE WHEN ds.SignatureDate IS NOT NULL THEN N'Y' ELSE N'N' END,
    ISNULL(ds.ClientSignedPaper, N'N'),
    ISNULL(ds.DeclinedSignature, N'N')
ORDER BY 1, 2, 3, 4;
GO
