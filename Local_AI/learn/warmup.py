"""Load the preferred Ollama model so the first Cline reply is not a cold start."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
OLLAMA = "http://127.0.0.1:11434"
FALLBACK = (
    "qwen3-coder:30b",
    "qwen3-coder:30b-a3b-q4_K_M",
    "qwen3:30b-a3b",
    "qwen2.5-coder:14b",
    "qwen2.5-coder:7b",
)


def _read_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    return data if isinstance(data, dict) else {}


def preferred() -> list[str]:
    names: list[str] = []
    for path in (
        KIT / "ide-data" / "team-overrides.json",
        KIT / "templates" / "team-defaults.json",
    ):
        cfg = _read_json(path)
        models = cfg.get("preferredModels")
        if isinstance(models, list):
            names.extend(str(m) for m in models if m)
    names.extend(FALLBACK)
    seen = set()
    out = []
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        out.append(name)
    return out


def installed() -> list[str]:
    try:
        with urllib.request.urlopen(f"{OLLAMA}/api/tags", timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return []
    return [str(item.get("name")) for item in (data.get("models") or []) if item.get("name")]


def pick() -> str | None:
    have = set(installed())
    if not have:
        return None
    for name in preferred():
        if name in have:
            return name
    return next(iter(have))


def main() -> int:
    model = pick()
    if not model:
        print("warmup=skip (ollama down or no model)")
        return 0
    body = json.dumps(
        {
            "model": model,
            "prompt": ".",
            "stream": False,
            "keep_alive": "60m",
            "options": {"num_predict": 1},
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            resp.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"warmup=fail {exc}")
        return 0
    print(f"warmup={model}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
