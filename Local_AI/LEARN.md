# Talon memory (background)

Talon writes **data maps** and **lessons learned** on this PC without you asking.

`run.ps1` starts `learn\talon_learn.py` hidden. It watches the kit `data\` folder, `examples\`, and the workspace you opened. It also reads finished Cline sessions under `ide-data\cline-home\data\sessions`.

| Folder | What it stores | What it never stores |
|--------|----------------|----------------------|
| `memory/data-maps/` | File name, column/table names, types, row counts | Cell values, names, chart IDs |
| `memory/lessons/` | Redacted ask + whether the session worked or failed | Full prompts, dumps, PHI |
| `memory/WHAT_WORKED.md` | Short "reuse this" rows | Source data |
| `memory/FAILED.md` | Short "do not retry this" rows | Source data |

Cline is also instructed (`.clinerules` + seed) to update the same files after each task. The watcher still runs if the model forgets.

This is **not** a second cloud model and **not** HIPAA certified. Keep `memory\` off git and off OneDrive if the maps could describe real agency tables.

One-shot (no watch):

```powershell
.\.venv\Scripts\python.exe .\learn\talon_learn.py --kit "$PWD"
```
