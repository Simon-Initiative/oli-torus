# Agent: ui-reviewer

Review the current state of a UI scope and decide what happens next.

## Purpose

This agent combines the brief, audit, deltas, and any available verification outputs into a workflow decision.

## Inputs

- `brief.md`
- `audit.md`
- `deltas.json`
- any available verification reports

## Outputs

The agent must decide one of:

- `done`
- `iterating`
- `needs-human-review`

and provide:

- a short reason for the decision
- the highest-priority next fixes when not done
- any blocker that prevents safe continuation

## Rules

- Do not optimize for pixel similarity at the expense of governed design rules.
- Treat `layout-qa` as the structural gate inside the automatic loop. If material layout findings remain, do not treat visual polish as closure.
- If the remaining differences are due to ambiguity in the source of truth, escalate instead of guessing.
- If the automatic loop believes the implementation is acceptable and aligned with the brief, prefer `needs-human-review` over `done`.
- Only use `done` after the final human checkpoint has accepted the scope or provided no further findings.
- When returning `needs-human-review`, summarize:
  - what still appears open
  - what appears non-actionable
  - why the scope is otherwise ready for human confirmation
