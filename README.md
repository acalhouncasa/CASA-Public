# CASA-Trinity public repository

CASA-Trinity shares optional **SmartCare** add-ons that other Streamline SmartCare agencies may find useful. This is not a dump of our internal EHR, reports, or client data.

**Maintainer:** Alan Calhoun, Senior Data Analyst, CASA-Trinity  
**GitHub user:** [acalhouncasa](https://github.com/acalhouncasa)

Start here:

1. Read [NOTICE.md](NOTICE.md) (not a Streamline product, test in Train first).
2. Open [SmartCare/](SmartCare/) for the package list.
3. Each package folder has a README, SQL you can F5 in SSMS, and a technical PDF when one exists.

## Current packages

| Folder | What it does |
|--------|----------------|
| [SmartCare/Staff_Appointment_Overlap](SmartCare/Staff_Appointment_Overlap/) | Hard-stop when the same staff person is already **Busy** at that time. Covers Staff Calendar, recurrence, and Group Service Detail. |

## What this repo is not

- Not official Streamline / SmartCare documentation
- Not CASA-Trinity's private operations repository
- Not a place for PHI, credentials, or production connection details

## License

[MIT](LICENSE). Scripts are provided as-is. Your agency owns testing, backups, and production change control.

## Contact

Questions about a package: open a GitHub issue (no PHI).  
Security: see [SECURITY.md](SECURITY.md).
