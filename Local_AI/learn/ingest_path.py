"""
Module: ingest_path.py

Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-09-21
Last Modified: 2026-09-21
AI Assistant: Talon

Description:
  Connect a local folder or file the user named, map CSV/Excel/SQLite/SQL/JSON
  for later sessions, and keep the folder on the learner watch list.

Usage:
  .venv\\Scripts\\python.exe learn\\ingest_path.py --path "D:\\Extracts"
  .venv\\Scripts\\python.exe learn\\ingest_path.py --kit C:\\Talon --path "D:\\Extracts\\file.csv"

License: UNLICENSED
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

LEARN = Path(__file__).resolve().parent
if str(LEARN) not in sys.path:
    sys.path.insert(0, str(LEARN))

from talon_learn import DATA_EXT, cycle, utc_now, write_index  # noqa: E402


def kit_from_env() -> Path:
    raw = os.environ.get("TALON_KIT") or ""
    if raw:
        candidate = Path(raw)
        if candidate.is_dir():
            return candidate.resolve()
    return LEARN.parent.resolve()


def normalize_user_path(raw: str) -> Path:
    text = (raw or "").strip().strip('"').strip("'")
    text = text.replace("`", "")
    if text.lower().startswith("file:"):
        parsed = urlparse(text)
        text = unquote(parsed.path or "")
        if os.name == "nt" and text.startswith("/") and len(text) >= 3 and text[2] == ":":
            text = text[1:]
        elif os.name == "nt" and text.startswith("/") and len(text) >= 2 and text[1] == ":":
            text = text[1:]
    text = unquote(text).replace("/", "\\") if os.name == "nt" else unquote(text)
    return Path(text)


def is_under(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except (OSError, ValueError):
        return False


def guess_role(folder: Path) -> str:
    blob = str(folder).lower()
    if any(token in blob for token in ("phi", "extract", "csv", "chart", "mrn")):
        return "phi"
    try:
        for dirpath, dirnames, filenames in os.walk(folder):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")][:20]
            for name in filenames[:80]:
                if Path(name).suffix.lower() in DATA_EXT:
                    return "phi"
            break
    except OSError:
        pass
    return "project"


def load_sources(path: Path) -> dict:
    if not path.is_file():
        return {"folders": [], "databases": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {"folders": [], "databases": []}
    if not isinstance(data, dict):
        return {"folders": [], "databases": []}
    data.setdefault("folders", [])
    data.setdefault("databases", [])
    if not isinstance(data["folders"], list):
        data["folders"] = []
    return data


def connect_folder(sources: dict, folder: Path, role: str) -> bool:
    want = str(folder.resolve())
    want_key = want.lower()
    for item in sources.get("folders") or []:
        if not isinstance(item, dict):
            continue
        have = str(item.get("path") or "")
        if have.lower() == want_key:
            return False
    leaf = folder.name
    label = f"PHI: {leaf}" if role == "phi" else f"Project: {leaf}" if role == "project" else leaf
    sources.setdefault("folders", []).append({"name": label, "path": want, "role": role})
    return True


def maps_for_root(memory: Path, folder: Path) -> list[str]:
    dest = memory / "data-maps"
    if not dest.is_dir():
        return []
    needles = {str(folder).replace("/", "\\").lower(), str(folder).replace("\\", "/").lower()}
    found: list[str] = []
    for path in sorted(dest.glob("*.md")):
        try:
            text = path.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            continue
        if any(n in text for n in needles if n):
            found.append(path.stem)
    return found


def apply_sources(kit: Path) -> None:
    script = LEARN / "apply_sources.py"
    if not script.is_file():
        return
    py = kit / ".venv" / "Scripts" / "python.exe"
    exe = str(py) if py.is_file() else sys.executable
    subprocess.run([exe, str(script), str(kit)], check=False, cwd=str(kit))


def main() -> int:
    parser = argparse.ArgumentParser(description="Connect a local path and map it into Talon memory")
    parser.add_argument("--kit", default="")
    parser.add_argument("--path", required=True, help="Local folder or file the user named")
    parser.add_argument("--role", default="", choices=["", "phi", "project", "other"])
    parser.add_argument("--skip-apply", action="store_true", help="Do not rewrite the workspace file")
    args = parser.parse_args()

    kit = Path(args.kit).resolve() if args.kit else kit_from_env()
    target = normalize_user_path(args.path)
    if not target.exists():
        print(f"Path not found: {target}", flush=True)
        print("Give a folder or file that exists on this PC.", flush=True)
        return 1

    folder = target if target.is_dir() else target.parent
    try:
        folder = folder.resolve()
    except OSError:
        pass

    print(f"{utc_now()} ingest {folder}", flush=True)
    print("Large CSV folders can take a few minutes on the first map.", flush=True)

    skip_connect = is_under(folder, kit) or folder == kit
    sources_path = kit / "ide-data" / "sources.json"
    connected_new = False
    if not skip_connect:
        sources_path.parent.mkdir(parents=True, exist_ok=True)
        sources = load_sources(sources_path)
        role = args.role or guess_role(folder)
        connected_new = connect_folder(sources, folder, role)
        sources_path.write_text(json.dumps(sources, indent=2), encoding="utf-8")
        if connected_new:
            print(f"Connected ({role}): {folder}", flush=True)
        else:
            print(f"Already connected: {folder}", flush=True)
        if not args.skip_apply:
            apply_sources(kit)
    else:
        print(f"Path is inside the Talon kit. Mapping only: {folder}", flush=True)

    memory = kit / "memory"
    cline_home = kit / "ide-data" / "cline-home"
    state_path = memory / "state.json"
    n_files, n_sess = cycle([folder], memory, cline_home, state_path)
    write_index(memory)
    names = maps_for_root(memory, folder)
    print(f"Mapped {n_files} new or changed file(s). Session lessons: {n_sess}.", flush=True)
    if names:
        print("Data maps:", flush=True)
        for name in names:
            print(f"  - {name}", flush=True)
    else:
        print("No CSV/TSV/Excel/SQLite/SQL/JSON/Parquet files found under that path.", flush=True)
    print(f"Future sessions: read {memory / 'INDEX.md'} before repeating work.", flush=True)
    print("Stay on this PC. Do not copy memory\\ off this machine.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
