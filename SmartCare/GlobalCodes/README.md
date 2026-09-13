# GlobalCodes — add a picklist

Portable idempotent SQL for `dbo.GlobalCodeCategories` + `dbo.GlobalCodes`.

**Do not test in Prod.**

## Files

| File | Purpose |
|------|---------|
| [SC_Add_GlobalCode_template.sql](SC_Add_GlobalCode_template.sql) | Set `@Category` and option labels; F5 |

## Rules

- Custom DFA categories usually start with **`X`** (max 20 characters).
- Insert the **category first** (FK).
- For DFA radios, set `HasSubcodes = N` and leave PrimaryDriven / AffiliateAllow* **NULL** (product default Y can hide the category).
- Radios (ItemType 5365) often persist **ExternalCode1** — set it when you need saved values.
- Dropdowns that store GlobalCodeId need a wide enough column (not `varchar(3)` for 8-digit ids).

Also see [AI/Agent_Rules/globalcodes-id-and-category.md](../../AI/Agent_Rules/globalcodes-id-and-category.md).
