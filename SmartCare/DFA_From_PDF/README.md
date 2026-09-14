# Build a SmartCare DFA from PDF / screenshots (code + AI)

Turn a paper form or screenshots into a **new** SmartCare DFA using a JSON spec, generated SQL, and an AI coding agent — without running vendor **DFA Export SQL** as-is.

**Do not test in Prod.**

| Doc | Topic |
|-----|--------|
| [PROCESS.md](PROCESS.md) | End-to-end steps |
| [FORM_SPEC.md](FORM_SPEC.md) | What goes in the JSON spec |
| [starter/](starter/) | **Runnable** Python generator + schema |
| [examples/FORM_SPEC_EXAMPLE.json](examples/FORM_SPEC_EXAMPLE.json) | Minimal example (matches starter) |
| [PITFALLS.md](PITFALLS.md) | Layout, GlobalCodes, PDF, promote |
| [PROMOTE.md](PROMOTE.md) | Greenfield vs merge when the form already exists |
| [AI_PROMPT.md](AI_PROMPT.md) | What to ask the agent |

Related public packs: [GlobalCodes/](../GlobalCodes/), [Scoring/](../Scoring/), [FormItem_Column_Alignment/](../FormItem_Column_Alignment/), [AI/Working_With_Cursor/](../../AI/Working_With_Cursor/).

## Idea in one picture

```text
PDF / screenshots
      ↓
 FORM_SPEC.json   (table, sections, fields, ItemTypes, GUIDs)
      ↓
 starter/generate_dfa_sql.py → 01_precheck / 02_globalcodes / 03_apply / 04_postcheck
      ↓
 Human F5s mutating SQL in SSMS (one file at a time)
      ↓
 Shared Tables Refresh → log out/in → New document → save / sign / PDF
```

## Why not “Export SQL” as-is?

Vendor export often hard-codes sample **FormId / DocumentCodeId / ScreenId / FormCollectionId**. On a live database that collides or attaches your form to someone else’s collection.

Portable pattern:

- Insert **without** `IDENTITY_INSERT` of stolen ids.
- Match reruns by **GUID** (`Forms.FormGUID`, document/screen codes).
- Always create a **new** `FormCollections` row for a greenfield form.
- Keep the same GUIDs when you deploy the **same** new form to another environment that does not have it yet.
