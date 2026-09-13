# SmartCare

Optional packages and patterns for **Streamline SmartCare**. Not Streamline Help Center content. Vendor docs: [support.smartcarenet.com](https://support.smartcarenet.com/).

**Do not test in Prod.**

## Packages and patterns

| Folder | What it is |
|--------|------------|
| [Staff_Appointment_Overlap/](Staff_Appointment_Overlap/) | Busy staff double-book hard-stop (SQL) |
| [GlobalCodes/](GlobalCodes/) | Add picklist category + codes (SQL template) |
| [Scoring/](Scoring/) | DFA FormJavascript live totals |
| [FormItem_Column_Alignment/](FormItem_Column_Alignment/) | Truncation / wrong-control discovery SQL |
| [Ad_Hoc_Reporting/](Ad_Hoc_Reporting/) | Custom SQL via Adhoc views + CatalogReports |
| [CIWA_Live_Scoring/](CIWA_Live_Scoring/) | Portable CIWA-Ar live total pattern |
| [Client_Tracking/](Client_Tracking/) | Flags + Tracking Protocols (method) |
| [DFA_Initialization/](DFA_Initialization/) | Initialization Editor (UI how-to) |
| [Consent_Wiring/](Consent_Wiring/) | Consent DocumentCode wiring (method) |
| [Discovery_Readonly/](Discovery_Readonly/) | Read-only discovery habits + sample SELECTs |
| [Change_Impact_Scan/](Change_Impact_Scan/) | Scan consumers before hide/relocate |

## Conventions

- F5 the whole SQL file.
- No `USE` of a customer database name in portable scripts (select the DB in SSMS).
- GRANT to `public` only when a package grants execute.
- Kill-switch / undo scripts next to apply scripts when the package mutates live behavior.
