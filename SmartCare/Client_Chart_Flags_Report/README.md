# Client chart flags report

A general SmartCare report of flags on client charts. One row is one flag. Filters cover dates, flag status, chart status, flag type, program, primary clinician, and client id.

This is for any agency that uses Streamline SmartCare. It does not include another site's folders, role list, or database names. Select the SmartCare database you want in SSMS. The scripts have no `USE` statement and no environment check.

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

## Connect the report

1. Open [rdl/ClientChartFlags.rdl](rdl/ClientChartFlags.rdl) in a text editor.
2. Replace `YOUR_SQL_SERVER` and `YOUR_DATABASE` with the SmartCare server and database.
3. Save the RDL.

The report prompts for credentials. It does not store a password. If your site already has a shared report data source, point the report's `SmartCare` data source at that source instead of the placeholder connection string.

## Create the procedures

Preferred:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Apply.ps1" -Server "YOUR_SQL_SERVER" -Database "YOUR_DATABASE"
```

Windows authentication is the default. For a SQL login, add `-User` and `-Password` for that session only. Do not save the password in this folder.

`Apply.ps1` runs [sql/01_readonly_check.sql](sql/01_readonly_check.sql) and then [sql/02_create_procedures.sql](sql/02_create_procedures.sql). It does not upload the report and it does not register My Reports.

SSMS:

1. Select the SmartCare database.
2. F5 [sql/01_readonly_check.sql](sql/01_readonly_check.sql). Read `DatabaseName` and `ClientFlagRows`.
3. F5 [sql/02_create_procedures.sql](sql/02_create_procedures.sql) on that same database.

`02` grants `EXECUTE` or `SELECT` to `public` on the objects it creates. It does not grant a My Reports role.

## Upload the report

1. Open Report Builder or the report server web portal.
2. Upload `rdl/ClientChartFlags.rdl` into the folder you choose.
3. Run the report. You should see the title **Client Chart Flags** and a Flags count. An empty grid with Flags 0 means no client chart flags match the filters.

## My Reports (optional)

After the report renders:

1. Edit `@ReportServerPath` in [sql/03_register_my_reports_optional.sql](sql/03_register_my_reports_optional.sql) so it matches the path you uploaded. The file will not run while that value still says `ReplaceWith`.
2. F5 that file on the same database.
3. In Role Definition, grant the Reports permission for the new report to the roles you choose.
4. Refresh shared tables (your name at the top right, then Refresh Shared Tables). Sign out and sign back in.
5. Open the report. Do not open the folder row.

`AssociatedWith` stays empty so SmartCare treats this as My Reports, not a report inside a client chart.

## Remove the procedures

F5 [sql/99_drop_procedures.sql](sql/99_drop_procedures.sql) on that database. That drops the procedures and list functions from this package. It does not delete a My Reports row. Inactivate or delete that row in SmartCare if you created one.

## Assumptions

- Streamline SmartCare on SQL Server 2017 or newer (`STRING_AGG`, `STRING_SPLIT`).
- Tables `ObjectFlags`, `FlagTypes`, `Clients`, `Staff`, `Programs`, `ClientPrograms`, `GlobalCodes`.
- Program status category `PROGRAMSTATUS` with code names `Requested` and `Enrolled`. If your site uses different names, the program list on each row will be blank until you change those two names in `02_create_procedures.sql`.
- You can create procedures on the database you selected.

[Client Tracking](../Client_Tracking/README.md) is a different topic. That note is about making a form due on a schedule. This report lists flags that are already on charts.

## Rebuild the RDL

```powershell
python tools/build_rdl.py
```

Then replace `YOUR_SQL_SERVER` and `YOUR_DATABASE` again.

## License

[MIT](../../LICENSE). Read [NOTICE.md](../../NOTICE.md). CASA-Trinity is not Streamline.
