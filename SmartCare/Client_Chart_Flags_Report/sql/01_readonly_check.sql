/*
File: sql/01_readonly_check.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Purpose:
  Read-only check before creating the client chart flags report.
  Select a non-production SmartCare database in SSMS. There is no USE statement.

  Do not test in Prod.
  This file stops when the database name contains Prod or Production.
  If your production database uses a different name, do not run this file there.

License: MIT
*/

SET NOCOUNT ON;

IF DB_NAME() LIKE N'%Prod%' OR DB_NAME() LIKE N'%Production%'
    THROW 50001, N'Stop. Do not test in Prod. Connect SSMS to a non-production SmartCare database (Train, QA, or Test).', 1;

SELECT
    DatabaseName = DB_NAME(),
    NextStep = N'Confirm this is not Production. Then run 02_create_procedures.sql on this same database.',
    ClientFlagRows = (
        SELECT COUNT(*)
        FROM dbo.ObjectFlags AS ofl
        WHERE ISNULL(ofl.RecordDeleted, N'N') = N'N'
          AND ofl.TableNameOfObject = N'Clients'
    ),
    FlagTypeRows = (
        SELECT COUNT(*)
        FROM dbo.FlagTypes AS ft
        WHERE ISNULL(ft.RecordDeleted, N'N') = N'N'
    );

PRINT N'If ClientFlagRows is 0, the report title can still render and the grid will be empty until a flag is assigned to a chart.';
GO
