---
name: prototype
description: >
  Build a fast, low-ceremony prototype to validate an idea quickly with runnable code where possible, intentionally skipping spec docs, hardening, and unit tests, then provide a short path to production hardening.
examples:
  - "$prototype Build a quick LiveView spike for inline rubric editing"
  - "Prototype a rough ingestion flow for CSV roster uploads"
  - "I want a prototype only, no production hardening yet"
when_to_use:
  - "User explicitly invokes $prototype."
  - "User explicitly asks for a prototype using the word 'prototype'."
when_not_to_use:
  - "User asks for production-ready implementation with tests."
  - "The request belongs in the spec-driven lane (use $spec_*)."
  - "The task is a ticketed bug fix requiring TDD (use $fixbug)."
---

## Purpose
Deliver a runnable spike fast to validate feasibility, UX direction, or integration shape.

## Inputs
- Short problem statement and success signal for the spike
- Optional constraints (timebox, target module/area, demo path)

## Required Resources
Always load before prototyping:

- `references/persona.md`
- `references/approach.md`
- `references/considerations.md`
- `references/output_requirements.md`

## Outputs (files changed/created)
- Minimal runnable code for the prototype path
- Optional minimal docs note only if needed to run the spike

## Process (step-by-step)
1. Confirm prototype scope and timebox.
2. Follow `references/approach.md` and keep decisions aligned with `references/considerations.md`.
3. Implement the smallest runnable path that demonstrates the core idea.
4. Prefer local, reversible changes and clear TODO markers for missing production concerns.
5. Verify it runs (manual path is acceptable).
6. Summarize what worked, what is unknown, and hardening steps using `references/output_requirements.md`.

## Quality bar / guardrails
- Trigger policy: only run when user says `prototype` or explicitly invokes `$prototype`.
- Do not create PRD/FDD/plan docs in this lane.
- Do not add unit tests in this lane.
- Do not harden for production best practices unless user asks to move beyond prototype mode.
- Keep output concise and demo-focused.

## Final response format (brief)
- `Prototype outcome:` short result statement
- `Runnable path:` brief run/use steps
- `Known limitations:` concise bullets
- `How to harden this into production code:`
  - 3-7 bullets
