# How Talon works

This page is the architecture. Install steps are in [INSTALL.md](INSTALL.md). PHI limits are in [HIPAA.md](HIPAA.md).

## Why a separate product

Hosted coding IDEs still send prompts off-box, even when you attach a local model. Microsoft VS Code + Copilot and Visual Studio + Copilot are the same class of problem.

Talon is a thin, auditable wrapper around three existing open-source pieces:

| Piece | Role |
|-------|------|
| [VSCodium](https://github.com/VSCodium/vscodium) | Editor UI (VS Code without Microsoft branding/telemetry defaults) |
| [Cline](https://open-vsx.org/extension/saoudrizwan/claude-dev) | Agent: read, edit, grep, terminal |
| [Ollama](https://github.com/ollama/ollama) | Local model server on `127.0.0.1:11434` |

The value of this folder is **how those three are launched and seeded**, not a new model. Row-by-row vs stock defaults: [FROM_STOCK.md](FROM_STOCK.md).

## Data path

```text
┌─────────────────────────────────────────────────────────────┐
│  Talon process (run.ps1)                              │
│                                                             │
│   VSCodium.exe                                              │
│     --user-data-dir   <kit>\ide-data                        │
│     --extensions-dir  <kit>\ide-extensions                  │
│     --disable-telemetry                                     │
│                                                             │
│   Cline (right bar)                                         │
│     CLINE_DIR = <kit>\ide-data\cline-home                   │
│     provider  = ollama                                      │
│                                                             │
│   PATH = <kit>\.venv\Scripts;...                            │
│   GIT_CONFIG_*  rewrite github.com → blocked                │
│   GH_TOKEN emptied                                          │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTP
                            ▼
                 Ollama  127.0.0.1:11434
                            │
                            ▼
                      GPU (qwen3-coder:30b)
```

Prompts, file chunks Cline attaches, and completions are intended to stay on that loopback hop. Cline still **reads and writes your workspace files** on disk. Treat the workspace like any other PHI share.

## Isolated profile

VSCodium without flags uses `%APPDATA%\VSCodium`. That would mix with any other VSCodium, and it is easy to install Copilot “just this once.”

`run.ps1` always passes:

- `--user-data-dir` → `ide-data\` (settings, window layout, Cline sqlite, last workspace)
- `--extensions-dir` → `ide-extensions\` (Cline, Python, Ruff, SQLTools, Jupyter only)

A Desktop shortcut that opens stock VSCodium is **not** Talon. Use `Launch-LocalCoder.vbs` → `run.ps1` → `Open-Talon.cmd`.

Talon Guard 1.3.0 (`extensions\talon.talon-guard-1.3.0`) stays in the isolated extensions dir. Launch copies it only after Talon is closed (replacing it while VSCodium is running marks it invalid). `package.json` must have no UTF-8 BOM. Getting started is a Guard **webview**, not an HTML file tab (a file tab shows source and expands the Talon tree).

**File → Open Folder** is removed by `learn\patch_vscodium_menus.py`: those File menu items use `ContextKeyExpr.false()` (`C.false()` or `y.false()`) in `workbench.desktop.main.js`. The patcher matches File-menu group `2_open` and the Open Folder command IDs, so a VSCodium update that only renames minified identifiers still works. A profile hide-list (`menu.hiddenCommands`) does not take them off this VSCodium’s File menu. Do not use `when: false` (boolean); this build treats that as “always show.” After the edit, the script writes the **raw-byte** SHA-256 of that file into `product.json` `checksums` so VSCodium does not toast “installation appears to be corrupt.” **Open File** stays. File → Add Folder to Workspace and Talon Connect remain. If someone opens a folder another way (Open Recent), Guard restores the kit workspace and adds the chosen folder. `Install-Guard.cmd` reinstalls the VSIX into this profile only.

`run.ps1` writes settings, seeds Cline, and copies Guard **after** it quits any running Talon window. Seeding while VSCodium is still open lets shutdown overwrite the profile store.

## How Cline is locked to Ollama

Cline’s current builds store real state in `CLINE_DIR` (`globalState.json`, `providers.json`, `global-settings.json`), not only the VS Code `state.vscdb`.

`seed_cline.py` writes all three:

1. Isolated `ide-data\cline-home\`
2. VS Code sqlite (if the DB already exists)
3. A sidecar `local-ollama.json` for humans / IT

It also:

- Picks the first available model from a preferred list (`qwen3-coder:30b` first)
- Dismisses ClinePass / welcome banners
- Places Cline on the **right** auxiliary bar and hides Source Control
- Disables Copilot / GitHub / `vscode.git` / Python Environments / remote-repo extension ids in that profile
- Records the installed VSCodium version as `releaseNotes/lastVersion` so Release Notes do not open on every launch

`run.ps1` re-runs the seed every launch so a stray click is less sticky.

During the session, Talon Guard watches `providers.json`, `global-settings.json`, and `globalState.json`. If the provider is not `ollama`, or a cloud API key appears, Guard rewrites those files to Ollama only and reloads the window so Cline drops the in-memory cloud provider.

`run.ps1` also starts Ollama if needed and waits up to 45 seconds. If `127.0.0.1:11434` still does not answer, Guard shows `ollama-down.html` and tells the user not to pick a cloud model.

## Why the agent can edit without asking every time

Staff were blocked by Cline’s approval UI (Read, Edit, Commands, plus “Proceed While Running”). Seed enables auto-approve for **local** file and command tools, and uses `backgroundExec` so a long `powershell` does not freeze the UI.

**Web Fetch and MCP stay denied.** Those are the easy ways for an agent to send text off-box.

This is a tradeoff: fewer clicks, more need to watch the terminal. See residual risk in [HIPAA.md](HIPAA.md).

## GitHub block (process-scoped)

`run.ps1` sets `GIT_CONFIG_COUNT` and six `insteadOf` mappings so any `git` child process in that window treats GitHub URLs as invalid. It also clears `GH_*` tokens.

It does **not** write `%USERPROFILE%\.gitconfig`. Everyday git outside Talon is unchanged. That is deliberate: a global rewrite would break agency source control on the same PC.

## Python and SQL (local toolchain)

A second 30B “SQL model” would fight a 24 GB GPU for VRAM. Coding quality for Python/SQL comes from **qwen3-coder** plus real tools:

| Piece | Purpose |
|-------|---------|
| `.venv` | pandas, numpy, scipy, scikit-learn, matplotlib, seaborn, SQLAlchemy, Jupyter, ruff |
| `data\local.sqlite` | On-disk SQL, no server |
| Jedi | Completions without Pylance’s cloud analysis |
| SQLTools + SQLite driver | Browse `local.sqlite` |
| Ruff | Format on save |

`learn\apply_sources.py` rebuilds User and workspace settings from `templates\settings.json` on each launch (Windows interpreter path, SQLite path, git locked off). It also writes kit `.vscode\settings.json` so the Python extension does not ask for a location. `python.useEnvironmentsExtension` is false and `python.createEnvironment.trigger` is off. SQLTools is given the Local SQLite connection but does not auto-connect, so the first window does not ask to npm-install `sqlite3`. Node-detect notifications are off.

## Branding

`setup.ps1` may copy SVG watermarks and the title-bar icon into VSCodium’s `resources\app\out\media`. Those are unsigned **resource files**. The signed `VSCodium.exe` is not rewritten.

## What happens at `.\run.ps1`

1. Find `VSCodium.exe`.
2. Probe Ollama; if down, start `ollama serve` and wait up to 45 seconds. Write `ide-data\ollama-status.json`.
3. Remember / accept `-Workspace`.
4. Copy Talon Guard 1.3.0, rebuild settings from the template, seed Cline.
5. Export venv PATH, GitHub block, `CLINE_DIR`, `OLLAMA_HOST`.
6. Launch through `Open-Talon.cmd` so `--user-data-dir` and the workspace path stay quoted (names with spaces stay one argument).

## Trust boundaries (honest)

```text
Trusted for inference:   Ollama on 127.0.0.1, weights on disk, GPU
Trusted for editing:     whatever folder you opened (can contain PHI)
Not trusted:             Cline if the user picks a cloud provider
Not trusted:             hosted IDEs, browsers, OneDrive, USB, other terminals
Not trusted:             this public GitHub repository
```

The kit makes the *default path* local. It cannot make a covered-entity program.
