"""Read Talon profile state after launch. Used for Check 1 / Check 2."""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path


def read_key(db: Path, key: str) -> str:
    if not db.is_file():
        return ""
    con = sqlite3.connect(str(db))
    try:
        row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
        return row[0] if row and row[0] else ""
    finally:
        con.close()


def main() -> int:
    kit = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
    ide = kit / "ide-data"
    report = {
        "guard_status": None,
        "release_notes_last_version": read_key(ide / "User" / "globalStorage" / "state.vscdb", "releaseNotes/lastVersion"),
        "guard_registered": False,
        "workspace_is_code_workspace": False,
        "explorer_expanded": None,
        "editor_memento": "",
        "ok": False,
        "fail": [],
    }
    status_path = ide / "guard-status.json"
    if status_path.is_file():
        try:
            report["guard_status"] = json.loads(status_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            report["fail"].append("guard-status.json is not valid JSON")
    else:
        report["fail"].append("guard-status.json missing (extension did not activate)")

    ext_index = kit / "ide-extensions" / "extensions.json"
    try:
        entries = json.loads(ext_index.read_text(encoding="utf-8"))
        report["guard_registered"] = any(
            str((item.get("identifier") or {}).get("id", "")).lower() == "talon.talon-guard"
            for item in entries
            if isinstance(item, dict)
        )
    except (OSError, json.JSONDecodeError):
        report["fail"].append("extensions.json missing or invalid")
    if not report["guard_registered"]:
        report["fail"].append("talon.talon-guard is not registered")

    ws_json = None
    for folder in (ide / "User" / "workspaceStorage").glob("*/workspace.json"):
        try:
            data = json.loads(folder.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if "workspace" in data and "Talon.code-workspace" in str(data.get("workspace")):
            ws_json = folder
            report["workspace_is_code_workspace"] = True
            db = folder.parent / "state.vscdb"
            report["explorer_expanded"] = read_key(db, "workbench.explorer.treeViewState")
            report["editor_memento"] = read_key(db, "memento/workbench.parts.editor")
            break
    if not report["workspace_is_code_workspace"]:
        report["fail"].append("active storage is not Talon.code-workspace")

    expanded = report["explorer_expanded"] or ""
    kit_uri = kit.resolve().as_uri()
    if f"{kit_uri}::{kit_uri}" in expanded:
        report["fail"].append("Talon root is still in explorer expanded list")

    mem = report["editor_memento"] or ""
    if "USAGE.md" in mem:
        report["fail"].append("USAGE.md is still a restored editor tab")
    if "releaseNotes" in mem or "Release Notes" in mem:
        report["fail"].append("Release Notes is still in editor memento")

    if report["release_notes_last_version"] in {"", "99.99.99"}:
        report["fail"].append(
            f"releaseNotes/lastVersion is {report['release_notes_last_version']!r} (must be the real VSCodium version)"
        )

    report["ok"] = len(report["fail"]) == 0
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
