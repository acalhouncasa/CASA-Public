"""Build a BOM-free VSIX so VSCodium will load Talon Guard."""

from __future__ import annotations

import json
import zipfile
from pathlib import Path

KIT = Path(__file__).resolve().parents[1]
EXT = KIT / "extensions" / "talon.talon-guard-1.3.0"
OUT = KIT / "extensions" / "talon-guard-1.3.0.vsix"

MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="talon-guard" Version="1.3.0" Publisher="talon"/>
    <DisplayName>Talon Guard</DisplayName>
    <Description xml:space="preserve">Keeps the Talon kit workspace open and shows Getting started.</Description>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json"/>
  </Assets>
</PackageManifest>
"""

CONTENT_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json"/>
  <Default Extension="js" ContentType="application/javascript"/>
  <Default Extension="html" ContentType="text/html"/>
  <Default Extension="vsixmanifest" ContentType="text/xml"/>
</Types>
"""


def main() -> int:
    pkg = json.loads(EXT.joinpath("package.json").read_text(encoding="utf-8-sig"))
    if pkg.get("name") != "talon-guard":
        print("bad package.json")
        return 1
    if OUT.exists():
        OUT.unlink()
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES)
        zf.writestr("extension.vsixmanifest", MANIFEST)
        for name in ("package.json", "extension.js", "getting-started.html", "ollama-down.html"):
            path = EXT / name
            raw = path.read_bytes()
            if name == "package.json" and raw.startswith(b"\xef\xbb\xbf"):
                raw = raw[3:]
            zf.writestr(f"extension/{name}", raw)
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
