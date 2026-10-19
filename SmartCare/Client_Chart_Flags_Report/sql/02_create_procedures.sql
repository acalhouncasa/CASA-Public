/*
File: sql/02_create_procedures.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Purpose:
  Create a portable client chart flags report for Streamline SmartCare.
  Select the SmartCare database in SSMS. There is no USE statement.
  Apply.ps1 runs this file after the read-only check.

  Grain: one dbo.ObjectFlags row where TableNameOfObject = Clients.
  Date window is overlap. StartDate is blank or before the day after To.
  EndDate is blank or on/after From.
  Active means ObjectFlags.Active = Y and the end is blank or on/after To.
  Programs are Requested or Enrolled. The flag row does not split.
  Blank, -1, or All means every value for that filter.
  @DateFrom NULL returns one empty header or detail row so the report can read the field list.
  The typed client parameter is ClientIdx. Do not rename it to ClientId.

License: MIT
*/

SET NOCOUNT ON;
GO

CREATE OR ALTER FUNCTION dbo.ssf_SCReportIdList (@Ids varchar(max))
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT Id = TRY_CAST(LTRIM(RTRIM(s.value)) AS int)
    FROM STRING_SPLIT(ISNULL(@Ids, ''), ',') AS s
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(@Ids, ''))), '') IS NOT NULL
      AND LTRIM(RTRIM(@Ids)) <> '-1'
      AND CHARINDEX(',-1,', ',' + REPLACE(ISNULL(@Ids, ''), ' ', '') + ',') = 0
      AND TRY_CAST(LTRIM(RTRIM(s.value)) AS int) IS NOT NULL
      AND TRY_CAST(LTRIM(RTRIM(s.value)) AS int) <> -1
);
GO

CREATE OR ALTER FUNCTION dbo.ssf_SCReportTextList (
    @Items varchar(max),
    @AllToken varchar(50)
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT Item = LTRIM(RTRIM(s.value))
    FROM STRING_SPLIT(ISNULL(@Items, ''), ',') AS s
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(@Items, ''))), '') IS NOT NULL
      AND UPPER(LTRIM(RTRIM(ISNULL(@Items, '')))) <> UPPER(LTRIM(RTRIM(ISNULL(@AllToken, 'All'))))
      AND CHARINDEX(
            ',' + UPPER(LTRIM(RTRIM(ISNULL(@AllToken, 'All')))) + ',',
            ',' + UPPER(REPLACE(ISNULL(@Items, ''), ' ', '')) + ','
          ) = 0
      AND NULLIF(LTRIM(RTRIM(s.value)), '') IS NOT NULL
      AND UPPER(LTRIM(RTRIM(s.value))) <> UPPER(LTRIM(RTRIM(ISNULL(@AllToken, 'All'))))
);
GO

CREATE OR ALTER PROCEDURE dbo.ssp_SCClientChartFlagsFlagTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FlagTypeId = CAST(-1 AS int),
        FlagTypeName = CAST('All' AS varchar(200)),
        SortKey = 0
    UNION ALL
    SELECT
        ft.FlagTypeId,
        FlagTypeName = CAST(
            CASE
                WHEN ISNULL(ft.Active, N'Y') = N'Y' THEN ft.FlagType
                ELSE ft.FlagType + ' (inactive)'
            END AS varchar(200)),
        SortKey = 1
    FROM dbo.FlagTypes AS ft
    WHERE ISNULL(ft.RecordDeleted, N'N') = N'N'
    ORDER BY SortKey, FlagTypeName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ssp_SCClientChartFlagsPrograms
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProgramId = CAST(-1 AS int), ProgramName = CAST(N'All' AS varchar(200)), SortKey = 0
    UNION ALL
    SELECT
        p.ProgramId,
        ProgramName = CAST(p.ProgramName AS varchar(200)),
        SortKey = 1
    FROM dbo.Programs AS p
    WHERE ISNULL(p.RecordDeleted, N'N') = N'N'
      AND ISNULL(p.Active, N'Y') = N'Y'
    ORDER BY SortKey, ProgramName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ssp_SCClientChartFlagsStaff
AS
BEGIN
    SET NOCOUNT ON;

    SELECT StaffId = CAST(-1 AS int), StaffName = CAST(N'All' AS varchar(200)), SortKey = 0
    UNION ALL
    SELECT
        st.StaffId,
        StaffName = CAST(st.LastName + N', ' + st.FirstName AS varchar(200)),
        SortKey = 1
    FROM dbo.Staff AS st
    WHERE ISNULL(st.RecordDeleted, N'N') = N'N'
      AND ISNULL(st.Active, N'Y') = N'Y'
    ORDER BY SortKey, StaffName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ssp_SCClientChartFlagsHeader
    @DateFrom datetime2 = NULL,
    @DateTo datetime2 = NULL,
    @FlagStatus varchar(max) = NULL,
    @ChartStatus varchar(max) = NULL,
    @FlagTypeId varchar(max) = NULL,
    @ProgramId varchar(max) = NULL,
    @StaffId varchar(max) = NULL,
    @ClientIdx int = -1
AS
BEGIN
    SET NOCOUNT ON;

    IF @DateFrom IS NULL
    BEGIN
        SELECT
            RunDateText = CAST(NULL AS varchar(10)),
            DateFromText = CAST(NULL AS varchar(10)),
            DateToText = CAST(NULL AS varchar(10)),
            FlagCount = CAST(NULL AS int),
            ClientCount = CAST(NULL AS int),
            ActiveCount = CAST(NULL AS int),
            EndedCount = CAST(NULL AS int),
            FlagStatusLabel = CAST(NULL AS varchar(200)),
            ChartStatusLabel = CAST(NULL AS varchar(200)),
            FlagTypeLabel = CAST(NULL AS varchar(200)),
            ProgramLabel = CAST(NULL AS varchar(200)),
            StaffLabel = CAST(NULL AS varchar(200)),
            ClientLabel = CAST(NULL AS varchar(50));
        RETURN;
    END;

    DECLARE @From date = CAST(@DateFrom AS date);
    DECLARE @Through date = CAST(COALESCE(@DateTo, @DateFrom) AS date);
    DECLARE @Swap date;
    DECLARE @ThroughNext date;
    DECLARE @WantActive bit = 0;
    DECLARE @WantEnded bit = 0;
    DECLARE @WantChartActive bit = 0;
    DECLARE @WantChartInactive bit = 0;
    DECLARE @FlagStatusLabel varchar(200);
    DECLARE @ChartStatusLabel varchar(200);
    DECLARE @FlagTypeLabel varchar(400);
    DECLARE @ProgramLabel varchar(400);
    DECLARE @StaffLabel varchar(400);
    DECLARE @ClientLabel varchar(50);

    IF @Through < @From
    BEGIN
        SET @Swap = @From;
        SET @From = @Through;
        SET @Through = @Swap;
    END;

    SET @ThroughNext = DATEADD(DAY, 1, @Through);

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All'))
       OR EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'All')
    BEGIN
        SET @WantActive = 1;
        SET @WantEnded = 1;
        SET @FlagStatusLabel = 'All';
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'Active')
            SET @WantActive = 1;
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'Ended')
            SET @WantEnded = 1;
        SELECT @FlagStatusLabel = STRING_AGG(CAST(x.Item AS varchar(50)), ', ') WITHIN GROUP (ORDER BY x.Item)
        FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') AS x;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All'))
       OR EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'All')
    BEGIN
        SET @WantChartActive = 1;
        SET @WantChartInactive = 1;
        SET @ChartStatusLabel = 'All';
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'Active')
            SET @WantChartActive = 1;
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'Inactive')
            SET @WantChartInactive = 1;
        SELECT @ChartStatusLabel = STRING_AGG(CAST(x.Item AS varchar(50)), ', ') WITHIN GROUP (ORDER BY x.Item)
        FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') AS x;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@FlagTypeId))
        SET @FlagTypeLabel = 'All';
    ELSE
        SELECT @FlagTypeLabel = STRING_AGG(CAST(ft.FlagType AS varchar(80)), ', ') WITHIN GROUP (ORDER BY ft.FlagType)
        FROM dbo.FlagTypes AS ft
        WHERE ft.FlagTypeId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@FlagTypeId));

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@ProgramId))
        SET @ProgramLabel = 'All';
    ELSE
        SELECT @ProgramLabel = STRING_AGG(CAST(p.ProgramName AS varchar(100)), ', ') WITHIN GROUP (ORDER BY p.ProgramName)
        FROM dbo.Programs AS p
        WHERE p.ProgramId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@ProgramId));

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@StaffId))
        SET @StaffLabel = 'All';
    ELSE
        SELECT @StaffLabel = STRING_AGG(CAST(st.LastName + ', ' + st.FirstName AS varchar(100)), ', ')
            WITHIN GROUP (ORDER BY st.LastName, st.FirstName)
        FROM dbo.Staff AS st
        WHERE st.StaffId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@StaffId));

    IF @ClientIdx IS NULL OR @ClientIdx <= 0
        SET @ClientLabel = 'All';
    ELSE
        SET @ClientLabel = CAST(@ClientIdx AS varchar(50));

    SELECT
        RunDateText = CONVERT(varchar(10), GETDATE(), 101),
        DateFromText = CONVERT(varchar(10), @From, 101),
        DateToText = CONVERT(varchar(10), @Through, 101),
        FlagCount = CAST(COUNT(*) AS int),
        ClientCount = CAST(COUNT(DISTINCT ofl.IdentityId) AS int),
        ActiveCount = CAST(ISNULL(SUM(CASE
            WHEN ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through) THEN 1
            ELSE 0 END), 0) AS int),
        EndedCount = CAST(ISNULL(SUM(CASE
            WHEN ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through) THEN 0
            ELSE 1 END), 0) AS int),
        FlagStatusLabel = @FlagStatusLabel,
        ChartStatusLabel = @ChartStatusLabel,
        FlagTypeLabel = @FlagTypeLabel,
        ProgramLabel = @ProgramLabel,
        StaffLabel = @StaffLabel,
        ClientLabel = @ClientLabel
    FROM dbo.ObjectFlags AS ofl
    INNER JOIN dbo.FlagTypes AS ft
        ON ft.FlagTypeId = ofl.FlagTypeId
       AND ISNULL(ft.RecordDeleted, N'N') = N'N'
    INNER JOIN dbo.Clients AS c
        ON c.ClientId = ofl.IdentityId
       AND ISNULL(c.RecordDeleted, N'N') = N'N'
    WHERE ISNULL(ofl.RecordDeleted, N'N') = N'N'
      AND ofl.TableNameOfObject = N'Clients'
      AND (ofl.StartDate IS NULL OR ofl.StartDate < @ThroughNext)
      AND (ofl.EndDate IS NULL OR ofl.EndDate >= @From)
      AND (
            (@WantActive = 1 AND @WantEnded = 1)
            OR (@WantActive = 1 AND ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through))
            OR (@WantEnded = 1 AND NOT (ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through)))
          )
      AND (
            (@WantChartActive = 1 AND @WantChartInactive = 1)
            OR (@WantChartActive = 1 AND c.Active = N'Y')
            OR (@WantChartInactive = 1 AND ISNULL(c.Active, N'N') <> N'Y')
          )
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@FlagTypeId))
            OR ofl.FlagTypeId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@FlagTypeId))
          )
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@StaffId))
            OR c.PrimaryClinicianId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@StaffId))
          )
      AND (@ClientIdx IS NULL OR @ClientIdx <= 0 OR c.ClientId = @ClientIdx)
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@ProgramId))
            OR EXISTS (
                SELECT 1
                FROM dbo.ClientPrograms AS cp
                INNER JOIN dbo.GlobalCodes AS gc
                    ON gc.GlobalCodeId = cp.Status
                   AND RTRIM(LTRIM(gc.Category)) = N'PROGRAMSTATUS'
                   AND gc.CodeName IN (N'Requested', N'Enrolled')
                WHERE cp.ClientId = c.ClientId
                  AND ISNULL(cp.RecordDeleted, N'N') = N'N'
                  AND cp.ProgramId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@ProgramId))
            )
          );
END;
GO

CREATE OR ALTER PROCEDURE dbo.ssp_SCClientChartFlagsDetail
    @DateFrom datetime2 = NULL,
    @DateTo datetime2 = NULL,
    @FlagStatus varchar(max) = NULL,
    @ChartStatus varchar(max) = NULL,
    @FlagTypeId varchar(max) = NULL,
    @ProgramId varchar(max) = NULL,
    @StaffId varchar(max) = NULL,
    @ClientIdx int = -1
AS
BEGIN
    SET NOCOUNT ON;

    IF @DateFrom IS NULL
    BEGIN
        SELECT
            ObjectFlagId = CAST(NULL AS int),
            ClientId = CAST(NULL AS int),
            ClientName = CAST(NULL AS varchar(200)),
            ChartStatus = CAST(NULL AS varchar(20)),
            FlagType = CAST(NULL AS varchar(200)),
            FlagStatus = CAST(NULL AS varchar(20)),
            StartDate = CAST(NULL AS datetime),
            StartDateText = CAST(NULL AS varchar(10)),
            EndDateText = CAST(NULL AS varchar(10)),
            Programs = CAST(NULL AS varchar(400)),
            PrimaryClinician = CAST(NULL AS varchar(200)),
            NoteText = CAST(NULL AS varchar(400)),
            SortRank = CAST(NULL AS int);
        RETURN;
    END;

    DECLARE @From date = CAST(@DateFrom AS date);
    DECLARE @Through date = CAST(COALESCE(@DateTo, @DateFrom) AS date);
    DECLARE @Swap date;
    DECLARE @ThroughNext date;
    DECLARE @WantActive bit = 0;
    DECLARE @WantEnded bit = 0;
    DECLARE @WantChartActive bit = 0;
    DECLARE @WantChartInactive bit = 0;

    IF @Through < @From
    BEGIN
        SET @Swap = @From;
        SET @From = @Through;
        SET @Through = @Swap;
    END;

    SET @ThroughNext = DATEADD(DAY, 1, @Through);

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All'))
       OR EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'All')
    BEGIN
        SET @WantActive = 1;
        SET @WantEnded = 1;
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'Active')
            SET @WantActive = 1;
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@FlagStatus, 'All') WHERE Item = 'Ended')
            SET @WantEnded = 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All'))
       OR EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'All')
    BEGIN
        SET @WantChartActive = 1;
        SET @WantChartInactive = 1;
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'Active')
            SET @WantChartActive = 1;
        IF EXISTS (SELECT 1 FROM dbo.ssf_SCReportTextList(@ChartStatus, 'All') WHERE Item = 'Inactive')
            SET @WantChartInactive = 1;
    END;

    SELECT
        ofl.ObjectFlagId,
        ClientId = c.ClientId,
        ClientName = CAST(c.LastName + ', ' + c.FirstName AS varchar(200)),
        ChartStatus = CAST(CASE WHEN c.Active = N'Y' THEN 'Active' ELSE 'Inactive' END AS varchar(20)),
        FlagType = CAST(ft.FlagType AS varchar(200)),
        FlagStatus = CAST(CASE
            WHEN ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through) THEN 'Active'
            ELSE 'Ended'
        END AS varchar(20)),
        StartDate = ofl.StartDate,
        StartDateText = CONVERT(varchar(10), ofl.StartDate, 101),
        EndDateText = CONVERT(varchar(10), ofl.EndDate, 101),
        PrimaryClinician = CAST(st.LastName + ', ' + st.FirstName AS varchar(200)),
        NoteText = LEFT(CONVERT(varchar(400), ofl.Note), 400)
    INTO #Flags
    FROM dbo.ObjectFlags AS ofl
    INNER JOIN dbo.FlagTypes AS ft
        ON ft.FlagTypeId = ofl.FlagTypeId
       AND ISNULL(ft.RecordDeleted, N'N') = N'N'
    INNER JOIN dbo.Clients AS c
        ON c.ClientId = ofl.IdentityId
       AND ISNULL(c.RecordDeleted, N'N') = N'N'
    LEFT JOIN dbo.Staff AS st
        ON st.StaffId = c.PrimaryClinicianId
       AND ISNULL(st.RecordDeleted, N'N') = N'N'
    WHERE ISNULL(ofl.RecordDeleted, N'N') = N'N'
      AND ofl.TableNameOfObject = N'Clients'
      AND (ofl.StartDate IS NULL OR ofl.StartDate < @ThroughNext)
      AND (ofl.EndDate IS NULL OR ofl.EndDate >= @From)
      AND (
            (@WantActive = 1 AND @WantEnded = 1)
            OR (@WantActive = 1 AND ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through))
            OR (@WantEnded = 1 AND NOT (ofl.Active = N'Y' AND (ofl.EndDate IS NULL OR ofl.EndDate >= @Through)))
          )
      AND (
            (@WantChartActive = 1 AND @WantChartInactive = 1)
            OR (@WantChartActive = 1 AND c.Active = N'Y')
            OR (@WantChartInactive = 1 AND ISNULL(c.Active, N'N') <> N'Y')
          )
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@FlagTypeId))
            OR ofl.FlagTypeId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@FlagTypeId))
          )
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@StaffId))
            OR c.PrimaryClinicianId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@StaffId))
          )
      AND (@ClientIdx IS NULL OR @ClientIdx <= 0 OR c.ClientId = @ClientIdx)
      AND (
            NOT EXISTS (SELECT 1 FROM dbo.ssf_SCReportIdList(@ProgramId))
            OR EXISTS (
                SELECT 1
                FROM dbo.ClientPrograms AS cp
                INNER JOIN dbo.GlobalCodes AS gc
                    ON gc.GlobalCodeId = cp.Status
                   AND RTRIM(LTRIM(gc.Category)) = N'PROGRAMSTATUS'
                   AND gc.CodeName IN (N'Requested', N'Enrolled')
                WHERE cp.ClientId = c.ClientId
                  AND ISNULL(cp.RecordDeleted, N'N') = N'N'
                  AND cp.ProgramId IN (SELECT Id FROM dbo.ssf_SCReportIdList(@ProgramId))
            )
          );

    SELECT
        ClientId,
        ProgramNames = STRING_AGG(CAST(p.ProgramName AS varchar(100)), ', ')
            WITHIN GROUP (ORDER BY p.ProgramName)
    INTO #Programs
    FROM (
        SELECT DISTINCT cp.ClientId, cp.ProgramId
        FROM dbo.ClientPrograms AS cp
        INNER JOIN dbo.GlobalCodes AS gc
            ON gc.GlobalCodeId = cp.Status
           AND RTRIM(LTRIM(gc.Category)) = N'PROGRAMSTATUS'
           AND gc.CodeName IN (N'Requested', N'Enrolled')
        WHERE ISNULL(cp.RecordDeleted, N'N') = N'N'
          AND cp.ClientId IN (SELECT ClientId FROM #Flags)
    ) AS cp
    INNER JOIN dbo.Programs AS p
        ON p.ProgramId = cp.ProgramId
       AND ISNULL(p.RecordDeleted, N'N') = N'N'
    GROUP BY ClientId;

    SELECT
        f.ObjectFlagId,
        f.ClientId,
        f.ClientName,
        f.ChartStatus,
        f.FlagType,
        f.FlagStatus,
        f.StartDate,
        f.StartDateText,
        f.EndDateText,
        Programs = CAST(pr.ProgramNames AS varchar(400)),
        f.PrimaryClinician,
        f.NoteText,
        SortRank = CAST(0 AS int)
    FROM #Flags AS f
    LEFT JOIN #Programs AS pr
        ON pr.ClientId = f.ClientId
    ORDER BY f.ClientName, f.FlagType, f.StartDate DESC, f.ObjectFlagId;
END;
GO

GRANT SELECT ON dbo.ssf_SCReportIdList TO public;
GRANT SELECT ON dbo.ssf_SCReportTextList TO public;
GRANT EXECUTE ON dbo.ssp_SCClientChartFlagsFlagTypes TO public;
GRANT EXECUTE ON dbo.ssp_SCClientChartFlagsPrograms TO public;
GRANT EXECUTE ON dbo.ssp_SCClientChartFlagsStaff TO public;
GRANT EXECUTE ON dbo.ssp_SCClientChartFlagsHeader TO public;
GRANT EXECUTE ON dbo.ssp_SCClientChartFlagsDetail TO public;
GO
