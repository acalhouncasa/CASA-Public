/*======================================================================================================================
File: SC_discovery_formitems_for_paper.sql
Purpose: Dump FormItems for one FormId (labels, types, groups) before building paper.
Mutates: N — SELECT only.
Usage: Set @FormId. Select the database in SSMS (no customer USE).
License: MIT (CASA-Public)
======================================================================================================================*/

DECLARE @FormId INT = 0;  -- set me

SET NOCOUNT ON;

SELECT
    F.FormId,
    F.FormName,
    FS.FormSectionId,
    FS.SortOrder AS SectionSort,
    FS.SectionLabel,
    FSG.FormSectionGroupId,
    FSG.SortOrder AS GroupSort,
    FSG.GroupName,
    FSG.GridType,
    FI.FormItemId,
    FI.SortOrder AS ItemSort,
    FI.ItemType,
    FI.ItemLabel,
    FI.ItemColumnName,
    FI.GlobalCodeCategory,
    FI.Active
FROM dbo.Forms AS F
INNER JOIN dbo.FormSections AS FS
    ON FS.FormId = F.FormId
   AND ISNULL(FS.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.FormSectionGroups AS FSG
    ON FSG.FormSectionId = FS.FormSectionId
   AND ISNULL(FSG.RecordDeleted, N'N') = N'N'
INNER JOIN dbo.FormItems AS FI
    ON FI.FormSectionGroupId = FSG.FormSectionGroupId
   AND ISNULL(FI.RecordDeleted, N'N') = N'N'
WHERE F.FormId = @FormId
  AND ISNULL(F.RecordDeleted, N'N') = N'N'
ORDER BY FS.SortOrder, FSG.SortOrder, FI.SortOrder;
