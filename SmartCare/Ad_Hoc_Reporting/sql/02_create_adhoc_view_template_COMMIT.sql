/*======================================================================================================================
File: 02_create_adhoc_view_template_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Template Adhoc view for a custom SmartCare Ad-hoc report.
  1) Find/replace AGENCYID with your site prefix.
  2) Rewrite the SELECT for your grain (example uses Documents header only).
  3) Flat columns only — Ad-hoc designer binds attributes, not nested SQL.
  Select the target SmartCare database in SSMS (no USE).
  Do not put PHI in view names or comments you will publish.

Mutates: Y (DDL)
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Adhoc')
BEGIN
    EXEC (N'CREATE SCHEMA Adhoc AUTHORIZATION dbo;');
END;
GO

CREATE OR ALTER VIEW Adhoc.vw_AGENCYID_ExampleDocumentList
AS
    SELECT
        d.DocumentId,
        d.ClientId,
        d.DocumentCodeId,
        dc.DocumentName,
        d.EffectiveDate,
        d.Status,
        d.AuthorId,
        d.CurrentDocumentVersionId,
        d.SignedByAuthor
    FROM dbo.Documents AS d
    INNER JOIN dbo.DocumentCodes AS dc
        ON dc.DocumentCodeId = d.DocumentCodeId
       AND ISNULL(dc.RecordDeleted, N'N') = N'N'
    WHERE ISNULL(d.RecordDeleted, N'N') = N'N';
GO

SELECT
    N'SUCCESS' AS [Status],
    N'Adhoc.vw_AGENCYID_ExampleDocumentList' AS [ViewName],
    OBJECT_ID(N'Adhoc.vw_AGENCYID_ExampleDocumentList', N'V') AS [ObjectId];
GO
