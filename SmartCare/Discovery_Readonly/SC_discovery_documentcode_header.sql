/*======================================================================================================================
File:    SC_discovery_documentcode_header.sql
Purpose: Read-only DocumentCode header + forms in the collection.
Mutates: N
License: MIT
======================================================================================================================*/

SET NOCOUNT ON;

DECLARE @DocumentCodeId INT = 0;  /* REQUIRED */

IF @DocumentCodeId = 0
BEGIN
    RAISERROR(N'Set @DocumentCodeId.', 16, 1);
    RETURN;
END;

SELECT
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.Active,
    dc.TableList,
    dc.FormCollectionId,
    dc.StoredProcedure,
    dc.ValidationStoredProcedure,
    dc.InitializationStoredProcedure
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId;

SELECT
    fcf.FormOrder,
    f.FormId,
    f.FormName,
    f.TableName,
    JsOverride = f.IsJavascriptOverride,
    JsLen = LEN(f.FormJavascript)
FROM dbo.DocumentCodes AS dc
INNER JOIN dbo.FormCollectionForms AS fcf
    ON fcf.FormCollectionId = dc.FormCollectionId
   AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.Forms AS f
    ON f.FormId = fcf.FormId
   AND ISNULL(f.RecordDeleted, N'N') = N'N'
WHERE dc.DocumentCodeId = @DocumentCodeId
ORDER BY fcf.FormOrder;
