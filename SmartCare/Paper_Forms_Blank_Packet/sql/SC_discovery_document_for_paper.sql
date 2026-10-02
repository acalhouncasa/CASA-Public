/*======================================================================================================================
File: SC_discovery_document_for_paper.sql
Purpose: Identify a DocumentCode and its FormCollection tabs for a blank paper packet.
Mutates: N — SELECT only.
Usage: Set @DocumentCodeId. Select the database in SSMS (no customer USE).
License: MIT (CASA-Public)
======================================================================================================================*/

DECLARE @DocumentCodeId INT = 0;  -- set me

SET NOCOUNT ON;

SELECT
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.FormCollectionId,
    dc.RequiresSignature,
    dc.Active,
    dc.ServiceNote,
    LEFT(CAST(dc.TableList AS NVARCHAR(MAX)), 400) AS TableListPreview
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dc.RecordDeleted, N'N') = N'N';

-- Live collection tabs (preferred source of FormOrder)
SELECT
    fcf.FormOrder,
    f.FormId,
    f.FormName,
    f.TableName,
    f.Active AS FormActive
FROM dbo.DocumentCodes AS dc
INNER JOIN dbo.FormCollectionForms AS fcf
    ON fcf.FormCollectionId = dc.FormCollectionId
   AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.Forms AS f
    ON f.FormId = fcf.FormId
   AND ISNULL(f.RecordDeleted, N'N') = N'N'
WHERE dc.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dc.RecordDeleted, N'N') = N'N'
ORDER BY fcf.FormOrder, f.FormId;

-- Fallback hint: forms named in TableList when FormCollectionId is null
SELECT
    f.FormId,
    f.FormName,
    f.TableName
FROM dbo.DocumentCodes AS dc
INNER JOIN dbo.Forms AS f
    ON ISNULL(f.RecordDeleted, N'N') = N'N'
   AND ISNULL(f.Active, N'Y') = N'Y'
   AND LEN(ISNULL(f.TableName, N'')) > 8
   AND CHARINDEX(f.TableName, CAST(dc.TableList AS NVARCHAR(MAX))) > 0
WHERE dc.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dc.RecordDeleted, N'N') = N'N'
  AND dc.FormCollectionId IS NULL
ORDER BY f.FormId;
