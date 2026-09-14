# Chat habits that work

## Be explicit about completeness

If you mean **every** form, **all** rows, or **make sure we got them**, say that. Agents sometimes invent a narrower “only the truly broken” filter. Push back if the count looks oddly small.

Related rule: [../Agent_Rules/do-not-invent-narrower-scope.md](../Agent_Rules/do-not-invent-narrower-scope.md).

## Interruptions are add-ons

A mid-run correction or extra check is usually **more instruction for the same job**, not a cancel. Use Stop / “cancel” only when you want the work dropped.

## Fix = reopen the source

When something printed wrong, point at the record. The agent should open the **source row/file**, compare label vs value, then fix. Do not let it “fix from memory.”

Related: [../Agent_Rules/fix-go-back-to-source.md](../Agent_Rules/fix-go-back-to-source.md).

## Generated batches

Code green ≠ outputs fixed. After a matcher or template change, re-check **already shipped** files against source grain.

Related: [../Agent_Rules/verify-outputs-against-source.md](../Agent_Rules/verify-outputs-against-source.md).

## Long jobs

Do not leave multi-hour pools only under the chat terminal. Prefer a detached process. If the chat aborts, verify and restart — do not only report status.

Related: [../Agent_Rules/long-jobs-survive-chat-abort.md](../Agent_Rules/long-jobs-survive-chat-abort.md).

## Screenshots and PDFs

For a new DFA, drop the PDF or numbered screenshots in the form folder and say what the staff-facing name should be. Ambiguous labels: expect the agent to ask before inventing column names.
