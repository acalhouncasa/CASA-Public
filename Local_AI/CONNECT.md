# Connect

Attach a local project folder, PHI folder, or database. The Talon kit remains the first Explorer root.

UI reference: [Getting started](USAGE.md).

---

## Workspace limit

Explorer and Cline only list folders in the current workspace. Connect adds folders beside the kit so extracts are visible without opening the kit as a dump of files.

After Connect, Explorer shows:

1. **Talon** — this kit (Python environment, memory, scripts), collapsed on launch
2. **Each connected folder** — project scripts and/or PHI extracts

The background learner watches every connected folder.

Cline can read a file outside the workspace if you give it a full local path. Prefer Connect so the files appear in Explorer.

Do not connect a consumer OneDrive, Desktop, or Downloads path if it will hold PHI.

**File → Open Folder** does not replace the kit. Talon restores the workspace and adds the folder you selected. **File → Add Folder to Workspace** is the intended command.

---

## What Connect configures

| Source | Selection | Result |
|--------|-----------|--------|
| Local folder | Directory picker | Added to the workspace and the learner |
| SQLite file | `.sqlite` / `.db` | SQLTools connection; parent folder added to the workspace |
| SQL Server on this PC | Server and database, Windows authentication | SQLTools MSSQL connection (`127.0.0.1` preferred) |

Connections are stored in `ide-data\sources.json` on this PC only. Use Windows authentication when possible. SQL passwords, if entered, stay in that local file.

Connect refuses duplicate paths, warns on OneDrive / Desktop / Downloads, and can remove a connection (menu item 5). Project versus PHI is a label in Explorer.

---

## Commands

```powershell
.\Connect-Talon.ps1
.\Connect-Talon.ps1 -Folder "D:\PHI"
.\Connect-Talon.ps1 -Sqlite "D:\PHI\extract.sqlite"
.\Connect-Talon.ps1 -SqlServer "127.0.0.1" -SqlDatabase "ScratchReporting"
.\run.ps1
```

In SQLTools, open the database icon and select the connection name you added.

---

## Limits

- Cloud databases and VPN-only hosts are out of scope. Keep the server on `127.0.0.1` or a host your privacy officer already treats as on-premises.
- SQL Server requires the SQLTools MSSQL driver (`setup.ps1` installs it) and a local ODBC or SQL client.
- Trust connected local folders when the editor prompts. Cloud-synced paths are not auto-trusted.
