"""
Module: rebrand_talon_to_orion.py

Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-26
Last Modified: 2026-10-26
AI Assistant: Talon

Description:
 One-shot rebrand of the Local_AI kit from Talon / LocalCoder to Orion.
 Run from the kit root after generating branding assets. Safe to re-run.

Usage:
 python tools\\rebrand_talon_to_orion.py
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {
    ".git",
    ".venv",
    "ide-data",
    "ide-extensions",
    "__pycache__",
    "dist",
    "logs",
    "node_modules",
}
TEXT_SUFFIXES = {
    ".md",
    ".txt",
    ".ps1",
    ".cmd",
    ".bat",
    ".vbs",
    ".py",
    ".json",
    ".html",
    ".js",
    ".iss",
    ".toml",
    ".svg",
    ".gitignore",
    ".clinerules",
    "",
}
# Ordered replacements (longest / most specific first).
REPLACEMENTS: list[tuple[str, str]] = [
    ("LocalCoder-blocked", "orion-blocked"),
    ("localcoder-blocked", "orion-blocked"),
    ("__LOCALCODER_PYTHON__", "__ORION_PYTHON__"),
    ("__LOCALCODER_SQLITE__", "__ORION_SQLITE__"),
    ("LOCALCODER_PYTHON", "ORION_PYTHON"),
    ("LOCALCODER_SQLITE", "ORION_SQLITE"),
    ("Find-TalonPython", "Find-OrionPython"),
    ("Install-TalonPythonIfMissing", "Install-OrionPythonIfMissing"),
    ("Refresh-TalonPath", "Refresh-OrionPath"),
    ("TALON_KIT", "ORION_KIT"),
    ("Talon.code-workspace", "Orion.code-workspace"),
    ("talon.talon-guard-1.3.0", "orion.orion-guard-1.3.0"),
    ("talon-guard-1.3.0.vsix", "orion-guard-1.3.0.vsix"),
    ("talon-guard", "orion-guard"),
    ("Talon Guard", "Orion Guard"),
    ("Open-Talon.cmd", "Open-Orion.cmd"),
    ("Start Talon.cmd", "Start Orion.cmd"),
    ("Start Local Coder.cmd", "Start Orion.cmd"),
    ("Backup-TalonMemory.ps1", "Backup-OrionMemory.ps1"),
    ("Connect-Talon.ps1", "Connect-Orion.ps1"),
    ("Launch-LocalCoder.vbs", "Launch-Orion.vbs"),
    ("Sign-LocalCoder.ps1", "Sign-Orion.ps1"),
    ("Uninstall-LocalCoder.ps1", "Uninstall-Orion.ps1"),
    ("Update-LocalCoder.ps1", "Update-Orion.ps1"),
    ("LocalCoder.iss", "Orion.iss"),
    ("talon_learn.py", "orion_learn.py"),
    ("verify_talon_ui.py", "verify_orion_ui.py"),
    ("learn\\talon_learn", "learn\\orion_learn"),
    ("learn/talon_learn", "learn/orion_learn"),
    ("C:\\\\Talon", "C:\\\\Orion"),
    ("C:\\Talon", "C:\\Orion"),
    ("cd C:\\\\Talon", "cd C:\\\\Orion"),
    ("Programs\\Talon", "Programs\\Orion"),
    ("Programs/Talon", "Programs/Orion"),
    ("Talon Connect", "Orion Connect"),
    ("Talon Backup Memory", "Orion Backup Memory"),
    ("Talon — Local AI", "Orion — Local AI"),
    ("Talon - Local AI", "Orion - Local AI"),
    ("Talon: ", "Orion: "),
    ('"publisher": "talon"', '"publisher": "orion"'),
    ("Publisher=\"talon\"", 'Publisher="orion"'),
    ("Id=\"talon-guard\"", 'Id="orion-guard"'),
    ("command\": \"talon.", 'command": "orion.'),
    ("\"talon.", '"orion.'),
    ("talon.addFolder", "orion.addFolder"),
    ("talon.reopenWorkspace", "orion.reopenWorkspace"),
    ("talon.warnOpenFolder", "orion.warnOpenFolder"),
    ("talon.starterIngestPath", "orion.starterIngestPath"),
    ("talon.starterMapFolder", "orion.starterMapFolder"),
    ("talon.starterListSql", "orion.starterListSql"),
    ("talon.starterMemory", "orion.starterMemory"),
    ("LocalCoder ", "Orion "),
    ("LocalCoder", "Orion"),
    ("LOCALCODER", "ORION"),
    ("localcoder", "orion"),
    ("Talon", "Orion"),
    ("TALON", "ORION"),
    # Bare talon token last (extension ids / paths already handled).
    ("talon", "orion"),
]

FILE_RENAMES: list[tuple[str, str]] = [
    ("Open-Talon.cmd", "Open-Orion.cmd"),
    ("Start Talon.cmd", "Start Orion.cmd"),
    ("Backup-TalonMemory.ps1", "Backup-OrionMemory.ps1"),
    ("Connect-Talon.ps1", "Connect-Orion.ps1"),
    ("Launch-LocalCoder.vbs", "Launch-Orion.vbs"),
    ("Sign-LocalCoder.ps1", "Sign-Orion.ps1"),
    ("Uninstall-LocalCoder.ps1", "Uninstall-Orion.ps1"),
    ("Update-LocalCoder.ps1", "Update-Orion.ps1"),
    ("pack/LocalCoder.iss", "pack/Orion.iss"),
    ("learn/talon_learn.py", "learn/orion_learn.py"),
    ("learn/verify_talon_ui.py", "learn/verify_orion_ui.py"),
    ("extensions/talon-guard-1.3.0.vsix", "extensions/orion-guard-1.3.0.vsix"),
]

DELETE_AFTER = [
    "Start Local Coder.cmd",
]

DIR_RENAMES: list[tuple[str, str]] = [
    ("extensions/talon.talon-guard-1.3.0", "extensions/orion.orion-guard-1.3.0"),
]


def is_text(path: Path) -> bool:
    if path.name in {".gitignore", ".clinerules", "VERSION"}:
        return True
    return path.suffix.lower() in TEXT_SUFFIXES


def transform_text(text: str) -> str:
    out = text
    for old, new in REPLACEMENTS:
        out = out.replace(old, new)
    # Fix accidental double-rebrand if script re-run.
    out = out.replace("OrionOrion", "Orion")
    out = out.replace("orionorion", "orion")
    out = out.replace("ORIONORION", "ORION")
    return out


def walk_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        # Do not rewrite this script mid-run into nonsense.
        if path.name == "rebrand_talon_to_orion.py":
            continue
        files.append(path)
    return files


def rename_paths() -> None:
    for old_rel, new_rel in DIR_RENAMES:
        old = KIT / old_rel
        new = KIT / new_rel
        if old.exists() and not new.exists():
            new.parent.mkdir(parents=True, exist_ok=True)
            old.rename(new)
            print(f"dir {old_rel} -> {new_rel}")
        elif new.exists():
            print(f"dir ok {new_rel}")
    for old_rel, new_rel in FILE_RENAMES:
        old = KIT / old_rel
        new = KIT / new_rel
        if old.exists() and not new.exists():
            new.parent.mkdir(parents=True, exist_ok=True)
            old.rename(new)
            print(f"file {old_rel} -> {new_rel}")
        elif new.exists():
            print(f"file ok {new_rel}")
    for rel in DELETE_AFTER:
        path = KIT / rel
        if path.exists():
            path.unlink()
            print(f"deleted {rel}")


def rewrite_contents() -> int:
    changed = 0
    for path in walk_files(KIT):
        if not is_text(path):
            continue
        raw = path.read_bytes()
        # Skip binaries mislabeled.
        if b"\x00" in raw[:2048]:
            continue
        for enc in ("utf-8-sig", "utf-8", "cp1252"):
            try:
                text = raw.decode(enc)
                break
            except UnicodeDecodeError:
                text = None
        else:
            continue
        new_text = transform_text(text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8", newline="\n")
            changed += 1
            print(f"edit {path.relative_to(KIT)}")
    return changed


def write_svgs() -> None:
    code_icon = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#0B1220"/>
  <rect x="6" y="6" width="52" height="52" rx="11" fill="none" stroke="#E8C547" stroke-width="1.6"/>
  <path fill="#E8C547" d="M32 12 L34.2 26.2 L48 28 L34.2 29.8 L32 44 L29.8 29.8 L16 28 L29.8 26.2 Z"/>
  <circle cx="32" cy="28" r="3.2" fill="#2EC4B6"/>
  <circle cx="22" cy="40" r="1.4" fill="#2EC4B6"/>
  <circle cx="42" cy="40" r="1.4" fill="#2EC4B6"/>
  <rect x="20" y="48" width="24" height="3.2" rx="1.4" fill="#E8C547"/>
</svg>
"""
    letter_dark = """<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <path fill="#E8C547" fill-opacity=".55" d="M20 8 L21.2 16.8 L30 18 L21.2 19.2 L20 28 L18.8 19.2 L10 18 L18.8 16.8 Z"/>
  <circle cx="20" cy="18" r="1.8" fill="#2EC4B6" fill-opacity=".7"/>
  <rect x="12" y="30" width="16" height="2.2" rx="1" fill="#B2B2B2" fill-opacity=".32"/>
</svg>
"""
    letter_light = """<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <path fill="#0B1220" fill-opacity=".28" d="M20 8 L21.2 16.8 L30 18 L21.2 19.2 L20 28 L18.8 19.2 L10 18 L18.8 16.8 Z"/>
  <circle cx="20" cy="18" r="1.8" fill="#2EC4B6" fill-opacity=".55"/>
  <rect x="12" y="30" width="16" height="2.2" rx="1" fill="#0B1220" fill-opacity=".22"/>
</svg>
"""
    brand = KIT / "branding"
    (brand / "code-icon.svg").write_text(code_icon, encoding="utf-8")
    (brand / "letterpress-dark.svg").write_text(letter_dark, encoding="utf-8")
    (brand / "letterpress-light.svg").write_text(letter_light, encoding="utf-8")
    print("wrote branding SVGs")


def bump_version() -> None:
    ver = KIT / "VERSION"
    ver.write_text("1.5.0\n", encoding="utf-8")
    print("VERSION -> 1.5.0")


def main() -> int:
    print(f"kit={KIT}")
    write_svgs()
    rename_paths()
    n = rewrite_contents()
    bump_version()
    # Remaining Talon / LocalCoder scan
    leftovers = []
    for path in walk_files(KIT):
        if not is_text(path):
            continue
        if path.name == "rebrand_talon_to_orion.py":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if re.search(r"Talon|LocalCoder|talon-guard|TALON_KIT", text):
            leftovers.append(str(path.relative_to(KIT)))
    print(f"content files changed: {n}")
    if leftovers:
        print("leftover brand tokens:")
        for item in leftovers[:40]:
            print(f"  {item}")
        if len(leftovers) > 40:
            print(f"  ... +{len(leftovers) - 40} more")
        return 1
    print("rebrand complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
