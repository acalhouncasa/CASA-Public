"""Build branding/icon.ico from branding/icon.png (or JPEG)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "icon.png"
ICO = ROOT / "icon.ico"


def main() -> int:
    if not SRC.is_file():
        print(f"missing {SRC}")
        return 1
    try:
        from PIL import Image
    except ImportError:
        print("Pillow required: pip install pillow")
        return 1
    im = Image.open(SRC).convert("RGBA")
    im.save(SRC, "PNG")
    im.save(
        ICO,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"wrote {ICO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
