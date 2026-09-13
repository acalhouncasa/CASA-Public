# SmartCare

Optional packages for **Streamline SmartCare**. These are not Streamline Help Center materials. Streamline does not review or support them. Use vendor documentation for product questions: [SmartCare support](https://support.smartcarenet.com/).

Scripts target a standard SmartCare database. In SSMS, select the correct database first. There is no `USE` of a customer database name and no named SQL logins.

**Do not test in Prod.**

## Packages

| Package | Audience | Apply script |
|---------|----------|----------------|
| [Staff Appointment Overlap](Staff_Appointment_Overlap/) | Implementers / IT | `SC_StaffAppointmentOverlap_apply_COMMIT.sql` |

## Conventions

- **F5 the whole file.** Do not run a highlighted section.
- **GRANT** is to `public` only.
- **Kill-switch** keys use Yes/No so help desk can turn a feature off without dropping objects.
- **Undo** scripts live next to apply scripts.

## Adding a package (maintainers)

Create `SmartCare/<Package_Name>/` with a README, apply/undo SQL (portable, no `USE`), and a technical PDF when needed. Update this table and the root [README.md](../README.md).

See [MAINTAINERS.md](../MAINTAINERS.md).
