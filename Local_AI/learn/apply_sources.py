"""Build Talon workspace + SQLTools connections from ide-data/sources.json."""

from __future__ import annotations

import json
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

    workspace = {
        "folders": folders,
        "settings": {
            "window.title": "Talon — Local AI — ${rootName}${separator}${activeEditorShort}"
        },
    }
    ws_path = ide / "Talon.code-workspace"
    ws_path.write_text(json.dumps(workspace, indent=2), encoding="utf-8")

    settings_path = ide / "User" / "settings.json"
    settings = load_json(settings_path, {})
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
