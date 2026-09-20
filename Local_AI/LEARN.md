# Talon memory (background)

Talon is meant to **work with PHI on this PC**. Maps, example values, and lessons stay on the local disk. That is allowed. Sending them to a cloud chat, email, or git is not.

`run.ps1` starts `learn\talon_learn.py` hidden. It watches `data\`, `examples\`, and the workspace you opened (including folders named PHI). It also reads finished Cline sessions.

| Folder | What it stores locally |
|--------|------------------------|
| `memory/data-maps/` | Path, columns, types, example values, row counts |
| `memory/talon-memory.sqlite` | Same facts in a queryable local DB for later questions |
| `memory/lessons/` | What was asked and whether it worked or failed |
| `memory/WHAT_WORKED.md` | Reuse this |
| `memory/FAILED.md` | Do not retry this |

Cline is told to update the same files after each task. The watcher still runs if the model forgets.

Treat `memory\` and `data\` as **PHI work folders**. BitLocker / agency disk rules apply. Do not commit them. Do not put them on OneDrive if that syncs off a managed store.

Local backup (USB or agency disk, never OneDrive):

```powershell
.\Backup.cmd
```

Or Connect menu item 6. The zip is PHI. Do not email it.

One-shot (no watch):

```powershell
.\.venv\Scripts\python.exe .\learn\talon_learn.py --kit "$PWD" --workspace "$PWD"
```
