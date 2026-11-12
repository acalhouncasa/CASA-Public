# SmartCare icons cheatsheet

Visual list of the **Font Awesome / `dbo.Icons` picker** used on Flag Types, QuickLinks, and related screens.

**Share this:** [SC_Icons_Cheatsheet.pdf](SC_Icons_Cheatsheet.pdf)

## What this is

- One PDF of picker tiles (title + icons).
- Useful when assigning `FlagTypes.IconId` or banner QuickLink icons.
- Icon library is shared: assigning an icon does not remove it from the picker.

## What this is not

- Not your site’s Flag Type or QuickLink **assignment** list (those are org-specific).
- Not a dump of `BitmapImage` LOB columns.
- Icon **Id** numbers can differ slightly by SmartCare version / seed; confirm on your database with:

```sql
SELECT IconId, IconName, Class
FROM dbo.Icons
WHERE ISNULL(RecordDeleted, N'N') = N'N'
ORDER BY IconId;
```

## Related

- Missing client signature flags often pick a signature-style icon — see [Missing_Client_Signature_Flag](../Missing_Client_Signature_Flag/README.md).
