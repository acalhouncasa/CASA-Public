"""Build Talon workspace + SQLTools connections from ide-data/sources.json."""

from __future__ import annotations

import json
import os
import sqlite3
import sys
from pathlib import Path


def load_json(path: Path, default):
    if not path.is_file():
        return default
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return default
    return data if isinstance(data, type(default)) else default


def default_sources(kit: Path) -> dict:
    sqlite = kit / "data" / "local.sqlite"
    return {
        "folders": [],
        "databases": [
            {
                "name": "Local SQLite",
                "kind": "sqlite",
                "path": str(sqlite),
            }
        ],
    }


def ollama_up() -> bool:
    try:
        import urllib.request

        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=2) as resp:
            resp.read()
        return True
    except OSError:
        return False


def is_cloud_path(path: Path) -> bool:
    try:
        resolved = str(path.resolve()).lower()
    except OSError:
        resolved = str(path).lower()
    if "\\onedrive\\" in resolved or "\\onedrive -" in resolved:
        return True
    for key in ("OneDrive", "OneDriveConsumer", "OneDriveCommercial"):
        raw = os.environ.get(key)
        if not raw:
            continue
        try:
            root = str(Path(raw).resolve()).lower()
        except OSError:
            root = raw.lower()
        if resolved == root or resolved.startswith(root + "\\"):
            return True
    home = Path.home()
    for extra in ("Desktop", "Documents", "Downloads"):
        candidate = home / extra
        try:
            root = str(candidate.resolve()).lower()
        except OSError:
            continue
        if resolved == root or resolved.startswith(root + "\\"):
            return True
    return False


def file_uri(path: Path) -> dict:
    resolved = path.resolve()
    as_posix = resolved.as_posix()
    if not as_posix.startswith("/"):
        as_posix = "/" + as_posix
    return {
        "$mid": 1,
        "scheme": "file",
        "path": as_posix,
        "external": resolved.as_uri(),
        "fsPath": str(resolved),
    }


def tree_handle(folder: Path) -> str:
    uri = folder.resolve().as_uri()
    return f"{uri}::{uri}"


def collapse_kit_in_explorer(ide: Path, kit: Path, extra_folders: list[Path]) -> None:
    """Persist Explorer so the Talon root is collapsed before the window opens."""
    expanded = []
    for folder in extra_folders:
        try:
            expanded.append(tree_handle(folder))
        except OSError:
            continue
    state = {
        "focus": [],
        "selection": [],
        "expanded": expanded,
        "scrollTop": 0,
    }
    payload = json.dumps(state, separators=(",", ":"))
    ws_root = ide / "User" / "workspaceStorage"
    if not ws_root.is_dir():
        return
    for db_path in ws_root.glob("*/state.vscdb"):
        con = sqlite3.connect(str(db_path))
        try:
            con.execute(
                "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
                ("workbench.explorer.treeViewState", payload),
            )
            con.commit()
        finally:
            con.close()


def trust_folders(ide: Path, folders: list[Path]) -> None:
    db = ide / "User" / "globalStorage" / "state.vscdb"
    if not db.is_file():
        return
    con = sqlite3.connect(str(db))
    try:
        row = con.execute(
            "SELECT value FROM ItemTable WHERE key = ?",
            ("content.trust.model.key",),
        ).fetchone()
        model: dict = {"uriTrustInfo": []}
        if row and row[0]:
            try:
                loaded = json.loads(row[0])
                if isinstance(loaded, dict):
                    model = loaded
            except json.JSONDecodeError:
                pass
        info = model.get("uriTrustInfo")
        if not isinstance(info, list):
            info = []
        have: set[str] = set()
        for item in info:
            if not isinstance(item, dict):
                continue
            uri = item.get("uri") or {}
            if not isinstance(uri, dict):
                continue
            fs = str(uri.get("fsPath") or uri.get("path") or "").replace("/", "\\").lower()
            if fs:
                have.add(fs)
        for folder in folders:
            if is_cloud_path(folder):
                continue
            try:
                resolved = folder.resolve()
            except OSError:
                continue
            key = str(resolved).lower()
            if key in have:
                continue
            info.append({"uri": file_uri(resolved), "trusted": True})
            have.add(key)
        model["uriTrustInfo"] = info
        con.execute(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
            ("content.trust.model.key", json.dumps(model)),
        )
        con.commit()
    finally:
        con.close()


def sqltools_entry(db: dict) -> dict | None:
    kind = str(db.get("kind") or "").lower()
    name = str(db.get("name") or "Database")
    if kind == "sqlite":
        path = str(db.get("path") or "").replace("\\", "/")
        if not path:
            return None
        return {
            "name": name,
            "driver": "SQLite",
            "previewLimit": 100,
            "database": path,
        }
    if kind in {"mssql", "sqlserver"}:
        server = str(db.get("server") or "127.0.0.1")
        database = str(db.get("database") or "master")
        trusted = bool(db.get("trusted", True))
        entry = {
            "name": name,
            "driver": "MSSQL",
            "previewLimit": 100,
            "server": server,
            "port": int(db.get("port") or 1433),
            "database": database,
            "connectionTimeout": 15,
            "mssqlOptions": {
                "appName": "Talon",
                "encrypt": True,
                "trustServerCertificate": True,
            },
        }
        if trusted:
            entry["connectionMethod"] = "Connection String"
            entry["connectString"] = (
                f"Server={server};Database={database};Trusted_Connection=True;"
                "TrustServerCertificate=True;Application Name=Talon;"
            )
        else:
            entry["username"] = str(db.get("username") or "")
            if db.get("password"):
                entry["password"] = str(db["password"])
            else:
                entry["askForPassword"] = True
        return entry
    return None


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: apply_sources.py <kit-root>")
        return 2
    kit = Path(sys.argv[1]).resolve()
    ide = kit / "ide-data"
    sources_path = ide / "sources.json"
    sources = load_json(sources_path, {})
    if not sources:
        sources = default_sources(kit)
        ide.mkdir(parents=True, exist_ok=True)
        sources_path.write_text(json.dumps(sources, indent=2), encoding="utf-8")

    folders = []
    folders.append({"name": "Talon", "path": str(kit).replace("\\", "/")})
    seen = {str(kit).lower()}
    for item in sources.get("folders") or []:
        if not isinstance(item, dict):
            continue
        raw = str(item.get("path") or "")
        if not raw:
            continue
        path = str(Path(raw))
        if path.lower() in seen:
            continue
        seen.add(path.lower())
        folders.append({"name": str(item.get("name") or Path(path).name), "path": path.replace("\\", "/")})

    extra_count = max(0, len(folders) - 1)
    extra = "kit only" if extra_count == 0 else f"{extra_count} folder" + ("" if extra_count == 1 else "s")
    ollama = "Ollama up" if ollama_up() else "Ollama down"
    title = f"Talon — local — {extra} — {ollama} — ${{rootName}}${{separator}}${{activeEditorShort}}"
    workspace = {
        "folders": folders,
        "settings": {
            "window.title": title,
            "explorer.autoReveal": False,
        },
    }
    ws_path = ide / "Talon.code-workspace"
    ws_path.write_text(json.dumps(workspace, indent=2), encoding="utf-8")
    folder_paths = [Path(item["path"]) for item in folders]
    trust_folders(ide, folder_paths)
    extras = [p for p in folder_paths[1:] if p.exists()]
    collapse_kit_in_explorer(ide, kit, extras)

    settings_path = ide / "User" / "settings.json"
    settings = load_json(settings_path, {})
    settings["window.title"] = title
    connections = []
    auto = []
    for db in sources.get("databases") or []:
        if not isinstance(db, dict):
            continue
        entry = sqltools_entry(db)
        if not entry:
            continue
        connections.append(entry)
        auto.append(entry["name"])
    if connections:
        settings["sqltools.connections"] = connections
        settings["sqltools.autoConnectTo"] = auto[:2]
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(settings, indent=2), encoding="utf-8")

    print(f"workspace={ws_path}")
    print(f"folders={len(folders)}")
    print(f"databases={len(connections)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
