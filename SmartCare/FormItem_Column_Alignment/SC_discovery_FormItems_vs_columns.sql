/*======================================================================================================================
File:    SC_discovery_FormItems_vs_columns.sql
Purpose: Read-only — compare FormItems metadata to physical CustomDocument columns for one DocumentCode.
         Select the SmartCare database in SSMS. Set @DocumentCodeId.
Mutates: N
License: MIT
======================================================================================================================*/

SET NOCOUNT ON;

DECLARE @DocumentCodeId INT = 0;  /* REQUIRED */

IF @DocumentCodeId = 0
BEGIN
    RAISERROR(N'Set @DocumentCodeId to the DocumentCodes.DocumentCodeId you are diagnosing.', 16, 1);
    RETURN;
END;

SELECT
    Step = N'0) DocumentCode',
    dc.DocumentCodeId,
    dc.DocumentName,
    dc.TableList,
    dc.FormCollectionId
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId
  AND ISNULL(dc.RecordDeleted, N'N') = N'N';

;WITH CollForms AS (
    SELECT f.FormId, f.FormName, f.TableName, fcf.FormOrder
    FROM dbo.DocumentCodes AS dc
    INNER JOIN dbo.FormCollectionForms AS fcf
        ON fcf.FormCollectionId = dc.FormCollectionId
       AND ISNULL(fcf.RecordDeleted, N'N') = N'N'
    INNER JOIN dbo.Forms AS f
        ON f.FormId = fcf.FormId
       AND ISNULL(f.RecordDeleted, N'N') = N'N'
    WHERE dc.DocumentCodeId = @DocumentCodeId
      AND ISNULL(dc.RecordDeleted, N'N') = N'N'
)
SELECT Step = N'1) Collection forms', * FROM CollForms ORDER BY FormOrder;

DECLARE @TableList NVARCHAR(MAX);
SELECT @TableList = dc.TableList
FROM dbo.DocumentCodes AS dc
WHERE dc.DocumentCodeId = @DocumentCodeId;

DECLARE @Tables TABLE (TableName SYSNAME NOT NULL PRIMARY KEY);
IF @TableList IS NOT NULL
BEGIN
    INSERT INTO @Tables (TableName)
    SELECT DISTINCT LTRIM(RTRIM(s.value))
    FROM STRING_SPLIT(REPLACE(@TableList, N' ', N''), N',') AS s
    WHERE NULLIF(LTRIM(RTRIM(s.value)), N'') IS NOT NULL;
END;

SELECT Step = N'2) TableList tables', t.TableName
FROM @Tables AS t
ORDER BY t.TableName;

SELECT
    Step = N'3) FormItems vs columns',
    f.TableName,
    fi.ItemColumnName,
    fi.ItemType,
    fi.MaximumLength AS FormItems_MaximumLength,
    ty.name AS SqlType,
    c.max_length AS Sys_MaxLength,
    c.precision,
    c.scale,
    Risk = CASE
        WHEN c.name IS NULL THEN N'Missing physical column'
        WHEN ty.name IN (N'varchar', N'nvarchar', N'char', N'nchar')
             AND fi.MaximumLength IS NOT NULL
             AND fi.MaximumLength > 0
             AND (
                    (ty.name IN (N'nvarchar', N'nchar') AND c.max_length / 2 < fi.MaximumLength)
                 OR (ty.name IN (N'varchar', N'char') AND c.max_length < fi.MaximumLength)
             )
            THEN N'Width may truncate'
        ELSE N'OK / review'
    END
FROM dbo.FormItems AS fi
INNER JOIN dbo.FormSectionGroups AS fsg ON fsg.FormSectionGroupId = fi.FormSectionGroupId
INNER JOIN dbo.FormSections AS fs ON fs.FormSectionId = fsg.FormSectionId
INNER JOIN dbo.Forms AS f ON f.FormId = fs.FormId
LEFT JOIN @Tables AS t ON t.TableName = f.TableName
LEFT JOIN sys.columns AS c
    ON c.object_id = OBJECT_ID(QUOTENAME(N'dbo') + N'.' + QUOTENAME(f.TableName))
   AND c.name = fi.ItemColumnName
LEFT JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE ISNULL(fi.RecordDeleted, N'N') = N'N'
  AND fi.ItemColumnName IS NOT NULL
  AND NULLIF(RTRIM(LTRIM(fi.ItemColumnName)), N'') IS NOT NULL
  AND (
        EXISTS (SELECT 1 FROM @Tables x WHERE x.TableName = f.TableName)
        OR NOT EXISTS (SELECT 1 FROM @Tables)
      )
ORDER BY f.TableName, fi.ItemColumnName;
