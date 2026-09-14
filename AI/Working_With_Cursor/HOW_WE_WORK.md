# How we work

## Roles

| Who | Does |
|-----|------|
| **Human** | Decides goals, runs mutating SQL in SSMS (F5 whole file), pastes result grids back, does UI UAT, owns change control |
| **AI agent** | Reads lessons first, drafts specs/SQL/docs, runs **read-only** checks when allowed, records lessons, never invents a thinner job than you asked |

The chat is for **orchestration**. Durable facts go into `LESSONS_LEARNED.md` or a project `RUN_STEPS.md`.

## Typical loop (database change)

1. You describe the outcome (and attach a PDF/screenshot if it is a form).
2. Agent reads project lessons, then drafts files in the repo.
3. Agent runs or reports **read-only** precheck results when that is safe.
4. You get **one** mutating script link. You F5 the whole file. You paste the grids back.
5. Agent interprets results, runs postcheck, names the next step (or stops).
6. You Refresh Shared Tables / re-login / test UI when the package says so.
7. Agent records what worked or failed in the lesson file **in the same session**.

## What “complete” means for code

When you need something to run or paste:

- Full SQL file (F5-safe), not “run section 2.”
- Full Power Query `let` … `in`, not a middle fragment.
- Full script files, not “replace lines 40–80” unless you asked for a diff review.

See [../Conventions/never-partial-code.md](../Conventions/never-partial-code.md).

## Lessons before tools

Before sqlcmd, greps, or edits on a known project, the agent should **read** that project’s lessons and use them. New durable knowledge gets **recorded**, including failed approaches.

See [../Lessons_Learned/](../Lessons_Learned/).
