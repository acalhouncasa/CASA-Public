# Maintainers

Internal notes for people who publish to **CASA-Public**. Not end-user documentation.

## Private vs public (hard rule)

| Path | Role |
|------|------|
| `C:\github\` (including `casapython`) | **Private.** Do not publish as-is. |
| `C:\GitHub_Public\` → [acalhouncasa/CASA-Public](https://github.com/acalhouncasa/CASA-Public) | **Public.** Only material prepared for outside readers. |

**Nothing from `C:\github` may be copied, synced, mirrored, or pushed into this public repository** unless a **new public-facing rewrite** is authored under `C:\GitHub_Public`.

That includes private repo folders, host names, login names, credential files, ticket corpora, exports with PHI, and site-only object names when the public package uses portable names.

## How to add something public

1. Author files **inside** `C:\GitHub_Public\…`.
2. Keep root docs general. Put product detail in the topic folder.
3. Strip site-only names, credentials, and internal runbooks.
4. Update the root [README.md](README.md) topic table when you add a new top-level folder.
5. Commit and push **from** `C:\GitHub_Public` only.

Do **not** `git subtree`, robocopy, or submodule `C:\github` into this repo.

## Wording

- Root: general (what the repo is, license, no PHI, do not test in Prod).
- Folders: product-specific steps, object names, and verify checks.
