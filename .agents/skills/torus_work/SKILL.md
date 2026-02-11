---
name: torus_work
description: Canonical single-entry Torus workflow dispatcher that triages requests into bug-fix TDD, ticket-sized enhancement, or new-feature PRD lanes and executes the selected playbook end-to-end.
examples:
  - "$torus_work JIRA-1234 failing import retries after timeout"
  - "$torus_work TOR-8891 add an instructor override warning banner"
  - "$torus_work build a new bulk enrollment reconciliation feature"
when_to_use:
  - "User wants one default workflow entry point and routing should be automatic."
  - "Task intent is unclear and should be classified as bug vs enhancement vs new feature."
when_not_to_use:
  - "User explicitly requires a specific lane already ($fixbug, $spec_enhancement, or $spec_analyze)."
---

## Required Resources
Always load before dispatching:

- `references/triage_matrix.md`
- `references/dispatch_contract.md`

## Workflow
1. Parse input context: ticket key, request text, changed files, and optional feature slug.
2. Classify lane using `references/triage_matrix.md`.
3. Announce route in one short statement:
   - `This looks like a <lane> because <reason>.`
4. Execute the selected playbook:
   - Bug lane (`fixbug_tdd` via `$fixbug`): run TDD-first regression-safe fix workflow.
   - Enhancement lane: run `$spec_enhancement` playbook (mini spec + design/develop + validation).
   - New feature lane: run `$spec_analyze` playbook (create new docs/features/<slug>, create/update PRD with hard validation gate).
5. If nested skill invocation is not available, execute the exact target lane workflow inline in the same run.
6. Do not switch lanes mid-run unless new evidence clearly invalidates the original classification; if switched, record why.

## Routing Rules
- Route to bug lane (`fixbug_tdd` / `$fixbug`) when there is regression language, expected-vs-actual mismatch, error/stacktrace, or explicit bug-fix request.
- Route to enhancement lane when scope is ticket-sized behavior tweak/refactor and does not require full feature discovery.
- Route to new feature lane when work is net-new capability or requirements are ambiguous enough to require PRD-first clarification.
- Tie-breaker default: enhancement lane unless risk/ambiguity indicates new-feature lane.

## Output Contract
- Always report:
  - Selected lane.
  - One-sentence reason.
  - Key artifacts created/updated.
  - Validation/test status from the chosen playbook.
