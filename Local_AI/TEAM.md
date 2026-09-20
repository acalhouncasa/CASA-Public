# Talon — Local AI for a small team

This kit is **per person, per PC**. Do not share `ide-data`, `.venv`, or `data\*.sqlite`. Those folders can hold PHI after first use.

Install steps: [INSTALL.md](INSTALL.md) (in the public pack) or `.\setup.ps1` here. Limits: keep Cline on Ollama.

## How a 3–10 person shop should run it

| Pattern | Use when | Do not |
|---------|----------|--------|
| **One kit folder per user** (`C:\Talon` or `%LOCALAPPDATA%\Programs\Talon`) | Default | Copy someone else’s `ide-data` |
| **Project folder separate from the kit** | Shared scripts, SQL, notebooks | Open the kit folder as the only workspace if it already has PHI |
| **Same model name on every GPU box** | You want comparable answers | Mix `qwen3-coder:30b` and a 7B without saying so |
| **Laptop / no 24 GB VRAM** | Pull `qwen2.5-coder:14b` or `7b` (see `templates\team-defaults.json`) | Pull a second 30B on the same 24 GB card |
| **One strong GPU workstation, thin clients** | Budget | RDP a PHI session to an unmanaged home PC |

Attach a project or PHI folder with `Connect.cmd`. The kit stays the first Explorer root.

## First day on a new PC

1. Copy the kit **out** of git / OneDrive. Run `.\setup.ps1 -PullModel`.
2. Run `.\doctor.ps1` (or `Check.cmd`). Fix every FAIL before anyone pastes a real export.
3. Open Cline. Confirm provider **Ollama** and the model you agreed on.
4. Ask Cline to run the synthetic demo in `examples\` (not a real extract).
5. Only then open a project that may contain PHI.

Shared-workstation extra:

```powershell
.\setup.ps1 -Strict
```

That writes `ide-data\team-overrides.json` so Cline does **not** auto-approve terminal commands. Read/Edit can still be auto-approved. Web Fetch and MCP stay off either way.

## Updates (do not re-install over PHI)

When CASA-Public or a coworker ships a new kit zip:

```powershell
.\Update-LocalCoder.ps1 -From "D:\Incoming\Local_AI"
.\doctor.ps1
```

The updater copies scripts, docs, templates, examples, and branding. It **does not** touch `ide-data`, `ide-extensions`, `.venv`, `logs`, or `data\*.sqlite`.

Then re-run `.\setup.ps1 -SkipDeps` only if you need new editor extensions.

## What to share vs what to keep local

| Share | Keep on that PC |
|-------|-----------------|
| This kit (scripts + docs) | `ide-data\`, `ide-extensions\` |
| Project source with **no PHI** | `data\local.sqlite`, CSVs, notebooks with client rows |
| `examples\` synthetic files | Anything that could identify a client |
| `doctor.ps1` output (no paths to charts) | Screenshots of Talon with live data |

Hash-check zip drops. See `IT.md`.

## Team knobs

Edit `templates\team-defaults.json` **before** you pack a drop for the agency:

- `preferredModels` — first match that Ollama has wins
- `autoApproveCommands` — `false` for a shared PC image

Per machine: `ide-data\team-overrides.json` (same keys). `setup.ps1 -Strict` creates that file.

## Support

```powershell
.\doctor.ps1
```

Send the FAIL/WARN lines, not a full screen of a chart. Re-seed without changing apps:

```powershell
python .\seed_cline.py .\ide-data
```
