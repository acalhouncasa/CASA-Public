# SmartCare

Optional packages and patterns for **Streamline SmartCare**. Not Streamline Help Center content. Vendor docs: [support.smartcarenet.com](https://support.smartcarenet.com/).

**Do not test in Prod.**

## Packages and patterns

| Folder | What it is | Completeness |
|--------|------------|--------------|
| [Staff_Appointment_Overlap/](Staff_Appointment_Overlap/) | Busy staff double-book hard-stop | Full SQL (apply / unwire / drop) |
| [Missing_Client_Signature_Flag/](Missing_Client_Signature_Flag/) | Chart flag when staff signed / client pad open | Full SQL (Flag Types, sync ssp, clear trigger, undo) — replace **`AGENCYID`** |
| [Client_Chart_Flags_Report/](Client_Chart_Flags_Report/) | Client chart flags report | Full SQL + RDL |
| [DFA_From_PDF/](DFA_From_PDF/) | Build a new DFA from PDF/screenshots | Process + starter generator |
| [GlobalCodes/](GlobalCodes/) | Add picklist category + codes | SQL template |
| [Scoring/](Scoring/) | DFA FormJavascript live totals | JS examples + verify + wire SQL |
| [CIWA_Live_Scoring/](CIWA_Live_Scoring/) | Portable CIWA-Ar live total pattern | JS + wire SQL |
| [FormItem_Column_Alignment/](FormItem_Column_Alignment/) | Truncation / wrong-control discovery | Discovery SQL |
| [Ad_Hoc_Reporting/](Ad_Hoc_Reporting/) | Custom SQL via Adhoc views + CatalogReports | Method + view/report SQL templates — replace **`AGENCYID`** |
| [Client_Tracking/](Client_Tracking/) | Flags + Tracking Protocols (method) | Method; signature pack is separate |
| [DFA_Initialization/](DFA_Initialization/) | Initialization Editor (UI how-to) | Method only (pairs are site-specific) |
| [Consent_Wiring/](Consent_Wiring/) | Consent DocumentCode wiring | Method only (legal text is site-specific) |
| [Discovery_Readonly/](Discovery_Readonly/) | Read-only discovery SELECTs | Sample scripts |
| [Change_Impact_Scan/](Change_Impact_Scan/) | Scan consumers before hide/relocate | Checklist + discovery SQL |
| [Paper_Forms_Blank_Packet/](Paper_Forms_Blank_Packet/) | Blank print PDF from live FormItems | Process + discovery + starter builder |

## Conventions

- F5 the whole SQL file.
- No `USE` of a customer database name in portable scripts (select the DB in SSMS).
- Replace the token **`AGENCYID`** with your site prefix on object names and stamps (keep stamps ≤ 30 characters).
- GRANT to `public` only when a package grants execute.
- Kill-switch / undo scripts next to apply scripts when the package mutates live behavior.
- Do not publish PHI, credentials, host names, or another agency’s DocumentCode catalog as if it were yours.
