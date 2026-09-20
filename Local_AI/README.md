# Talon — Local AI

A local coding agent for Windows: **VSCodium + Cline + Ollama**.

Prompts stay on the workstation (`127.0.0.1:11434`). Talon is its own kit.

| Document | Subject |
|----------|---------|
| [USAGE.md](USAGE.md) | Getting started: editor layout, folders, daily use |
| [CONNECT.md](CONNECT.md) | Attach a local project folder, PHI folder, or database |
| [INSTALL.md](INSTALL.md) | Install, first launch, and verification |
| [LEARN.md](LEARN.md) | Background data maps and lessons |
| [TEAM.md](TEAM.md) | Small-team operations |
| [HIPAA.md](HIPAA.md) | PHI limits and residual risk |
| [HOW_IT_WORKS.md](HOW_IT_WORKS.md) | Architecture |
| [IT.md](IT.md) | Sharing, hashes, Authenticode |

**Use at your own risk.** This kit is not HIPAA certified. Local PHI in `data\` and `memory\` is expected. Do not put PHI in a hosted chat or in this GitHub repository.

## Folders

Keep the Talon kit as the first Explorer root. It starts collapsed. Attach project and PHI folders with `Connect.cmd` or File → Add Folder to Workspace. File → Open Folder adds a folder; it does not replace the kit.

## Quick start

```powershell
.\setup.ps1 -PullModel
.\doctor.ps1
.\Connect.cmd
```

After setup, use **Talon** and **Talon Connect** from the Start Menu. Desktop shortcuts use the Talon icon.

To copy `memory\` to a local disk or USB (never OneDrive):

```powershell
.\Backup.cmd
```
