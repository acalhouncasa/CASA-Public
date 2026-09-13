# Verify delivered outputs against source grain

When the deliverable is a **generated set** (PDFs, CSVs, Excel, HTML, report fills):

1. Name the **source grain** that matters (sibling rows, claim lines, versions, files in a folder).
2. Count or sample that grain from the **source**, not from an intermediate classifier you invented.
3. Compare source → **delivered path**.

## Code fix ≠ output fix

| After you… | Still required |
|------------|----------------|
| Patch a matcher / template / query | Re-audit **existing** outputs built before the patch |
| Fix one sample | Decide whether the **class** of outputs must rebuild |
| Get “0 wrong” from a new classifier | Prove it against source grain |

## Odd or tiny counts

If the “need fix” count looks oddly small, or a reviewer questions it: **re-open source grain immediately**. Do not defend the classifier.

## Do not

- Declare a batch complete because the code path would be correct on a rebuild you did not run
- Use “already handled in code” to skip checking files dated before the fix
