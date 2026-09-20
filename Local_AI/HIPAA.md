# HIPAA / PHI — limits and residual risk

**Use at your own risk.**

This toolkit is a **technical control**, not a compliance program. Nobody can honestly stamp an editor **“100% HIPAA safe.”** HIPAA is organizational: policies, workforce training, access control, encryption, audit, breach process, and business associate agreements where they apply.

CASA-Trinity publishes these scripts so other agencies can see the pattern. **Your privacy officer still has to accept the stack.** MIT license: as-is, no warranty.

If you need a covered-entity determination, stop and talk to compliance. Do not treat this README as legal advice.

---

## The short version

| Statement | True? |
|-----------|--------|
| Prompts are designed to stay on `127.0.0.1` (Ollama) when you use this kit as documented | Yes |
| Hosted IDEs / Copilot / ChatGPT are safe for PHI if you “turn on privacy mode” | **No** |
| This repo or kit is HIPAA certified | **No** |
| Local inference replaces a BAA, audit log, or disk encryption | **No** |
| A user can still leak PHI (OneDrive, USB, browser, switching Cline to a cloud API) | **Yes** |

**Do not put PHI in a hosted IDE or browser chat.** Those products still send prompt-construction traffic through a vendor backend, even when you point them at a local model. Talon exists so the default path never does that.

---

## What “local AI” means here

```text
You  →  VSCodium (isolated profile)  →  Cline  →  Ollama  →  GPU
                                              127.0.0.1:11434
```

The large language model runs on the workstation. There is **no LLM vendor** seeing the prompt, so there is no LLM-vendor BAA for inference — because the tokens are not supposed to leave the box.

That is the HIPAA-relevant benefit. It is also the limit: everything else on the PC, the network, and the human still applies.

---

## What we implemented to reduce risk

These controls are in the scripts. They are not a complete HIPAA program. They are the list of things this kit actually does.

### Isolation from cloud IDEs

| Control | Where | Why |
|---------|--------|-----|
| Not Microsoft VS Code, not Visual Studio + Copilot, not a hosted IDE agent | Product choice | Those products send prompts or telemetry off-box |
| Isolated `--user-data-dir` (`ide-data\`) and `--extensions-dir` (`ide-extensions\`) | `run.ps1`, `setup.ps1` | Everyday Copilot / personal VS Code settings cannot mix in |
| `CLINE_DIR=ide-data\cline-home` | `run.ps1` | Current Cline builds store provider and onboarding in `~/.cline`, not only VS Code sqlite. Isolation stops the cloud “free model / Create my Account” picker |

### Local inference only

| Control | Where | Why |
|---------|--------|-----|
| `OLLAMA_HOST=127.0.0.1:11434` | `setup.ps1`, `run.ps1` | Bind the API to localhost, not a LAN/WAN interface |
| `OLLAMA_ORIGINS=http://127.0.0.1` | `run.ps1` | Limit browser-origin access to the local API |
| Cline `planModeApiProvider` / `actModeApiProvider` = `ollama` | `seed_cline.py` | Agent cannot start on OpenAI / Anthropic / OpenRouter |
| No cloud API keys written by seed | `seed_cline.py` | Seed never stores vendor tokens |
| `.clinerules` + Cline `customInstructions` | kit root | Tell the agent: Ollama only; no ClinePass; no web fetch |

### Cline cloud surfaces turned off

| Control | Where | Why |
|---------|--------|-----|
| `welcomeViewCompleted`, `isNewUser=false` | `seed_cline.py` | Skip first-run cloud onboarding |
| ClinePass banner ids dismissed | `seed_cline.py` | Hide “ClinePass” upsell (remote account) |
| `telemetrySetting=disabled`, `openTelemetryEnabled=false`, `optOutOfRemoteConfig=true` | `seed_cline.py` | Cline telemetry / remote config |
| `clineWebToolsEnabled=false`, `webSearchEnabled=false` | `seed_cline.py` | Web search leaves the box |
| `mcpMarketplaceEnabled=false`, MCP servers file empty | `seed_cline.py` | Marketplace and MCP are remote tool channels |
| Browser tool disabled (`disableToolUse`, `useBrowser=false`) | `seed_cline.py` | Headless Chrome is a network client |
| Auto-approve: Read / Edit / Commands on; **Web Fetch and MCP stay off** | `seed_cline.py` | Staff were blocked too often by prompts; web/MCP remain a PHI path so they stay denied |
| `vscodeTerminalExecutionMode=backgroundExec` | `seed_cline.py` | Avoid “Proceed While Running” hangs that train people to click through anything |

### IDE telemetry and update surfaces

| Control | Where | Why |
|---------|--------|-----|
| VSCodium instead of Microsoft VS Code | `setup.ps1` | No Microsoft branding / default telemetry channel |
| `telemetry.*` off, crash reporter off | `templates/settings.json`, `templates/argv.json` | Less unexpected outbound telemetry |
| `--disable-telemetry` on the process | `run.ps1` | Belt and suspenders |
| Auto-update off, extension auto-update off, release notes off | `templates/settings.json` | Surprise extension updates can re-enable cloud features |
| Natural-language settings search off | `templates/settings.json` | That feature is a cloud NLP call in VS Code-family products |
| Experiments off, tips off, cloud Changes off | `templates/settings.json` | Same class of remote features |
| Built-in chat / inline chat / MCP access disabled | `templates/settings.json` | VSCodium chat is not the local agent |
| `npm.fetchOnlinePackageInfo` off, JSON schema download off, TS ATA off | `templates/settings.json` | Editor language services that phone home |

### GitHub and remote code hosts (this window only)

| Control | Where | Why |
|---------|--------|-----|
| `github.gitAuthentication=false` and related GitHub UI off | `templates/settings.json` | No GitHub login prompt in the PHI window |
| `GIT_CONFIG_COUNT` `url.*.insteadof` rewrites `https://github.com/`, `git@github.com:`, gist, and `http://github.com/` | `run.ps1` | `git push` / clone to GitHub fail **inside Talon only**. Your user `.gitconfig` is not edited |
| `GH_TOKEN`, `GITHUB_TOKEN`, `GH_ENTERPRISE_TOKEN` cleared | `run.ps1` | `gh` cannot silently use a token from the environment |
| Copilot, GitHub PRs, GitHub auth, Remote Repositories, Azure Repos disabled in the isolated profile | `seed_cline.py` `DISABLED_EXTENSIONS` | Those extensions exist to talk to Microsoft / GitHub |
| Source Control view hidden; `git.autoRepositoryDetection=false`; `git.openRepositoryInParentFolders=never` | settings + seed layout | Stops the “parent repo is E:\github” toast and a git icon that invites remotes |
| `git.autofetch=false`, `git.terminalAuthentication=false` | `templates/settings.json` | No background fetch / askpass to a host |

This **does not** block git remotes in an ordinary Windows terminal outside Talon.

### Python and SQL kept on-box

| Control | Where | Why |
|---------|--------|-----|
| Local `.venv` (pandas, numpy, scikit-learn, matplotlib, SQLAlchemy, Jupyter, ruff) | `setup-datasci.ps1` | Analysis does not need a cloud notebook |
| `PYTHONNOUSERSITE=1` and venv on PATH | `run.ps1` | Do not pick up user-site packages that include cloud SDKs |
| Requirements file has **no** OpenAI / Anthropic / Azure / Google LLM SDKs | `templates/requirements-datasci.txt` | Those SDKs exist to send text off-box |
| Default DB is `data\local.sqlite` (file, no server) | `setup-datasci.ps1`, SQLTools settings | SQL work can stay on disk |
| Python language server = **Jedi**, not Pylance | `templates/settings.json` | Pylance / Microsoft language servers can send code for analysis |
| `python.telemetry` / `python.experiments` off | `templates/settings.json` | Microsoft Python extension telemetry |
| Jupyter remote notebook discovery off; widget CDN sources empty | `templates/settings.json` | Jupyter can otherwise pull remote kernels / scripts |

### Process and sharing hygiene

| Control | Where | Why |
|---------|--------|-----|
| Share as **readable PowerShell + hashes**, not a packed unsigned EXE | `Pack-ShareKit.ps1`, [IT.md](IT.md) | Packers trip Defender and hide what IT should review |
| Do not disable Defender / SmartScreen | docs + installer banner | “Fixing” SmartScreen by turning security off is how malware is shipped |
| Do not patch `VSCodium.exe` | `setup.ps1` branding | Patching the binary breaks Authenticode |
| Optional `harden-firewall.ps1` | admin script | Block `VSCodium.exe` from the public Internet; allow localhost |
| Workspace Trust on | `templates/settings.json` | User must accept a folder before the agent runs there |
| Crash dumps stay under `ide-data\crashes` | `run.ps1` | Avoid a default crash-reporter upload |
| Remote port auto-forward off | `templates/settings.json` | Less accidental LAN exposure |
| `.gitignore` excludes `ide-data`, `.venv`, `data\*.sqlite` | this folder | Runtime PHI must not be committed to GitHub |

---

## Local PHI is in scope

Talon is meant to **open, query, and remember PHI on this workstation**. `data\`, `memory\`, and `ide-data\` may hold charts, maps, and lessons. That is the point of a local kit.

The line is **off the box**, not “never touch PHI”:

- Allowed: local SQLite, local CSVs, local memory maps, local Cline sessions
- Not allowed: Cline cloud providers, browser chat, git push, gist, email, consumer OneDrive

Treat those folders as a PHI share. Encrypt the disk. Do not commit them to [CASA-Public](https://github.com/acalhouncasa/CASA-Public).

---

## What this does **not** cover (residual risk)

Be explicit with your privacy officer. Residual paths we know about:

1. **The human.** Paste into Outlook, Teams, a browser, a ticket, or a hosted chat and the control is gone.
2. **OneDrive / Desktop redirection / consumer sync.** If `data\` or the workspace lives in a sync root, PHI leaves the PC.
3. **Other processes.** USB, RDP clipboards, screen share, print to PDF, email.
4. **Cline provider switch.** Settings UI can still be pointed at OpenAI, Anthropic, OpenRouter, or ClinePass. Seed sets the default; it is not a hardware interlock.
5. **Cline or VSCodium updates.** If someone turns updates back on, a new build can add cloud UI. Firewall + “update.mode=none” reduce this; they do not freeze bits forever.
6. **Microsoft Python env helper.** Installing the Python extension may also pull `ms-python.vscode-python-envs`. Treat it as a possible telemetry surface; keep Python experiments/telemetry off.
7. **Agent terminal.** Auto-approved commands can `curl`, copy files, or open a browser. Web Fetch/MCP are off; raw PowerShell is not a sandbox.
8. **Install-time internet.** First setup talks to winget, Open VSX, PyPI, and (if you pull a model) ollama.com. Do not put PHI in the folder until that is done — or use the offline payload path.
9. **No audit log, no BAA, no access-control UI.** Windows login + BitLocker + your SIEM are still your program. This editor does not log “who prompted what” for six years.
10. **Shared accounts.** One Windows login = one profile. Do not share a PHI workstation login.
11. **Parent git remotes outside this window.** Everyday Terminal / Git GUI can still push. The GitHub block is process-scoped.
12. **Model quality / prompt injection.** A local model can still follow a malicious file that says “email this CSV.”
13. **Screenshots and issues.** This public GitHub repo is public. No chart numbers, no client names.

---

## Agency checklist (your work, not this repo’s)

- [ ] Privacy officer accepted local LLM use on this class of workstation
- [ ] Disk encryption (BitLocker) and patching already required
- [ ] Working folder is **not** consumer-synced
- [ ] Named Windows accounts; screen lock; no shared PHI login
- [ ] One Talon folder **per user** (do not copy `ide-data` between PCs)
- [ ] Workforce told: Talon only; never Copilot or a hosted chat for PHI
- [ ] Workforce told: do not switch Cline off Ollama
- [ ] Optional firewall script reviewed by IT
- [ ] Retention / wipe procedure for `ide-data` and `data\`
- [ ] Change control if the agent will author SQL that later runs in SmartCare (**do not test in Prod**)

---

## Tools that remain unsafe for PHI

Even after this kit is installed on the same PC:

- Hosted IDE agents (including “just look at this file” in another editor)
- Microsoft VS Code + GitHub Copilot
- Visual Studio + GitHub Copilot
- Cline with any provider other than local Ollama
- ChatGPT, Claude.ai, Gemini, Copilot Chat in a browser
- This public repository’s Issues and Pull Requests

---

## If something looks like a leak

1. Do not attach PHI to a public GitHub issue.
2. Follow [SECURITY.md](../SECURITY.md) (private vulnerability reporting).
3. Follow your agency incident process.

Related hosted-tool habits (different product): [AI/Working_With_Cursor/SAFETY.md](../AI/Working_With_Cursor/SAFETY.md). That folder is not Talon.
