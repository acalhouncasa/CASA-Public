# Starter — blank paper from FormItems

Runnable Python that reads SmartCare metadata and writes HTML (optional Playwright PDF).

## Requirements

- Python 3.10+
- `pyodbc` + ODBC Driver 17 or 18 for SQL Server
- Optional: `playwright` + Chromium (`playwright install chromium`) for `--pdf`

## Environment

| Variable | Purpose |
|----------|---------|
| `SC_SQL_SERVER` | SQL Server host |
| `SC_SQL_DATABASE` | Database name (select Train/Setup, not Prod for trials) |
| `SC_SQL_USER` | Read-capable login |
| `SC_SQL_PASSWORD` | Password |

No credential files are shipped in this pack.

## Run

```powershell
python build_blank_paper_from_formitems.py --document-code-id 12345 --out ..\examples\out
python build_blank_paper_from_formitems.py --document-code-id 12345 --out ..\examples\out --pdf --logo C:\path\to\logo.png
```

## Notes

- Radio option table names differ by SmartCare version. If option load fails, the starter falls back to Yes/No placeholders for radios.
- This is a **starting point**. Site forms with unusual grids may need local tweaks. See [../LAYOUT.md](../LAYOUT.md) and [../PITFALLS.md](../PITFALLS.md).
- Core Assessment / Rx screens are out of scope ([../LIMITS.md](../LIMITS.md)).
