/*======================================================================================================================
File:    verify_scoring_formitems_and_globalcodes.sql
Purpose: Read-only checks for a scoring DFA (FormItems + GlobalCodes numeric Code).
         Select the SmartCare database in SSMS. Set @TableName / @GlobalCodeCategory.
Mutates: N
License: MIT
======================================================================================================================*/

SET NOCOUNT ON;

DECLARE @TableName SYSNAME = N'CustomDocumentYourForm';
DECLARE @GlobalCodeCategory NVARCHAR(20) = N'XYourScale';

SELECT
    fi.FormItemId,
    fi.ItemColumnName,
    fi.ItemType,
    fi.GlobalCodeCategory,
    fi.MaximumLength,
    f.TableName
FROM dbo.FormItems AS fi
INNER JOIN dbo.FormSectionGroups AS fsg ON fsg.FormSectionGroupId = fi.FormSectionGroupId
INNER JOIN dbo.FormSections AS fs ON fs.FormSectionId = fsg.FormSectionId
INNER JOIN dbo.Forms AS f ON f.FormId = fs.FormId
WHERE f.TableName = @TableName
  AND ISNULL(fi.RecordDeleted, N'N') = N'N'
ORDER BY fi.ItemColumnName;

SELECT
    GlobalCodeId,
    Category,
    Code,
    CodeName,
    ExternalCode1,
    Active
FROM dbo.GlobalCodes
WHERE RTRIM(LTRIM(Category)) = RTRIM(LTRIM(@GlobalCodeCategory))
  AND ISNULL(RecordDeleted, N'N') = N'N'
ORDER BY SortOrder, CodeName;

SELECT
    Step = N'NonNumericOrNullCode',
    GlobalCodeId,
    CodeName,
    Code,
    ExternalCode1
FROM dbo.GlobalCodes
WHERE RTRIM(LTRIM(Category)) = RTRIM(LTRIM(@GlobalCodeCategory))
  AND ISNULL(RecordDeleted, N'N') = N'N'
  AND (
        Code IS NULL
        OR TRY_CONVERT(INT, Code) IS NULL
      );
