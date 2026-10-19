/*
File: sql/03_register_my_reports_optional.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Purpose:
  Optional. Register the report in SmartCare My Reports.
  Upload the RDL first.
  Edit @ReportServerPath below so it matches that upload path.

  AssociatedWith stays NULL so this is a My Reports item, not a chart-level report.
  This file does not grant role permissions. Do that in Role Definition on the same database.

License: MIT
*/

SET NOCOUNT ON;

DECLARE @ReportServerPath varchar(500) = N'/ReplaceWithYourReportFolder/Client Chart Flags';

IF @ReportServerPath LIKE N'%ReplaceWith%'
    THROW 50002, N'Edit @ReportServerPath to the report server path before you run this file.', 1;

DECLARE @ReportServerId int;
SELECT TOP (1)
    @ReportServerId = rs.ReportServerId
FROM dbo.ReportServers AS rs
WHERE ISNULL(rs.RecordDeleted, N'N') = N'N'
ORDER BY rs.ReportServerId;

IF @ReportServerId IS NULL
    THROW 50004, N'No dbo.ReportServers row. Cannot register an in-app report.', 1;

DECLARE @Actor varchar(30) = LEFT(SUSER_SNAME(), 30);
DECLARE @FolderId int;
DECLARE @NewIds TABLE (ReportId int NOT NULL);

SELECT @FolderId = r.ReportId
FROM dbo.Reports AS r
WHERE r.Name = N'Client Chart Flags'
  AND r.IsFolder = N'Y'
  AND ISNULL(r.RecordDeleted, N'N') = N'N';

IF @FolderId IS NULL
BEGIN
    INSERT INTO dbo.Reports (
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate,
        ParentFolderId,
        ReportServerId,
        Name,
        Description,
        IsFolder,
        AssociatedWith,
        ReportServerPath,
        AddAsBanner,
        RowIdentifier
    )
    OUTPUT inserted.ReportId INTO @NewIds (ReportId)
    VALUES (
        @Actor,
        GETDATE(),
        @Actor,
        GETDATE(),
        NULL,
        @ReportServerId,
        N'Client Chart Flags',
        N'Client chart flags with flag type, open programs, and primary clinician.',
        N'Y',
        NULL,
        NULL,
        N'N',
        NEWID()
    );

    SELECT @FolderId = ReportId FROM @NewIds;
    DELETE FROM @NewIds;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Reports AS r
    WHERE r.Name = N'Client Chart Flags'
      AND ISNULL(r.IsFolder, N'N') <> N'Y'
      AND ISNULL(r.RecordDeleted, N'N') = N'N'
)
BEGIN
    INSERT INTO dbo.Reports (
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate,
        ParentFolderId,
        ReportServerId,
        Name,
        Description,
        IsFolder,
        AssociatedWith,
        ReportServerPath,
        AddAsBanner,
        RowIdentifier
    )
    VALUES (
        @Actor,
        GETDATE(),
        @Actor,
        GETDATE(),
        @FolderId,
        @ReportServerId,
        N'Client Chart Flags',
        N'Client chart flags with flag type, open programs, and primary clinician.',
        N'N',
        NULL,
        @ReportServerPath,
        N'N',
        NEWID()
    );
END
ELSE
BEGIN
    UPDATE dbo.Reports
    SET
        ReportServerPath = @ReportServerPath,
        ParentFolderId = @FolderId,
        ReportServerId = @ReportServerId,
        ModifiedBy = @Actor,
        ModifiedDate = GETDATE()
    WHERE Name = N'Client Chart Flags'
      AND ISNULL(IsFolder, N'N') <> N'Y'
      AND ISNULL(RecordDeleted, N'N') = N'N';
END;

SELECT
    r.ReportId,
    r.Name,
    IsFolder = ISNULL(r.IsFolder, N'N'),
    r.ParentFolderId,
    r.ReportServerPath,
    r.ReportServerId
FROM dbo.Reports AS r
WHERE ISNULL(r.RecordDeleted, N'N') = N'N'
  AND (
        r.Name = N'Client Chart Flags'
        OR r.ParentFolderId = @FolderId
      )
ORDER BY ISNULL(r.IsFolder, N'N') DESC, r.Name;
GO
