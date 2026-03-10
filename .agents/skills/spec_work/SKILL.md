---
name: spec_work
description: Execute a Jira-driven lightweight lane for small stories/enhancements by generating a brief technical approach + plan in-chat, then implementing after user approval.
examples:
  - "$spec_work MER-1234"
  - "Handle this small behavior tweak with spec_work: MER-8891 add late-pass override audit logging"
  - "Read MER-4054 and propose a brief implementation plan, then implement after approval ($spec_work)"
when_to_use:
  - "Small Jira story/task enhancement or refactor that does not need full PRD/FDD/plan ceremony."
  - "Ticket should be implemented from a concise, reviewed technical approach."
when_not_to_use:
  - "Large net-new capabilities that need full feature lane planning (use $spec_analyze, $spec_architect, $spec_plan, $spec_develop)."
  - "Bug/regression tickets (use $spec_fixbug)."
---

## Required Resources
Always load before running:

- `references/persona.md`
- `references/approach.md`
- `references/considerations.md`
- `references/jira_intake.md`
- `references/epic_context.md`
- `references/review_gate.md`
- `references/execution_guardrails.md`
- `references/output_requirements.md`
- Implementation phase must also load these `spec_develop` references:
  - `.agents/skills/spec_develop/references/coding_guidelines.md`
  - `.agents/skills/spec_develop/references/definition_of_done.md`
  - `.agents/skills/spec_develop/references/elixir_best_practices.md`
  - `.agents/skills/spec_develop/references/typescript_best_practices.md`

## Phase 1: Technical Approach and Planning (No Code Changes)
1. Parse input and require Jira ticket key/URL.
2. Fetch ticket details and comments from Jira using configured MCP resources.
3. Extract concise requirements from title, description, acceptance text, and engineering clarification comments.
4. If issue type is bug/regression, stop and route to `$spec_fixbug`.
5. If ticket is linked to an epic, read epic context docs from `docs/epics/<epic_slug>/` (`overview.md`, `prd.md`, `edd.md`, `plan.md`) when present.
6. Perform UI/design-source triage:
   - Classify the ticket as one of:
     - `backend-only`
     - `ui-without-design-source`
     - `ui-with-design-source`
   - If the ticket is `ui-with-design-source`, use `$spec_ui_implement` before finalizing the technical approach.
   - Use the brief from `$spec_ui_implement` to inform token mapping, icon reuse, reusable component decisions, and file targets.
   - Do not use `$spec_ui_implement` for backend-only tickets.
7. Produce an in-chat review draft:
   - Very brief technical approach (2-4 sentences + short bullet list).
   - Very brief implementation plan (3-6 numbered steps).
   - Scope boundaries, assumptions, risks, and test strategy.
   - Scenario testing decision:
     - Assess whether scenario coverage should be added for this ticket.
     - If scenario coverage is needed, assess whether existing scenario infrastructure already supports the workflow.
     - If unsupported, explicitly plan to run `$spec_scenario_expand` before `$spec_scenario`.
8. Pause for user review:
   - If user requests changes, revise and re-present Phase 1 output.
   - If user gives any positive approval response, transition to Phase 2.

## Phase 2: Implementation (Code + Verification)
1. Before coding, load required implementation references listed above from `.agents/skills/spec_develop/references/`.
2. Implement approved scope only, with minimal changes and Torus best practices.
3. Add/update all new or affected automated tests.
4. Scenario lane (when applicable):
   - If scenario coverage is planned and infrastructure exists, run `$spec_scenario` to add/update scenario tests.
   - If scenario coverage is planned but infrastructure is missing, run `$spec_scenario_expand` first, then `$spec_scenario`.
5. Run `spec_review` after tests pass:
   - Execute at least one review round.
   - Address findings and re-run review up to 3 rounds total.
   - Resolve all high/medium findings before completion.
6. Run formatting and verification gates before final response:
   - `mix format`
   - `mix compile`
   - all new or affected tests
7. Report implementation summary, files changed, commands run, outcomes, and residual risks.

## Output Contract
- Do not create permanent enhancement spec files under `docs/` or elsewhere.
- Use `references/output_requirements.md` for both:
  - Pre-implementation review summary.
  - Post-implementation execution summary.
