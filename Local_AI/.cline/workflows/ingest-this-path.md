---
description: Ingest a local folder or file the user named
---
The user named a local folder or file. Do not ask what they want. Ingest it now.

1. Run this with the path they gave (quotes around the path):

`.venv\Scripts\python.exe learn\ingest_path.py --path "<the path>"`

That connects the folder, maps CSV/Excel/SQLite/SQL/JSON/Parquet, and writes `memory/data-maps/` so later sessions can reuse columns and example values.

2. Read `memory/INDEX.md` and the new maps.

3. Summarize what was mapped (file names, columns if present). Then answer their question using those maps.

If they did not paste a path yet, ask once for the local folder, then run the same command. Stay on this PC. Do not email, gist, or call a cloud API.
