/*======================================================================================================================
File: SC_StaffAppointmentOverlap_apply_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-09-12
Last Modified: 2026-09-12
AI Assistant: Talon

Purpose:
  Portable SmartCare package (any customer DB). Run in SSMS against the target
  SmartCare database (select the correct DB first — no USE / no DB name guard).

  All-path staff Busy appointment overlap hard-stop (Style B message):
    1) Helper ssp_StaffAppointmentOverlapCheck
    2) Thin Screen 46 validate ssp_ValidateGroupServiceOverlap → helper
    3) Trigger tr_Appointments_SOHS on Appointments
       Naming: Staff Appointment Overlap Hard Stop → capitals S,A,O,H,S
       minus capital of second word (A) → SOHS → tr_Appointments_SOHS
    4) Kill-switch SystemConfigurationKeys StaffAppointmentOverlapHardStop = Yes
    5) Wire Screen 46 ValidationStoredProcedureUpdate when empty or already ours

  GRANT EXECUTE to public only (no named logins).
  ModifiedBy uses SUSER_SNAME() (truncated).

  Easy disable: set StaffAppointmentOverlapHardStop = No, or DROP tr_Appointments_SOHS.
  Screen 46 unwire: SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql

Mutates: Y — CREATE OR ALTER PROCEDURE; CREATE TRIGGER; MERGE SystemConfigurationKeys;
           UPDATE Screens; GRANT
Paste back: Deployed + Trigger + KillSwitch + Screen46 rows.

License: MIT
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT N'=== Target (confirm this is the correct SmartCare DB) ===';
SELECT
    Instance = @@SERVERNAME,
    CurrentDb = DB_NAME(),
    LoginName = SUSER_SNAME();
GO

/*============================================================================
  Shared helper: one staff + time window → @ErrorMessage (empty = OK)
============================================================================*/
CREATE OR ALTER PROCEDURE dbo.ssp_StaffAppointmentOverlapCheck
(
    @StaffId INT,
    @StartTime DATETIME,
    @EndTime DATETIME,
    @ExcludeGroupServiceId INT = NULL,
    @ExcludeAppointmentIds VARCHAR(MAX) = NULL,
    @ContextGroupId INT = NULL,
    @ContextGroupName VARCHAR(250) = NULL,
    @ErrorMessage NVARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @ErrorMessage = N'';

    IF @StaffId IS NULL OR @StartTime IS NULL OR @EndTime IS NULL OR @EndTime <= @StartTime
        RETURN;

    DECLARE @DurationMin INT = DATEDIFF(MINUTE, @StartTime, @EndTime);
    IF @DurationMin IS NULL OR @DurationMin <= 0
        RETURN;

    DECLARE @BusyShowTimeAs INT = (
        SELECT TOP (1) gc.GlobalCodeId
        FROM dbo.GlobalCodes AS gc
        WHERE RTRIM(LTRIM(gc.Category)) = N'SHOWTIMEAS'
          AND gc.CodeName = N'Busy'
          AND ISNULL(gc.RecordDeleted, N'N') = N'N'
          AND gc.Active = N'Y'
        ORDER BY gc.GlobalCodeId
    );

    IF @BusyShowTimeAs IS NULL
        RETURN;

    CREATE TABLE #ExcludeAppt (AppointmentId INT NOT NULL PRIMARY KEY);

    IF NULLIF(LTRIM(RTRIM(@ExcludeAppointmentIds)), N'') IS NOT NULL
    BEGIN
        INSERT INTO #ExcludeAppt (AppointmentId)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(ss.value)) AS INT)
        FROM STRING_SPLIT(@ExcludeAppointmentIds, N',') AS ss
        WHERE TRY_CAST(LTRIM(RTRIM(ss.value)) AS INT) IS NOT NULL;
    END;

    CREATE TABLE #Conflicts
    (
        StaffId INT NOT NULL,
        AppointmentId INT NOT NULL,
        StartTime DATETIME NOT NULL,
        EndTime DATETIME NOT NULL,
        GroupServiceId INT NULL,
        SubjectText VARCHAR(250) NULL,
        TypeName VARCHAR(100) NULL,
        OtherGroupName VARCHAR(250) NULL
    );

    INSERT INTO #Conflicts
    (
        StaffId,
        AppointmentId,
        StartTime,
        EndTime,
        GroupServiceId,
        SubjectText,
        TypeName,
        OtherGroupName
    )
    SELECT
        a.StaffId,
        a.AppointmentId,
        a.StartTime,
        a.EndTime,
        a.GroupServiceId,
        LEFT(ISNULL(a.Subject, N''), 250),
        typ.CodeName,
        og.GroupName
    FROM dbo.Appointments AS a
    LEFT JOIN dbo.GlobalCodes AS typ
        ON typ.GlobalCodeId = a.AppointmentType
       AND RTRIM(LTRIM(typ.Category)) = N'APPOINTMENTTYPE'
    LEFT JOIN dbo.GlobalCodes AS st
        ON st.GlobalCodeId = a.Status
       AND RTRIM(LTRIM(st.Category)) = N'PCAPPOINTMENTSTATUS'
    LEFT JOIN dbo.GroupServices AS ogs
        ON ogs.GroupServiceId = a.GroupServiceId
       AND ISNULL(ogs.RecordDeleted, N'N') = N'N'
    LEFT JOIN dbo.Groups AS og
        ON og.GroupId = ogs.GroupId
    WHERE a.StaffId = @StaffId
      AND ISNULL(a.RecordDeleted, N'N') = N'N'
      AND a.ShowTimeAs = @BusyShowTimeAs
      AND a.StartTime IS NOT NULL
      AND a.EndTime IS NOT NULL
      AND a.EndTime > a.StartTime
      AND a.StartTime < @EndTime
      AND @StartTime < a.EndTime
      AND NOT EXISTS (
            SELECT 1
            FROM #ExcludeAppt AS x
            WHERE x.AppointmentId = a.AppointmentId
        )
      AND (
            @ExcludeGroupServiceId IS NULL
         OR ISNULL(a.GroupServiceId, -1) <> @ExcludeGroupServiceId
          )
      AND ISNULL(st.CodeName, N'') NOT IN (N'Cancelled', N'No Show', N'Rescheduled')
      AND ISNULL(typ.CodeName, N'') NOT IN (N'Cancelled', N'No Show');

    /* Same-group overlapping GroupServices (Detail path / missing appt rows) */
    IF @ContextGroupId IS NOT NULL
    BEGIN
        INSERT INTO #Conflicts
        (
            StaffId,
            AppointmentId,
            StartTime,
            EndTime,
            GroupServiceId,
            SubjectText,
            TypeName,
            OtherGroupName
        )
        SELECT
            COALESCE(gs.ClinicianId, @StaffId),
            -gs.GroupServiceId,
            gs.DateOfService,
            gs.EndDateOfService,
            gs.GroupServiceId,
            N'Group Service',
            N'Group Service',
            g.GroupName
        FROM dbo.GroupServices AS gs
        INNER JOIN dbo.Groups AS g
            ON g.GroupId = gs.GroupId
        WHERE gs.GroupId = @ContextGroupId
          AND (
                @ExcludeGroupServiceId IS NULL
             OR gs.GroupServiceId <> @ExcludeGroupServiceId
              )
          AND ISNULL(gs.RecordDeleted, N'N') = N'N'
          AND gs.DateOfService IS NOT NULL
          AND gs.EndDateOfService IS NOT NULL
          AND gs.EndDateOfService > gs.DateOfService
          AND gs.DateOfService < @EndTime
          AND @StartTime < gs.EndDateOfService
          AND NOT EXISTS (
                SELECT 1
                FROM #Conflicts AS c
                WHERE c.GroupServiceId = gs.GroupServiceId
            );
    END;

    IF NOT EXISTS (SELECT 1 FROM #Conflicts)
        RETURN;

    /*
      Style B: short STOP / TRY for flat Error! banner.
      Same staff+slot+label collapsed; meeting count only (no GS ids).
    */
    DECLARE @ConflictLines NVARCHAR(MAX) = N'';
    DECLARE @StaffName VARCHAR(200);
    DECLARE @WhatLabel VARCHAR(250);
    DECLARE @StartTimeC DATETIME;
    DECLARE @EndTimeC DATETIME;
    DECLARE @HitCount INT;
    DECLARE @SlotN INT = 0;

    DECLARE c_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT TOP (3)
            StaffName = ISNULL(RTRIM(stf.LastName) + N', ' + RTRIM(stf.FirstName), N'(staff)'),
            WhatLabel = ISNULL(
                NULLIF(c.OtherGroupName, N''),
                ISNULL(NULLIF(c.TypeName, N''), ISNULL(NULLIF(c.SubjectText, N''), N'an appointment'))
            ),
            c.StartTime,
            c.EndTime,
            HitCount = COUNT(*)
        FROM #Conflicts AS c
        LEFT JOIN dbo.Staff AS stf
            ON stf.StaffId = c.StaffId
        GROUP BY
            c.StaffId,
            stf.LastName,
            stf.FirstName,
            c.StartTime,
            c.EndTime,
            ISNULL(
                NULLIF(c.OtherGroupName, N''),
                ISNULL(NULLIF(c.TypeName, N''), ISNULL(NULLIF(c.SubjectText, N''), N'an appointment'))
            )
        ORDER BY MIN(c.StartTime), MIN(c.StaffId);

    OPEN c_cur;
    FETCH NEXT FROM c_cur INTO @StaffName, @WhatLabel, @StartTimeC, @EndTimeC, @HitCount;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SlotN = @SlotN + 1;
        SET @ConflictLines = @ConflictLines
            + CASE WHEN @ConflictLines = N'' THEN N'' ELSE N'; ' END
            + @StaffName
            + N' is booked '
            + CONVERT(VARCHAR(10), @StartTimeC, 101)
            + N' '
            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @StartTimeC, 100), 7))
            + N'-'
            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @EndTimeC, 100), 7))
            + N' for '
            + @WhatLabel
            + N' ('
            + CONVERT(VARCHAR(10), @HitCount)
            + CASE WHEN @HitCount = 1 THEN N' meeting)' ELSE N' meetings)' END;
        FETCH NEXT FROM c_cur INTO @StaffName, @WhatLabel, @StartTimeC, @EndTimeC, @HitCount;
    END;
    CLOSE c_cur;
    DEALLOCATE c_cur;

    DECLARE @Suggestions NVARCHAR(MAX) = N'';
    DECLARE @CandStart DATETIME;
    DECLARE @CandEnd DATETIME;
    DECLARE @TryDay INT = 0;
    DECLARE @HourOff INT;
    DECLARE @Found INT = 0;
    DECLARE @BaseTime DATETIME = @StartTime;
    DECLARE @FirstSuggestDate CHAR(10) = NULL;

    WHILE @TryDay <= 28 AND @Found < 3
    BEGIN
        SET @HourOff = 0;
        WHILE @HourOff <= 4 AND @Found < 3
        BEGIN
            SET @CandStart = DATEADD(HOUR, @HourOff, DATEADD(DAY, @TryDay, @BaseTime));
            IF DATEPART(WEEKDAY, @CandStart) = DATEPART(WEEKDAY, @BaseTime)
               AND @CandStart > GETDATE()
               AND NOT (@TryDay = 0 AND @HourOff = 0)
            BEGIN
                SET @CandEnd = DATEADD(MINUTE, @DurationMin, @CandStart);
                IF NOT EXISTS (
                    SELECT 1
                    FROM dbo.Appointments AS a
                    LEFT JOIN dbo.GlobalCodes AS st
                        ON st.GlobalCodeId = a.Status
                       AND RTRIM(LTRIM(st.Category)) = N'PCAPPOINTMENTSTATUS'
                    LEFT JOIN dbo.GlobalCodes AS typ
                        ON typ.GlobalCodeId = a.AppointmentType
                       AND RTRIM(LTRIM(typ.Category)) = N'APPOINTMENTTYPE'
                    WHERE a.StaffId = @StaffId
                      AND ISNULL(a.RecordDeleted, N'N') = N'N'
                      AND a.ShowTimeAs = @BusyShowTimeAs
                      AND a.StartTime IS NOT NULL
                      AND a.EndTime IS NOT NULL
                      AND a.StartTime < @CandEnd
                      AND @CandStart < a.EndTime
                      AND NOT EXISTS (
                            SELECT 1
                            FROM #ExcludeAppt AS x
                            WHERE x.AppointmentId = a.AppointmentId
                        )
                      AND (
                            @ExcludeGroupServiceId IS NULL
                         OR ISNULL(a.GroupServiceId, -1) <> @ExcludeGroupServiceId
                          )
                      AND ISNULL(st.CodeName, N'') NOT IN (N'Cancelled', N'No Show', N'Rescheduled')
                      AND ISNULL(typ.CodeName, N'') NOT IN (N'Cancelled', N'No Show')
                )
                BEGIN
                    SET @Found = @Found + 1;
                    IF @FirstSuggestDate IS NULL
                        SET @FirstSuggestDate = CONVERT(VARCHAR(10), @CandStart, 101);

                    IF CONVERT(VARCHAR(10), @CandStart, 101) = @FirstSuggestDate AND @Found > 1
                    BEGIN
                        SET @Suggestions = @Suggestions
                            + N'; '
                            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @CandStart, 100), 7))
                            + N'-'
                            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @CandEnd, 100), 7));
                    END
                    ELSE
                    BEGIN
                        SET @Suggestions = @Suggestions
                            + CASE WHEN @Suggestions = N'' THEN N'' ELSE N'; ' END
                            + CONVERT(VARCHAR(10), @CandStart, 101)
                            + N' '
                            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @CandStart, 100), 7))
                            + N'-'
                            + LTRIM(RIGHT(CONVERT(VARCHAR(20), @CandEnd, 100), 7));
                    END;
                END;
            END;
            SET @HourOff = @HourOff + 1;
        END;
        SET @TryDay = @TryDay + 1;
    END;

    SET @ErrorMessage =
        N'STOP: '
        + ISNULL(@ConflictLines, N'(conflict)')
        + N' TRY (' + CONVERT(VARCHAR(10), @DurationMin) + N' min): '
        + CASE
              WHEN @Suggestions <> N''
              THEN @Suggestions
              ELSE N'no free same-weekday slot in the next 28 days.'
          END
        + N'.';
END;
GO

GRANT EXECUTE ON dbo.ssp_StaffAppointmentOverlapCheck TO [public];
GO

/*============================================================================
  Screen 46 validate: thin wrapper over helper (all assigned staff)
============================================================================*/
CREATE OR ALTER PROCEDURE dbo.ssp_ValidateGroupServiceOverlap
(
    @CurrentUser VARCHAR(30),
    @ScreenKeyId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @GroupServiceId INT = @ScreenKeyId;
    DECLARE @GroupId INT;
    DECLARE @GroupName VARCHAR(250);
    DECLARE @StartTime DATETIME;
    DECLARE @EndTime DATETIME;
    DECLARE @ClinicianId INT;
    DECLARE @Msg NVARCHAR(MAX) = N'';
    DECLARE @StaffId INT;
    DECLARE @OneMsg NVARCHAR(MAX);

    IF @GroupServiceId IS NULL OR @GroupServiceId <= 0
        RETURN;

    SELECT
        @GroupId = gs.GroupId,
        @GroupName = g.GroupName,
        @StartTime = gs.DateOfService,
        @EndTime = gs.EndDateOfService,
        @ClinicianId = gs.ClinicianId
    FROM dbo.GroupServices AS gs
    LEFT JOIN dbo.Groups AS g
        ON g.GroupId = gs.GroupId
    WHERE gs.GroupServiceId = @GroupServiceId
      AND ISNULL(gs.RecordDeleted, N'N') = N'N';

    IF @StartTime IS NULL OR @EndTime IS NULL OR @EndTime <= @StartTime
        RETURN;

    CREATE TABLE #Staff (StaffId INT NOT NULL PRIMARY KEY);

    IF @ClinicianId IS NOT NULL
        INSERT INTO #Staff (StaffId) VALUES (@ClinicianId);

    INSERT INTO #Staff (StaffId)
    SELECT DISTINCT gss.StaffId
    FROM dbo.GroupServiceStaff AS gss
    WHERE gss.GroupServiceId = @GroupServiceId
      AND ISNULL(gss.RecordDeleted, N'N') = N'N'
      AND gss.StaffId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #Staff AS s WHERE s.StaffId = gss.StaffId);

    INSERT INTO #Staff (StaffId)
    SELECT DISTINCT a.StaffId
    FROM dbo.Appointments AS a
    WHERE a.GroupServiceId = @GroupServiceId
      AND ISNULL(a.RecordDeleted, N'N') = N'N'
      AND a.StaffId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #Staff AS s WHERE s.StaffId = a.StaffId);

    IF NOT EXISTS (SELECT 1 FROM #Staff)
        RETURN;

    DECLARE s_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT StaffId FROM #Staff ORDER BY StaffId;

    OPEN s_cur;
    FETCH NEXT FROM s_cur INTO @StaffId;
    WHILE @@FETCH_STATUS = 0 AND @Msg = N''
    BEGIN
        SET @OneMsg = N'';
        EXEC dbo.ssp_StaffAppointmentOverlapCheck
            @StaffId = @StaffId,
            @StartTime = @StartTime,
            @EndTime = @EndTime,
            @ExcludeGroupServiceId = @GroupServiceId,
            @ExcludeAppointmentIds = NULL,
            @ContextGroupId = @GroupId,
            @ContextGroupName = @GroupName,
            @ErrorMessage = @OneMsg OUTPUT;

        IF NULLIF(@OneMsg, N'') IS NOT NULL
            SET @Msg = @OneMsg;

        FETCH NEXT FROM s_cur INTO @StaffId;
    END;
    CLOSE s_cur;
    DEALLOCATE s_cur;

    IF NULLIF(@Msg, N'') IS NULL
        RETURN;

    IF LEFT(@Msg, 5) = N'STOP:'
        SET @Msg = N'STOP (group meeting):' + SUBSTRING(@Msg, 6, 4000);

    SELECT
        TableName = CAST(N'GroupServices' AS VARCHAR(100)),
        ColumnName = CAST(N'DateOfService' AS VARCHAR(100)),
        ErrorMessage = @Msg,
        TabOrder = CAST(1 AS INT),
        ValidationOrder = CAST(1 AS INT);
END;
GO

GRANT EXECUTE ON dbo.ssp_ValidateGroupServiceOverlap TO [public];
GO

/*============================================================================
  Wire Group Service Detail (Screen 46) when empty or already our proc
============================================================================*/
BEGIN TRANSACTION;

UPDATE dbo.Screens
SET
    ValidationStoredProcedureUpdate = N'ssp_ValidateGroupServiceOverlap',
    ModifiedBy = LEFT(SUSER_SNAME(), 30),
    ModifiedDate = GETDATE()
WHERE ScreenId = 46
  AND (
        ValidationStoredProcedureUpdate IS NULL
     OR ValidationStoredProcedureUpdate = N''
     OR ValidationStoredProcedureUpdate = N'ssp_ValidateGroupServiceOverlap'
      );

IF @@ROWCOUNT = 0
BEGIN
    /* Do not overwrite a different vendor/customer validate SP */
    IF EXISTS (
        SELECT 1
        FROM dbo.Screens AS s
        WHERE s.ScreenId = 46
          AND NULLIF(LTRIM(RTRIM(s.ValidationStoredProcedureUpdate)), N'') IS NOT NULL
          AND s.ValidationStoredProcedureUpdate <> N'ssp_ValidateGroupServiceOverlap'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(
            N'Screen 46 already has a different ValidationStoredProcedureUpdate. Clear it first or skip Detail wiring; trigger still covers calendar paths.',
            16,
            1
        );
        RETURN;
    END;
END;

COMMIT TRANSACTION;
GO

/*============================================================================
  Trigger: tr_Appointments_SOHS
  SOHS = Staff Appointment Overlap Hard Stop (S,A,O,H,S minus second-word A)
============================================================================*/
IF OBJECT_ID(N'dbo.tr_Appointments_SOHS', N'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_Appointments_SOHS;
GO

CREATE TRIGGER dbo.tr_Appointments_SOHS
ON dbo.Appointments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(
           OBJECT_ID(N'dbo.tr_Appointments_SOHS', N'TR'),
           N'AFTER',
           N'DML'
       ) > 1
        RETURN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.SystemConfigurationKeys AS sck
        WHERE sck.[Key] = N'StaffAppointmentOverlapHardStop'
          AND sck.Value = N'Yes'
          AND ISNULL(sck.RecordDeleted, N'N') = N'N'
    )
        RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @BusyShowTimeAs INT = (
        SELECT TOP (1) gc.GlobalCodeId
        FROM dbo.GlobalCodes AS gc
        WHERE RTRIM(LTRIM(gc.Category)) = N'SHOWTIMEAS'
          AND gc.CodeName = N'Busy'
          AND ISNULL(gc.RecordDeleted, N'N') = N'N'
          AND gc.Active = N'Y'
        ORDER BY gc.GlobalCodeId
    );

    IF @BusyShowTimeAs IS NULL
        RETURN;

    /* Entire INSERT/UPDATE batch: exclude sibling rows so clean series create works */
    DECLARE @ExcludeIds VARCHAR(MAX) = N'';
    SELECT @ExcludeIds =
        STUFF((
            SELECT N',' + CONVERT(VARCHAR(20), i.AppointmentId)
            FROM inserted AS i
            FOR XML PATH(N''), TYPE
        ).value(N'.', N'VARCHAR(MAX)'), 1, 1, N'');

    DECLARE @StaffId INT;
    DECLARE @StartTime DATETIME;
    DECLARE @EndTime DATETIME;
    DECLARE @GroupServiceId INT;
    DECLARE @GroupId INT;
    DECLARE @GroupName VARCHAR(250);
    DECLARE @Msg NVARCHAR(MAX);
    DECLARE @ThrowMsg NVARCHAR(2048);

    DECLARE c_ins CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.StaffId,
            i.StartTime,
            i.EndTime,
            i.GroupServiceId
        FROM inserted AS i
        LEFT JOIN dbo.GlobalCodes AS st
            ON st.GlobalCodeId = i.Status
           AND RTRIM(LTRIM(st.Category)) = N'PCAPPOINTMENTSTATUS'
        LEFT JOIN dbo.GlobalCodes AS typ
            ON typ.GlobalCodeId = i.AppointmentType
           AND RTRIM(LTRIM(typ.Category)) = N'APPOINTMENTTYPE'
        WHERE i.StaffId IS NOT NULL
          AND ISNULL(i.RecordDeleted, N'N') = N'N'
          AND i.ShowTimeAs = @BusyShowTimeAs
          AND i.StartTime IS NOT NULL
          AND i.EndTime IS NOT NULL
          AND i.EndTime > i.StartTime
          AND ISNULL(st.CodeName, N'') NOT IN (N'Cancelled', N'No Show', N'Rescheduled')
          AND ISNULL(typ.CodeName, N'') NOT IN (N'Cancelled', N'No Show');

    OPEN c_ins;
    FETCH NEXT FROM c_ins INTO @StaffId, @StartTime, @EndTime, @GroupServiceId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @GroupId = NULL;
        SET @GroupName = NULL;

        IF @GroupServiceId IS NOT NULL
        BEGIN
            SELECT
                @GroupId = gs.GroupId,
                @GroupName = g.GroupName
            FROM dbo.GroupServices AS gs
            LEFT JOIN dbo.Groups AS g
                ON g.GroupId = gs.GroupId
            WHERE gs.GroupServiceId = @GroupServiceId;
        END;

        SET @Msg = N'';
        EXEC dbo.ssp_StaffAppointmentOverlapCheck
            @StaffId = @StaffId,
            @StartTime = @StartTime,
            @EndTime = @EndTime,
            @ExcludeGroupServiceId = @GroupServiceId,
            @ExcludeAppointmentIds = @ExcludeIds,
            @ContextGroupId = @GroupId,
            @ContextGroupName = @GroupName,
            @ErrorMessage = @Msg OUTPUT;

        IF NULLIF(@Msg, N'') IS NOT NULL
        BEGIN
            CLOSE c_ins;
            DEALLOCATE c_ins;

            SET @ThrowMsg = LEFT(@Msg, 2047);
            THROW 50051, @ThrowMsg, 1;
        END;

        FETCH NEXT FROM c_ins INTO @StaffId, @StartTime, @EndTime, @GroupServiceId;
    END;

    CLOSE c_ins;
    DEALLOCATE c_ins;
END;
GO

/*============================================================================
  Kill-switch key = Yes
============================================================================*/
BEGIN TRANSACTION;

DECLARE @ModBy VARCHAR(30) = LEFT(SUSER_SNAME(), 30);

IF EXISTS (
    SELECT 1
    FROM dbo.SystemConfigurationKeys AS sck
    WHERE sck.[Key] = N'StaffAppointmentOverlapHardStop'
)
BEGIN
    UPDATE dbo.SystemConfigurationKeys
    SET
        Value = N'Yes',
        Description = N'When Yes, tr_Appointments_SOHS blocks Busy staff time overlaps on any Appointments INSERT/UPDATE. Set No to disable without dropping the trigger.',
        AcceptedValues = N'Yes, No',
        ShowKeyForViewingAndEditing = N'Y',
        AllowEdit = N'Y',
        Modules = N'SCM Admin 2',
        Screens = N'Staff Calendar, Group Service Detail, Recurrences Scheduler',
        ModifiedBy = @ModBy,
        ModifiedDate = GETDATE(),
        RecordDeleted = N'N',
        DeletedBy = NULL,
        DeletedDate = NULL
    WHERE [Key] = N'StaffAppointmentOverlapHardStop';
END
ELSE
BEGIN
    INSERT INTO dbo.SystemConfigurationKeys
    (
        CreatedBy,
        CreateDate,
        ModifiedBy,
        ModifiedDate,
        RecordDeleted,
        [Key],
        Value,
        Description,
        AcceptedValues,
        ShowKeyForViewingAndEditing,
        Modules,
        Screens,
        Comments,
        AllowEdit,
        PrimaryDriven,
        AffiliateAllowModification
    )
    VALUES
    (
        @ModBy,
        GETDATE(),
        @ModBy,
        GETDATE(),
        N'N',
        N'StaffAppointmentOverlapHardStop',
        N'Yes',
        N'When Yes, tr_Appointments_SOHS blocks Busy staff time overlaps on any Appointments INSERT/UPDATE. Set No to disable without dropping the trigger.',
        N'Yes, No',
        N'Y',
        N'SCM Admin 2',
        N'Staff Calendar, Group Service Detail, Recurrences Scheduler',
        N'Portable SC package. Disable with Value=No or DROP tr_Appointments_SOHS.',
        N'Y',
        N'N',
        N'Y'
    );
END;

COMMIT TRANSACTION;
GO

SELECT
    Step = N'Deployed',
    HelperExists = CASE
        WHEN OBJECT_ID(N'dbo.ssp_StaffAppointmentOverlapCheck', N'P') IS NULL THEN N'N'
        ELSE N'Y'
    END,
    ValidateExists = CASE
        WHEN OBJECT_ID(N'dbo.ssp_ValidateGroupServiceOverlap', N'P') IS NULL THEN N'N'
        ELSE N'Y'
    END;

SELECT
    Step = N'Trigger',
    t.name AS TriggerName,
    t.is_disabled,
    ParentTable = OBJECT_NAME(t.parent_id)
FROM sys.triggers AS t
WHERE t.name = N'tr_Appointments_SOHS';

SELECT
    Step = N'KillSwitch',
    sck.[Key],
    sck.Value,
    sck.AcceptedValues
FROM dbo.SystemConfigurationKeys AS sck
WHERE sck.[Key] = N'StaffAppointmentOverlapHardStop';

SELECT
    Step = N'Screen46',
    s.ScreenId,
    s.ValidationStoredProcedureUpdate
FROM dbo.Screens AS s
WHERE s.ScreenId = 46;
GO
