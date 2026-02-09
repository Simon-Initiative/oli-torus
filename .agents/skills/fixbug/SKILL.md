---
name: fixbug
description: >
  Execute a ticket-driven, TDD-first bug-fix workflow for Torus by reproducing the issue from a JIRA ticket, writing a failing ExUnit regression test, implementing the minimal safe fix, verifying tests pass, and ending with a PR-ready summary.
examples:
  - "$fixbug JIRA-1234"
  - "Fix JIRA-981 using TDD ($fixbug)"
  - "Investigate and patch this ticket: https://jira.example.com/browse/JIRA-77"
when_to_use:
  - "A JIRA ticket is provided with bug details."
  - "User explicitly invokes $fixbug."
  - "A regression-safe, minimal bug-fix workflow is required."
when_not_to_use:
  - "No JIRA ticket is provided and user did not explicitly invoke $fixbug."
  - "The work is a net-new feature/spec workflow (use $spec_* skills)."
  - "The user asks for an exploratory prototype (use $prototype)."
---

## Purpose
Fix a bug with regression safety and minimal change scope.

## Inputs
- JIRA ticket key/URL (required unless explicitly invoked as `$fixbug`)
- Current codebase and relevant tests
- Optional logs, stack traces, or reproduction notes

## Outputs (files changed/created)
- New or updated failing-then-passing ExUnit regression test
- Minimal production code fix
- Optional docs updates if behavior contract changed

## Process (step-by-step)
1. Read the JIRA ticket and extract:
   - Reproduction steps
   - Expected behavior
   - Actual behavior
2. Reproduce the bug locally where possible.
3. Write a failing ExUnit test that captures the bug.
4. Implement the minimal fix to make the test pass.
5. Run relevant tests (at least the new regression test and affected suite) until green.
6. Verify no unnecessary scope expansion occurred.
7. Prepare a PR-ready summary.

## Quality bar / guardrails
- Trigger policy: run only with JIRA ticket context or explicit `$fixbug`.
- TDD-first is mandatory: test fails before fix, then passes after fix.
- Keep fixes minimal and localized; avoid opportunistic refactors.
- Preserve Elixir/Phoenix best practices and production safety.
- Include regression coverage for the reported behavior.

## Final response format (brief)
- `PR title suggestion: <title>`
- `Changes:` concise bullets (test + fix)
- `Verification:` tests run and outcomes
- `Risk:` one short assessment

