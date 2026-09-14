# Pitfalls

## Generator / identity

| Pitfall | Do instead |
|---------|------------|
| Run vendor DFA Export SQL as-is | GUID-based inserts; new FormCollection |
| `IDENTITY_INSERT` with sample FormId/DocumentCodeId | Let the database assign identities; match on GUID |
| Reuse an existing FormCollectionId for a new form | Always new collection for greenfield |
| Trust matching FormId across databases | Confirm `FormGUID` + `DB_NAME()` |
| Re-F5 `03_apply` after PASS on that env | Stop; use merge for later field adds |

## Screen / PDF

| Pitfall | Do instead |
|---------|------------|
| Point DocumentCodes GET SP at an RDL `*Text` proc | Use `ssp_GetDFADocumentsData` (or a real document GET) |
| Set `Screens.CustomFieldFormId` to the DFA form | Keep **NULL** for standard DFA with grids |
| Model wet signature/date as FormItems | `RequiresSignature = Y` |
| Import `.sql` via SmartCare web Import DFA | Run in SSMS |

## Layout / save

| Pitfall | Do instead |
|---------|------------|
| Multiline height set to 6 | Leave `MultilineEditFieldHeight` NULL |
| Group heading repeated as ItemLabel | Blank item label when group is named |
| Radio category PrimaryDriven defaults to Y | Insert NULL + `HasSubcodes = N` |
| Radio ExternalCode1 = `1`,`2`,`3` | Alphanumeric tokens |
| Multi-select dropdown column typed `int` | Wide varchar; comma-separated ids are not an int |
| Phone control on `varchar(10)` | Widen; control may post punctuation |

## After metadata change

Shared Tables → Refresh, log out/in, open a **new** document. Old drafts can look wrong even when SQL is fine.

## Scoring

Live totals live on `Forms.FormJavascript`, not on the item canvas. See [../Scoring/](../Scoring/).
