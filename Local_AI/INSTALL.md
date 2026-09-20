# Install Talon

This is the full install path for another agency or a new workstation. Read [NOTICE.md](../NOTICE.md) and [HIPAA.md](HIPAA.md) first.

**Use at your own risk.** The scripts do not disable Windows Defender or SmartScreen. They do not certify you for HIPAA.

**Do not test against a production EHR** from this editor until your privacy officer and change control have accepted the stack.

---

## 1. Before you start

### Decide whether this is appropriate

1. Your privacy / compliance officer knows you intend to run a **local** LLM on a workstation.
2. You understand the residual risks in [HIPAA.md](HIPAA.md) (OneDrive, other apps, a user switching Cline to a cloud provider, agent terminal commands).
3. You will **not** paste PHI into Copilot, ChatGPT, or a browser assistant.
4. You will keep working files on a disk your organization already treats as in-scope (BitLocker, access control, backup rules).

If any of those are “no,” stop. Publish the folder as documentation only.

### What the installer will and will not do

| The installer does | The installer does not |
|---|---|
| Install VSCodium and Ollama from **winget** or `payload\` | Pack those EXEs into one unsigned dropper |
| Install Cline and Python/SQL extensions from **Open VSX** into an isolated profile | Touch your everyday VS Code profile |
| Seed Cline to Ollama on `127.0.0.1:11434` | Create a Cline cloud account |
| Create a local `.venv` and `data\local.sqlite` | Install cloud LLM SDKs |
| Create Start Menu / Desktop shortcuts | Turn off Defender, SmartScreen, or antivirus |
| Set `OLLAMA_HOST=127.0.0.1:11434` for the Windows user | Change your global git config |

Install needs the internet **once** (winget + Open VSX + optional model pull). After that, inference is intended to stay on localhost. Optional: [harden-firewall.ps1](harden-firewall.ps1) (section 9).

---

## 2. Requirements

### Workstation

| Item | Required | Notes |
|------|----------|--------|
| OS | Windows 10/11 64-bit | PowerShell 5.1 or newer |
| Disk | ~5 GB for apps + 20–40 GB for the 30B model | SSD strongly preferred |
| RAM | 32 GB recommended | 16 GB may run a smaller model only |
| GPU | NVIDIA, **~24 GB VRAM** for `qwen3-coder:30b` | RTX 4090 class. Weaker GPUs: pick a smaller Ollama model |
| NVIDIA driver | Current Game Ready or Studio | Ollama uses the GPU; confirm `nvidia-smi` works |
| Account | Local admin **not** required for default setup | Admin **is** required for the optional firewall script |
| winget | Present on modern Windows | `winget --version`. If missing, use offline `payload\` (section 10) |
| Python | 3.12+ | `setup.ps1` can install `Python.Python.3.12` via winget if none is found |

### Network (first install only)

Allow outbound HTTPS to:

- Microsoft winget / Store source (or your internal winget source)
- [https://github.com/VSCodium/vscodium/releases](https://github.com/VSCodium/vscodium/releases) if you download the VSCodium installer by hand
- [https://github.com/ollama/ollama/releases](https://github.com/ollama/ollama/releases) if you download Ollama by hand
- [https://open-vsx.org](https://open-vsx.org) for Cline, Python, Ruff, SQLTools, Jupyter
- [https://ollama.com](https://ollama.com) if you pull a model (`ollama pull`)
- [https://pypi.org](https://pypi.org) for the data-science venv

After install, Cline + Ollama are intended to talk only to `127.0.0.1:11434`.

### Do not install on

- A machine that syncs the working folder to **consumer OneDrive / Dropbox** if that folder will hold PHI
- A shared kiosk without a named Windows login
- A VM with no GPU if you expect `qwen3-coder:30b` to be usable

---

## 3. Where to put the folder

Copy **this entire `Local_AI` folder** to a working path that is **not** the Git clone you will push.

Good:

```text
C:\\Talon\
D:\Tools\LocalCoder\
```

Avoid:

| Location | Why |
|----------|-----|
| This GitHub clone (`CASA-Public\Local_AI`) | `setup.ps1` creates `ide-data`, `.venv`, and `data\*.sqlite`. Those must never be committed. |
| OneDrive / Desktop (if Desktop is redirected) | Consumer sync can take PHI off the box. |
| A path you later zip and email | Runtime folders can contain client data. |

If the path has a space (`Talon`), that is fine. Scripts quote their arguments.

After first run you will see extra folders. **Do not commit them:**

```text
ide-data\          isolated VSCodium profile and Cline state
ide-extensions\    Cline + Python/SQL extensions
.venv\             local Python
data\local.sqlite  local SQL file (can later hold PHI)
logs\              install transcripts
```

---

## 4. Get the files onto the PC

### Option A — Git clone (IT-friendly)

On a machine that may use git (this is the **public** repo; still no PHI):

```powershell
gh auth switch --user YOUR_ORG_ACCOUNT   # if you use more than one GitHub login
git clone https://github.com/acalhouncasa/CASA-Public.git
Copy-Item -Recurse .\CASA-Public\Local_AI C:\\Talon
cd C:\\Talon
```

### Option B — Download ZIP from GitHub

1. Open [https://github.com/acalhouncasa/CASA-Public](https://github.com/acalhouncasa/CASA-Public).
2. Code → Download ZIP.
3. Unzip.
4. Copy the `Local_AI` folder to `C:\\Talon` (or your chosen path).
5. If Windows marked the zip: only unblock **after** you trust the source.

```powershell
# Example after you copy out of the unzipped tree
Unblock-File C:\\Talon\*.ps1, C:\\Talon\*.cmd, C:\\Talon\*.vbs
```

### Option C — Agency share kit

If a coworker already built `LocalCoder-1.0.0.zip` with `.\Pack-ShareKit.ps1`:

1. Compare the SHA-256 of the zip to `SHA256SUMS.txt`.
2. Unblock the zip **only if the hash matches**.
3. Unzip and continue at section 5.

```powershell
Get-FileHash .\LocalCoder-1.0.0.zip -Algorithm SHA256
# compare to SHA256SUMS.txt
Unblock-File .\LocalCoder-1.0.0.zip
```

Details: [IT.md](IT.md).

---

## 5. Online install (usual path)

1. Open **PowerShell** (user session is enough).
2. Change to the working copy:

```powershell
cd C:\\Talon
```

3. Confirm execution policy will allow a local script. The `.cmd` launchers already pass `-ExecutionPolicy Bypass` for that one file. From PowerShell you can also run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

4. Run setup. The first time, add `-PullModel` so Ollama downloads the coding model (large; can take a long time).

```powershell
.\setup.ps1 -PullModel
```

Or double-click `Install.cmd` (same script; it pauses at the end so you can read the log).

`Install.cmd` does **not** pass `-PullModel`. If you used the double-click installer, pull the model yourself (section 6).

5. Watch for:

```text
Setup finished.
  Start Menu: Talon
  Or: .\run.ps1
  Verify: .\doctor.ps1
```

6. Run the health check before anyone opens real data:

```powershell
.\doctor.ps1
```

Shared PC (front desk / training room): add `-Strict` so the agent does not auto-approve terminal commands.

```powershell
.\setup.ps1 -PullModel -Strict
```

6. If a step fails, open the newest file under `logs\install-*.log` and see [section 12](#12-troubleshooting).

### What `setup.ps1` does, in order

1. Starts a transcript in `logs\`.
2. Installs **Ollama** (payload EXE if present, otherwise `winget install Ollama.Ollama`).
3. Installs **VSCodium** (payload EXE if present, otherwise `winget install VSCodium.VSCodium`).
4. Installs **Python 3.12** via winget only if `py` / `python` is missing.
5. Sets user environment `OLLAMA_HOST=127.0.0.1:11434`.
6. Creates `ide-data\` and `ide-extensions\`.
7. Copies `templates\settings.json` and `templates\argv.json` into the isolated profile.
8. Optionally replaces VSCodium watermark SVGs with Talon marks (unsigned resource files only; it does **not** patch `VSCodium.exe`).
9. Installs **Cline** (`saoudrizwan.claude-dev`) into the isolated extensions dir.
10. Runs `seed_cline.py` so Cline is Ollama-only, telemetry off, ClinePass banners dismissed, web/MCP off.
11. Installs Open VSX extensions: Python, debugpy, Ruff, SQLTools, SQLTools SQLite, Jupyter.
12. Runs `setup-datasci.ps1` (venv + pip + empty SQLite).
13. Creates Start Menu and Desktop shortcuts that launch `Launch-LocalCoder.vbs` → `run.ps1`.

Useful switches:

```powershell
.\setup.ps1                    # apps + extensions + venv; no model pull
.\setup.ps1 -PullModel         # also ollama pull qwen3-coder:30b
.\setup.ps1 -PullModel -Model qwen2.5-coder:14b
.\setup.ps1 -SkipDeps          # profile + extensions only (apps already installed)
.\setup.ps1 -NoShortcuts
```

---

## 6. Download the model

If you did not pass `-PullModel`:

```powershell
ollama pull qwen3-coder:30b
```

Confirm Ollama is listening and the model is present:

```powershell
curl.exe http://127.0.0.1:11434/api/tags
```

You should see JSON that includes `"name":"qwen3-coder:30b"` (or the model you chose).

If 24 GB VRAM is not available, pick a smaller coding model and re-run seed after it is pulled:

```powershell
ollama pull qwen2.5-coder:14b
python .\seed_cline.py .\ide-data
```

`seed_cline.py` prefers, in order: `qwen3-coder:30b`, then other qwen3-coder tags, then `qwen3:30b-a3b`, then `codellama`, then `llama3`.

Do **not** pull a second 30B “SQL model” on a 24 GB card. The coding model plus a real local Python/SQL toolchain is the intended design.

---

## 7. First launch

```powershell
cd C:\\Talon
.\run.ps1
```

Or use **Start Menu → Talon** or `Start Talon.cmd`.

`run.ps1` will:

1. Start Ollama if `http://127.0.0.1:11434/api/tags` does not answer.
2. Re-apply `templates\settings.json` (interpreter + SQLite paths).
3. Re-run `seed_cline.py`.
4. Put `.venv\Scripts` on PATH for that process (`PYTHONNOUSERSITE=1`).
5. Block GitHub remotes **in this process only** (`GIT_CONFIG_COUNT` `insteadOf`). Clear `GH_TOKEN` / `GITHUB_TOKEN`.
6. Set `CLINE_DIR` to `ide-data\cline-home` so Cline does not open a cloud free-model picker from `%USERPROFILE%\.cline`.
7. Launch VSCodium with `--user-data-dir` and `--extensions-dir` pointed at this folder.

The first time, if no last workspace is stored, it opens this kit folder. To open a project:

```powershell
.\run.ps1 -Workspace "D:\Work\MyProject"
```

The path is remembered in `ide-data\last-workspace.txt`.

### First-run checklist (do this once)

1. Title bar says **Talon**.
2. Right sidebar is **Cline** (robot), already open.
3. Cline **API Provider = Ollama**, base URL `http://127.0.0.1:11434`.
4. Model is `qwen3-coder:30b` (or the smaller model you pulled).
5. You are **not** asked to “Create my Account” / pick a free cloud model. If you are, close Cline, run `python .\seed_cline.py .\ide-data`, then `.\run.ps1` again.
6. Auto-approve: Read, Edit, and Commands may be on. **Web Fetch and MCP stay off.**
7. Left activity bar: Explorer is active. Source Control (git) icon is hidden.
8. Status bar / Python interpreter: `.\.venv\Scripts\python.exe`.
9. SQLTools connection **Local SQLite** points at `data\local.sqlite`.
10. Do not sign in to GitHub. GitHub login is disabled in this profile.

Type a simple prompt in Cline, for example: “Create `data\hello.py` that prints hello, run it with the venv python.” Confirm it uses `.venv\Scripts\python.exe`.

---

## 8. Verify Python and SQL

```powershell
cd C:\\Talon
.\.venv\Scripts\python.exe -c "import pandas, numpy, sklearn, sqlalchemy, matplotlib; print('ok', pandas.__version__)"
.\.venv\Scripts\python.exe -c "import sqlite3; sqlite3.connect(r'data\local.sqlite').execute('create table if not exists smoke(id int)'); print('sqlite ok')"
```

In the editor:

- Open a `.py` file → Ruff should be the formatter.
- Open SQLTools → connect **Local SQLite**.
- Do **not** `pip install openai`, `anthropic`, or Azure/Google LLM SDKs into this venv.

To rebuild the venv later:

```powershell
.\setup-datasci.ps1
```

---

## 9. Optional: lock VSCodium off the public internet

Elevated PowerShell:

```powershell
cd C:\\Talon
.\harden-firewall.ps1
```

This adds LocalCoder firewall rules: allow `127.0.0.1` / `::1`, block Internet for `VSCodium.exe`.

Confirm in Resource Monitor that VSCodium has no public sockets. Rule order on Windows can be sensitive; treat this as a **defense in depth** layer, not a guarantee.

Remove later:

```powershell
Get-NetFirewallRule | Where-Object DisplayName -like 'LocalCoder *' | Remove-NetFirewallRule
```

Do this **after** install and model pull. If you firewall first, winget / Open VSX / `ollama pull` will fail.

---

## 10. Offline / air-gapped install

1. On a networked PC, download publisher-signed installers (do not rename):

```powershell
cd C:\\Talon
winget download -e --id VSCodium.VSCodium -d payload --accept-package-agreements --accept-source-agreements
winget download -e --id Ollama.Ollama -d payload --accept-package-agreements --accept-source-agreements
```

2. Download the Cline `.vsix` from [Open VSX: saoudrizwan.claude-dev](https://open-vsx.org/extension/saoudrizwan/claude-dev) and place it in `payload\`.
3. Copy `payload\` plus this folder to the air-gapped PC.
4. Run `.\setup.ps1` (it prefers `payload\` over winget).
5. Open VSX extensions (Python, Ruff, SQLTools, Jupyter) still need a `.vsix` each if that PC has no internet. Download those from Open VSX on the networked PC and `codium --install-extension` them with the same `--user-data-dir` / `--extensions-dir` as in `setup.ps1`, or run setup once on a networked machine and copy `ide-extensions\` (extensions only — not `ide-data` if it already has PHI).
6. Copy an already-pulled Ollama model (Ollama’s model directory) per Ollama’s own docs, or pull on a networked box and transfer the blobs.

`payload\README.txt` lists the expected file names.

---

## 11. Daily use

```powershell
cd C:\\Talon
.\run.ps1
# or
.\run.ps1 -Workspace "D:\Work\MyProject"
```

Habits:

- Keep Cline on **Ollama**. If anyone picks OpenAI / Anthropic / OpenRouter / ClinePass, prompts leave the box.
- Keep Web Fetch and MCP off.
- Save query output under `data\` on this PC. Do not gist it.
- Git remotes to github.com fail **inside Talon only**. Everyday git outside this window is unchanged.
- Do not open this working copy in a hosted IDE or Microsoft VS Code for PHI work.

---

## 12. Troubleshooting

| Symptom | What to do |
|---------|------------|
| `VSCodium is missing` | Re-run `.\setup.ps1`. Open a **new** terminal if winget just installed it (`$env:Path` refresh). |
| `Isolated profile is missing` | Re-run `.\setup.ps1`. |
| Ollama not running | Start Ollama from the Start Menu, or `.\run.ps1` will try `ollama serve`. Check `http://127.0.0.1:11434/api/tags`. |
| Cline shows “Create my Account” / free cloud models | You launched without `CLINE_DIR`. Use `.\run.ps1` (not a raw VSCodium shortcut). Then `python .\seed_cline.py .\ide-data`. |
| ClinePass banner | Re-run seed. Banner ids are dismissed in `seed_cline.py`. |
| Agent stuck on “Proceed While Running” | Seed sets `vscodeTerminalExecutionMode=backgroundExec`. Re-run `.\run.ps1`. Avoid `&&` chains that never exit. |
| Git parent-repo toast | Settings force `git.openRepositoryInParentFolders=never`. Open a project folder, not `E:\github` as the workspace. |
| Desktop shortcut does nothing | Shortcut must call `wscript.exe` + `Launch-LocalCoder.vbs`. Re-run `.\setup.ps1` to recreate it. |
| Title bar still looks like VSCodium | Cosmetic only. `setup.ps1` copies SVGs into `resources\app\out\media`. It will not patch `VSCodium.exe` (that would break Authenticode). |
| winget blocked by policy | Use section 10 (`payload\`). |
| SmartScreen on a custom Setup.exe | Expected if unsigned. Prefer the zip + `Install.cmd`. See [IT.md](IT.md). |
| Python packages fail | Confirm `py -3 --version`. Re-run `.\setup-datasci.ps1`. |
| Out of VRAM / model tiny-slow | Use a smaller model (section 6). Do not load two 30B models. |
| Script is blocked | `Unblock-File` the scripts after you trust the hash/source. |
| Not sure the box is still local | Run `.\doctor.ps1`. FAIL on Cline provider means someone left Ollama. |

---

## 13. Uninstall

```powershell
cd C:\\Talon
.\Uninstall-LocalCoder.ps1
```

That removes Start Menu shortcuts. It leaves VSCodium and Ollama installed unless you pass `-RemoveDeps` (those apps may be used for other work).

Then delete the working folder in Explorer (`C:\\Talon`), including `ide-data` and `data` if they hold PHI — follow your agency’s media sanitization procedure.

Firewall rules (if you applied them):

```powershell
Get-NetFirewallRule | Where-Object DisplayName -like 'LocalCoder *' | Remove-NetFirewallRule
```

---

## 14. Share with another workstation (same agency)

Do **not** email a used kit that already has `ide-data` or `data\*.sqlite`. Pack from a clean copy, or use the updater on the receiving PC.

```powershell
.\Pack-ShareKit.ps1
```

On the receiving PC, if Talon is already installed:

```powershell
.\Update-LocalCoder.ps1 -From "D:\Incoming\Local_AI"
python .\seed_cline.py .\ide-data
.\doctor.ps1
```

Send `dist\LocalCoder-1.1.0.zip` and `dist\SHA256SUMS.txt` for a first-time drop. Recipients follow section 4 option C, then section 5.

IT notes, Intune sketch, and Authenticode: [IT.md](IT.md). Small-team rules: [TEAM.md](TEAM.md).

---

## 15. What not to do

- Do not claim this install is HIPAA certified.
- Do not put PHI in Copilot, a hosted chat, or this GitHub repo.
- Do not instruct staff to turn off Defender or SmartScreen.
- Do not wrap VSCodium + Ollama in ps2exe / a self-extracting EXE.
- Do not `pip install` hosted LLM SDKs into `.venv`.
- Do not sign in to a Cline account or paste cloud API keys.
- Do not run `setup.ps1` inside the public git clone and commit the result.
- Do not test mutating EHR SQL in Prod from this (or any) editor.
