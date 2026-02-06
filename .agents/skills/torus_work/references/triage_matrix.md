# Triage Matrix

Use these signals to classify work.

## Bug lane (`$fixbug`)

Strong signals:

- Words like "bug", "regression", "broken", "error", "stack trace", "fails".
- Repro steps with expected vs actual behavior.
- Existing behavior unexpectedly changed.

## Enhancement lane (`$spec_enhancement`)

Strong signals:

- Ticket-sized behavior tweak or refactor.
- Existing feature area; bounded scope.
- Words like "enhancement", "improve", "update".
- Needs AC/risk/test/rollout structure but not full PRD+FDD+plan ceremony.

## New feature lane (`$spec_analyze`)

Strong signals:

- Net-new capability or workflow.
- Requirements are incomplete/ambiguous and need FR/AC clarification.
- Scope implies future architecture/planning phases.

## Tie-breaker

- Choose enhancement lane by default.
- Escalate to new feature lane only when ambiguity or scope breadth makes PRD-first work necessary.
