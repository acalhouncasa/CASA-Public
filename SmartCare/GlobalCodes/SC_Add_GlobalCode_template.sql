/*======================================================================================================================
File:    SC_Add_GlobalCode_template.sql
Author:  CASA-Trinity (public pack)
Created: 2026-09-13
Last Modified: 2026-09-13

Purpose:
  Portable template: add GlobalCodeCategories + GlobalCodes (idempotent).
  Select the target SmartCare database in SSMS first (no USE).

  1. Set @Category (custom DFA picklists usually start with X).
  2. Edit @CodeNames rows.
  3. F5 whole file.
  4. Confirm the verify SELECTs.

Mutates: Y — INSERT/UPDATE GlobalCodeCategories and GlobalCodes
License: MIT
======================================================================================================================*/

SET NOCOUNT ON;

DECLARE @Category NVARCHAR(20) = N'XYourCategory';  /* REQUIRED — max 20 */
DECLARE @CategoryRowIdentifier UNIQUEIDENTIFIER = NEWID();

DECLARE @CodeNames TABLE (SortOrder INT NOT NULL, CodeName NVARCHAR(500) NOT NULL);
INSERT INTO @CodeNames (SortOrder, CodeName) VALUES
    (10, N'Option label one'),
    (20, N'Option label two');

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.GlobalCodeCategories
        WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category))
          AND Active = N'Y'
          AND ISNULL(RecordDeleted, N'N') = N'N'
    )
    INSERT INTO dbo.GlobalCodeCategories (
        Category, CategoryName, Active, AllowAddDelete, AllowCodeNameEdit, AllowSortOrderEdit,
        UserDefinedCategory, HasSubcodes, RowIdentifier, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate,
        PrimaryDriven, AffiliateAllowAddition, AffiliateAllowDeactivation
    )
    VALUES (
        @Category, @Category, N'Y', N'Y', N'Y', N'Y',
        N'Y', N'N', @CategoryRowIdentifier, SYSTEM_USER, GETDATE(), SYSTEM_USER, GETDATE(),
        NULL, NULL, NULL
    );

    UPDATE dbo.GlobalCodeCategories
    SET UserDefinedCategory = N'Y',
        HasSubcodes = N'N',
        PrimaryDriven = NULL,
        AffiliateAllowAddition = NULL,
        AffiliateAllowDeactivation = NULL,
        ModifiedBy = SYSTEM_USER,
        ModifiedDate = GETDATE()
    WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category))
      AND ISNULL(RecordDeleted, N'N') = N'N';

    DECLARE @Sort INT, @Name NVARCHAR(500);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT SortOrder, CodeName FROM @CodeNames ORDER BY SortOrder;
    OPEN c;
    FETCH NEXT FROM c INTO @Sort, @Name;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.GlobalCodes
            WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category))
              AND RTRIM(LTRIM(CAST(CodeName AS NVARCHAR(500)))) = RTRIM(LTRIM(@Name))
              AND Active = N'Y'
              AND ISNULL(RecordDeleted, N'N') = N'N'
        )
        INSERT INTO dbo.GlobalCodes (Category, CodeName, Active, SortOrder)
        VALUES (@Category, @Name, N'Y', @Sort);

        FETCH NEXT FROM c INTO @Sort, @Name;
    END;
    CLOSE c;
    DEALLOCATE c;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT GlobalCodeCategoryId, Category, Active, HasSubcodes, PrimaryDriven, AffiliateAllowAddition, AffiliateAllowDeactivation, RowIdentifier
FROM dbo.GlobalCodeCategories
WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category));

SELECT GlobalCodeId, Category, Code, CodeName, Active, SortOrder, RecordDeleted
FROM dbo.GlobalCodes
WHERE RTRIM(LTRIM(CAST(Category AS NVARCHAR(20)))) = RTRIM(LTRIM(@Category))
ORDER BY SortOrder, CodeName;
