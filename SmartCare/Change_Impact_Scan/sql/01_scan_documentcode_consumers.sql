/*======================================================================================================================
File: 01_scan_documentcode_consumers.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Read-only impact scan before hide / relocate / rename of a DocumentCode.
  Set @DocumentCodeId. Select the target SmartCare database in SSMS (no USE).

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
    dc.Active,
    dc.ServiceNote,
    dc.TableList,
    dc.ViewDocumentRDL
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId;

SELECT
    s.ScreenId,
    s.ScreenName,
    s.DocumentCodeId,
    s.Active,
    s.AllowedToOpenDirectly
FROM dbo.Screens AS s
WHERE s.DocumentCodeId = @DocumentCodeId
  AND ISNULL(s.RecordDeleted, N'N') = N'N';

SELECT
    b.BannerId,
    b.BannerName,
    b.ScreenId,
    b.ParentBannerId,
    b.Active
FROM dbo.Banners AS b
INNER JOIN dbo.Screens AS s
    ON s.ScreenId = b.ScreenId
WHERE s.DocumentCodeId = @DocumentCodeId
  AND ISNULL(b.RecordDeleted, N'N') = N'N'
  AND ISNULL(s.RecordDeleted, N'N') = N'N';

SELECT
    ft.FlagTypeId,
    ft.FlagType,
    ft.FlagLinkTo,
    ft.DocumentCodeId,
    ft.Active
FROM dbo.FlagTypes AS ft
WHERE ft.DocumentCodeId = @DocumentCodeId
  AND ISNULL(ft.RecordDeleted, N'N') = N'N';

SELECT
    dv.DocumentValidationId,
    dv.DocumentCodeId,
    dv.ErrorMessage,
    dv.Active
FROM dbo.DocumentValidations AS dv
WHERE dv.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dv.RecordDeleted, N'N') = N'N';

SELECT
    pc.ProcedureCodeId,
    pc.DisplayAs,
    pc.AssociatedNoteId,
    pc.Active
FROM dbo.ProcedureCodes AS pc
WHERE pc.AssociatedNoteId = @DocumentCodeId
  AND ISNULL(pc.RecordDeleted, N'N') = N'N';

/* Adhoc / Catalog text search — may be slow; review hits before hide */
SELECT
    N'CatalogXML' AS [WhereFound],
    c.CatalogId,
    c.CatalogName
FROM dbo.Catalogs AS c
WHERE CAST(c.CatalogXML AS NVARCHAR(MAX)) LIKE N'%' + CAST(@DocumentCodeId AS NVARCHAR(20)) + N'%'
  AND ISNULL(c.RecordDeleted, N'N') = N'N';

SELECT
    N'CatalogReportXML' AS [WhereFound],
    cr.CatalogReportId,
    cr.ReportName
FROM dbo.CatalogReports AS cr
WHERE CAST(cr.CatalogReportXML AS NVARCHAR(MAX)) LIKE N'%' + CAST(@DocumentCodeId AS NVARCHAR(20)) + N'%'
  AND ISNULL(cr.RecordDeleted, N'N') = N'N';

SELECT
    N'sys.sql_modules' AS [WhereFound],
    OBJECT_SCHEMA_NAME(m.object_id) AS [SchemaName],
    OBJECT_NAME(m.object_id) AS [ObjectName]
FROM sys.sql_modules AS m
WHERE m.definition LIKE N'%' + CAST(@DocumentCodeId AS NVARCHAR(20)) + N'%'
ORDER BY 2, 3;
GO
