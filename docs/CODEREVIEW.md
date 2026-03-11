# Code Review

## Policy

Code review in Torus should focus on correctness, regressions, maintainability, security, performance, and test adequacy. Reviews should stay grounded in the actual diff, produce specific actionable findings with file and line references, and avoid vague style-only feedback when a concrete behavioral or architectural concern exists.

At a high level, reviewers should:

- understand the scope of the change before reviewing details
- verify that behavior matches the stated intent and existing repository patterns
- look for missing authorization, data-shape, performance, and edge-case handling
- confirm that tests are present where risk warrants them
- leave concrete comments that suggest the next corrective action

This document is only the entry point. The actual review checklists live in `.review/` and should be treated as the canonical review guidance.

## Review Guides

Before performing a substantive review, load and read the relevant checklist files in `.review/`.

Always read these two guides for every review:

- `.review/security.md`
- `.review/performance.md`

Add the remaining guides based on the scope of the change:

- `.review/elixir.md` for backend, Phoenix, LiveView, Ecto, or other Elixir changes
- `.review/ui.md` for UI, frontend, interaction, accessibility, or visual behavior changes
- `.review/typescript.md` for TypeScript or React code changes
- `.review/requirements.md` when a `docs/exec-plans/**/prd.md` file is added or changed and the review needs requirements traceability

## Expected Review Flow

1. Read the diff and identify which technology areas and risk areas are touched.
2. Load `.review/security.md` and `.review/performance.md`.
3. Load any additional `.review/*.md` files that match the change scope.
4. Review the code using those checklists as the structure for findings.
5. Report findings in priority order with file references and concrete remediation guidance.

## Output Expectations

Good review comments in this repository should be:

- specific about the problem
- tied to the changed code
- explicit about risk or regression potential
- clear about what should change next

If no issues are found, say so explicitly, but still call out residual risks or missing verification where applicable.
