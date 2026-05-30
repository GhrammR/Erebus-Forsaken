# Stage Handoff — Response Format

At the end of every stage (and at the end of any session that completes
discrete work), the agent's final response must end with a fenced
"next-phase prompt" the user can copy-paste verbatim to begin the next
phase in a fresh session. This protects against the documented failure
mode "context loss between sessions" (`rules/failure-modes.md` #4).

The handoff is part of "done." A stage that does not produce a valid
handoff prompt is not closed.

## Format — fixed template

The handoff goes at the very bottom of the response under a level-2
heading:

````
## Next-phase prompt

```
Erebus Forsaken — begin Stage <N+1>: <stage name from act1-status.md>.

Context recap (from last session):
- Last completed: Stage <N> — <one-line summary>
- Project state: runnable from main.tscn, build label vX.Y.Z, no editor errors
- Open risks / parked items: <list, or "none">
- Branch: <current branch>, last commit: <short-sha or "uncommitted">

Goals for Stage <N+1> (from act1-status.md):
- <copy the bullet list from act1-status for that stage>

Constraints (do not relax):
- Scope lock: .agent_governance/rules/scope-lock.md
- Stat lock: .agent_governance/rules/stat-system.md
  (BlockChance, CastSpeed, HitRecovery do not exist)
- Definition of done: .agent_governance/rules/testing.md
- Read .agent_governance/CLAUDE.md before writing code

First actions on resume:
1. Read .agent_governance/commands/act1-status.md and confirm Stage <N> is fully [x].
2. Run the relevant skill audit(s): <combat-validator / scene-auditor / class-balance>.
3. Propose the implementation sketch for Stage <N+1> before writing code.

Then begin Stage <N+1>.
```
````

## Rules for filling the template

- `<N>` and `<N+1>` are integers matching `commands/act1-status.md` stage
  numbers. If the just-completed stage is Stage 12, the handoff prompt
  instead says "Act 1 complete — initiate launch checklist."
- "Context recap" is **factual**: report what is true on disk, not what
  you intended. If a stage closed with one item deferred, say so.
- "Open risks / parked items" links to `parking_lot.md` entries by name.
  Do not silently drop carried-over risks between stages.
- "Constraints" list is fixed; copy it verbatim every time. The user
  should not have to re-derive the guardrails.
- "First actions on resume" always begins with reading the charter and
  status file. Always.

## When a session ends without closing a stage

Use the same template but title the heading `## Resume prompt` and the
first line becomes:

`Erebus Forsaken — resume Stage <N> in progress.`

"Goals" become the **remaining** checklist items, not the original list.

## When the user is mid-stage and asks a question

No handoff required. Handoffs only appear when:
- A stage closes, OR
- The user requests a session stop, OR
- The user asks for the handoff explicitly.

Producing a handoff after every chat message is noise. Producing one at
stage close is binding.
