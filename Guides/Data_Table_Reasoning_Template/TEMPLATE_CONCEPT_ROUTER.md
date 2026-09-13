# Concept → table router (template)

| Concept | Primary table | Grain | Date column | Notes / anti-patterns |
|---------|---------------|-------|-------------|------------------------|
| Example: billable procedure lines | | | | |
| Example: census / enrollment | | | | |
| Example: demographics | | | | |

## Rules of thumb

1. Confirm grain (person vs chart vs encounter vs line).
2. Confirm the date that assigns a month.
3. Prefer documented metric helpers over raw “billable” flags when your warehouse has them.
