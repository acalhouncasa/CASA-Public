# Local Coder

A **local** coding agent for Windows: **VSCodium + Cline + Ollama**.

Prompts and completions are meant to stay on the workstation (`127.0.0.1:11434`). Local Coder is its own kit — not a hosted IDE and not GitHub Copilot.

| Doc | Read it for |
|-----|-------------|
| [INSTALL.md](INSTALL.md) | Full install, first launch, verify, troubleshooting |
| [TEAM.md](TEAM.md) | Small-team habits, updates, shared vs local files |
| [HIPAA.md](HIPAA.md) | PHI limits, residual risk, and every control we added |
| [HOW_IT_WORKS.md](HOW_IT_WORKS.md) | Architecture: isolated profile, Cline seed, Python/SQL |
| [IT.md](IT.md) | Sharing, hashes, Authenticode, Intune |
| [THIRD_PARTY.md](THIRD_PARTY.md) | Upstream licenses and official download sites |
| [WELCOME.md](WELCOME.md) | Short in-editor reminder |
| [examples/](examples/) | Synthetic monthly-encounter demo (not PHI) |

## Use at your own risk

**This kit is not HIPAA certified and is not “100% HIPAA safe.”** HIPAA is an organization program (policies, access control, encryption, audit, BAAs, workforce training). An editor cannot replace that.

CASA-Trinity publishes the scripts as-is under MIT so other Streamline agencies can reuse the pattern. **Your organization owns** the decision to run it, the hardware, the change control, and any PHI that later sits in the working folder.

Do **not** put PHI in a hosted IDE or browser chat. Those products send prompts through a cloud backend.

Read [HIPAA.md](HIPAA.md) before you open a chart, claim, or export in Local Coder.

## What you get

- Isolated VSCodium profile (separate from everyday VS Code)
- Cline locked to **Ollama on localhost** (cloud onboarding and ClinePass banners dismissed)
- GitHub login and `github.com` git remotes blocked **inside this window only**
- Local Python venv (pandas, SQLAlchemy, scikit-learn, Jupyter, ruff)
- On-disk SQLite at `data\local.sqlite` (no database server)
- `doctor.ps1` health check and `Update-LocalCoder.ps1` (refreshes scripts, leaves PHI folders alone)
- Optional Windows Firewall lock so VSCodium cannot reach the public internet

## Quick start

Detailed steps: **[INSTALL.md](INSTALL.md)**. Small team: **[TEAM.md](TEAM.md)**.

```powershell
# 1. Copy this folder to a local working path (not OneDrive if you can avoid it)
# 2. Open PowerShell in that copy
.\setup.ps1 -PullModel
.\doctor.ps1
.\run.ps1
```

Or double-click `Install.cmd`, then `Check.cmd`, then `Start Local Coder.cmd`.

Shared / training PC: `.\setup.ps1 -PullModel -Strict` (terminal commands are not auto-approved).

## Hardware

`qwen3-coder:30b` (Q4) is the intended coding model. It needs a recent NVIDIA GPU with about **24 GB VRAM**. Laptops can use `qwen2.5-coder:14b` or `7b` — set the order in `templates\team-defaults.json`.

## What this is not

- Not an official vendor product or support channel
- Not a replacement for SmartCare, SSMS, or your EHR
- Not a place to store PHI in this GitHub repository
- Not a hosted “bring your own key” IDE (those still leave the box)
