# Memory

Talon is expected to work with PHI on this PC. Maps, example values, and lessons stay on this disk. Do not send them to a cloud chat, email, or git remote.

This page is what the learner **actually does**. It does not train a model and it does not “understand” a dataset the way a person does. It writes local notes so the next Talon session can start with file shapes and past outcomes instead of rediscovering them.

---

## Purpose

Three writers keep `memory\`:

1. **Background learner** (`learn\talon_learn.py`) — started by `run.ps1`. It scans files and finished Cline sessions on a timer. Each watch cycle re-reads `ide-data\sources.json`, so a folder added after launch still gets mapped.
2. **Cline** — instructed to ingest a local path the user names (no “what should I do with this folder?”), read those notes before repeating work, and write a richer map and a short lesson after a task.
3. **`learn\ingest_path.py`** — connect + one-shot map. Cline, Connect, and Add Folder to Workspace all call this.

The next task is supposed to open `memory\INDEX.md` first, then `WHAT_WORKED.md`, `FAILED.md`, and the data maps that match the files in play. That is how Talon prepares: it reuses columns, types, example values, and known good/bad approaches. It does not load the SQLite memory into the model automatically.

---

## What the background learner does

`run.ps1` starts `learn\talon_learn.py --watch` against the kit plus every folder in `ide-data\sources.json` (Connect). Default interval is **20 seconds**. A second copy will not start if one is already running. Folders added later are picked up on the next cycle from `sources.json`.

If the user pastes a local path in Cline, Cline runs:

```powershell
.\.venv\Scripts\python.exe .\learn\ingest_path.py --path "<that path>"
```

That writes `sources.json`, maps the files immediately, and leaves the folder on the watch list. Do not treat a pasted extract folder as a one-off.

Each cycle it:

1. Walks `data\`, `examples\`, connected workspace folders, and (if nothing was connected) the kit itself.
2. Skips `.git`, `.venv`, `ide-data`, `ide-extensions`, `dist`, `logs`, `memory`, `branding`, `pack`, `learn`, `payload`, `__pycache__`, `node_modules`, and hidden directories.
3. Looks at files with these extensions: `.csv`, `.tsv`, `.xlsx`, `.xls`, `.sqlite`, `.db`, `.sql`, `.json`, `.parquet`.
4. Hashes each file. Unchanged files are skipped (`memory\state.json`).
5. Writes or updates a markdown map under `memory\data-maps\`.
6. Mirrors the same facts into `memory\talon-memory.sqlite` (`files`, `columns`, `lessons` tables).
7. Reads finished Cline sessions under `ide-data\cline-home\data\sessions\` and writes a lesson the first time a session has `completed`, `failed`, `error`, or an `ended_at` timestamp.
8. Rebuilds `memory\INDEX.md` when anything new was written.

### How it maps data

| File type | What it records |
|-----------|-----------------|
| CSV / TSV | Headers, inferred type (`integer` / `number` / `text`), non-empty count in the sample, up to **8** common example values. Reads at most **200** data rows. |
| SQLite / `.db` | Table names, `PRAGMA table_info` types, `COUNT(*)`, up to **8** distinct example values per column. |
| `.sql` | Object names found after `FROM`, `JOIN`, `INTO`, `UPDATE`, or `TABLE` in the first 12,000 characters. |
| JSON | File name and path only (`kind: json`). No key walk. |
| Excel / Parquet | File name, path, and suffix only. **No column map** from this script. |

`May contain PHI` is a **path-name guess** (`phi`, `ssn`, `mrn`, or `chart` in the path). It is not a content scan. Treat every map as if it might hold PHI.

Example values are stored on purpose so later questions can reuse site codes, month labels, and join-looking columns without opening the raw extract again. Those examples can be real PHI. Keep them here.

### How it records lessons

For each finished Cline session it has not seen before, it writes `memory\lessons\<session_id>.md` with:

- the prompt / title (trimmed)
- Cline status and whether it treats the session as failed
- model name
- workspace path
- a reminder to read the memory files next time

It then appends one row to `WHAT_WORKED.md` or `FAILED.md`.

The watcher **does not** copy the chat, the SQL that ran, or the steps that fixed a problem. Those details only appear if Cline writes them after the task.

---

## What Cline is told to do

On launch, Cline’s custom instructions say:

- If the user names a local folder or file, run `learn\ingest_path.py` immediately. Do not ask what the path is for.
- Before repeating work, read `memory\INDEX.md`, `WHAT_WORKED.md`, `FAILED.md`, and `data-maps\`.
- After a task, write a data map (columns, types, useful example values) and a short lesson.

Command Palette starters:

| Command | What it asks Cline to do |
|---------|--------------------------|
| **Talon: Starter — ingest this path** | Run `ingest_path.py` on the path the user named, then use the maps. |
| **Talon: Starter — read memory index** | Read the index and the ledgers before answering. |
| **Talon: Starter — map this folder** | Walk connected folders and write maps (path, columns, types, example values, likely join keys, row count) plus a lesson. |
| **Talon: Starter — list SQL tables** | List tables, then update maps for anything new. |

The map-this-folder starter asks for **join keys**. The Python watcher does not infer joins. If a map has join notes, a person or Cline added them.

---

## Layout

| Location | What is there |
|----------|----------------|
| `memory\INDEX.md` | Links to every current map and lesson. Start here. |
| `memory\data-maps\` | One markdown file per scanned data file, with a JSON payload. |
| `memory\talon-memory.sqlite` | Same facts in tables: `files`, `columns`, `lessons`. |
| `memory\lessons\` | One file per recorded Cline session. |
| `memory\WHAT_WORKED.md` | Date, topic, “reuse this approach.” Created when the first success is recorded. |
| `memory\FAILED.md` | Date, topic, “do not retry this exact approach.” Created when the first failure is recorded. |
| `memory\state.json` | File hashes and session ids already processed. |

`memory\` and `data\` are PHI work folders. Apply BitLocker or agency disk rules. Do not commit them. Do not put them on OneDrive if that account syncs off a managed store.

---

## What this is not

- Not model training and not fine-tuning Ollama.
- Not a search index of file contents.
- Not a guarantee that Cline read the maps. The files are there; the agent still has to open them.
- Not a full post-mortem. Watcher lessons are status + the ask. The useful “do this next time” text has to be written by Cline or by you.
- Not a substitute for opening the real CSV or database when counts or codes must be exact.

---

## One-shot scan (no watch)

```powershell
.\.venv\Scripts\python.exe .\learn\ingest_path.py --path "D:\Extracts"
.\.venv\Scripts\python.exe .\learn\talon_learn.py --kit "$PWD" --workspace "$PWD"
```

`ingest_path.py` is the usual command when someone just named a folder. Add more `--workspace` paths on `talon_learn.py` only when you want a scan without updating `sources.json`.

---

## Local backup

```powershell
.\Backup.cmd
```

Or Connect menu item 6. Choose a USB drive or agency disk. The zip is PHI. Do not email it.

---

## What you can expect on the next task

If the learner has already seen a file, a later question can start from the map: column names, rough types, and example values. If a similar Cline session already failed or worked, that title is on `FAILED.md` or `WHAT_WORKED.md`.

If a file is new, wait one watch cycle (or paste the folder path so Cline runs `ingest_path.py`) so a map exists before asking Cline to analyze it. If you need join keys or “what we did last time,” use **map this folder** after the work, or add those lines yourself. The watcher will not invent them.

**Lesson (2026-09-21):** A pasted local extract folder is a connect-and-map request. Cline must not ask what to do with it. `ingest_path.py` records the folder in `sources.json` so later sessions reuse `memory\INDEX.md`.

**Lesson (2026-09-21, 1.4.10):** Small local models still offered a menu of options and invented `10e11_data.csv` when the user said `C:\Power BI`. Rules now put CRITICAL first: exact path only, first action is `ingest_path.py`, no invented filenames, folder of many CSVs is normal.
