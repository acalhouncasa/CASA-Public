/*======================================================================================================================
File: SC_wire_FormJavascript_template_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Wire Forms.FormJavascript + IsJavascriptOverride = Y for a DFA live-scoring form.
  1) Set @TableName to CustomDocument* TableList value.
  2) Paste your script into @Js (see examples/*.js).
  3) Find/replace AGENCYID in the stamp if desired.
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y (dbo.Forms)
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TableName VARCHAR(100) = N'CustomDocumentYourForm';  /* REPLACE */
DECLARE @Stamp VARCHAR(30) = N'AGENCYID_ScoreJS';
DECLARE @Js NVARCHAR(MAX) = N'/* paste examples/scoring_total_from_radios.js or scoring_yes_count_radioyn.js */';

IF @TableName IS NULL OR LTRIM(RTRIM(@TableName)) = N''
BEGIN
    RAISERROR(N'Set @TableName before F5.', 16, 1);
    RETURN;
END;

IF @Js IS NULL OR LEN(@Js) < 20 OR @Js LIKE N'%paste examples%'
BEGIN
    RAISERROR(N'Paste real FormJavascript into @Js before F5.', 16, 1);
    RETURN;
END;

BEGIN TRANSACTION;

UPDATE f
SET
    FormJavascript = @Js,
    IsJavascriptOverride = N'Y',
    ModifiedBy = @Stamp,
    ModifiedDate = GETDATE()
FROM dbo.Forms AS f
INNER JOIN dbo.DocumentCodes AS dc
    ON dc.FormId = f.FormId
   AND ISNULL(dc.RecordDeleted, N'N') = N'N'
WHERE ISNULL(f.RecordDeleted, N'N') = N'N'
  AND (
        dc.TableList = @TableName
        OR dc.TableList LIKE @TableName + N',%'
        OR dc.TableList LIKE N'%,' + @TableName
        OR dc.TableList LIKE N'%,' + @TableName + N',%'
      );

DECLARE @Updated INT = @@ROWCOUNT;

IF @Updated = 0
BEGIN
    ROLLBACK TRANSACTION;
    RAISERROR(N'No Forms row matched DocumentCodes.TableList for @TableName.', 16, 1);
    RETURN;
END;

SELECT
    N'SUCCESS' AS [Status],
    @Updated AS [FormsUpdated],
    @TableName AS [TableName];

SELECT
    f.FormId,
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.TableList,
    f.IsJavascriptOverride,
    JsChars = LEN(CAST(f.FormJavascript AS NVARCHAR(MAX)))
FROM dbo.Forms AS f
INNER JOIN dbo.DocumentCodes AS dc
    ON dc.FormId = f.FormId
WHERE ISNULL(f.RecordDeleted, N'N') = N'N'
  AND ISNULL(dc.RecordDeleted, N'N') = N'N'
  AND (
        dc.TableList = @TableName
        OR dc.TableList LIKE @TableName + N',%'
        OR dc.TableList LIKE N'%,' + @TableName
        OR dc.TableList LIKE N'%,' + @TableName + N',%'
      );

COMMIT TRANSACTION;
GO

/*
  After F5: Shared Tables → Refresh; log out / in; test on a NEW document version.
*/
