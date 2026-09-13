# DFA live scoring (FormJavascript)

Show a running total on a SmartCare DFA while the clinician selects radios or similar controls.

**Do not test in Prod.**

## Two approaches

| Approach | When | Where |
|----------|------|-------|
| Form JavaScript | Live total while documenting | `Forms.FormJavascript` + `IsJavascriptOverride = Y` |
| Stored procedure | PDF / SSRS / batch | Your RDL dataset proc |

You can use both.

## Design

1. Name scored radio columns with a shared prefix (example: `Score…`).
2. Add a total column (example: `ScoreTotal`) and matching FormItem.
3. GlobalCodes for scored options: numeric points in **External Code 1** / `Code` (`0`,`1`,`2`…).
4. Wire JS on the **Forms** header row (not a FormItem on the designer canvas).
5. Shared Tables → Refresh. Log out / in. Test on a **new** document.

## Files

| File | Purpose |
|------|---------|
| [examples/scoring_total_from_radios.js](examples/scoring_total_from_radios.js) | Likert-style sum via `parseInt` on radio values |
| [examples/scoring_yes_count_radioyn.js](examples/scoring_yes_count_radioyn.js) | Count Yes on RADIOYN (do not parseInt Y/N) |
| [sql/verify_scoring_formitems_and_globalcodes.sql](sql/verify_scoring_formitems_and_globalcodes.sql) | Read-only verify |

## Pitfalls

| Symptom | Likely cause |
|---------|----------------|
| Total always 0 on Likert | `GlobalCodes.Code` / External Code 1 is NULL or non-numeric |
| Total always 0 on Yes/No | Script used `parseInt` on Y/N |
| Cannot find JS on item canvas | Expected — script is on Forms header / SQL |
| RADIOYN with DropdownType G | Usually wrong for Y/N ExternalCode1 pattern |
