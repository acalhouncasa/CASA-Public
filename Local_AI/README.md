# Talon — Local AI

A **local** coding agent for Windows: **VSCodium + Cline + Ollama**.

Prompts stay on the workstation (`127.0.0.1:11434`). Talon is its own kit.

| Doc | Read it for |
|-----|-------------|
| [USAGE.md](USAGE.md) | How to use the UI; main kit vs project vs PHI folders |
| [CONNECT.md](CONNECT.md) | Attach a local PHI folder or database; remove / dedupe / warn |
| [INSTALL.md](INSTALL.md) | Full install, first launch, verify |
| [LEARN.md](LEARN.md) | Background data maps and lessons |
| [TEAM.md](TEAM.md) | Small-team habits |
| [HIPAA.md](HIPAA.md) | PHI limits and residual risk |
| [HOW_IT_WORKS.md](HOW_IT_WORKS.md) | Architecture |
| [IT.md](IT.md) | Sharing, hashes, Authenticode |

**Use at your own risk.** Not HIPAA certified. Local PHI in `data\` and `memory\` is expected. Do not put PHI in a hosted chat or this GitHub repo.

## Folder model

Keep the **Talon kit** as the main Explorer root. Attach **project** and **PHI** folders with `Connect.cmd` so they appear beside the kit. Do not File → Open Folder on PHI only.

## Quick start

```powershell
.\setup.ps1 -PullModel
.\doctor.ps1
.\Connect.cmd
```

Or **Talon** and **Talon Connect** from the Start Menu after setup. Desktop shortcuts use the Talon claw icon.

Local memory zip (PHI — USB or agency disk only): `.\Backup.cmd`
