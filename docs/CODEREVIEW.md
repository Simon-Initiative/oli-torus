# Code Review

## Policy

Code review in Torus should focus on correctness, regressions, maintainability, security, performance, and test adequacy. Reviews should stay grounded in the current changes, produce specific actionable findings with file and line references, and avoid vague style-only feedback when a concrete behavioral or architectural concern exists.

This document is the repository entry point for review orchestration. The detailed checklists live in `.review/`, but the main review agent should not load every checklist into its own context. Instead, it should inspect the current changes, decide which reviews apply, and delegate each selected checklist to a dedicated `reviewer` subagent.

## Review Guide Selector

Always run these two reviews:

- `.review/security.md`: authorization, input handling, secrets, unsafe data exposure, and other security regressions
- `.review/performance.md`: query shape, hot paths, N+1s, expensive loops, blocking work, and scalability risks

Run these additional reviews only when the current changes warrant them:

- `.review/elixir.md`: backend Elixir, Phoenix, LiveView, Ecto, jobs, or server-side architecture changes
- `.review/ui.md`: UX, accessibility, interaction, layout, navigation, or visual behavior changes
- `.review/typescript.md`: TypeScript, React, frontend state, client data flow, or type-safety changes
- `.review/requirements.md`: PRD traceability and acceptance-criteria coverage when a `docs/exec-plans/**/*prd*.md` file is added or changed

## Required Workflow

1. Inspect the current changes on the branch and determine which review guides apply.
2. Always include `.review/security.md` and `.review/performance.md`.
3. Add `.review/elixir.md`, `.review/ui.md`, `.review/typescript.md`, and `.review/requirements.md` only if the changed files or behavior make those reviews relevant.
4. Do not read the checklist files into this current context.
5. For each selected checklist, spawn a `reviewer` subagent and pass it:
   - the checklist file path
   - instructions to review only against that checklist and current outstanding changes and return concrete findings with file and line references
6. Run those reviewer subagents in parallel.
7. Wait for all reviewer subagents to complete.
8. Merge and de-duplicate the returned findings.
9. Order the final findings by severity.
10. If no findings remain after consolidation, state that explicitly and then call out residual risks or missing verification.

## Reviewer Subagent Contract

Each reviewer subagent should:

- read only its assigned checklist file, not every file under `.review/`
- review the current changes through the lens of that checklist only
- return concrete findings tied to changed code
- include file references and clear remediation guidance
- avoid style-only commentary unless it creates a real correctness, security, performance, accessibility, or maintenance risk

## Output Expectations

The final merged review should:

- present findings first
- sort findings by severity
- keep comments specific to the changed code
- explain the risk or regression clearly
- include concrete next-step guidance

If no issues are found, say so explicitly, but still call out residual risks or missing verification where applicable.
