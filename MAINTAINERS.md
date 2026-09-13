# Maintainers (CASA-Trinity only)

This file is for people who publish to **CASA-Public**. It is not end-user documentation.

## Private vs public (hard rule)

| Path | Role |
|------|------|
| `C:\github\` (including `casapython`) | **Private.** Internal ops, EHR work, credentials helpers, client data paths, CASA-only SQL, Rules, Automation, reports. |
| `C:\GitHub_Public\` → [acalhouncasa/CASA-Public](https://github.com/acalhouncasa/CASA-Public) | **Public.** Only material explicitly prepared for outside readers. |

**Nothing from `C:\github` may be copied, synced, mirrored, or pushed into this public repository** unless Alan has approved a **new public-facing rewrite** written under `C:\GitHub_Public`.

That includes (not exhaustive):

- Private repo folders (`Smart Care/`, `Rules/`, `Automation/`, `Reports/`, `10e11/`, `.cursor/`, etc.)
- Prod/Train database names, host names, login names, `SC SQL.txt` references
- Zendesk tickets, Outlook/Graph caches, Power BI exports, PHI
- CASA-only object names (`ssp_CASA…`, `CASASmartcareProd`, kill-switch keys prefixed `CASA…`) when a portable public package uses different names

## How to add something public

1. Author (or re-author) the files **inside** `C:\GitHub_Public\…`.
2. Strip CASA-only names, credentials, and internal runbooks.
3. Add a local README for that item.
4. Update the root [README.md](README.md) table if you add a new top-level topic.
5. Commit and push **from** `C:\GitHub_Public` only.

Do **not** `git subtree`, robocopy, or submodule `C:\github` into this repo.

## SmartCare packages

Portable SmartCare items still live under [SmartCare/](SmartCare/). See that folder’s README for SQL conventions.
