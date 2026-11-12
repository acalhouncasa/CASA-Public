/*======================================================================================================================
File: 01_discovery_catalogs.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Read-only: list Ad-hoc catalogs, existing Adhoc views, and sample CatalogReports.
  Select the target SmartCare database in SSMS (no USE).

Mutates: N
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;

SELECT
    c.CatalogId,
    c.CatalogName,
    c.Active,
    LEN(CAST(c.CatalogXML AS NVARCHAR(MAX))) AS [CatalogXmlChars]
FROM dbo.Catalogs AS c
WHERE ISNULL(c.RecordDeleted, N'N') = N'N'
ORDER BY c.CatalogName;

SELECT
    s.name AS [SchemaName],
    v.name AS [ViewName]
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE s.name = N'Adhoc'
ORDER BY v.name;

SELECT TOP (50)
    cr.CatalogReportId,
    cr.ReportName,
    cr.CatalogId,
    cr.ShareReport,
    cr.StaffId,
    cr.Active
FROM dbo.CatalogReports AS cr
WHERE ISNULL(cr.RecordDeleted, N'N') = N'N'
ORDER BY cr.CatalogReportId DESC;
GO
