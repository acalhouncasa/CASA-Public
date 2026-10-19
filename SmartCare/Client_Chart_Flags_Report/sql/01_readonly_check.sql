/*
File: sql/01_readonly_check.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Purpose:
  Read-only check before creating the client chart flags report.
  Select the SmartCare database in SSMS. There is no USE statement.

License: MIT
*/

SET NOCOUNT ON;

SELECT
    DatabaseName = DB_NAME(),
    NextStep = N'Run 02_create_procedures.sql on this same database.',
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
