/*======================================================================================================================
File: SC_StaffAppointmentOverlap_drop_trigger_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-09-12
Last Modified: 2026-09-12

Purpose:
  Portable SmartCare package. Easy undo for the all-path Busy overlap hard-stop.
  DROP tr_Appointments_SOHS and set StaffAppointmentOverlapHardStop = No.

  Does NOT remove Screen 46 validate (use SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql).
  Does NOT drop ssp_StaffAppointmentOverlapCheck (harmless if left).

  Run in SSMS against the target SmartCare database (no USE / no DB name guard).

Mutates: Y — DROP TRIGGER; UPDATE SystemConfigurationKeys
Paste back: Dropped + KillSwitch rows.
ModifiedBy uses SUSER_SNAME() (truncated).

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

IF OBJECT_ID(N'dbo.tr_Appointments_SOHS', N'TR') IS NOT NULL
BEGIN
    DROP TRIGGER dbo.tr_Appointments_SOHS;
END;
GO

BEGIN TRANSACTION;

IF EXISTS (
    SELECT 1
    FROM dbo.SystemConfigurationKeys AS sck
    WHERE sck.[Key] = N'StaffAppointmentOverlapHardStop'
)
BEGIN
    UPDATE dbo.SystemConfigurationKeys
    SET
        Value = N'No',
        ModifiedBy = LEFT(SUSER_SNAME(), 30),
        ModifiedDate = GETDATE()
    WHERE [Key] = N'StaffAppointmentOverlapHardStop';
END;

COMMIT TRANSACTION;
GO

SELECT
    Step = N'Dropped',
    TriggerExists = CASE
        WHEN OBJECT_ID(N'dbo.tr_Appointments_SOHS', N'TR') IS NULL THEN N'N'
        ELSE N'Y'
    END;

SELECT
    Step = N'KillSwitch',
    sck.[Key],
    sck.Value
FROM dbo.SystemConfigurationKeys AS sck
WHERE sck.[Key] = N'StaffAppointmentOverlapHardStop';

SELECT
    Step = N'Note',
    Detail = N'Screen 46 validate is still wired if previously applied. Unwire with SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql if needed.';
GO
