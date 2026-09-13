# Do not invent a narrower job than asked

## Failure modes

1. Ignore an explicit completeness rule and substitute “known list is enough.”
2. Abort discovery early and treat “no finding yet” as “nothing to find.”
3. Write a lesson that excuses the abort.
4. After a miss, invent a thinner classifier instead of returning to the original rule.

## Mandatory

| Situation | Do |
|-----------|-----|
| A detection / completeness rule is stated in plain words | Use **that** rule. Do not add filters that shrink the set without approval. |
| Words like **all**, **every**, **complete** | Completeness first |
| Code that affects generated outputs changes | Re-check **delivered artifacts** against **source rows** |
| A count feels oddly small | Stop. Re-count from source with the original framing. |

## When a heuristic is tempting

Say it out loud: “Your rule finds N; my extra filter would drop to M. Use N unless you want the filter.” Default to **N**.
