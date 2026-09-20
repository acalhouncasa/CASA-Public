"""Seed Cline to Ollama-only, telemetry off. Never writes cloud API keys."""

from __future__ import annotations

import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
from pathlib import Path

PREFERRED_MODELS_FALLBACK = (
    "qwen3-coder:30b",
    "qwen3-coder:30b-a3b-q4_K_M",
    "qwen3:30b-a3b",
    "qwen2.5-coder:14b",
    "qwen2.5-coder:7b",
    "codellama:latest",
    "llama3:latest",
)

KIT_ROOT = Path(__file__).resolve().parent
OLLAMA = "http://127.0.0.1:11434"
CTX = "16384"


def _read_json_file(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    return loaded if isinstance(loaded, dict) else {}


def team_config() -> dict:
    cfg = {
        "preferredModels": list(PREFERRED_MODELS_FALLBACK),
        "autoApproveCommands": True,
    }
    cfg.update(_read_json_file(KIT_ROOT / "templates" / "team-defaults.json"))
    cfg.update(_read_json_file(KIT_ROOT / "ide-data" / "team-overrides.json"))
    return cfg


def preferred_models() -> tuple[str, ...]:
    models = team_config().get("preferredModels")
    if isinstance(models, list) and models:
        return tuple(str(m) for m in models)
    return PREFERRED_MODELS_FALLBACK


def auto_approval() -> dict:
    allow_cmd = bool(team_config().get("autoApproveCommands", True))
    return {
        "version": 1,
        "enabled": True,
        "favorites": [],
        "maxRequests": 100,
        "actions": {
            "readFiles": True,
            "readFilesExternally": True,
            "editFiles": True,
            "editFilesExternally": True,
            "executeSafeCommands": allow_cmd,
            "executeAllCommands": allow_cmd,
            "useBrowser": False,
            "useMcp": False,
        },
        "enableNotifications": False,
    }

DISMISSED_BANNER_IDS = (
    "cline-pass-home-promo-v2",
    "cline-pass-settings-hint-v1",
    "cline-pass-settings-hint",
    "cline-pass-welcome-callout",
    "cline-pass-card",
    "cline-pass-limit-error",
)


def ollama_models() -> list[str]:
    try:
        with urllib.request.urlopen(f"{OLLAMA}/api/tags", timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return []
    names = []
    for item in data.get("models") or []:
        name = item.get("name")
        if name:
            names.append(name)
    return names


def pick_model(available: list[str]) -> str:
    have = set(available)
    preferred = preferred_models()
    for name in preferred:
        if name in have:
            return name
    return available[0] if available else preferred[0]


def cline_payload(model: str) -> dict:
    return {
        "planModeApiProvider": "ollama",
        "actModeApiProvider": "ollama",
        "ollamaBaseUrl": OLLAMA,
        "ollamaApiOptionsCtxNum": CTX,
        "planModeOllamaModelId": model,
        "actModeOllamaModelId": model,
        "telemetrySetting": "disabled",
        "openTelemetryEnabled": False,
        "optOutOfRemoteConfig": True,
        "mcpMarketplaceEnabled": False,
        "clineWebToolsEnabled": False,
        "customPrompt": "compact",
        "customInstructions": (
            "You are Talon, the on-device Local AI agent. Use only Ollama on 127.0.0.1. "
            "Prefer Python and SQL. Run code with this kit's .venv (pandas, numpy, "
            "SQLAlchemy, scikit-learn, Jupyter, ruff). Default DB is data/local.sqlite. "
            "Do not call cloud APIs, ClinePass, or web fetch. Do not pip-install OpenAI "
            "or other hosted-LLM SDKs. Working with PHI on this PC is expected: read it, "
            "map it, and keep extracts in data\\ and memory\\ on this disk. Never send PHI "
            "off the box. Starters live in .cline/workflows and the Command Palette "
            "(map this folder, list SQL tables, read memory index). Without being asked: "
            "read memory/INDEX.md, WHAT_WORKED.md, FAILED.md, and data-maps before "
            "repeating work; after each task write a data map (columns, types, useful "
            "example values) and a short lesson."
        ),
        "welcomeViewCompleted": True,
        "isNewUser": False,
        "shouldShowAnnouncement": False,
        "showFeatureTips": False,
        "webSearchEnabled": False,
        "lastDismissedInfoBannerVersion": 999,
        "lastDismissedModelBannerVersion": 999,
        "lastDismissedCliBannerVersion": 999,
        "dismissedBanners": [
            {"bannerId": banner_id, "dismissedAt": 1} for banner_id in DISMISSED_BANNER_IDS
        ],
        "autoApprovalSettings": auto_approval(),
        "vscodeTerminalExecutionMode": "backgroundExec",
        "terminalReuseEnabled": True,
        "mode": "act",
        "yoloModeToggled": False,
        "autoApproveAllToggled": False,
        "subagentsEnabled": False,
        "nativeToolCallEnabled": True,
        "browserSettings": {
            "viewport": {"width": 900, "height": 600},
            "remoteBrowserEnabled": False,
            "chromeExecutablePath": "",
            "disableToolUse": True,
        },
    }


CLINE_CONTAINER = "workbench.view.extension.claude-dev-ActivityBar"
AUXILIARY_BAR = 2  # ViewContainerLocation.AuxiliaryBar
HIDDEN_ACTIVITY_BAR = (
    "workbench.view.scm",
)


DISABLED_EXTENSIONS = (
    "github.copilot",
    "github.copilot-chat",
    "github.vscode-pull-request-github",
    "github.vscode-github-actions",
    "github.remotehub",
    "vscode.git",
    "vscode.git-base",
    "vscode.github",
    "vscode.github-authentication",
    "vscode.microsoft-authentication",
    "ms-python.vscode-python-envs",
    "ms-vscode.remote-repositories",
    "ms-vscode.remote-server",
    "ms-vscode.remote-explorer",
    "ms-vscode.azure-repos",
)


def merge_sqlite(db_path: Path, payload: dict) -> bool:
    if not db_path.is_file():
        return False
    con = sqlite3.connect(str(db_path))
    try:
        rows = con.execute("SELECT key, value FROM ItemTable").fetchall()
        changed = False
        for key, value in rows:
            if "saoudrizwan.claude-dev" not in str(key):
                continue
            try:
                current = json.loads(value) if isinstance(value, str) else json.loads(value.decode("utf-8"))
            except (json.JSONDecodeError, AttributeError, UnicodeDecodeError):
                continue
            if not isinstance(current, dict):
                continue
            current.update(payload)
            con.execute(
                "UPDATE ItemTable SET value = ? WHERE key = ?",
                (json.dumps(current), key),
            )
            changed = True
        if not changed:
            # Fresh profile: store the whole bag under the extension id.
            con.execute(
                "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
                ("saoudrizwan.claude-dev", json.dumps(payload)),
            )
        con.commit()
        return True
    finally:
        con.close()


def write_sidecar(storage_dir: Path, payload: dict) -> None:
    storage_dir.mkdir(parents=True, exist_ok=True)
    path = storage_dir / "local-ollama.json"
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _union_dismissed_banners(path: Path) -> None:
    current: dict = {}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                current = loaded
        except (json.JSONDecodeError, OSError):
            current = {}
    existing = current.get("dismissedBanners")
    have = set()
    merged: list = []
    if isinstance(existing, list):
        for item in existing:
            if isinstance(item, dict) and item.get("bannerId"):
                have.add(str(item["bannerId"]))
                merged.append(item)
    for banner_id in DISMISSED_BANNER_IDS:
        if banner_id not in have:
            merged.append({"bannerId": banner_id, "dismissedAt": 1})
    current["dismissedBanners"] = merged
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(current, indent=2), encoding="utf-8")


def _merge_json_file(path: Path, updates: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    current: dict = {}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                current = loaded
        except (json.JSONDecodeError, OSError):
            current = {}
    current.update(updates)
    path.write_text(json.dumps(current, indent=2), encoding="utf-8")


def write_cline_home(ide_data: Path, payload: dict, model: str) -> None:
    """Cline's next bundle ignores VS Code sqlite and reads ~/.cline (or CLINE_DIR)."""
    from datetime import datetime, timezone

    isolated = ide_data / "cline-home"
    homes = [isolated]
    default_home = Path.home() / ".cline"
    default_state = default_home / "data" / "globalState.json"
    if default_state.is_file():
        try:
            raw = default_state.read_text(encoding="utf-8")
        except OSError:
            raw = ""
        if "Local AI" in raw.replace("/", "\\") or "localcoder" in raw.lower():
            homes.append(default_home)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state_updates = {
        **payload,
        "welcomeViewCompleted": True,
        "isNewUser": False,
        "telemetrySetting": "disabled",
        "optOutOfRemoteConfig": True,
        "clineWebToolsEnabled": False,
        "mcpMarketplaceEnabled": False,
        "webSearchEnabled": False,
        "showFeatureTips": False,
        "shouldShowAnnouncement": False,
        "lastDismissedInfoBannerVersion": 999,
        "lastDismissedModelBannerVersion": 999,
        "lastDismissedCliBannerVersion": 999,
    }
    providers = {
        "version": 1,
        "modes": {},
        "lastUsedProvider": "ollama",
        "providers": {
            "ollama": {
                "settings": {
                    "provider": "ollama",
                    "model": model,
                    "baseUrl": OLLAMA,
                },
                "updatedAt": now,
                "tokenSource": "localcoder",
            }
        },
    }
    global_settings = {
        "autoUpdateEnabled": False,
        "telemetryOptOut": True,
        "mcpMarketplaceEnabled": False,
        "clineWebToolsEnabled": False,
        "webSearchEnabled": False,
        "showFeatureTips": False,
        "autoApprovalSettings": auto_approval(),
        "browserSettings": payload["browserSettings"],
        "telemetrySetting": "disabled",
        "optOutOfRemoteConfig": True,
        "planModeApiProvider": "ollama",
        "actModeApiProvider": "ollama",
        "ollamaBaseUrl": OLLAMA,
        "ollamaApiOptionsCtxNum": CTX,
        "planModeOllamaModelId": model,
        "actModeOllamaModelId": model,
        "mode": "act",
        "vscodeTerminalExecutionMode": "backgroundExec",
        "terminalReuseEnabled": True,
        "autoApprovalSettings": auto_approval(),
    }

    for home in homes:
        data = home / "data"
        state_path = data / "globalState.json"
        _merge_json_file(state_path, state_updates)
        _union_dismissed_banners(state_path)
        (data / "settings").mkdir(parents=True, exist_ok=True)
        (data / "settings" / "providers.json").write_text(
            json.dumps(providers, indent=2), encoding="utf-8"
        )
        _merge_json_file(data / "settings" / "global-settings.json", global_settings)
        mcp = data / "settings" / "cline_mcp_settings.json"
        mcp.write_text(json.dumps({"mcpServers": {}}, indent=2), encoding="utf-8")


def _json_dump(value: object) -> str:
    return json.dumps(value, separators=(",", ":"))


def _read_json(con: sqlite3.Connection, key: str, default):
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
    if not row or row[0] in (None, ""):
        return default
    raw = row[0] if isinstance(row[0], str) else row[0].decode("utf-8")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return default


def _put(con: sqlite3.Connection, key: str, value) -> None:
    if isinstance(value, bool):
        stored = "true" if value else "false"
    elif isinstance(value, (int, float)):
        stored = str(value)
    elif isinstance(value, str):
        stored = value
    else:
        stored = _json_dump(value)
    con.execute(
        "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
        (key, stored),
    )


def _cline_placeholder(ide_data: Path, existing: dict | None = None) -> dict:
    if isinstance(existing, dict) and existing.get("id") == CLINE_CONTAINER:
        item = dict(existing)
        item["views"] = existing.get("views") or [{}]
        return item
    item: dict = {
        "id": CLINE_CONTAINER,
        "name": "Cline",
        "isBuiltin": False,
        "views": [{}],
    }
    matches = sorted((ide_data.parent / "ide-extensions").glob("saoudrizwan.claude-dev-*"))
    if matches:
        icon = matches[0] / "assets" / "icons" / "icon.svg"
        if icon.is_file():
            item["iconUrl"] = {
                "$mid": 1,
                "path": "/" + str(icon).replace("\\", "/"),
                "scheme": "file",
            }
    return item


def vscodium_version() -> str:
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "VSCodium" / "resources" / "app" / "package.json",
        Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "VSCodium" / "resources" / "app" / "package.json",
    ]
    for path in candidates:
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        version = data.get("version")
        if version:
            return str(version)
    return "1.135.06055"


def apply_agent_layout(ide_data: Path) -> None:
    """Put Cline on the right (auxiliary) bar and keep it open."""
    global_db = ide_data / "User" / "globalStorage" / "state.vscdb"
    if global_db.is_file():
        con = sqlite3.connect(str(global_db))
        try:
            custom = _read_json(con, "views.customizations", {})
            if not isinstance(custom, dict):
                custom = {}
            locations = custom.get("viewContainerLocations")
            if not isinstance(locations, dict):
                locations = {}
            locations[CLINE_CONTAINER] = AUXILIARY_BAR
            custom["viewContainerLocations"] = locations
            custom.setdefault("viewLocations", {})
            custom.setdefault("viewContainerBadgeEnablementStates", {})
            _put(con, "views.customizations", custom)

            pinned = _read_json(con, "workbench.auxiliarybar.pinnedPanels", [])
            if not isinstance(pinned, list):
                pinned = []
            pinned = [p for p in pinned if isinstance(p, dict) and p.get("id") != CLINE_CONTAINER]
            pinned.insert(
                0,
                {"id": CLINE_CONTAINER, "pinned": True, "visible": True, "order": 0},
            )
            for item in pinned:
                if item.get("id") == "workbench.panel.chat":
                    item["visible"] = False
            _put(con, "workbench.auxiliarybar.pinnedPanels", pinned)

            placeholders = _read_json(con, "workbench.auxiliarybar.placeholderPanels", [])
            if not isinstance(placeholders, list):
                placeholders = []
            activity_ph = _read_json(con, "workbench.activity.placeholderViewlets", [])
            existing_ph = None
            if isinstance(activity_ph, list):
                for item in activity_ph:
                    if isinstance(item, dict) and item.get("id") == CLINE_CONTAINER:
                        existing_ph = item
                        break
            aux_ids = {p.get("id") for p in placeholders if isinstance(p, dict)}
            if CLINE_CONTAINER not in aux_ids:
                placeholders.insert(0, _cline_placeholder(ide_data, existing_ph))
            _put(con, "workbench.auxiliarybar.placeholderPanels", placeholders)

            activity_pinned = _read_json(con, "workbench.activity.pinnedViewlets2", [])
            if isinstance(activity_pinned, list):
                activity_pinned = [
                    p
                    for p in activity_pinned
                    if not (isinstance(p, dict) and p.get("id") == CLINE_CONTAINER)
                ]
                seen = set()
                for item in activity_pinned:
                    if not isinstance(item, dict):
                        continue
                    vid = item.get("id")
                    seen.add(vid)
                    if vid in HIDDEN_ACTIVITY_BAR:
                        item["pinned"] = False
                        item["visible"] = False
                for vid in HIDDEN_ACTIVITY_BAR:
                    if vid not in seen:
                        activity_pinned.append(
                            {"id": vid, "pinned": False, "visible": False, "order": 2}
                        )
                _put(con, "workbench.activity.pinnedViewlets2", activity_pinned)
            _put(con, "workbench.sidebar.activeviewletid", "workbench.view.explorer")
            if isinstance(activity_ph, list):
                activity_ph = [
                    p
                    for p in activity_ph
                    if not (isinstance(p, dict) and p.get("id") == CLINE_CONTAINER)
                ]
                _put(con, "workbench.activity.placeholderViewlets", activity_ph)

            # Must equal the installed VSCodium version. A fake version
            # (e.g. 99.99.99) makes Release Notes open on every launch.
            _put(con, "releaseNotes/lastVersion", vscodium_version())
            _put(con, "workbench.startupEditor", "none")
            _put(con, "workbench.auxiliarybar.activepanelid", CLINE_CONTAINER)
            _put(con, "workbench.auxiliaryBar.empty", False)
            size = _read_json(con, "workbench.auxiliaryBar.size", 420)
            try:
                if int(size) < 360:
                    size = 420
            except (TypeError, ValueError):
                size = 420
            _put(con, "workbench.auxiliaryBar.size", int(size) if str(size).isdigit() else 420)
            con.commit()
        finally:
            con.close()

    ws_root = ide_data / "User" / "workspaceStorage"
    if not ws_root.is_dir():
        return
    for db_path in ws_root.glob("*/state.vscdb"):
        con = sqlite3.connect(str(db_path))
        try:
            _put(con, "workbench.auxiliaryBar.hidden", False)
            _put(con, "workbench.sidebar.activeviewletid", "workbench.view.explorer")
            state = _read_json(con, "workbench.auxiliarybar.viewContainersWorkspaceState", [])
            if not isinstance(state, list):
                state = []
            state = [s for s in state if isinstance(s, dict) and s.get("id") != CLINE_CONTAINER]
            state.insert(0, {"id": CLINE_CONTAINER, "visible": True})
            for item in state:
                if item.get("id") == "workbench.panel.chat":
                    item["visible"] = False
            _put(con, "workbench.auxiliarybar.viewContainersWorkspaceState", state)
            con.commit()
        finally:
            con.close()


def disable_cloud_extensions(db_path: Path) -> None:
    if not db_path.is_file():
        return
    wanted = [{"id": ext} for ext in DISABLED_EXTENSIONS]
    con = sqlite3.connect(str(db_path))
    try:
        row = con.execute(
            "SELECT value FROM ItemTable WHERE key = ?",
            ("extensionsIdentifiers/disabled",),
        ).fetchone()
        current: list = []
        if row and row[0]:
            try:
                current = json.loads(row[0])
            except json.JSONDecodeError:
                current = []
        if not isinstance(current, list):
            current = []
        have = {str(item.get("id")).lower() for item in current if isinstance(item, dict)}
        for item in wanted:
            if item["id"].lower() not in have:
                current.append(item)
        con.execute(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
            ("extensionsIdentifiers/disabled", json.dumps(current)),
        )
        con.commit()
    finally:
        con.close()


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: seed_cline.py <ide-data-dir>")
        return 2
    ide_data = Path(sys.argv[1])
    model = pick_model(ollama_models())
    payload = cline_payload(model)
    db = ide_data / "User" / "globalStorage" / "state.vscdb"
    storage = ide_data / "User" / "globalStorage" / "saoudrizwan.claude-dev"
    write_sidecar(storage, payload)
    write_cline_home(ide_data, payload, model)
    sqlite_ok = merge_sqlite(db, payload)
    disable_cloud_extensions(db)
    apply_agent_layout(ide_data)
    print(f"model={model}")
    print(f"sqlite={'updated' if sqlite_ok else 'missing (open Local Coder once, then re-run setup)'}")
    print(f"sidecar={storage / 'local-ollama.json'}")
    print(f"cline-home={ide_data / 'cline-home'}")
    print("layout=cline-right-ollama")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
