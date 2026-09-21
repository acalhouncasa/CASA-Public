"""Turn off File → Open Folder in this VSCodium workbench.

Do not use when:!1 (boolean false). contextMatchesRules treats a falsy
when as "no clause" and shows the item. Use y.false(), the never-true
ContextKeyExpr already used in this file.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path

REPLACEMENTS = (
    (
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:mZ.ID,title:d(5899,null)},order:2,when:kF})',
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:mZ.ID,title:d(5899,null)},order:2,when:y.false()})',
    ),
    (
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:nNe.ID,title:d(5900,null)},order:2,when:y.and(kF.toNegated(),Ha.isEqualTo("workspace"))})',
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:nNe.ID,title:d(5900,null)},order:2,when:y.false()})',
    ),
    (
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:Uqi.ID,title:d(5902,null)},order:3,when:fI})',
        'fe.appendMenuItem(T.MenubarFileMenu,{group:"2_open",command:{id:Uqi.ID,title:d(5902,null)},order:3,when:y.false()})',
    ),
    (
        'static{this.ID="workbench.action.files.openFolder"}constructor(){super({id:bUs.ID,title:R(5910,"Open Folder..."),category:Le.File,f1:!0,precondition:kF',
        'static{this.ID="workbench.action.files.openFolder"}constructor(){super({id:bUs.ID,title:R(5910,"Open Folder..."),category:Le.File,f1:!1,precondition:y.false()',
    ),
    (
        'static{this.ID="workbench.action.files.openFolderViaWorkspace"}constructor(){super({id:wUs.ID,title:R(5911,"Open Folder..."),category:Le.File,f1:!0,precondition:y.and(kF.toNegated(),Ha.isEqualTo("workspace"))',
        'static{this.ID="workbench.action.files.openFolderViaWorkspace"}constructor(){super({id:wUs.ID,title:R(5911,"Open Folder..."),category:Le.File,f1:!1,precondition:y.false()',
    ),
    (
        'static{this.ID="workbench.action.openWorkspace"}constructor(){super({id:yUs.ID,title:R(5913,"Open Workspace from File..."),category:Le.File,f1:!0,precondition:fI})',
        'static{this.ID="workbench.action.openWorkspace"}constructor(){super({id:yUs.ID,title:R(5913,"Open Workspace from File..."),category:Le.File,f1:!1,precondition:y.false()})',
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


def already_patched(text: str) -> bool:
    return all(new in text for _, new in REPLACEMENTS)


def workbench_checksum(path: Path) -> str:
    raw = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"")
    digest = hashlib.sha256(raw).digest()
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
    product.write_text(text.replace(f'"{old}"', f'"{new}"', 1), encoding="utf-8")
    print(f"updated {key} checksum")


def main() -> int:
    path = workbench_path()
    if path is None:
        print("vscodium workbench not found")
        return 1
    text = path.read_text(encoding="utf-8")
    if already_patched(text):
        update_product_checksum(path)
        print("open-folder menus already disabled")
        return 0
    if "when:!1}" in text and "id:mZ.ID" in text:
        print("old boolean-false patch present; restore workbench.desktop.main.js.talon-bak first")
        return 1
    backup = path.with_suffix(".js.talon-bak")
    if not backup.is_file():
        backup.write_text(text, encoding="utf-8")
    updated = text
    missing = []
    for old, new in REPLACEMENTS:
        if old not in updated:
            missing.append(old[:80])
            continue
        updated = updated.replace(old, new, 1)
    if missing:
        print("workbench strings changed; not patching:")
        for item in missing:
            print(" ", item)
        return 1
    path.write_text(updated, encoding="utf-8")
    update_product_checksum(path)
    print(f"disabled Open Folder in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
