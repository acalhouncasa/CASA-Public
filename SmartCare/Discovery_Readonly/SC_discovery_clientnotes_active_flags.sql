/*======================================================================================================================
File: SC_discovery_clientnotes_active_flags.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Read-only: active ClientNotes (chart flags) by Flag Type — ClientId only, no names.
  Select the target SmartCare database in SSMS (no USE).

Mutates: N
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;

SELECT
    ft.FlagTypeId,
    ft.FlagType,
    ft.FlagLinkTo,
    ft.DocumentCodeId,
    ActiveNotes = COUNT(*),
    DistinctClients = COUNT(DISTINCT cn.ClientId)
FROM dbo.ClientNotes AS cn
INNER JOIN dbo.FlagTypes AS ft
    ON ft.FlagTypeId = cn.NoteType
   AND ISNULL(ft.RecordDeleted, N'N') = N'N'
WHERE cn.Active = N'Y'
  AND ISNULL(cn.RecordDeleted, N'N') = N'N'
GROUP BY
    ft.FlagTypeId,
    ft.FlagType,
    ft.FlagLinkTo,
    ft.DocumentCodeId
ORDER BY ActiveNotes DESC, ft.FlagType;
GO
