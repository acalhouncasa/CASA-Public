/*======================================================================================================================
File: SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-09-12
Last Modified: 2026-09-12
AI Assistant: Talon

Purpose:
  Portable SmartCare package. Clear Screen 46 ValidationStoredProcedureUpdate when
  it is ssp_ValidateGroupServiceOverlap only.
  Leaves the proc, helper, and trigger tr_Appointments_SOHS in place.
  Run in SSMS against the target SmartCare database (no USE / no DB name guard).

  To disable the all-path hard-stop without unwire:
    set SystemConfigurationKeys StaffAppointmentOverlapHardStop = No
    or DROP TRIGGER dbo.tr_Appointments_SOHS

Mutates: Y — UPDATE dbo.Screens
Paste back: Unwired row.
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

BEGIN TRANSACTION;

UPDATE dbo.Screens
SET
    ValidationStoredProcedureUpdate = NULL,
    ModifiedBy = LEFT(SUSER_SNAME(), 30),
    ModifiedDate = GETDATE()
WHERE ScreenId = 46
  AND ValidationStoredProcedureUpdate = N'ssp_ValidateGroupServiceOverlap';

IF @@ROWCOUNT <> 1
BEGIN
    ROLLBACK TRANSACTION;
    RAISERROR(
        N'Screen 46 unwire failed (expected 1 row matching ssp_ValidateGroupServiceOverlap).',
        16,
        1
    );
    RETURN;
END;

COMMIT TRANSACTION;

SELECT
    Step = N'Unwired',
    s.ScreenId,
    s.ValidationStoredProcedureUpdate
FROM dbo.Screens AS s
WHERE s.ScreenId = 46;
GO
