# Pitfalls

## Labels and metadata

| Mistake | Fix |
|---------|-----|
| Print `ItemColumnName` as the question | Use stripped `ItemLabel` HTML when present |
| Treat every 5374 as a blue section bar | 5374 is usually a **note**. Address-group write-ins are boxes |
| Show designer groups (`sec1`, `content`, …) as headings | Hide them |
| Freeze `FormOrder` from an old deploy map | Always read live `FormCollectionForms` |
| Prefill assessment/form date with today | Leave blank `mm/dd/yyyy` |

## Layout length

| Mistake | Fix |
|---------|-----|
| New page for every tab | Auto page breaks; only break when a section truly needs it |
| “Check when complete” section list on the cover | Drop it; use header + ID strip |
| Signature on its own page | Compact block on the last content page |
| Logo on every page | Page 1 only |

## Wrong source

| Mistake | Fix |
|---------|-----|
| Expect blank handouts from View Document RDLs | Those need a saved chart version |
| Invent FormItems for Rx / ePrescribe | No DocumentCode; screenshot replica if needed |
| Copy Core Assessment / fillable overlay rules onto a simple DFA | See [LIMITS.md](LIMITS.md) |
| Merge this with DFA Creation SQL or data-load migrations | Paper is read-only metadata → PDF |

## Playwright / PDF

| Mistake | Fix |
|---------|-----|
| Assume ☐/○ in HTML are fillable PDF fields | They are glyphs. AcroForm is a separate pass |
| CSS `@page { size: letter }` fighting `landscape=True` | Match `@page` size to orientation and PDF width/height |

## Encoding

| Mistake | Fix |
|---------|-----|
| “Fix” a FormName that shows `` in the console | Encoding in the DFA name; do not rename Setup. Paper title can still come from FormName or an override |
