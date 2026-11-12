/*======================================================================================================================
File: 03_register_catalog_report_template_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Template: register an Ad-hoc CatalogReport that binds ENTATTR columns only
  (no raw SQL in CatalogReportXML).
  Prerequisites:
    - Adhoc.vw_AGENCYID_ExampleDocumentList exists (02_*)
    - You added a Table + Entity for that view into the target Catalogs.CatalogXML
      (Billing / Clinical / MCO — site-specific XML edit; do that carefully)
  1) Find/replace AGENCYID.
  2) Set @CatalogId from 01_discovery.
  3) Set @StaffId to a publisher staff row (ShareReport = Y needs this).
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y (dbo.CatalogReports)
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CatalogId INT = 0;   /* REPLACE: CatalogId from discovery */
DECLARE @StaffId INT = 0;     /* REPLACE: publisher StaffId */
DECLARE @ReportName VARCHAR(250) = N'AGENCYID Example Document List';
DECLARE @Stamp VARCHAR(30) = N'AGENCYID_AdhocReg';

IF @CatalogId IS NULL OR @CatalogId <= 0
BEGIN
    RAISERROR(N'Set @CatalogId before F5.', 16, 1);
    RETURN;
END;

IF @StaffId IS NULL OR @StaffId <= 0
BEGIN
    RAISERROR(N'Set @StaffId (publisher) before F5.', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'Adhoc.vw_AGENCYID_ExampleDocumentList', N'V') IS NULL
BEGIN
    RAISERROR(N'Adhoc.vw_AGENCYID_ExampleDocumentList missing. Run 02 first.', 16, 1);
    RETURN;
END;

/*
  CatalogReportXML must be ENTATTR-only. Shape varies by SmartCare build.
  Replace the inner attribute list to match columns you exposed on the entity
  after editing CatalogXML. Do NOT put Expr class="SQL" / raw SELECT here.
*/
DECLARE @Xml XML = N'
<Report>
  <Columns>
    <Column name="DocumentId" />
    <Column name="ClientId" />
    <Column name="DocumentCodeId" />
    <Column name="DocumentName" />
    <Column name="EffectiveDate" />
    <Column name="Status" />
    <Column name="AuthorId" />
    <Column name="CurrentDocumentVersionId" />
    <Column name="SignedByAuthor" />
  </Columns>
</Report>';

BEGIN TRANSACTION;

IF EXISTS (
    SELECT 1
    FROM dbo.CatalogReports AS cr
    WHERE cr.ReportName = @ReportName
      AND ISNULL(cr.RecordDeleted, N'N') = N'N'
)
BEGIN
    UPDATE dbo.CatalogReports
    SET
        CatalogId = @CatalogId,
        StaffId = @StaffId,
        ShareReport = N'Y',
        Active = N'Y',
        CatalogReportXML = @Xml,
        ModifiedBy = @Stamp,
        ModifiedDate = GETDATE()
    WHERE ReportName = @ReportName
      AND ISNULL(RecordDeleted, N'N') = N'N';

    SELECT N'SUCCESS' AS [Status], N'Updated existing CatalogReport' AS [Detail], @ReportName AS [ReportName];
END
ELSE
BEGIN
    INSERT INTO dbo.CatalogReports (
        ReportName,
        CatalogId,
        StaffId,
        ShareReport,
        Active,
        CatalogReportXML,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate
    )
    VALUES (
        @ReportName,
        @CatalogId,
        @StaffId,
        N'Y',
        N'Y',
        @Xml,
        @Stamp,
        GETDATE(),
        @Stamp,
        GETDATE()
    );

    SELECT N'SUCCESS' AS [Status], N'Inserted CatalogReport' AS [Detail], @ReportName AS [ReportName], SCOPE_IDENTITY() AS [CatalogReportId];
END;

COMMIT TRANSACTION;
GO

/*
  After F5:
  1) Confirm CatalogXML already exposes Adhoc.vw_AGENCYID_ExampleDocumentList as Table/Entity.
  2) Administration → Shared Tables → Refresh (or re-login).
  3) Open Ad-hoc and confirm the report list + designer pane (blank pane often means raw SQL in XML).
*/
