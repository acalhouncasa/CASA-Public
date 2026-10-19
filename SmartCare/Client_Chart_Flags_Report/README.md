# Client chart flags report

A general SmartCare report of flags on client charts. One row is one flag. Filters cover dates, flag status, chart status, flag type, program, primary clinician, and client id.

This is for any agency that uses Streamline SmartCare. It does not include another site's folders, role list, or database names.

**Do not test in Prod.**

Use a non-production SmartCare database. That is often named Train, QA, or Test. A production database can sit on the same SQL Server as Train. The database you select is what matters.

The scripts stop when the database name contains `Prod` or `Production`. A name such as NonProd is refused too, because those letters are in the name. If your non-production database is named that way, change the check only after you have confirmed the target is not Production. If your production database is named something else, do not run these files there. Read the database name on the SSMS status bar before you press F5.

## What you get

| Item | Name |
|------|------|
| Flag list | `dbo.ObjectFlags` where the object is `Clients` |
| Header and detail | `ssp_SCClientChartFlagsHeader`, `ssp_SCClientChartFlagsDetail` |
| Dropdowns | `ssp_SCClientChartFlagsFlagTypes`, `ssp_SCClientChartFlagsPrograms`, `ssp_SCClientChartFlagsStaff` |
| Checkbox parsers | `ssf_SCReportIdList`, `ssf_SCReportTextList` |
| Report file | [rdl/ClientChartFlags.rdl](rdl/ClientChartFlags.rdl) |

Dates overlap the flag. A flag is included when it starts before the day after To, and it has no end or the end is on or after From. Active means the flag is still open on the To date. Programs listed are Requested or Enrolled. Several programs stay on one row. The Note column is the flag note on the chart.

Blank, `-1`, or All means every value for that filter. Client ID `-1` means every client. The client parameter is named `ClientIdx` on purpose.

Flag counts are whole numbers. If nobody has a flag, the title still shows and the grid is empty. Flags 0 is a data result. Flag Types can exist before any chart has a flag.

## Before you run anything

1. Confirm you are not connected to Production.
2. Open [rdl/ClientChartFlags.rdl](rdl/ClientChartFlags.rdl) in a text editor.
3. Replace `YOUR_NON_PRODUCTION_SQL_SERVER` and `YOUR_NON_PRODUCTION_DATABASE` with the non-production server and database. Do not type a production server or database.
4. Save the RDL. Do not upload it yet.

The report prompts for credentials. It does not store a password.

## Apply on a non-production database

Preferred:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Apply_NonProd.ps1" -Server "YOUR_NON_PRODUCTION_SQL_SERVER" -Database "YOUR_NON_PRODUCTION_DATABASE"
```

Windows authentication is the default. For a SQL login, add `-User` and `-Password` for that session only. Do not save the password in this folder.

`Apply_NonProd.ps1` exits immediately when the database name contains Prod. It then runs [sql/01_readonly_check.sql](sql/01_readonly_check.sql) and [sql/02_create_procedures.sql](sql/02_create_procedures.sql). It does not upload the report and it does not register My Reports.

SSMS, if you are not using the script:

1. Connect to the non-production database. Read the name on the status bar.
2. F5 [sql/01_readonly_check.sql](sql/01_readonly_check.sql). Read `DatabaseName` and `ClientFlagRows`.
3. F5 [sql/02_create_procedures.sql](sql/02_create_procedures.sql) on that same database.
4. Stop. Do not run those files on Production.

`02` grants `EXECUTE` or `SELECT` to `public` on the objects it creates. It does not grant a My Reports role.

## Upload the report (non-production report server only)

1. Open Report Builder or the report server web portal for the **non-production** report server.
2. Upload `rdl/ClientChartFlags.rdl` into a non-production folder you choose.
3. If your site already has a shared data source for that non-production database, point the report's `SmartCare` data source at that shared source instead of the placeholder connection string.
4. Run the report there. You should see the title **Client Chart Flags** and a Flags count. An empty grid with Flags 0 means no client chart flags match the filters.

Do not upload this file to the production report server as the first test.

## My Reports (optional, still not Production)

After the report renders on the non-production report server:

1. Edit `@ReportServerPath` in [sql/03_register_my_reports_optional.sql](sql/03_register_my_reports_optional.sql) so it matches the path you uploaded. The file will not run while that value still says `ReplaceWith`. It also stops if the path or the database name contains Prod.
2. F5 that file on the **same non-production database**.
3. In Role Definition, grant the Reports permission for the new report to the roles you choose. Do that on the non-production database.
4. Refresh shared tables (your name at the top right, then Refresh Shared Tables). Sign out and sign back in.
5. Open the report. Do not open the folder row.

`AssociatedWith` stays empty so SmartCare treats this as My Reports, not a report inside a client chart.

## Remove it from the non-production database

F5 [sql/99_drop_procedures.sql](sql/99_drop_procedures.sql) on that non-production database. That drops the procedures and list functions from this package. It does not delete a My Reports row. Inactivate or delete that row in SmartCare if you created one.

## Assumptions

- Streamline SmartCare on SQL Server 2017 or newer (`STRING_AGG`, `STRING_SPLIT`).
- Tables `ObjectFlags`, `FlagTypes`, `Clients`, `Staff`, `Programs`, `ClientPrograms`, `GlobalCodes`.
- Program status category `PROGRAMSTATUS` with code names `Requested` and `Enrolled`. If your site uses different names, the program list on each row will be blank until you change those two names in `02_create_procedures.sql`.
- You can create procedures on the non-production database.

[Client Tracking](../Client_Tracking/README.md) is a different topic. That note is about making a form due on a schedule. This report lists flags that are already on charts.

## Rebuild the RDL

```powershell
python tools/build_rdl.py
```

Then replace the two connection placeholders again. Do not test in Prod.

## License

[MIT](../../LICENSE). Read [NOTICE.md](../../NOTICE.md). CASA-Trinity is not Streamline. **Do not test in Prod.**
