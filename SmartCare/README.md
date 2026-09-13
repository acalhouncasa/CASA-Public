# SmartCare

Portable SQL and guides for other **Streamline SmartCare** customers. Scripts target a standard SmartCare database. In SSMS, select the correct database first. These files do not contain CASA-Trinity database names or named logins.

This is one topic under the public repo. Other non-SmartCare folders may appear at the repo root later.

## Packages

| Package | Audience | Apply script |
|---------|----------|----------------|
| [Staff Appointment Overlap](Staff_Appointment_Overlap/) | Implementers / IT | `SC_StaffAppointmentOverlap_apply_COMMIT.sql` |

## Conventions

- **F5 the whole file.** Do not run a highlighted section.
- **GRANT** is to `public` only.
- **Kill-switch** keys use Yes/No so help desk can turn a feature off without dropping objects.
- **Undo** scripts live next to apply scripts.

## Adding a SmartCare package (CASA maintainers)

Create `SmartCare/<Package_Name>/` with:

- `README.md` (how to deploy, verify, disable)
- Apply / undo SQL (portable, no `USE`)
- Technical PDF when the package needs implementer documentation

Then add a row to the table above and to the root [README.md](../README.md).

**Never** copy from `C:\github`. See [MAINTAINERS.md](../MAINTAINERS.md).
