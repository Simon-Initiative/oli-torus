---
name: self_review
description: >
  Perform a concise, prioritized review of current code changes with concrete fixes, focusing on correctness, reliability, performance, and maintainability in Torus (especially Elixir/Phoenix conventions) while keeping output compact and actionable.
examples:
  - "$self_review"
  - "Review this diff for risks before I open a PR ($self_review)"
  - "Quick self review of changed files, keep it concise"
when_to_use:
  - "Any implementation is complete and needs a quality pass."
  - "User asks for review, risk scan, or PR readiness check."
  - "A skill (for example $spec_develop) requires a final self-review gate."
when_not_to_use:
  - "No meaningful changes are present to review."
  - "The user wants a full rewrite instead of issue-oriented review."
  - "The task is pure product/spec drafting with no code diff."
---

## Purpose
Return a short, prioritized list of issues and suggested fixes for current changes.

## Inputs
- Current diff / changed files
- Optional context docs (`prd.md`, `fdd.md`, `plan.md`) when available
- Review guides (required for every self review):
  - `.review/elixir.md`
  - `.review/performance.md`
  - `.review/requirements.md`
  - `.review/security.md`
  - `.review/typescript.md`
  - `.review/ui.md`

## Outputs (files changed/created)
- No required files
- Optional: small follow-up fixes if requested or required by calling workflow

## Process (step-by-step)
1. Inspect changed files and identify behavior-impacting risks first.
2. Read all six `.review/*.md` guides and run each review/checklist against the current changes:
   - Elixir review: `.review/elixir.md`
   - Performance review: `.review/performance.md`
   - Requirements review: `.review/requirements.md`
   - Security review: `.review/security.md`
   - TypeScript review: `.review/typescript.md`
   - UI review: `.review/ui.md`
3. Review against this consolidated checklist:
   - Correctness and edge cases
   - Error handling and failure paths
   - Elixir patterns (pattern matching, `with`, clear return contracts)
   - Supervision/process boundaries when concurrency is involved
   - Telemetry/logging hygiene (signal quality, no noisy or sensitive logs)
   - Test quality and regression coverage
   - Performance footguns (N+1, expensive loops, unbounded work)
   - Readability and maintainability
4. Prioritize findings by severity: high, medium, low.
5. Provide concrete suggestions for each finding (BUT DO NOT MAKE THESE FIXES)

## Quality bar / guardrails
- Keep output concise: maximum 20 bullets total.
- Findings first, no long summary before issues.
- Avoid speculative nits; focus on real risk and behavior impact.
- The six `.review/*.md` guides are mandatory inputs on every run.
- Review comments from the six guide-based reviews must be addressed before completion.
- If no findings, say so explicitly and mention residual test gaps if any.

## Final response format (brief)
- `Findings:` bullets ordered high -> medium -> low
- `Residual risks/test gaps:` short bullets (or `None`)
