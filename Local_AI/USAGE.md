# How to use the Talon UI

Talon is the editor on the left and the agent on the right. Keep **Cline → Ollama**. Do not sign in to a Cline account.

## Best folder setup

Use **one main kit** plus **named work folders**. Do not File → Open Folder on a PHI tree (that drops the kit and the venv).

| Root you see in Explorer | What belongs there |
|--------------------------|--------------------|
| **Talon** (always first) | This kit: `.venv`, `memory\`, scripts. Not a dump of extracts. |
| **Project** (optional) | SQL, notebooks, scripts for a job. One folder per project if you have several. |
| **PHI** (optional) | Local extracts, CSVs, SQLite files that may be PHI. |

Example on disk:

```text
C:\Talon\                 kit (this folder)
D:\TalonProjects\Ops\     project scripts
D:\TalonPHI\Extracts\     PHI files for this month
```

Attach the last two with **Talon Connect** (desktop / Start Menu) or `Connect.cmd`. After that, Explorer shows all of them at once. The learner watches every connected folder.

If code and PHI already live in one agency folder, Connect **that** folder once. You do not need three roots.

## What not to do in the UI

- **File → Open Folder** on PHI only — you lose Talon, Python, and memory.
- To add another tree later: **File → Add Folder to Workspace**, or run Connect again.
- Do not Trust a OneDrive / consumer-sync path for PHI.
- Do not switch Cline off Ollama.

## The screen

Left: Explorer (Talon, then Project, then PHI).  
Center: the file you opened.  
Right: Cline (provider = Ollama).  
Bottom status bar: Python should be `.venv\Scripts\python.exe`.  
Database icon: SQLTools (Local SQLite plus anything you Connected).

1. **Trust** each new folder when Windows / VSCodium asks.
2. Left: open a file under **Project** or **PHI**.
3. Right: tell Cline what to do. It can see every root in this workspace.
4. Database icon (SQLTools): **Local SQLite** is the kit scratch DB. Connections you added in Connect show up here.
5. First session: ask Cline to “read `memory/INDEX.md` then describe the connected PHI folder.”

## Daily start

1. Shortcut **Talon** (not stock VSCodium).
2. If Explorer only shows the kit: **Talon Connect** and pick the PHI / project folder again.
3. Keep Cline on the right. If it is empty, it is still this window’s agent — do not open a cloud chat.

## If something looks wrong

| You see | Do this |
|---------|---------|
| Only one folder, named Talon | Run **Talon Connect** |
| “Create my Account” in Cline | Close Talon, run `.\run.ps1` (not a raw VSCodium icon) |
| Python not the venv | Status bar interpreter → `.venv\Scripts\python.exe` |
| SQLTools empty | Connect a SQLite file or SQL Server; or use `data\local.sqlite` |

More: [CONNECT.md](CONNECT.md) (attach data), [LEARN.md](LEARN.md) (background maps), [HIPAA.md](HIPAA.md) if you have the public pack.
