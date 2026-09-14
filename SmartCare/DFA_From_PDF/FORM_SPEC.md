# FORM_SPEC — what to put in the JSON

The spec is the contract between the PDF and the generator. Keep it in source control next to the form.

## Required ideas (names may vary in your schema)

| Field | Meaning |
|-------|---------|
| `form_name` | Forms.FormName |
| `table_name` | `CustomDocument…` only |
| `document_name` | DocumentCodes.DocumentName (staff see this) |
| `screen_name` | Screens.ScreenName |
| `form_collection_name` | New collection name for greenfield |
| `sections[]` | Major headers → FormSections |
| fields under sections/groups | ItemColumnName, ItemType, labels |

## GUIDs

| GUID | Use |
|------|-----|
| `form_guid` | `Forms.FormGUID` — stable across environments for the same new form |
| Document / screen codes | Stable codes so reruns update instead of duplicating |

Never steal identity integers from a vendor sample export.

## Control → SQL type (portable defaults)

| Control | ItemType | Column type |
|---------|----------|-------------|
| CheckBox | 5362 | `TYPE_YORN` (or your site’s Y/N type) |
| Text | 5361 | `VARCHAR(256)` |
| Long text | 5363 | `VARCHAR(8000)` — leave multiline height **NULL** |
| Radio | 5365 | `VARCHAR(20)` + `X*` category; **ExternalCode1** alphanumeric |
| DropDown | 5372 | `INT` (stores GlobalCodeId) |

## Layout rules that prevent ugly UAT

| Do | Do not |
|----|--------|
| Name the **group**; leave item label blank when it would duplicate the group heading | Same string on GroupLabel and ItemLabel (prints twice) |
| Multi-column via `FormSectionGroups.NumberOfItemsInRow` | Raising form/section column counts hoping for two fields on one row |
| Two labeled fields on one row ≈ **4** items (label + control, twice) | Guess without checking a known good form on your build |
| Section-header enable checkbox → `FormSections.SectionEnableCheckBox*` | Modeling that enable as a normal FormItem |

## Radios / GlobalCodes

- Custom categories usually start with **`X`**, max 20 characters.
- Insert category **before** codes.
- Set `HasSubcodes = N` and leave PrimaryDriven / AffiliateAllow* **NULL** for user-defined radio lists (SQL defaults of Y can hide the category).
- New radio **ExternalCode1** tokens: names like `PrivateRoom`, `Min15` — not bare `1`/`2`/`3` (those can collide with GlobalCodeId decoding in RDLs).

Public SQL template: [../GlobalCodes/](../GlobalCodes/).

## Optional flags (only when you need them)

| Idea | Notes |
|------|-------|
| Client co-signer | DocumentCodes default co-signer |
| Recreate PDF after client pad-sign | When the PDF must refresh after signature |
| Service note | Separate Procedure Associate Note UI work |

## Example

See [examples/FORM_SPEC_EXAMPLE.json](examples/FORM_SPEC_EXAMPLE.json).
