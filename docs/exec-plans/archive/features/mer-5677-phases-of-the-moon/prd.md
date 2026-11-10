# MER-5677 Adaptive Lesson: Phases of the Moon - Product Requirements Document

## 1. Overview

Add an archive-backed Playwright happy-path test for the non-scored adaptive practice lesson “Phases of the Moon - Infiniscope MASTER.” The documented route starts on Easy Mission, switches to Difficult Mission at Mission Update, and continues to completion without embedding private course material or answer keys in this public repository.

## 2. Background & Problem Statement

The lesson depends on a simulation, question banks, randomization, and learner-selected pathways. Manual happy-path instructions and correct answers are maintained in the ticket's linked private document. Without automation, a release-sensitive adaptive lesson remains unverified and regressions in hard-path progression are expensive to find.

MER-5672 established authenticated private ZIP/JSON asset retrieval for adaptive lesson coverage; MER-5673 extracted the reusable happy-path driver. MER-5677 should add coverage using that established pattern, not a third implementation.

## 3. Goals & Non-Goals

### Goals

- Cover the documented route through the Phases of the Moon lesson: Easy Mission initially, then Difficult Mission from Mission Update onward.
- Reuse the private asset, course-import, adaptive-deck, and answer-driver infrastructure.
- Keep course IP and answer keys private.

### Non-Goals

- Change lesson content, adaptive runtime behavior, scoring, or simulation code.
- Cover every randomized variant or the easy pathway.
- Add new generic adaptive automation infrastructure unless the lesson exposes a concrete unsupported interaction.

## 4. Users & Use Cases

- QA and release engineering: run targeted browser coverage for the lesson's high-risk hard pathway.
- Course maintainers: receive regression evidence without publishing private answers.
- Future automation contributors: add archive-backed adaptive tests using an established convention.

## 5. UX / UI Requirements

- The test must interact through the learner delivery UI, beginning from the course outline.
- The test must choose Easy Mission at Mission Level and select “Switch to difficult Mission” at Mission Update.
- Assertions should use accessible or stable rendered-state selectors supplied by existing page objects.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: setup, page advancement, and cleanup use existing bounded helper behavior.
- Security and privacy: the archive and answer key are retrieved only from the scenario-token-protected asset endpoint; neither is checked into Git.
- Maintainability: use shared tasks and page objects; the spec owns only MER-5677-specific asset keys, lesson guard, and hard-path answers.
- Performance: retain the established targeted Playwright timeout profile; no new production hot path is introduced.

## 9. Data, Interfaces & Dependencies

- Private object storage must contain the MER-5677 course archive and `answers.json` under an agreed `phases-of-the-moon_phases-of-the-moon/` key prefix.
- `answers.json` must conform to `LessonAnswers` and include rules for the initial Easy Mission selection and later switch to Difficult Mission.
- The test depends on `/test/assets/*`, `PLAYWRIGHT_SCENARIO_TOKEN`, `PLAYWRIGHT_ASSETS_BUCKET`, and `PLAYWRIGHT_AUTOMATION_API_KEY`.
- The ticket's private happy-path document is the authoritative source for the archive, answer key, expected lesson text, completion text, and hard-path rules.

## 10. Repository & Platform Considerations

- Browser automation belongs in `assets/automation/tests/torus/student_delivery/` and uses the existing TypeScript Playwright tooling.
- The shared driver lives in `assets/automation/src/systems/torus/tasks/AdaptiveHappyPathTask.ts`; general-purpose improvements require regression coverage for existing adaptive specs.
- The imported course and learner section are test-owned and must be cleaned up best-effort, preserving the bounded teardown convention introduced in MER-5673.
- Jira MER-5677 is the system-of-record issue.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

The test is additive coverage and deploys with the normal repository test suite. No production migration is required.

## 12. Telemetry & Success Metrics

- Playwright screen-by-screen logs and failure feedback from `completeAdaptiveHappyPath` make progression failures diagnosable.
- Success is a repeatable targeted run reaching the answer key's completion text after the documented Easy-to-Difficult route.
- No production telemetry is needed because this changes only internal test coverage.

## 13. Risks & Mitigations

- Private assets or credentials unavailable: skip as documented locally and configure the protected bucket before end-to-end validation.
- Randomization changes the visible question sequence: encode resilient answer rules in the private JSON and test the documented Easy-to-Difficult route, not one fixed screen sequence.
- Unsupported simulation interaction: add the smallest reusable page-object/driver capability, with focused regression coverage, only after documenting the exact interaction.
- Teardown remains vulnerable to the known full-course cleanup limitation: retain bounded best-effort cleanup and name leaked slugs in warnings.

## 14. Open Questions & Assumptions

### Open Questions

- What exact archive filename and object key should the private bucket use for MER-5677?
- Does the private answer document already have a `LessonAnswers`-compatible JSON, including the hard-path selection, or must it be normalized?
- Which lesson text is stable enough for the expected-lesson guard and final completion assertion?
- Does the lesson require an interaction not handled by the shared adaptive driver?

### Assumptions

- Assets will be stored under `phases-of-the-moon_phases-of-the-moon/` and will remain private.
- The current `LessonAnswers` schema can encode the hard-path choice through its MCQ, dropdown, or iframe rules.
- MER-5672 and MER-5673 are the canonical implementation references.

## 15. QA Plan

- Automated validation:
  - Validate Harness traceability and documentation gates.
  - Run TypeScript type checking, ESLint, and Prettier for the new spec.
  - With configured private assets and credentials, run the targeted Playwright spec and verify hard-path completion.
- Manual validation:
  - Compare private JSON rules and the selected path against the ticket's happy-path document.
  - Confirm the uploaded archive/JSON keys match the spec exactly and are not tracked by Git.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
