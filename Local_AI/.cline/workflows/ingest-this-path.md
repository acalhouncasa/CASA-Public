---
description: Ingest a local folder or file the user named
---
The user named a local folder or file. That IS the task. Do not ask. Do not list options. Do not invent filenames.

1. FIRST action — run in the terminal with the EXACT path they typed (quotes if spaces):

`.venv\Scripts\python.exe learn\ingest_path.py --path "<exact path>"`

Example: if they said `C:\Power BI`, run with `--path "C:\Power BI"`. That is a folder of many CSVs. Never invent a single file name.

2. Wait until the command finishes. Then read `memory/INDEX.md` and new files under `memory/data-maps/`.

3. Reply with a short summary: how many files mapped, a few names, that maps are ready for later sessions. Stop unless they asked something else.

Stay on this PC. Do not email, gist, or call a cloud API.
