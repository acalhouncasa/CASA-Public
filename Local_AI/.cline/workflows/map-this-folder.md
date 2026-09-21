---
description: Map every connected folder
---
Read `memory/INDEX.md`, `memory/WHAT_WORKED.md`, and `memory/FAILED.md` if they exist.

Then walk every connected workspace folder. Skip `.venv`, `ide-data`, `ide-extensions`, and `branding`.

If the user just named a local path, run `.venv\Scripts\python.exe learn\ingest_path.py --path "<that path>"` first instead of asking.

For each CSV, Excel, SQLite, or SQL file you find, write or update `memory/data-maps/<name>.md` with:
- path
- columns and types
- useful example values (local PHI is allowed)
- likely join keys
- row count if cheap

Append a short lesson under `memory/lessons/` and a line on WHAT_WORKED or FAILED. Stay on this PC. Do not email, gist, or call a cloud API.
