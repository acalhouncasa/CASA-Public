# Publish log — 09/13/2026

Alan marked **Y** on Desktop `CASA_Public_Share_Candidates_2026-09-12.xlsx`. This log records what shipped as **portable rewrites** under `C:\GitHub_Public` (never a dump of `C:\github`).

## Shipped

See topic folders. All SQL/docs are rewritten without customer database names, host names, named logins, or site-only catalogs.

## Method-only (Y, but no site SQL/catalogs)

| Candidate | Public path | Why not full code |
|-----------|-------------|-------------------|
| Consent wiring | `SmartCare/Consent_Wiring/` | Legal forms are site-specific; pattern only |
| Client Tracking / To Do seeds | `SmartCare/Client_Tracking/` | Form due matrices are site-specific |
| DFA Initialization pairs | `SmartCare/DFA_Initialization/` | Form pairs are site-specific; UI how-to only |
| Read-only discovery kit | `SmartCare/Discovery_Readonly/` | Pattern + generic SELECTs; not a private script dump |
| Data table reasoning | `Guides/Data_Table_Reasoning_Template/` | Empty template; not live table dumps |
| REPO_FIND | `Guides/Repo_Intent_Router/` | Template structure; not private inventory |
| Python env setup | `Guides/Python_Env_Setup/` | Generic venv guide; not a private-repo clone guide |
| SC PBI Desktop build | `Guides/SmartCare_PBI_Desktop_Build/` | Desktop-first rules; no credentials or site theme assets |

## Already public

| Candidate | Path |
|-----------|------|
| Staff Appointment Overlap | `SmartCare/Staff_Appointment_Overlap/` |

## Hard exclusions (even if useful internally)

Anything that only works with this agency’s private tree, credentials helpers, ticket corpora, named client/group Fix folders, or filled leadership reports stays out of this repo.

---

## 09/14/2026 — DFA + Cursor workflow

| Public path | What |
|-------------|------|
| `SmartCare/DFA_From_PDF/` | Portable process: PDF → FORM_SPEC → generated SQL → SSMS; pitfalls; promote; example prompt |
| `SmartCare/DFA_From_PDF/starter/` | Sanitized `generate_dfa_sql.py` + schema (MIT); smoke-tested on example |
| `AI/Working_With_Cursor/` | Human vs agent roles, chat habits, safety |

Site form packs and private-only helpers stay in the private repo. Public starter uses placeholders (`YourSmartCareDatabase`), not agency hosts or logins.

---

## 09/18/2026 — Local Coder (on-device AI)

| Public path | What |
|-------------|------|
| `Local_AI/` | Portable kit: VSCodium + Cline + Ollama on `127.0.0.1`. Scripts, branding, Python/SQL venv setup. |
| `Local_AI/INSTALL.md` | Full workstation install, verify, offline, uninstall |
| `Local_AI/HIPAA.md` | Use-at-your-own-risk limits plus every control we shipped |
| `Local_AI/HOW_IT_WORKS.md` | Architecture (isolated profile, Cline seed, GitHub block) |

Runtime folders (`ide-data`, `.venv`, `data/*.sqlite`) are gitignored. No PHI, no personal analysis notebooks, no packed EXEs. Not HIPAA certified.

---

## 09/19/2026 — Local Coder 1.1.0 (small team)

| Public path | What |
|-------------|------|
| `Local_AI/TEAM.md` | Per-user kit, updates, shared vs local, Strict mode |
| `Local_AI/doctor.ps1` | Health check (Ollama, model, venv, Cline provider) |
| `Local_AI/Update-LocalCoder.ps1` | Refresh scripts without wiping ide-data / SQLite |
| `Local_AI/examples/` | Synthetic monthly encounters (not PHI) |

---

## 09/20/2026 — Talon — Local AI 1.4.3

| Public path | What |
|-------------|------|
| `Local_AI/` | **1.4.3.** Quoted launch (`Open-Talon.cmd`) so paths with spaces do not become extra Explorer roots. |
| `Local_AI/seed_cline.py` | Disable `vscode.git`, `vscode.git-base`, and `ms-python.vscode-python-envs`. Record the real VSCodium version so Release Notes do not reopen. |
| `Local_AI/templates/settings.json` + `learn/apply_sources.py` | Rebuild settings from the template. Git parent-folder prompt is Never. SQLTools does not auto-connect or toast Node/`sqlite3` on launch. Windows Python interpreter path. |
| `Local_AI/extensions/talon.talon-guard-1.3.0` | Guard 1.3.0 (Open Folder adds; Getting started HTML). Replaces 1.0.0. |
| `Local_AI/USAGE.md` | Getting started 1.4.3 |

---

## 09/20/2026 — Talon — Local AI 1.2.0

| Public path | What |
|-------------|------|
| `Local_AI/` | Rebranded as **Talon — Local AI** (icons, shortcuts, window title) |
| `Local_AI/learn/talon_learn.py` | Background learner: data maps + lessons, no cell values |
| `Local_AI/LEARN.md` | How memory works |
| `Local_AI/memory/README.txt` | Runtime memory is local-only; not committed |
