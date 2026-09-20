"""Talon background learner. Local files only. Never stores row-level values."""

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
from datetime import datetime, timezone
from pathlib import Path

SKIP_DIR = {
    ".git",
    ".venv",
    "ide-data",
    "ide-extensions",
    "dist",
    "logs",
    "__pycache__",
    "node_modules",
    ".ipynb_checkpoints",
}
SKIP_NAME_HINT = re.compile(r"(^|[^a-z])phi([^a-z]|$)|ssn|dob|mrn|chart.?id", re.I)
EMAIL = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I)
LONG_DIGIT = re.compile(r"\b\d{6,}\b")
DATA_EXT = {".csv", ".tsv", ".xlsx", ".xls", ".sqlite", ".db", ".sql", ".json", ".parquet"}


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def redact(text: str, limit: int = 160) -> str:
    if not text:
        return ""
    cleaned = EMAIL.sub("[email]", text)
    cleaned = LONG_DIGIT.sub("[n]", cleaned)
    cleaned = re.sub(r"(?i)test\s*phi", "[redacted-folder]", cleaned)
    cleaned = re.sub(r"(?i)[\w.-]*phi[\w.-]*", "[redacted-file]", cleaned)
    cleaned = re.sub(r"[A-Za-z]:\\[^\s]{8,}", "[path]", cleaned)
    cleaned = re.sub(r"(?i)(client|patient|member)\s*[:=]\s*\S+", r"\1=[redacted]", cleaned)
    cleaned = " ".join(cleaned.split())
    return cleaned[:limit]


def file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


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


def write_index(memory: Path) -> None:
    maps = sorted((memory / "data-maps").glob("*.md"))
    lessons = sorted((memory / "lessons").glob("*.md"))
    lines = [
        "# Talon memory index",
        "",
        "Generated locally. Schema and lessons only — not source row values.",
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


def infer_csv_map(path: Path) -> dict | None:
    if SKIP_NAME_HINT.search(path.name):
        return {
            "kind": "tabular",
            "path": path.name,
            "note": "filename looks sensitive; headers not stored",
        }
    try:
        with path.open(newline="", encoding="utf-8-sig", errors="replace") as fh:
            reader = csv.reader(fh)
            headers = next(reader, [])
            sample = []
            for i, row in enumerate(reader):
                if i >= 8:
                    break
                sample.append(row)
    except OSError:
        return None
    types = []
    for idx, name in enumerate(headers):
        col = [r[idx] for r in sample if idx < len(r) and r[idx] != ""]
        kind = "text"
        if col and all(re.fullmatch(r"-?\d+", v) for v in col):
            kind = "integer"
        elif col and all(re.fullmatch(r"-?\d+(\.\d+)?", v) for v in col):
            kind = "number"
        types.append({"name": redact(name, 80), "type": kind})
    return {
        "kind": "tabular",
        "file": path.name,
        "columns": types,
        "sample_rows_seen": len(sample),
        "values_stored": False,
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
            cols = [
                {"name": redact(r[1], 80), "type": r[2] or "TEXT"}
                for r in con.execute(f"PRAGMA table_info({table})")
            ]
            count = con.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            tables.append({"table": table, "columns": cols, "row_count": count})
    except sqlite3.Error:
        return None
    finally:
        con.close()
    return {"kind": "sqlite", "file": path.name, "tables": tables, "values_stored": False}


def infer_sql_map(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")[:8000]
    except OSError:
        return None
    tables = sorted(set(re.findall(r"(?i)(?:from|join|into|update|table)\s+([A-Za-z_][A-Za-z0-9_]*)", text)))
    return {
        "kind": "sql",
        "file": path.name,
        "object_names": tables[:40],
        "values_stored": False,
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
        return {"kind": "json", "file": path.name, "values_stored": False}
    return {"kind": "file", "file": path.name, "suffix": ext, "values_stored": False}


def write_data_map(memory: Path, path: Path, payload: dict) -> None:
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", path.name)
    dest = memory / "data-maps" / f"{stem}.md"
    lines = [
        f"# Data map — {path.name}",
        "",
        f"Updated: {utc_now()}",
        f"Relative file: `{path.name}`",
        "",
        "Row values are not stored. This is schema / shape only.",
        "",
        "```json",
        json.dumps(payload, indent=2),
        "```",
        "",
    ]
    dest.write_text("\n".join(lines), encoding="utf-8")


def append_ledger(memory: Path, name: str, row: str) -> None:
    path = memory / name
    if not path.is_file():
        header = (
            "# What worked\n\n| When | Topic | Do |\n|---|---|---|\n"
            if name == "WHAT_WORKED.md"
            else "# Failed approaches\n\n| When | Topic | Do not |\n|---|---|---|\n"
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
                "Prompts and row values are redacted. Do not paste PHI back into this file.",
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


def iter_data_files(roots: list[Path]) -> list[Path]:
    found: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [
                d
                for d in dirnames
                if d not in SKIP_DIR and not d.startswith(".") and not SKIP_NAME_HINT.search(d)
            ]
            for name in filenames:
                path = Path(dirpath) / name
                if path.suffix.lower() in DATA_EXT and not SKIP_NAME_HINT.search(str(path)):
                    found.append(path)
    return found


def scan_files(roots: list[Path], memory: Path, state: dict) -> int:
    changed = 0
    for path in iter_data_files(roots):
        try:
            digest = file_hash(path)
        except OSError:
            continue
        key = str(path)
        if state["files"].get(key) == digest:
            continue
        payload = infer_map(path)
        if payload:
            write_data_map(memory, path, payload)
            state["files"][key] = digest
            changed += 1
    return changed


def session_title(meta: dict) -> str:
    raw = str(meta.get("prompt") or meta.get("metadata", {}).get("title") or meta.get("session_id") or "session")
    return redact(raw, 100) or "session"


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
        raw_prompt = str(meta.get("prompt") or meta.get("metadata", {}).get("title") or "")
        if SKIP_NAME_HINT.search(raw_prompt):
            state["sessions"][sid] = {"status": "skipped-sensitive", "at": utc_now()}
            continue
        title = session_title(meta)
        model = redact(str(meta.get("model") or ""), 40)
        body = (
            f"Model: `{model}`\n\n"
            f"Cline status: `{status or 'ended'}`\n\n"
            f"Ask (redacted): {title}\n\n"
            "Talon recorded this so the same failed path is visible next time, "
            "and so a working path can be reused. Read `memory/WHAT_WORKED.md` and "
            "`memory/FAILED.md` before repeating an approach."
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
    parser.add_argument("--workspace", default="")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=int, default=20)
    args = parser.parse_args()

    kit = Path(args.kit).resolve()
    workspace = Path(args.workspace).resolve() if args.workspace else kit
    memory = kit / "memory"
    cline_home = kit / "ide-data" / "cline-home"
    state_path = memory / "state.json"
    pid_path = kit / "logs" / "talon-learn.pid"
    pid_path.parent.mkdir(parents=True, exist_ok=True)

    roots = [kit / "data", kit / "examples"]
    if workspace != kit:
        roots.append(workspace)
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
