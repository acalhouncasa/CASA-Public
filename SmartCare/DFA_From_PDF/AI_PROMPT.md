# Prompting the AI for a new DFA

Paste or adapt this when you start a form in Cursor (or similar).

---

Build a **new** SmartCare DFA from the PDF/screenshots in this folder.

Follow the public process: SmartCare/DFA_From_PDF (PROCESS + FORM_SPEC + PITFALLS).

Requirements:

1. Read any LESSONS_LEARNED in this form folder first.
2. Draft FORM_SPEC.json (CustomDocument* table, sections from major headers, ItemTypes).
3. Ask me before inventing ambiguous column names or picklist labels.
4. Radios: X* GlobalCodes, alphanumeric ExternalCode1, PrimaryDriven NULL, HasSubcodes N.
5. Do not model wet signature lines as FormItems when RequiresSignature is Y.
6. Generate numbered SQL: 01_precheck, optional 02_globalcodes, 03_apply_form, 04_postcheck.
7. No IDENTITY_INSERT of sample ids. Match on GUID. New FormCollection for greenfield.
8. Give me **one** mutating script at a time. You run read-only precheck/postcheck if you can.
9. Do not tell me to Import DFA in the browser. SSMS F5 only.
10. After apply: remind Shared Tables Refresh, re-login, New document UAT.
11. Record lessons in this folder when something fails or we confirm a fix.
12. Do not test in Prod.

Attachments: (list PDF / screenshot files)

Staff-facing document name: …

---

## After the first environment works

Say whether the next database is **greenfield** (same GUIDs, retarget) or **merge** (form already exists). See [PROMOTE.md](PROMOTE.md).
