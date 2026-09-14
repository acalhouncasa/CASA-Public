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
