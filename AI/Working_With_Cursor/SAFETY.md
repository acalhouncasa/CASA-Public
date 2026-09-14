# Safety habits

## Production

**Do not test in Prod.** Apply and UAT on a non-production SmartCare database first. Your organization owns promotion order and backups.

## PHI and secrets

Do not paste client names, chart numbers, passwords, connection strings, or token caches into public issues or public repos.

Prefer chart ids or fake test clients in private chats when you must talk about a record.

## Public vs private

Internal ops repos stay private. Public packs are **rewrites** with portable names and no site hosts/logins. Never mirror a private tree into a public GitHub.

## Mutating SQL

- One concern per file when possible.
- F5 the whole file.
- Prefer numbered `01_precheck` → apply → `04_postcheck`.
- Know the undo path before you apply a hard-stop or trigger.

## Impact scan

Before you hide or move a DocumentCode / screen / Ad-hoc view, scan consumers in the same change.

See [../Agent_Rules/change-impact-scan.md](../Agent_Rules/change-impact-scan.md).
