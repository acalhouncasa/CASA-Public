/*
File: sql/99_drop_procedures.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-19
Last Modified: 2026-10-19

Purpose:
  Drop only the objects this package creates.
  Does not delete dbo.Reports rows. Remove a My Reports entry in the application if you added one.

  Do not test in Prod.

License: MIT
*/

SET NOCOUNT ON;

IF DB_NAME() LIKE N'%Prod%' OR DB_NAME() LIKE N'%Production%'
    THROW 50001, N'Stop. Do not test in Prod. Connect SSMS to a non-production SmartCare database.', 1;

DROP PROCEDURE IF EXISTS dbo.ssp_SCClientChartFlagsDetail;
DROP PROCEDURE IF EXISTS dbo.ssp_SCClientChartFlagsHeader;
DROP PROCEDURE IF EXISTS dbo.ssp_SCClientChartFlagsStaff;
DROP PROCEDURE IF EXISTS dbo.ssp_SCClientChartFlagsPrograms;
DROP PROCEDURE IF EXISTS dbo.ssp_SCClientChartFlagsFlagTypes;
DROP FUNCTION IF EXISTS dbo.ssf_SCReportTextList;
DROP FUNCTION IF EXISTS dbo.ssf_SCReportIdList;

SELECT Dropped = N'ssp_SCClientChartFlags* and ssf_SCReport* list functions';
GO
