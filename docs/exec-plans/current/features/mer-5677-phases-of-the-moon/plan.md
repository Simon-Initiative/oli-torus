# MER-5677 Adaptive Lesson: Phases of the Moon - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/features/mer-5677-phases-of-the-moon/prd.md`
- FDD: `docs/exec-plans/current/features/mer-5677-phases-of-the-moon/fdd.md`

## Scope

Deliver one additive, archive-backed Playwright student-delivery spec for the documented Phases of the Moon route: Easy Mission initially, then a switch to Difficult Mission at Mission Update. Reuse the MER-5672/5673 private asset and shared adaptive-driver pattern. Do not change course content, product adaptive behavior, or commit instructional IP.

## Clarifications & Default Assumptions

- The private bucket prefix is `phases-of-the-moon_phases-of-the-moon/`; the seeded objects are `course.zip` and `answers.json`.
- `phases-of-the-moon_phases-of-the-moon/answers.json` conforms to `LessonAnswers` and includes the initial Easy Mission selection plus the Mission Update switch to Difficult Mission.
- The ticket's linked private happy-path document is authoritative when JSON and observed UI behavior differ.
- Existing generic driver support is presumed adequate; a new generic interaction is added only if an actual test run demonstrates a gap.

## Phase 1: Confirm Private Test Inputs

- Goal: Establish the exact private inputs and stable test contract without exposing course IP.
- Tasks:
  - [x] Read the updated ticket's linked happy-path document and identify its Easy Mission start, “Switch to difficult Mission” transition, stable lesson title/search/completion text, and unusual interactions.
  - [x] Obtain the course ZIP and answers JSON through the approved private channel; do not add either file to the repository.
  - [x] Agree the exact object keys under `phases-of-the-moon_phases-of-the-moon/` and seed the configured Playwright assets bucket.
  - [x] Validate the JSON against `LessonAnswers`; encode semantic rules rather than screen-number assumptions.
- Testing Tasks:
  - [ ] Verify authenticated retrieval of both keys from `/test/assets/*` in the configured environment.
  - Command(s): `cd assets/automation && npx playwright test <new-spec-name> --list`
- Definition of Done:
  - Asset names, expected lesson guard, completion text, Easy-to-Difficult transition, and private assets are known and accessible but untracked.
- Gate:
  - Do not write a runnable spec until exact key names, image-based answers, and path-switch rules are confirmed.
- Dependencies:
  - Ticket owner/private asset owner access.
- Parallelizable Work:
  - Static review of MER-5672/5673 conventions can proceed while assets are being prepared.

## Phase 2: Implement the Additive Spec

- Goal: Add the MER-5677 lifecycle wrapper around the shared adaptive driver.
- Tasks:
  - [x] Create `assets/automation/tests/torus/student_delivery/phases-of-the-moon.spec.ts` from the MER-5673 structure.
  - [x] Configure MER-5677 ZIP/JSON keys, API-key skip behavior, placeholder runtime login, JSON parsing, and expected-title guard.
  - [x] Import the archive, set the learner credentials, open the lesson from the outline, and call `completeAdaptiveHappyPath`.
  - [x] Assert the private completion state and retain bounded best-effort teardown plus temp-directory deletion.
  - [x] Keep all answers and course artifacts in private storage only.
- Testing Tasks:
  - [ ] Run TypeScript type checking, linting, and formatting for the touched automation files.
  - Command(s): `cd assets/automation && yarn tsc --noEmit && yarn eslint tests/torus/student_delivery/<phases-of-the-moon>.spec.ts && yarn prettier --check tests/torus/student_delivery/<phases-of-the-moon>.spec.ts`
- Definition of Done:
  - The new spec is isolated, compiles, uses only shared infrastructure, and owns all MER-5677-specific behavior.
- Gate:
  - No duplicated generic driver/setup implementation; no private asset or answer is present in Git.
- Dependencies:
  - Phase 1 exact inputs.
- Parallelizable Work:
  - The static spec shell and final JSON-rule review can occur independently once the asset key contract is known.

## Phase 3: Exercise the Easy-to-Difficult Route and Close Driver Gaps

- Goal: Prove the full learner path and make only necessary reusable automation changes.
- Tasks:
  - [x] Run the targeted spec against a live local stack with scenario token, assets bucket, and automation API key configured.
  - [x] Confirm the Easy Mission start, the Difficult Mission switch, and final completion state, not merely lesson termination.
  - [x] Add the smallest generic POM/driver capabilities needed for the Infiniscope lesson interactions.
  - [x] Re-run the affected happy-path flow after shared helper changes.
- Testing Tasks:
  - [ ] Execute the targeted spec at least once successfully with private assets.
  - [ ] Execute regression coverage for any shared helper change.
  - Command(s): `cd assets/automation && npx playwright test <new-spec-name>`
- Definition of Done:
  - The test reaches expected completion through the documented Easy-to-Difficult route and any driver extension has focused regression evidence.
- Gate:
  - A successful real-asset run is required; an environment-driven skip is not completion evidence.
- Dependencies:
  - Phase 2 implementation and a running environment with configured private credentials/assets.
- Parallelizable Work:
  - No; diagnosing randomized adaptive progression requires a single reproducible execution context.

## Phase 4: Verify and Prepare Review

- Goal: Produce review-ready, traceable coverage with explicit residual environment constraints.
- Tasks:
  - [x] Run Harness documentation and requirements validation.
  - [ ] Inspect Git status/diff to ensure private artifacts and credentials are absent.
  - [ ] Record the exact asset key contract and test command in the PR description without including answer content.
  - [ ] Review changed TypeScript through security, performance, and TypeScript lenses, as required by repository policy.
- Testing Tasks:
  - [ ] Run all targeted static checks and the successful E2E command from prior phases.
  - [ ] Run `git diff --check`.
  - Command(s): `python3 /Users/nicocirio/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/features/mer-5677-phases-of-the-moon --action verify_plan && python3 /Users/nicocirio/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/features/mer-5677-phases-of-the-moon --action master_validate --stage plan_present && python3 /Users/nicocirio/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/features/mer-5677-phases-of-the-moon --check plan`
- Definition of Done:
  - Requirements traceability is valid, quality gates pass, and the diff contains only test infrastructure/docs with no private answer data.
- Gate:
  - PR-ready only after static checks and an authenticated Easy-to-Difficult execution have passed.
- Dependencies:
  - Phases 1–3.
- Parallelizable Work:
  - Documentation validation and diff/private-content inspection can run in parallel after the E2E run completes.

## Parallelization Notes

- Phase 1 asset preparation is external; while waiting, inspect shared helper behavior and draft the non-sensitive spec shell.
- Do not run two full imported-course instances against the same local environment unless their setup/teardown capacity is known; the tests are serial by design.
- If a shared helper changes, regressions should be evaluated before unrelated formatting/docs work is finalized.

## Phase Gate Summary

- Gate A: Private ZIP/JSON keys and the Easy-to-Difficult contract are confirmed and accessible.
- Gate B: The additive spec compiles, uses shared helpers, and contains no private instructional content.
- Gate C: A configured real-asset run reaches completion after the Easy-to-Difficult transition.
- Gate D: Static, traceability, and review gates pass with no private artifacts in the diff.
