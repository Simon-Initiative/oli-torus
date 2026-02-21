---
name: spec_fixbug
description: >
  Execute a ticket-driven, TDD-first bug-fix workflow for Torus by reproducing the issue from a JIRA ticket, writing a failing ExUnit regression test, implementing the minimal safe fix, verifying tests pass, and ending with a PR-ready summary.
examples:
  - "$spec_fixbug MER-1234"
  - "Fix MER-2981 using TDD ($spec_fixbug)"
  - "Investigate and patch this ticket: https://eliterate.atlassian.net/browse/MER-5178"
when_to_use:
  - "A JIRA ticket is provided with bug details."
  - "User explicitly invokes $spec_fixbug."
  - "A regression-safe, minimal bug-fix workflow is required."
when_not_to_use:
  - "No JIRA ticket is provided and user did not explicitly invoke $spec_fixbug."
  - "The work is a net-new feature/spec workflow (use $spec_* skills)."
  - "The user asks for an exploratory prototype (use $spec_prototype)."
---

## Purpose
Fix a bug with regression safety and minimal change scope.

## Inputs
- JIRA ticket key/URL (required unless explicitly invoked as `$spec_fixbug`)
- Current codebase and relevant tests
- Optional logs, stack traces, or reproduction notes

## Required Resources
Always load before fixing:

- `references/persona.md`
- `references/approach.md`
- `references/considerations.md`
- `references/output_requirements.md`

## Outputs (files changed/created)
- New or updated failing-then-passing ExUnit regression test
- Minimal production code fix
- Optional docs updates if behavior contract changed

## Process (step-by-step)
1. Read the ticket and extract:
   - Reproduction steps
   - Expected behavior
   - Actual behavior
2. Follow `references/approach.md` and keep changes aligned with `references/considerations.md`.
3. Reproduce the bug locally where possible.
4. Write a failing ExUnit test that captures the bug.
5. Implement the minimal fix to make the test pass.
6. Run relevant tests (at least the new regression test and affected suite) until green.
7. Verify no unnecessary scope expansion occurred.
8. Prepare a PR-ready summary using `references/output_requirements.md`.

## Quality bar / guardrails
- Trigger policy: run only with JIRA ticket context or explicit `$spec_fixbug`.
- TDD-first is mandatory: test fails before fix, then passes after fix.
- Keep fixes minimal and localized; avoid opportunistic refactors.
- Preserve Elixir/Phoenix best practices and production safety.
- Include regression coverage for the reported behavior.

## Final response format (brief)
- `PR title suggestion: <title>`
- `Changes:` concise bullets (test + fix)
- `Verification:` tests run and outcomes
- `Risk:` one short assessment
