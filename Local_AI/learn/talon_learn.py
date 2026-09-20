"""Talon background learner. Local disk only, including PHI on this PC."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

SKIP_DIR = {
    ".git",
    ".venv",
    "ide-data",
    "ide-extensions",
    "dist",
    "logs",
    "memory",
    "branding",
    "pack",
    "learn",
    "payload",
    "__pycache__",
    "node_modules",
    ".ipynb_checkpoints",
}
DATA_EXT = {".csv", ".tsv", ".xlsx", ".xls", ".sqlite", ".db", ".sql", ".json", ".parquet"}
EXAMPLE_LIMIT = 8
SAMPLE_ROWS = 200


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def clip(text: str, limit: int = 400) -> str:
    cleaned = " ".join((text or "").split())
    return cleaned[:limit]


def file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def looks_like_phi_path(path: Path) -> bool:
    blob = str(path).lower()
    return any(token in blob for token in ("phi", "ssn", "mrn", "chart"))


def load_state(path: Path) -> dict:
    if not path.is_file():
        return {"files": {}, "sessions": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {"files": {}, "sessions": {}}
    data.setdefault("files", {})
    data.setdefault("sessions", {})
    return data


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def ensure_memory_dirs(memory: Path) -> None:
    for name in ("data-maps", "lessons"):
        (memory / name).mkdir(parents=True, exist_ok=True)


def memory_db(memory: Path) -> sqlite3.Connection:
    con = sqlite3.connect(str(memory / "talon-memory.sqlite"))
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            name TEXT,
            kind TEXT,
            may_contain_phi INTEGER,
            mapped_at TEXT,
            extra_json TEXT
        )
        """
    )
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS columns (
            path TEXT,
            col_name TEXT,
            col_type TEXT,
            examples_json TEXT,
            PRIMARY KEY (path, col_name)
        )
        """
    )
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS lessons (
            session_id TEXT PRIMARY KEY,
            title TEXT,
            failed INTEGER,
            body TEXT,
            recorded_at TEXT
        )
        """
    )
    return con


def upsert_file(con: sqlite3.Connection, path: Path, payload: dict) -> None:
    con.execute(
        """
        INSERT OR REPLACE INTO files (path, name, kind, may_contain_phi, mapped_at, extra_json)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            str(path),
            path.name,
            payload.get("kind"),
            1 if payload.get("may_contain_phi") else 0,
            utc_now(),
            json.dumps(payload),
        ),
    )
    con.execute("DELETE FROM columns WHERE path = ?", (str(path),))
    for col in payload.get("columns") or []:
        con.execute(
            """
            INSERT OR REPLACE INTO columns (path, col_name, col_type, examples_json)
            VALUES (?, ?, ?, ?)
            """,
            (
                str(path),
                col.get("name"),
                col.get("type"),
                json.dumps(col.get("examples") or []),
            ),
        )
    for table in payload.get("tables") or []:
        for col in table.get("columns") or []:
            con.execute(
                """
                INSERT OR REPLACE INTO columns (path, col_name, col_type, examples_json)
                VALUES (?, ?, ?, ?)
                """,
                (
                    str(path),
                    f"{table.get('table')}.{col.get('name')}",
                    col.get("type"),
                    json.dumps(col.get("examples") or []),
                ),
            )
    con.commit()


def infer_type(values: list[str]) -> str:
    if values and all(re.fullmatch(r"-?\d+", v) for v in values):
        return "integer"
    if values and all(re.fullmatch(r"-?\d+(\.\d+)?", v) for v in values):
        return "number"
    return "text"


def infer_csv_map(path: Path) -> dict | None:
    try:
        with path.open(newline="", encoding="utf-8-sig", errors="replace") as fh:
            reader = csv.reader(fh)
            headers = [h.strip() for h in next(reader, [])]
            rows = []
            for i, row in enumerate(reader):
                if i >= SAMPLE_ROWS:
                    break
                rows.append(row)
    except OSError:
        return None
    columns = []
    for idx, name in enumerate(headers):
        values = [r[idx].strip() for r in rows if idx < len(r) and r[idx].strip()]
        counts = Counter(values)
        examples = [val for val, _ in counts.most_common(EXAMPLE_LIMIT)]
        columns.append(
            {
                "name": name,
                "type": infer_type(values[:20]),
                "non_empty": len(values),
                "examples": examples,
            }
        )
    return {
        "kind": "tabular",
        "file": path.name,
        "path": str(path),
        "row_samples": len(rows),
        "columns": columns,
        "may_contain_phi": looks_like_phi_path(path),
        "local_only": True,
    }


def infer_sqlite_map(path: Path) -> dict | None:
    try:
        con = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    except sqlite3.Error:
        return None
    tables = []
    try:
        names = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]
        for table in names:
            info = list(con.execute(f'PRAGMA table_info("{table}")'))
            count = con.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            cols = []
            for _cid, col_name, col_type, *_rest in info:
                examples: list[str] = []
                try:
                    examples = [
                        str(r[0])
                        for r in con.execute(
                            f'SELECT DISTINCT "{col_name}" FROM "{table}" WHERE "{col_name}" IS NOT NULL LIMIT {EXAMPLE_LIMIT}'
                        )
                    ]
                except sqlite3.Error:
                    examples = []
                cols.append({"name": col_name, "type": col_type or "TEXT", "examples": examples})
            tables.append({"table": table, "columns": cols, "row_count": count})
    except sqlite3.Error:
        return None
    finally:
        con.close()
    return {
        "kind": "sqlite",
        "file": path.name,
        "path": str(path),
        "tables": tables,
        "may_contain_phi": looks_like_phi_path(path),
        "local_only": True,
    }


def infer_sql_map(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")[:12000]
    except OSError:
        return None
    tables = sorted(set(re.findall(r"(?i)(?:from|join|into|update|table)\s+([A-Za-z_][A-Za-z0-9_]*)", text)))
    return {
        "kind": "sql",
        "file": path.name,
        "path": str(path),
        "object_names": tables[:80],
        "may_contain_phi": looks_like_phi_path(path),
        "local_only": True,
    }


def infer_map(path: Path) -> dict | None:
    ext = path.suffix.lower()
    if ext in {".csv", ".tsv"}:
        return infer_csv_map(path)
    if ext in {".sqlite", ".db"}:
        return infer_sqlite_map(path)
    if ext == ".sql":
        return infer_sql_map(path)
    if ext == ".json":
        return {"kind": "json", "file": path.name, "path": str(path), "local_only": True}
    return {"kind": "file", "file": path.name, "suffix": ext, "path": str(path), "local_only": True}


def write_data_map(memory: Path, path: Path, payload: dict) -> None:
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", path.name)
    dest = memory / "data-maps" / f"{stem}.md"
    phi = "yes" if payload.get("may_contain_phi") else "maybe"
    lines = [
        f"# Data map — {path.name}",
        "",
        f"Updated: {utc_now()}",
        f"Local path: `{path}`",
        f"May contain PHI: {phi}",
        "",
        "This map is for Talon on this PC. It may include example values so later questions can reuse joins and codes. Do not copy this file to email, git, or a cloud chat.",
        "",
        "```json",
        json.dumps(payload, indent=2),
        "```",
        "",
    ]
    dest.write_text("\n".join(lines), encoding="utf-8")


def write_index(memory: Path) -> None:
    maps = sorted((memory / "data-maps").glob("*.md"))
    lessons = sorted((memory / "lessons").glob("*.md"))
    lines = [
        "# Talon memory index",
        "",
        "Local only. These files may describe PHI. Do not commit or upload them.",
        "",
        "## Data maps",
    ]
    if maps:
        lines.extend(f"- [{p.stem}](data-maps/{p.name})" for p in maps)
    else:
        lines.append("- (none yet)")
    lines.append("")
    lines.append("## Lessons")
    if lessons:
        lines.extend(f"- [{p.stem}](lessons/{p.name})" for p in lessons)
    else:
        lines.append("- (none yet)")
    lines.append("")
    (memory / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def append_ledger(memory: Path, name: str, row: str) -> None:
    path = memory / name
    if not path.is_file():
        header = (
            "# What worked\n\nLocal only. May describe PHI.\n\n| When | Topic | Do |\n|---|---|---|\n"
            if name == "WHAT_WORKED.md"
            else "# Failed approaches\n\nLocal only. May describe PHI.\n\n| When | Topic | Do not |\n|---|---|---|\n"
        )
        path.write_text(header, encoding="utf-8")
    text = path.read_text(encoding="utf-8")
    if row in text:
        return
    with path.open("a", encoding="utf-8") as fh:
        fh.write(row + "\n")


def write_lesson(memory: Path, session_id: str, title: str, body: str, failed: bool) -> None:
    dest = memory / "lessons" / f"{session_id}.md"
    dest.write_text(
        "\n".join(
            [
                f"# Lesson — {title}",
                "",
                f"Session: `{session_id}`",
                f"When: {utc_now()}",
                f"Outcome: {'failed' if failed else 'worked'}",
                "",
                body,
                "",
                "Local only. This lesson may mention PHI. Do not copy it off this PC.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    topic = title.replace("|", "/")
    if failed:
        append_ledger(memory, "FAILED.md", f"| {utc_now()[:10]} | {topic} | Do not retry this exact approach |")
    else:
        append_ledger(memory, "WHAT_WORKED.md", f"| {utc_now()[:10]} | {topic} | Reuse this approach |")
    con = memory_db(memory)
    try:
        con.execute(
            """
            INSERT OR REPLACE INTO lessons (session_id, title, failed, body, recorded_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (session_id, title, 1 if failed else 0, body, utc_now()),
        )
        con.commit()
    finally:
        con.close()


def iter_data_files(roots: list[Path]) -> list[Path]:
    found: list[Path] = []
    seen: set[str] = set()
    for root in roots:
        if not root.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIR and not d.startswith(".")]
            for name in filenames:
                path = Path(dirpath) / name
                key = str(path.resolve()) if path.exists() else str(path)
                if path.suffix.lower() in DATA_EXT and key not in seen:
                    seen.add(key)
                    found.append(path)
    return found


def scan_files(roots: list[Path], memory: Path, state: dict) -> int:
    changed = 0
    con = memory_db(memory)
    try:
        for path in iter_data_files(roots):
            try:
                digest = file_hash(path)
            except OSError:
                continue
            key = str(path)
            if state["files"].get(key) == digest:
                continue
            payload = infer_map(path)
            if not payload:
                continue
            write_data_map(memory, path, payload)
            upsert_file(con, path, payload)
            state["files"][key] = digest
            changed += 1
    finally:
        con.close()
    return changed


def session_title(meta: dict) -> str:
    raw = str(meta.get("prompt") or meta.get("metadata", {}).get("title") or meta.get("session_id") or "session")
    return clip(raw, 200) or "session"


def scan_sessions(cline_home: Path, memory: Path, state: dict) -> int:
    sessions = cline_home / "data" / "sessions"
    if not sessions.is_dir():
        return 0
    changed = 0
    for folder in sessions.iterdir():
        if not folder.is_dir():
            continue
        sid = folder.name
        if sid in state["sessions"]:
            continue
        meta_path = folder / f"{sid}.json"
        if not meta_path.is_file():
            continue
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        status = str(meta.get("status") or "")
        if status not in {"completed", "failed", "error"} and not meta.get("ended_at"):
            continue
        failed = status in {"failed", "error"} or meta.get("exit_code") not in (None, 0)
        title = session_title(meta)
        model = clip(str(meta.get("model") or ""), 40)
        cwd = clip(str(meta.get("cwd") or meta.get("workspace_root") or ""), 200)
        body = (
            f"Model: `{model}`\n\n"
            f"Cline status: `{status or 'ended'}`\n\n"
            f"Workspace: `{cwd}`\n\n"
            f"Ask: {title}\n\n"
            "Recorded so Talon can reuse what worked and skip a failed approach. "
            "Read `memory/WHAT_WORKED.md`, `memory/FAILED.md`, and `memory/data-maps/` first."
        )
        write_lesson(memory, sid, title, body, failed)
        state["sessions"][sid] = {"status": status, "at": utc_now()}
        changed += 1
    return changed


def cycle(roots: list[Path], memory: Path, cline_home: Path, state_path: Path) -> None:
    ensure_memory_dirs(memory)
    state = load_state(state_path)
    n_files = scan_files(roots, memory, state)
    n_sess = scan_sessions(cline_home, memory, state)
    if n_files or n_sess:
        write_index(memory)
        save_state(state_path, state)
        print(f"{utc_now()} maps+{n_files} lessons+{n_sess}", flush=True)


def already_running(pid_path: Path) -> bool:
    if not pid_path.is_file():
        return False
    try:
        pid = int(pid_path.read_text(encoding="utf-8").strip())
    except ValueError:
        return False
    if pid == os.getpid():
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Talon local learner")
    parser.add_argument("--kit", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--workspace", action="append", default=[])
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=int, default=20)
    args = parser.parse_args()

    kit = Path(args.kit).resolve()
    workspaces = [Path(item).resolve() for item in (args.workspace or []) if item]
    memory = kit / "memory"
    cline_home = kit / "ide-data" / "cline-home"
    state_path = memory / "state.json"
    pid_path = kit / "logs" / "talon-learn.pid"
    pid_path.parent.mkdir(parents=True, exist_ok=True)

    roots = [kit / "data", kit / "examples"]
    roots.extend(workspaces)
    if not workspaces:
        roots.append(kit)
    if args.watch and already_running(pid_path):
        print("talon-learn already running", flush=True)
        return 0

    pid_path.write_text(str(os.getpid()), encoding="utf-8")
    try:
        cycle(roots, memory, cline_home, state_path)
        if not args.watch:
            return 0
        while True:
            time.sleep(max(5, args.interval))
            cycle(roots, memory, cline_home, state_path)
    finally:
        try:
            if pid_path.is_file() and pid_path.read_text(encoding="utf-8").strip() == str(os.getpid()):
                pid_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
