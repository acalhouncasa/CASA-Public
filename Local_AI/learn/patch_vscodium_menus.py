"""Turn off File → Open Folder in this VSCodium workbench.

Do not use when:!1 (boolean false). contextMatchesRules treats a falsy
when as "no clause" and shows the item. Use ContextKeyExpr.false()
(minified as C.false() or y.false() depending on the VSCodium build).

Exact minified identifiers change between VSCodium versions. Match the
File-menu group and command IDs, not the identifier names from one build.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import sys
from pathlib import Path

HIDE_COMMAND_IDS = (
    "workbench.action.files.openFolder",
    "workbench.action.files.openFolderViaWorkspace",
    "workbench.action.openWorkspace",
)

MENU_RES = (
    re.compile(
        r'(appendMenuItem\([^.]+\.MenubarFileMenu,\{group:"2_open",command:\{id:[^}]+?\},order:2,when:)'
        r'(?!C\.false\(\)|y\.false\(\))([^}]+)(\})'
    ),
    re.compile(
        r'(appendMenuItem\([^.]+\.MenubarFileMenu,\{group:"2_open",command:\{id:[^}]+?\},order:3,when:)'
        r'(?!C\.false\(\)|y\.false\(\))([^}]+)(\})'
    ),
)


def workbench_path() -> Path | None:
    local = os.environ.get("LOCALAPPDATA", "")
    candidates = [
        Path(local)
        / "Programs"
        / "VSCodium"
        / "resources"
        / "app"
        / "out"
        / "vs"
        / "workbench"
        / "workbench.desktop.main.js",
        Path(os.environ.get("ProgramFiles", r"C:\Program Files"))
        / "VSCodium"
        / "resources"
        / "app"
        / "out"
        / "vs"
        / "workbench"
        / "workbench.desktop.main.js",
    ]
    for path in candidates:
        if path.is_file():
            return path
    return None


def false_expr(text: str) -> str:
    if "C.false()" in text:
        return "C.false()"
    if "y.false()" in text:
        return "y.false()"
    if "C.true()" in text:
        return "C.false()"
    if "y.true()" in text:
        return "y.false()"
    raise RuntimeError("Could not find ContextKeyExpr.false() in this workbench")


def hide_command(text: str, command_id: str, never: str) -> str:
    marker = f'static{{this.ID="{command_id}"}}constructor(){{super({{'
    i = text.find(marker)
    if i < 0:
        raise RuntimeError(f"command {command_id} not found")
    window_start = i
    window = text[i : i + 800]
    key = "f1:!0,precondition:"
    k = window.find(key)
    if k < 0:
        if "f1:!1,precondition:C.false()" in window or "f1:!1,precondition:y.false()" in window:
            return text
        raise RuntimeError(f"command {command_id} f1/precondition not found")
    start = k + len(key)
    depth = 0
    j = start
    while j < len(window):
        ch = window[j]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch in ",}" and depth == 0:
            break
        j += 1
    patched = window[:k] + "f1:!1,precondition:" + never + window[j:]
    return text[:window_start] + patched + text[window_start + len(window) :]


def is_patched(text: str) -> bool:
    for command_id in HIDE_COMMAND_IDS:
        marker = f'static{{this.ID="{command_id}"}}'
        i = text.find(marker)
        if i < 0:
            return False
        window = text[i : i + 400]
        if "f1:!1" not in window or ("precondition:C.false()" not in window and "precondition:y.false()" not in window):
            return False
    open_folder_menus = 0
    for match in re.finditer(
        r'appendMenuItem\([^.]+\.MenubarFileMenu,\{group:"2_open",command:\{id:[^}]+?\},order:2,when:([^}]+)\}',
        text,
    ):
        open_folder_menus += 1
        if match.group(1) not in {"C.false()", "y.false()"}:
            return False
    return open_folder_menus >= 1


def workbench_checksum(path: Path) -> str:
    """Same hash VSCodium uses at runtime: SHA-256 of the file bytes, no LF rewrite."""
    digest = hashlib.sha256(path.read_bytes()).digest()
    return base64.b64encode(digest).decode("ascii").rstrip("=")


def update_product_checksum(workbench: Path) -> None:
    """Keep VSCodium from toasting 'installation appears to be corrupt'."""
    product = workbench.parents[3] / "product.json"
    if not product.is_file():
        print("product.json not found; checksum not updated")
        return
    text = product.read_text(encoding="utf-8")
    data = json.loads(text)
    checksums = data.get("checksums")
    if not isinstance(checksums, dict):
        print("product.json has no checksums")
        return
    key = "vs/workbench/workbench.desktop.main.js"
    old = checksums.get(key)
    new = workbench_checksum(workbench)
    if old == new:
        print("product.json checksum already matches")
        return
    if not old or f'"{old}"' not in text:
        print("could not find existing workbench checksum in product.json")
        return
    product.write_bytes(text.replace(f'"{old}"', f'"{new}"', 1).encode("utf-8"))
    print(f"updated {key} checksum")


def patch_text(text: str) -> str:
    never = false_expr(text)
    updated = text
    menu_hits = 0
    for pattern in MENU_RES:
        updated, n = pattern.subn(rf"\g<1>{never}\g<3>", updated, count=2)
        menu_hits += n
    if menu_hits < 2:
        raise RuntimeError(f"File menu Open Folder items not found (matched {menu_hits})")
    for command_id in HIDE_COMMAND_IDS:
        updated = hide_command(updated, command_id, never)
    return updated


def main() -> int:
    check_only = "--check" in sys.argv
    path = workbench_path()
    if path is None:
        print("vscodium workbench not found")
        return 1
    text = path.read_text(encoding="utf-8")
    if is_patched(text):
        if check_only:
            print("open-folder menus already disabled")
            return 0
        update_product_checksum(path)
        print("open-folder menus already disabled")
        return 0
    if check_only:
        print("open-folder menus still present")
        return 1
    try:
        updated = patch_text(text)
    except RuntimeError as exc:
        print(f"workbench strings changed; not patching: {exc}")
        return 1
    if not is_patched(updated):
        print("patch applied but verification failed")
        return 1
    backup = path.with_suffix(".js.talon-bak")
    if not backup.is_file():
        backup.write_bytes(path.read_bytes())
    path.write_bytes(updated.encode("utf-8"))
    update_product_checksum(path)
    print(f"disabled Open Folder in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
