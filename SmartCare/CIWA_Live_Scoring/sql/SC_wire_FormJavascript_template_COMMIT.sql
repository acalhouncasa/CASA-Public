/*======================================================================================================================
File:    SC_wire_FormJavascript_template_COMMIT.sql
Purpose: Portable template — set Forms.FormJavascript + IsJavascriptOverride for one TableName.
         Select the SmartCare database in SSMS. Paste your JS into @Js (escape single quotes as '').
Mutates: Y
License: MIT
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TableName SYSNAME = N'CustomDocumentYourCIWA';  /* REQUIRED */
DECLARE @Js NVARCHAR(MAX) = N'/* paste JS from examples/ciwa_ar_live_total.js here */';

IF @Js IS NULL OR LEN(@Js) < 20 OR @Js LIKE N'%paste JS%'
BEGIN
    RAISERROR(N'Set @Js to your FormJavascript (full script).', 16, 1);
    RETURN;
END;

DECLARE @FormId INT;
SELECT @FormId = F.FormId
FROM dbo.Forms AS F
WHERE F.TableName = @TableName
  AND ISNULL(F.RecordDeleted, N'N') = N'N';

IF @FormId IS NULL
BEGIN
    RAISERROR(N'No Forms row for that TableName.', 16, 1);
    RETURN;
END;

BEGIN TRANSACTION;

UPDATE dbo.Forms
SET
    FormJavascript = @Js,
    IsJavascriptOverride = N'Y',
    ModifiedBy = LEFT(SUSER_SNAME(), 30),
    ModifiedDate = GETDATE()
WHERE FormId = @FormId;

COMMIT TRANSACTION;

SELECT
    Step = N'Wired',
    FormId,
    TableName,
    IsJavascriptOverride,
    JsLen = LEN(FormJavascript)
FROM dbo.Forms
WHERE FormId = @FormId;
