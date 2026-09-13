# Never partial code

When someone needs code to **run, paste, or deploy**, deliver the **complete artifact**.

## Mandatory

| Situation | Do |
|-----------|-----|
| Power Query / M | Full `let` … `in` |
| SQL in SSMS | Full script, F5-safe start to finish |
| Python / PowerShell | Full file or full callable block |
| Config | Complete valid document |

## Forbidden in paste-ready output

- Middle sections with `...` / “rest unchanged”
- “Insert after step X” without the entire replacement file
- Partial queries that reference steps not included

## When too long for chat

1. Write the complete file in the repo.
2. Link the file.
3. Say **replace all** in the editor / Advanced Editor.
