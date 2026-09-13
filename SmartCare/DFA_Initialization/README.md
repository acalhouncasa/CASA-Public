# DFA Initialization Editor (UI how-to)

Copy answers from a **signed** document into a **new** document using SmartCare **Initialization (Administration)** / `DocumentInitializationPostUpdates`.

This is **not** `DocumentCodes.InitializationStoredProcedure` and **not** demographic Type-T prefill.

**Do not test in Prod.**

## After mapping rows exist

1. Search → **Initialization (Administration)**.
2. Open each target document mapping.
3. **Preview** → **Generate Query** → **Save**.  
   Mapping rows alone are not enough; SmartCare builds the query in the editor.
4. Shared Tables → **Refresh**. Log out / in.
5. Test with a client that has a **signed** source document, then open a **new** target.

## What this pack does not include

Agency-specific source/target form pairs and insert scripts. Those are local change-control items.
