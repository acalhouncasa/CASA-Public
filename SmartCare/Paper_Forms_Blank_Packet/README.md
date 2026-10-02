# Blank paper packet from FormItems

Build a **blank printable PDF** of an existing SmartCare DFA (or FormCollection document) from live metadata: `DocumentCodes` → `FormCollectionForms` / `Forms` → `FormSections` → `FormSectionGroups` → `FormItems`.

This is for agencies that need a paper handout when SmartCare has no blank template. It is **not** DFA Creation (on-screen form SQL), not FormLab, and not a saved-chart View Document PDF.

**Do not test mutating SQL in Prod.** This pack is read-only discovery plus a local HTML/PDF builder.

## When to use

| Situation | Use this pack? |
|-----------|----------------|
| Multi-tab DFA / FormCollection; all fields on `FormItems` | **Yes** (default path) |
| Single form with FormItems, no collection | **Yes** (builder also loads by `TableList`) |
| Core Assessment tabs, attached docs with 0 FormItems, static RDL labels | **No** — different builder; see [LIMITS.md](LIMITS.md) |
| ePrescribe / Rx screen with no DocumentCode | **No** — screenshot replica, not FormItems |
| You need staff to type into PDF fields (AcroForm) | Optional later; default here is **print-only** |

## Files

| Path | Purpose |
|------|---------|
| [PROCESS.md](PROCESS.md) | End-to-end steps |
| [LAYOUT.md](LAYOUT.md) | Print layout defaults that keep packets short |
| [PITFALLS.md](PITFALLS.md) | Common mistakes |
| [LIMITS.md](LIMITS.md) | What this pattern does not cover |
| [sql/SC_discovery_document_for_paper.sql](sql/SC_discovery_document_for_paper.sql) | Find DocumentCode + tabs |
| [sql/SC_discovery_formitems_for_paper.sql](sql/SC_discovery_formitems_for_paper.sql) | Dump FormItems for one FormId |
| [starter/build_blank_paper_from_formitems.py](starter/build_blank_paper_from_formitems.py) | HTML (+ optional Playwright PDF) from live SQL |
| [examples/](examples/) | Synthetic sample only (no PHI) |

## Idea in one picture

```text
DocumentCodeId
      ↓
 FormCollectionForms (live FormOrder)  or  Forms via TableList
      ↓
 FormItems.ItemLabel (HTML stripped) + ItemType
      ↓
 HTML blank packet  →  print PDF
```

## Related public packs

- [DFA_From_PDF/](../DFA_From_PDF/) — build a **new** on-screen DFA (opposite direction)
- [FormItem_Column_Alignment/](../FormItem_Column_Alignment/) — truncation / wrong control
- [Discovery_Readonly/](../Discovery_Readonly/) — safe SELECT habits
