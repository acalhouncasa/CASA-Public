# SmartCare Power BI — Desktop-first build

## Rule

**Do not hand-author new Power Query M inside TMDL** for a greenfield SmartCare dashboard. Let Power BI Desktop create the connection, parameters, and partitions, then Save.

| Deliver in the project folder | Do in Desktop |
|-------------------------------|---------------|
| Verified `.m` / `.sql` text files | Paste into Advanced Editor or Get Data → SQL |
| `RUN_STEPS.md` | Enter SQL credentials locally; approve native query; Refresh; Save |
| Optional DAX text | Paste measures; layout visuals; Save |

Hand-written TMDL M for named SQL instances often fails open (`Token Literal expected` and related parse issues).

## Visual guidance (generic)

- Prefer **native** Power BI charts (no AI chart PNGs for data).
- Optional AI art only for header / atmosphere bands.
- Keep a documented theme (navy/blue/grey works well on printouts).

## Credentials

Never commit SQL passwords or VPN profiles to a public repo. Each analyst enters credentials in Desktop on their PC.

**Do not test against Prod** unless your change control says so.
