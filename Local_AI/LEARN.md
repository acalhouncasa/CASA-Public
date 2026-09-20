# Memory

Talon is expected to work with PHI on this PC. Maps, example values, and lessons stay on the local disk. Do not send them to a cloud chat, email, or git remote.

`run.ps1` starts `learn\talon_learn.py` in the background. It watches `data\`, `examples\`, and every connected folder. It also reads finished Cline sessions.

| Location | Contents |
|----------|----------|
| `memory/data-maps/` | Path, columns, types, example values, row counts |
| `memory/talon-memory.sqlite` | The same facts in a local database |
| `memory/lessons/` | What was asked and whether it succeeded |
| `memory/WHAT_WORKED.md` | Approaches to reuse |
| `memory/FAILED.md` | Approaches not to repeat |

Cline is instructed to update the same files after each task. The watcher still runs if the model omits a write.

Treat `memory\` and `data\` as PHI work folders. Apply BitLocker or agency disk rules. Do not commit them. Do not place them on OneDrive if that account syncs off a managed store.

### Local backup

```powershell
.\Backup.cmd
```

Or use Connect menu item 6. Choose a USB drive or agency disk. The zip is PHI. Do not email it.

### One-shot scan (no watch)

```powershell
.\.venv\Scripts\python.exe .\learn\talon_learn.py --kit "$PWD" --workspace "$PWD"
```
