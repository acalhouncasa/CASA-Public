/*======================================================================================================================
File: 02_flagtypes_COMMIT.sql
Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-11-12
Last Modified: 2026-11-12
AI Assistant: Talon

Purpose:
  Insert / retag Flag Types for missing client signature alerts.
  1) Find/replace AGENCYID with your site prefix.
  2) Edit @Wanted (DocumentCodeId, FlagType name, Code stamp).
  3) Set @IconId from discovery.
  Select the target SmartCare database in SSMS (no USE).

Mutates: Y (dbo.FlagTypes)
Undo: 99_undo_COMMIT.sql
License: MIT (CASA-Public)
======================================================================================================================*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @Stamp VARCHAR(30) = N'AGENCYID_MissClientSig';  /* <= 30 chars after replace */
DECLARE @IconId INT = 0;  /* REPLACE: IconId from 01_discovery */

IF @IconId IS NULL OR @IconId <= 0
BEGIN
    RAISERROR(N'Set @IconId to a valid dbo.Icons.IconId before F5.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Icons AS i
    WHERE i.IconId = @IconId
      AND ISNULL(i.RecordDeleted, N'N') = N'N'
)
BEGIN
    RAISERROR(N'IconId not found. Abort.', 16, 1);
    RETURN;
END;

DECLARE @Wanted TABLE (
    DocumentCodeId INT NOT NULL PRIMARY KEY,
    FlagType       VARCHAR(250) NOT NULL,
    Code           VARCHAR(30) NOT NULL
);

/* ---- edit: one row per DocumentCode you watch ---- */
INSERT INTO @Wanted (DocumentCodeId, FlagType, Code) VALUES
    (10001, N'Example Form A needs client signature', N'AGENCYID_FormAClientSig'),
    (10002, N'Example Form B needs client signature', N'AGENCYID_FormBClientSig');

IF EXISTS (
    SELECT 1
    FROM @Wanted AS w
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DocumentCodes AS dc
        WHERE dc.DocumentCodeId = w.DocumentCodeId
          AND ISNULL(dc.RecordDeleted, N'N') = N'N'
    )
)
BEGIN
    RAISERROR(N'One or more DocumentCodeId values missing. Abort.', 16, 1);
END;

IF EXISTS (
    SELECT 1
    FROM @Wanted AS w
    WHERE LEN(w.Code) > 30
)
BEGIN
    RAISERROR(N'Flag Type Code / stamp must be <= 30 characters. Abort.', 16, 1);
END;

INSERT INTO dbo.FlagTypes (
    FlagType,
    Active,
    PermissionedFlag,
    DoNotDisplayFlag,
    NeverPopup,
    FlagLinkTo,
    DocumentCodeId,
    Code,
    IconId,
    CreatedBy,
    CreatedDate,
    ModifiedBy,
    ModifiedDate
)
SELECT
    w.FlagType,
    N'Y',
    N'N',
    N'N',
    N'N',
    N'D',
    w.DocumentCodeId,
    w.Code,
    @IconId,
    @Stamp,
    GETDATE(),
    @Stamp,
    GETDATE()
FROM @Wanted AS w
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.FlagTypes AS ft
    WHERE ft.FlagType = w.FlagType
      AND ISNULL(ft.RecordDeleted, N'N') = N'N'
);

DECLARE @Inserted INT = @@ROWCOUNT;

UPDATE ft
SET
    Code = w.Code,
    IconId = @IconId,
    NeverPopup = N'N',
    DoNotDisplayFlag = N'N',
    PermissionedFlag = N'N',
    Active = N'Y',
    FlagLinkTo = N'D',
    DocumentCodeId = w.DocumentCodeId,
    ModifiedBy = @Stamp,
    ModifiedDate = GETDATE()
FROM dbo.FlagTypes AS ft
INNER JOIN @Wanted AS w
    ON w.FlagType = ft.FlagType
WHERE ISNULL(ft.RecordDeleted, N'N') = N'N'
  AND (
        ISNULL(ft.Code, N'') <> w.Code
        OR ft.IconId IS NULL
        OR ft.IconId <> @IconId
        OR ISNULL(ft.NeverPopup, N'Y') <> N'N'
        OR ISNULL(ft.Active, N'N') <> N'Y'
        OR ISNULL(ft.FlagLinkTo, N'') <> N'D'
        OR ISNULL(ft.DocumentCodeId, 0) <> w.DocumentCodeId
      );

DECLARE @Updated INT = @@ROWCOUNT;

SELECT
    N'SUCCESS' AS [Status],
    @Inserted AS [FlagTypesInserted],
    @Updated AS [FlagTypesUpdated];

SELECT
    ft.FlagTypeId,
    ft.FlagType,
    ft.IconId,
    i.Class AS [IconClass],
    ft.NeverPopup,
    ft.FlagLinkTo,
    ft.DocumentCodeId,
    ft.Code
FROM dbo.FlagTypes AS ft
INNER JOIN @Wanted AS w
    ON w.FlagType = ft.FlagType
INNER JOIN dbo.Icons AS i
    ON i.IconId = ft.IconId
WHERE ISNULL(ft.RecordDeleted, N'N') = N'N'
ORDER BY ft.DocumentCodeId;

COMMIT TRANSACTION;
GO
