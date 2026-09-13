# Staff Appointment Overlap Hard-Stop

Prevent the same staff member from holding two **Busy** appointments at the same time, on every SmartCare path that writes `Appointments`.

Portable SQL for any SmartCare customer database. Select the target database in SSMS before you run. There is no `USE` statement and no host-name guard.

**Formatted PDF:** [CASA_StaffAppointmentOverlap_Technical_Guide.pdf](CASA_StaffAppointmentOverlap_Technical_Guide.pdf)

CASA-Trinity · Shared SmartCare packaging · 09/12/2026

## Deploy the package

Goal: hard-stop is on, Screen 46 is wired when safe, and you have a kill-switch.

1. Open SSMS connected to the target SmartCare database (Train or a test copy first).
2. Run [SC_StaffAppointmentOverlap_apply_COMMIT.sql](SC_StaffAppointmentOverlap_apply_COMMIT.sql) start to finish (F5).
3. Confirm the result grids:
   - Deployed = Y
   - Trigger = `tr_Appointments_SOHS` enabled
   - KillSwitch Value = Yes
   - Screen46 validate = `ssp_ValidateGroupServiceOverlap` (or apply stopped because another validate was already wired)
4. Tell help desk the key name `StaffAppointmentOverlapHardStop` for a fast Off.

GRANT EXECUTE is to `public` only. No named logins. `ModifiedBy` uses `SUSER_SNAME()`.

## Verify it works

Use a test staff calendar that starts empty.

1. Save a Busy appointment at 1:00PM–2:00PM.
2. Try a second Busy at the same time for the same staff. Expect a hard **STOP** message with **TRY** times. The second appointment must not remain.
3. Save Busy at 2:00PM–3:00PM (empty). Expect a normal save.

SmartCare may show its own soft “Save anyway?” first. Ignore that for pass/fail. Grade only the hard `STOP: … TRY …` message after OK.

Expected message shape (Error! banners may flatten newlines):

```
STOP: Last, First is booked mm/dd/yyyy h:mmAM-h:mmPM for {name} (N meetings). TRY (60 min): mm/dd/yyyy …
```

Do not expect GroupService ids in staff-facing text.

## Understand how it works

Custom Pages for Staff Calendar and recurrence have no validation stored-procedure hooks. Group Service Detail (Screen 46) can call a validate proc, but that alone misses calendar and series creates. This package uses a shared helper plus an `Appointments` AFTER INSERT/UPDATE trigger so every Busy write is covered.

| Path | What runs |
|------|-----------|
| Staff Calendar / New Event | Writes Appointments, then the trigger |
| Recurrence / series | Batch insert, then the trigger (siblings in the same batch are excluded) |
| Group Service Detail | Screen 46 validate plus the trigger |

All Busy paths call `ssp_StaffAppointmentOverlapCheck`. The kill-switch key must be Yes.

**On save (bottom OK):** After any vendor soft warning, SmartCare writes Busy appointment rows. The trigger checks each Busy staff row in that batch, including Additional Staff.

**Mid-form Insert:** Stages Additional Staff on the form only. It does **not** run the overlap check. OK does.

## What is blocked

| Situation | Hard-stop? |
|-----------|------------|
| Same staff, overlapping Busy times | Yes |
| Partial overlap (for example 1:00–2:00 vs 1:30–2:30) | Yes |
| Different staff, same clock time | No |
| Show Time As Free / Tentative / Out Of Office | No |
| Prior meeting Cancelled / No Show / Rescheduled only | No (slot reusable) |
| Clean recurring series on empty hours | No (batch self-exclude) |

## Object catalog

Trigger abbrev **SOHS** = Staff Appointment Overlap Hard Stop (capitals S, A, O, H, S minus second-word A).

| Object | Name | Role |
|--------|------|------|
| Procedure | `ssp_StaffAppointmentOverlapCheck` | Shared Busy check + STOP/TRY message |
| Procedure | `ssp_ValidateGroupServiceOverlap` | Screen 46 Detail validate wrapper |
| Trigger | `tr_Appointments_SOHS` | Hard-stop on Appointments INSERT/UPDATE |
| Config key | `StaffAppointmentOverlapHardStop` | Yes = on, No = off without DROP |
| Screen wire | ScreenId **46** | `ValidationStoredProcedureUpdate` when empty or already ours |

## Files

| File | Purpose |
|------|---------|
| [SC_StaffAppointmentOverlap_apply_COMMIT.sql](SC_StaffAppointmentOverlap_apply_COMMIT.sql) | Create helper, validate, trigger, key=Yes, wire Screen 46 |
| [SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql](SC_StaffAppointmentOverlap_unwire_screen46_COMMIT.sql) | Clear Screen 46 validate only. Leave the trigger. |
| [SC_StaffAppointmentOverlap_drop_trigger_COMMIT.sql](SC_StaffAppointmentOverlap_drop_trigger_COMMIT.sql) | DROP the trigger and set the kill-switch to No |
| [CASA_StaffAppointmentOverlap_Technical_Guide.pdf](CASA_StaffAppointmentOverlap_Technical_Guide.pdf) | Same guide as this README, formatted for print |

## Disable or undo

1. **Fast Off:** set `StaffAppointmentOverlapHardStop` = **No**.
2. **Remove the hard-stop:** run [SC_StaffAppointmentOverlap_drop_trigger_COMMIT.sql](SC_StaffAppointmentOverlap_drop_trigger_COMMIT.sql) (DROP `tr_Appointments_SOHS` and set key No).
3. **Detail only:** run the Screen 46 unwire script if Detail validate should go away but calendar protection should stay.

If Screen 46 already has a different `ValidationStoredProcedureUpdate`, apply will not overwrite it. The trigger still protects calendar and recurrence paths.

The apply script does not drop the helper procedures. Leaving `ssp_StaffAppointmentOverlapCheck` in place is harmless after the trigger is dropped.

## Assumptions

- Standard Streamline SmartCare with `dbo.Appointments`, `GlobalCodes` categories SHOWTIMEAS and PCAPPOINTMENTSTATUS, `Screens`, and `SystemConfigurationKeys`.
- Group Service Detail is ScreenId **46** on typical builds. Confirm if your site customized screens.
- Deployer can CREATE PROCEDURE / TRIGGER and UPDATE Screens and SystemConfigurationKeys.
- Coexists with other AFTER triggers on Appointments via a nest-level guard on this trigger.

## Recurring series notes

- The entire inserted batch `AppointmentId` list is excluded from conflict lookup.
- A clean multi-week series on empty hours can save without self-blocking.
- A second series that collides with an existing Busy row is blocked.

## License and caution

[MIT](../../LICENSE). Read [NOTICE.md](../../NOTICE.md) before production. CASA-Trinity is not Streamline. Test in Train first.
