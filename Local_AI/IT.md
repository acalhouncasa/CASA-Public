# IT notes: sharing Talon without tripping security tools

This kit is meant to look like ordinary internal software. The way to do that
is **transparency and publisher signatures**, not packing tricks.

Staff install: [INSTALL.md](INSTALL.md). Team habits: [TEAM.md](TEAM.md).
PHI limits: [HIPAA.md](HIPAA.md).

After every install or update, staff run `.\doctor.ps1` (or `Check.cmd`) and
send FAIL lines only — no screenshots of live charts.

## What will still warn, and why that is correct

An **unsigned `.exe` you built** will show SmartScreen. Windows is working.
“Fixing” that by packing, obfuscating, disabling Defender, or adding
exclusions is how real malware hides, and agency SOC tools will treat it as
malware.

Quiet installs come from one of these, in order of preference:

1. **Zip of scripts + hashes** (this folder’s default share format). IT reviews
   `setup.ps1`, then staff run `Install.cmd`.
2. **Intune / Company Portal / SCCM** wrapping that same script. The company
   portal is already trusted.
3. **Authenticode signature** on the Inno installer *and* the PowerShell
   files, using **your organization’s** code-signing certificate (EV cert
   if you need SmartScreen reputation on day one).
4. **winget** for VSCodium and Ollama so Windows sees *their* publishers,
   not a third wrapper.

## Do not

- Convert `setup.ps1` to an EXE with ps2exe / similar (high false-positive rate)
- Wrap Ollama + VSCodium inside one self-extracting archive
- Instruct users to turn off SmartScreen or Windows Defender
- Ship GitHub Copilot or another hosted coding agent
- Claim the kit is “HIPAA certified” or “100% HIPAA safe”
- Commit `ide-data`, `.venv`, or `data\*.sqlite` to git (those can hold PHI)
- Zip a used kit that already has `ide-data` or real CSVs

## Build a share zip

```powershell
.\Pack-ShareKit.ps1
```

That writes `dist\LocalCoder-1.4.4.zip` plus `dist\SHA256SUMS.txt`.

On a PC that already has Talon, refresh scripts without wiping the
profile:

```powershell
.\Update-LocalCoder.ps1 -From "D:\Incoming\Local_AI"
python .\seed_cline.py .\ide-data
.\doctor.ps1
```

Optional offline payload (vendor-signed files, still separate):

```powershell
.\Pack-ShareKit.ps1 -DownloadPayload
```

## Hash check after download

```powershell
Get-FileHash .\LocalCoder-1.4.4.zip -Algorithm SHA256
# compare to SHA256SUMS.txt from the same drop
Unblock-File .\LocalCoder-1.4.4.zip   # only after the hash matches
```

## Sign (when the agency has a cert)

```powershell
# Thumbprint of the org code-signing cert in the local machine store
.\Sign-LocalCoder.ps1 -Thumbprint "YOURTHUMBPRINT"
```

IT can also sign only the zip’s PowerShell files and keep the zip as the
distribution unit.

An Inno Setup script is in `pack\LocalCoder.iss` if you want an EXE *after*
you can sign it. Unsigned `Setup.exe` will show SmartScreen; that is expected.

## Intune Win32 sketch

- Install command: `Install.cmd`
- Detection: folder exists and `VERSION` is present (or `%LOCALAPPDATA%\Programs\LocalCoder\VERSION` if you copy there)
- Requirement: 64-bit Windows; NVIDIA GPU recommended for `qwen3-coder:30b`
- Do not run as SYSTEM if you want a per-user VSCodium profile
- Run model pull as a separate, long-running step (`ollama pull`) so the
  Intune window does not time out
- Detection should not require `ide-data` (that folder is created per user)

## Network the installer needs (online mode)

- `winget` / Microsoft Store source (or your internal winget source)
- GitHub releases for VSCodium and Ollama if using `payload` download
- Open VSX (`open-vsx.org`) for Cline and the Python/SQL extensions
- PyPI for `setup-datasci.ps1`
- ollama.com if staff pull `qwen3-coder:30b`

After install, Cline + Ollama are intended to stay on `127.0.0.1`. Optional:
`harden-firewall.ps1` (admin) blocks VSCodium from the public internet.

## HIPAA (technical control only)

Local inference means the LLM vendor never sees prompts. That does **not**
replace a BAA, access control, encryption, audit, or workforce training.
Each agency’s privacy officer still has to accept the stack. Full list of
controls and residual risk: [HIPAA.md](HIPAA.md).
