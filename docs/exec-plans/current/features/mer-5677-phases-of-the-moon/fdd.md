# MER-5677 Adaptive Lesson: Phases of the Moon - Functional Design Document

## 1. Executive Summary

Add one self-contained student-delivery Playwright spec that follows the MER-5673 architecture: download the private ZIP and answer JSON, import a disposable course and learner section, open the target adaptive lesson, drive answers with `completeAdaptiveHappyPath`, and assert completion. The private JSON supplies all lesson-specific content and rules for the documented route: Easy Mission initially, then Difficult Mission at Mission Update. The repository contains only mechanics and stable non-sensitive guards.

## 2. Requirements & Assumptions

- Functional requirements:
  - Deliver the documented Easy-to-Difficult happy-path test and protect course IP/answers (`FR-001`, `FR-002`).
  - Reuse shared adaptive automation and maintain targeted diagnosability (`FR-003`, `FR-004`).
- Non-functional requirements:
  - Use bounded setup and teardown behavior and avoid new production interfaces.
  - Preserve the authenticated test-assets access boundary.
- Assumptions:
  - The final JSON conforms to `LessonAnswers`; its rule order and selectors select Easy Mission first and later switch to Difficult Mission.
  - The required archive and JSON will be seeded privately before the end-to-end test is run.

## 3. Repository Context Summary

- What we know:
  - `AutomationAssetsTask` downloads protected answer and archive assets and writes large archives outside Playwright tracing.
  - `AutomationSetupTask` imports an archive and creates a section/learner using the automation API key.
  - `AdaptiveLessonTask` opens a page from the outline and `AdaptiveHappyPathTask` scans/answers adaptive screens, reporting advancement and feedback.
  - MER-5673's `real-chem-dazzling-d-orbitals.spec.ts` is the current reference for expected-lesson validation and bounded best-effort cleanup.
- Unknowns to confirm:
  - The exact private asset names and the final path-switch answer rules.
  - Whether an existing driver interaction is sufficient for the Infiniscope simulation.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- New `phases-of-the-moon` spec:
  - owns MER-5677 asset keys, expected title guard, course lifecycle, and completion assertion.
- Private `answers.json`:
  - owns target title/search/completion strings plus widget, dropdown, input, and path-switch answer rules.
- Existing shared tasks and page objects:
  - own downloads, import, login data, adaptive scanning/answering, progression, and teardown.

### 4.2 State & Data Flow

1. The spec fetches `phases-of-the-moon_phases-of-the-moon/answers.json` and the ZIP concurrently through `/test/assets/*` using the scenario token.
2. It parses and validates the answer key's lesson identity, then imports the archive and sets the runtime learner credentials.
3. The learner logs in, locates the lesson by private JSON title/search term, selects Easy Mission, and progresses through Levels 1 and 2.
4. At Mission Update, answer rules select “Switch to difficult Mission”; `completeAdaptiveHappyPath` then repeatedly scans, answers, and advances through the difficult levels until the lesson ends.
5. The spec asserts the private JSON completion text, then performs bounded best-effort course teardown and deletes the local temporary archive directory.

### 4.3 Lifecycle & Ownership

- The test owns only data created by its import request.
- The archive temp directory is owned by the test and always removed in `afterAll`.
- Object storage is pre-seeded externally and is read-only from the test.
- Answer content remains outside Git; the test uses no fallback hardcoded answers.

### 4.4 Alternatives Considered

- Embed answers and course fixtures in the repository: rejected because they are private instructional IP and would duplicate MER-5672's protected-asset solution.
- Build a lesson-specific driver: rejected unless a documented unsupported interaction proves the generic driver insufficient.
- Cover a separate all-Easy or all-Difficult route: rejected because the updated happy-path document specifies the Easy-to-Difficult transition, and a single documented route is more diagnosable.

## 5. Interfaces

- Asset read contract:
  - `GET /test/assets/phases-of-the-moon_phases-of-the-moon/<asset>` with `x-playwright-scenario-token`.
- Private JSON contract:
  - `LessonAnswers`, with lesson metadata and answer rules that select Easy Mission first and Difficult Mission at Mission Update.
- Course setup contract:
  - `importArchiveAndCreateSection(request, archive.filePath, { baseUrl, apiKey })`.
- Adaptive completion contract:
  - `completeAdaptiveHappyPath(page, adaptiveLesson.deck, answers)`.

## 6. Data Model & Storage

- No application database schema, migration, or production storage change.
- The test creates imported project/section/learner records through the existing automation endpoint and removes them best-effort.
- Private object storage contains the ZIP and answer JSON under the `phases-of-the-moon_phases-of-the-moon/` prefix.

## 7. Consistency & Transactions

- Archive import and section creation are owned by the existing automation setup endpoint.
- The adaptive runtime owns learner attempt state and normal server-side evaluation.
- The test has no cross-request transaction; it fails fast if setup or progression fails and attempts cleanup afterward.

## 8. Caching Strategy

N/A. The test reads each private asset once and exercises current delivery behavior.

## 9. Performance & Scalability Posture

- Download archive bytes with plain `fetch` to avoid traced-request archive corruption.
- Set test timeouts consistent with the MER-5673 30-screen adaptive coverage baseline.
- Restrict execution to targeted Playwright lanes; this is not a fast unit-test concern.

## 10. Failure Modes & Resilience

- Missing/unauthorized asset: surface HTTP status and key in the existing helper error.
- JSON targets another lesson: fail in `beforeAll` using an expected-title regex guard.
- The documented route cannot advance: `completeAdaptiveHappyPath` reports screen index, answer label, and feedback after its bounded stuck threshold.
- Teardown timeout/failure: warn with project and section slugs while still deleting the local temp directory.
- New unsupported interaction: capture it from the happy-path document and add a minimal generic driver extension plus tests before encoding the rule.

## 11. Observability

- Reuse existing per-screen advancement logs and feedback diagnostics.
- Reuse MER-5673 teardown warnings with the MER-5677 identifier and affected slugs.
- Playwright trace, screenshots, and video behavior remain configured by the existing automation project.

## 12. Security & Privacy

- Maintain scenario-token protection on asset reads and API-key protection on automation setup.
- Do not commit archives, answer JSON, credentials, or values from the private happy-path document.
- Keep error messages limited to asset keys, lesson metadata, and disposable test identifiers.

## 13. Testing Strategy

- Static: run TypeScript type checking, ESLint, and Prettier on affected automation files.
- Targeted E2E: with credentials/assets, execute the new spec and verify the completion text after Easy-to-Difficult progression.
- Regression: if shared driver or POM behavior changes, run the relevant existing adaptive specs and focused unit/regression tests for the changed helper.
- Documentation: validate `requirements.yml`, PRD, FDD, and plan gates.

## 14. Backwards Compatibility

- This is an additive test file and does not change product runtime behavior.
- Existing asset, setup, and adaptive test callers remain unchanged unless a narrowly justified shared capability is added.

## 15. Risks & Mitigations

- Asset naming mismatch: agree and document the exact `phases-of-the-moon_phases-of-the-moon/` key names before coding.
- JSON schema mismatch: validate the key in a targeted test run and extend the shared type only when a new generic rule is necessary.
- Adaptive randomness: use semantic matching/rules rather than fixed screen positions and encode the explicit Easy-to-Difficult transition.
- Cleanup leak: retain bounded best-effort cleanup and warning output.

## 16. Open Questions & Follow-ups

- Obtain the archive and JSON from the ticket owner and seed the configured private bucket.
- Confirm the exact stable title, search term, completion string, archive filename, and image-based answer mappings from the source document.
- If a driver gap appears, open a narrowly scoped follow-up or include it only with focused regression coverage.

## 17. References

- Jira: `MER-5677` — Adaptive Lesson: Phases of the Moon - Infiniscope MASTER (Playwright).
- PR #6731 / MER-5672 — private adaptive course asset infrastructure.
- PR #6738 / MER-5673 — shared adaptive happy-path driver and current spec shape.
- `assets/automation/tests/torus/student_delivery/real-chem-dazzling-d-orbitals.spec.ts`.
- `assets/automation/src/systems/torus/tasks/AdaptiveHappyPathTask.ts`.
