# Connect a folder or database

UI walkthrough (Explorer, Cline, what not to click): [USAGE.md](USAGE.md).

Yes: staff can attach **a local PHI folder** and **a local database** without rewriting the kit. Use `Connect.cmd` (or `.\Connect-Talon.ps1`).

## Are they limited by the open folder?

**In Explorer, yes — unless you connect.** VSCodium only lists folders in the current workspace. Cline also treats that workspace as home.

Talon now opens a **multi-root workspace**:

1. **Talon** — this kit (Python venv, memory, scripts)
2. **Each connected PHI folder** — their extracts

So they are not stuck inside `C:\Talon`. After Connect, both trees show on the left. The background learner watches every connected folder, not just the one they clicked last.

Cline can also read a file outside the workspace if you give it a full local path (`readFilesExternally` is on). Prefer Connect so they can *see* the files.

Do not open a consumer OneDrive folder if it will hold PHI.

## What Connect sets up

| Source | What you pick | What Talon does |
|--------|---------------|-----------------|
| Local folder | File-picker for a directory | Added to the workspace + learner |
| SQLite file | `.sqlite` / `.db` | SQLTools connection + parent folder in the workspace |
| SQL Server on this PC | Server + database, Windows auth | SQLTools MSSQL connection (`127.0.0.1` preferred) |

Saved in `ide-data\sources.json` (this PC only, not git). Passwords: use Windows auth when you can. SQL logins stay in that local file.

## Commands

```powershell
.\Connect-Talon.ps1                  # menu + pickers
.\Connect-Talon.ps1 -Folder "D:\PHI"
.\Connect-Talon.ps1 -Sqlite "D:\PHI\extract.sqlite"
.\Connect-Talon.ps1 -SqlServer "127.0.0.1" -SqlDatabase "ScratchReporting"
.\run.ps1                            # reopen last workspace + all connections
```

SQLTools: click the database icon, pick the connection name you added.

## Limits

- Cloud databases and VPN-only hosts are out of scope for a “local PHI” kit. Keep the server on `127.0.0.1` or a machine your privacy officer already treats as on-prem.
- SQL Server needs the SQLTools MSSQL driver (`setup.ps1` installs it) and a local ODBC / SQL client as usual.
- Workspace Trust: click **Trust** on the PHI folder the first time.
