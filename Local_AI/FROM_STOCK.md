# What Talon changes from stock

**Stock** means VSCodium, Cline, and Ollama as those publishers ship them, opened the usual way (Start Menu VSCodium, Cline’s first-run wizard, Ollama on its default settings).

`VSCodium.exe`, the Cline VSIX, and `ollama.exe` stay publisher-signed. Talon is a **wrapper**: isolated profile, launch flags, and seeded settings. Launch also edits **File menu when-clauses** in `workbench.desktop.main.js` (not the EXE) so Open Folder is actually gone. A `.talon-bak` sits next to that file.

Why each row exists: [HIPAA.md](HIPAA.md). Architecture: [HOW_IT_WORKS.md](HOW_IT_WORKS.md).

**Use at your own risk.** This is not HIPAA certified.

---

## Left alone (not Talon)

| Item | Stock behavior stays |
|------|----------------------|
| `VSCodium.exe` | Not patched. Authenticode stays. |
| Workbench File menu | Launch sets Open Folder / Open Workspace `when` to `y.false()` in `workbench.desktop.main.js`. Branding may also copy SVG/ICO resources. |
| Cline bits from Open VSX | Same extension. We seed its settings; we do not ship a fork. |
| Ollama installer / weights | Same app. We set `OLLAMA_HOST=127.0.0.1:11434` for this user/process. |
| Windows Defender / SmartScreen | Never turned off. |
| Everyday VS Code, Cursor, Chrome, Outlook | Untouched. They can still send PHI if someone opens files there. |
| `%USERPROFILE%\.gitconfig` | Not edited. GitHub remotes fail **inside the Talon window only**. |
| Other Windows accounts / other copies of VSCodium | Their profiles are separate. |

Optional: [harden-firewall.ps1](harden-firewall.ps1) (admin) blocks this `VSCodium.exe` from the public internet. That is not on by default.

---

## Launch and profile

| Stock VSCodium | Talon |
|----------------|-------|
| Uses `%APPDATA%\VSCodium` and the default extensions dir | `--user-data-dir ide-data\` and `--extensions-dir ide-extensions\` |
| Cline stores onboarding in `%USERPROFILE%\.cline` | `CLINE_DIR=ide-data\cline-home` |
| `--disable-telemetry` is optional | Always passed |
| Start Menu “VSCodium” | Start Menu / Desktop **Talon** → `run.ps1` → `Open-Talon.cmd` (quoted paths) |
| Opens the last folder or an empty window | Opens `ide-data\Talon.code-workspace` (kit first) |
| Restores previous windows and editor tabs | `window.restoreWindows=none`, `files.hotExit=off` |
| Release Notes / Welcome on upgrade | Seeded so Release Notes do not take the first tab; Getting started is a Guard webview |
| Crash reporter default location | `--crash-reporter-directory ide-data\crashes` |

---

## Cline (the agent)

| Stock Cline | Talon |
|-------------|-------|
| First run: account, ClinePass, “free cloud models” | Seeded as not a new user; ClinePass banners dismissed |
| Provider picker (OpenAI, Anthropic, OpenRouter, …) | Seeded to **Ollama** at `http://127.0.0.1:11434` every launch |
| You can switch provider mid-session and it sticks | Guard resets `providers.json` to Ollama and reloads |
| If Ollama is down, the UI invites a cloud key | `run.ps1` waits up to 45s; then a local **Ollama is not running** page |
| Telemetry / remote config on unless you opt out | Telemetry off, remote config opted out |
| Web search, MCP marketplace, browser tool available | All off; MCP servers file empty |
| Approve every Read / Edit / Command | Local Read / Edit / Commands auto-approved; **Web Fetch and MCP stay denied** |
| Sidebar location varies | Cline locked on the **right** |
| Custom instructions empty | Ollama-only / no cloud SDKs / PHI stays on disk |

---

## Editor (VSCodium settings in this profile only)

| Stock | Talon |
|-------|-------|
| Telemetry / experiments / cloud Changes / tips | Off |
| Built-in chat, inline chat, MCP access | Disabled (`chat.disableAIFeatures`, `chat.mcp.access=none`) |
| Auto-update and extension auto-update | Off |
| Natural-language settings search | Off |
| File → Open Folder / Open Workspace from File | Off the File menu (`y.false()` in the workbench). **Open File** stays. |
| Ctrl+K Ctrl+O = Open Folder | Add Folder to Workspace |
| Open Folder replaces the window | Guard keeps the kit and **adds** the folder |
| Git / GitHub / Source Control | Git off; parent-folder prompt Never; `vscode.git` disabled; GitHub login off |
| Copilot / GitHub / remote-repo extensions | Disabled in this profile |
| Python: Pylance + Python Environments | Jedi; `ms-python.vscode-python-envs` disabled |
| Interpreter: whatever the machine has | Kit `.venv\Scripts\python.exe` |
| SQLTools may auto-connect and ask to npm-install `sqlite3` | Connection listed; no auto-connect; Node-detect toasts off |
| Title bar is the product name | `Talon — local — … — Ollama up/down` |
| Workspace Trust default | On; startup prompt stays |

---

## Python, SQL, and memory (kit extras — not stock)

Stock VSCodium/Cline do not create these. Talon setup does:

- `.venv` with pandas, numpy, scikit-learn, matplotlib, SQLAlchemy, Jupyter, ruff — **no** OpenAI / Anthropic / Azure / Google LLM SDKs
- `data\local.sqlite`
- `memory\` maps and lessons on this disk (`Backup.cmd` refuses OneDrive)
- `Connect.cmd` to attach a project or PHI folder beside the kit
- `doctor.ps1` / `Check.cmd`
- `setup.ps1 -Strict` (commands not auto-approved)

---

## How to tell you are not in stock

1. Shortcut name is **Talon**, not VSCodium.
2. Title bar starts with **Talon — local**.
3. File menu has **Add Folder to Workspace**, not **Open Folder**.
4. Cline is on the right and says **Ollama**.
5. `doctor.ps1` reports provider `ollama`.

If any of those fail, close the window and start from `Start Talon.cmd`. A stock VSCodium shortcut is a different product and is not safe for PHI.
