"""
Module: apply_win32_icons.py

Author: Alan Calhoun, Senior Data Analyst, CASA-Trinity
Created: 2026-10-26
Last Modified: 2026-10-26
AI Assistant: Talon

Description:
 Copy Orion branding\\icon.ico (and PNG sizes) over VSCodium win32
 code.ico resources so the taskbar shows Orion. Does not patch VSCodium.exe.

Usage:
 python tools\\apply_win32_icons.py [path-to-VSCodium.exe]
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]


def backup_once(dest: Path) -> None:
    bak = Path(str(dest) + ".vscodium-bak")
    if dest.is_file() and not bak.is_file():
        shutil.copy2(dest, bak)


def main() -> int:
    brand_ico = KIT / "branding" / "icon.ico"
    brand_png = KIT / "branding" / "icon.png"
    if not brand_ico.is_file():
        print(f"missing {brand_ico}")
        return 1

    if len(sys.argv) > 1:
        exe = Path(sys.argv[1])
    else:
        local = Path.home() / "AppData/Local/Programs/VSCodium/VSCodium.exe"
        prog = Path(r"C:\Program Files\VSCodium\VSCodium.exe")
        exe = local if local.is_file() else prog
    if not exe.is_file():
        print("VSCodium.exe not found")
        return 1

    win32 = exe.parent / "resources" / "app" / "resources" / "win32"
    if not win32.is_dir():
        print(f"missing {win32}")
        return 1

    dest_ico = win32 / "code.ico"
    backup_once(dest_ico)
    shutil.copy2(brand_ico, dest_ico)
    print(f"wrote {dest_ico} ({dest_ico.stat().st_size} bytes)")

    if brand_png.is_file():
        try:
            from PIL import Image
        except ImportError:
            print("Pillow missing; ico only")
            return 0
        im = Image.open(brand_png).convert("RGBA")
        for name, size in (("code_70x70.png", 70), ("code_150x150.png", 150)):
            dest = win32 / name
            backup_once(dest)
            im.resize((size, size), Image.Resampling.LANCZOS).save(dest)
            print(f"wrote {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
