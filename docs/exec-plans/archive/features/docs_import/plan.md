# Google Docs Page Import — Delivery Plan

Scope and guardrails reference the approved PRD (`docs/features/docs_import/prd.md`) and FDD (`docs/features/docs_import/fdd.md`). The plan decomposes work into dependency-ordered phases with gating tests and explicit definitions of done.

- **Scope Summary:** Deliver an admin-only workflow that imports Google Docs via Markdown export, converts content (including CustomElements), uploads embedded images to the Torus media library, creates the resulting page in the curriculum hierarchy.
- **Non-Functional Guardrails:** p50 import ≤ 6 s, p95 ≤ 12 s for ≤ 3 MB Markdown; fail at 10 MB. ≤ 1 % error rate; admin-only access; tenant isolation; WCAG-compliant modal; media ingestion dedupes by hash.

## Clarifications & Default Assumptions
- Media deduplication is hash-based: identical images across imports reuse existing assets. (Assumed until product says otherwise.)
- If media upload fails, importer should fall back to the original data URL and surface warnings rather than aborting the entire import.
- Maximum concurrent imports per node remains five to avoid exhausting HTTP/media resources.

## Phase 1: Fixture Capture & Test Harness Foundations
- **Goal:** Establish representative Markdown fixtures, warning catalogue, and testing utilities.
- **Tasks**
  - [x] Capture at least three anonymised Markdown exports (baseline text, CustomElement YouTube, MCQ, media-heavy) and store under `test/support/google_docs_import/`.
  - [x] Document expected Torus outputs per fixture (tables, CustomElements, media) in a README alongside fixtures.
  - [x] Implement test helpers for loading fixtures and configuring `Oli.Test.MockHTTP` responses.
  - [x] Seed warning catalogue with codes/messages referenced throughout the pipeline.
  - [x] Tests: `mix test test/oli/google_docs/fixtures_test.exs` verifying fixture integrity and helper behaviour.
- **Definition of Done:** Fixtures committed; helper exercises pass; baseline test suite (`mix test`) remains green. Gate unlocks Phases 2–4.

## Phase 2: HTTP Client & Concurrency Guardrails *(can run in parallel with Phase 3 after Phase 1 DoD)*
- **Goal:** Provide network layer with validation, retries, size enforcement, and FILE_ID guard.
- **Tasks**
  - [x] Implement `Oli.GoogleDocs.Client.fetch_markdown/2` with host allowlist, regex validation, retry-once policy, and 10 MB cap.
  - [x] Tests: `mix test test/oli/google_docs/client_test.exs` covering valid/invalid IDs, timeout retry, oversized responses.
- **Definition of Done:** All new tests and full suite pass; Gate unlocks Phases 5–6.

## Phase 3: Markdown Parsing & Content Normalisation *(parallel to Phase 2 once Phase 1 complete)*
- **Goal:** Convert Markdown AST into Torus-friendly block structures and identify CustomElements.
- **Tasks**
  - [x] Implement `Oli.GoogleDocs.MarkdownParser` producing intermediate blocks, CustomElement specs, and embedded media payloads.
  - [x] Map headings, paragraphs, inline marks, lists, blockquotes, and tables to Torus equivalents.
  - [x] Detect `CustomElement` tables and forward metadata for specialised handling; warn on unsupported constructs.
  - [x] Tests: `mix test test/oli/google_docs/markdown_parser_test.exs` validating fixtures, warning counts, and CustomElement detection.
- **Definition of Done:** Parser tests pass; warning catalogue entries referenced and documented. Gate unlocks Phases 4–5.

## Phase 4: Media Ingestion Pipeline *(depends on Phase 3 for payload shape)*
- **Goal:** Decode base64 images, dedupe, upload, and produce Torus asset URLs with robust failure handling.
- **Tasks**
  - [x] Implement `Oli.GoogleDocs.MediaIngestor` defers to using existing media library module to upload and track new media library entries for the project
  - [x] Tests: `mix test test/oli/google_docs/media_ingestor_test.exs` covering success and failure scenarios (happy path, duplicate reuse, oversized images, upload error fallback)
- **Definition of Done:** Media tests green; configuration knobs (e.g., media budget) documented. Gate unlocks Phase 5.

## Phase 5: MCQ Activity Builder & CustomElement Conversion *(depends on Phases 3–4)*
- **Goal:** Transform CustomElement specs into Torus components and activities.
- **Tasks**
  - [x] Implement `Oli.GoogleDocs.CustomElements` dispatcher returning typed structs for recognised elements.
  - [x] Build `Oli.GoogleDocs.McqBuilder` for MCQ activity creation, including validation for `correct`, `choiceN`, `feedbackN`.
  - [x] Ensure graceful fallback to table rendering with warnings when validation fails.
  - [x] Tests: `mix test test/oli/google_docs/custom_elements_test.exs` (YouTube + MCQ success/failure cases) and `mix test test/oli/google_docs/mcq_builder_test.exs` (activity creation with mocked ActivityEditor).
- **Definition of Done:** CustomElement + MCQ tests pass; warnings integrated with catalogue. Gate unlocks Phase 6.

## Phase 6: Import Orchestrator & Persistence Transaction *(depends on Phases 2–5)*
- **Goal:** Compose download, parsing, media ingestion, activity creation, and page persistence.
- **Tasks**
  - [x] Implement `Oli.GoogleDocs.Import.import/4`, orchestrating pipeline, aggregating warnings, and returning revision.
  - [x] Integrate ETS in-flight guard, audit logging, and telemetry span start/stop hooks.
  - [x] Repo transaction ensures atomic creation; add fallback to external URLs when media upload warnings present.
  - [x] Tests: `mix test test/oli/google_docs/import_test.exs` exercising success, invalid FILE_ID, media failure, MCQ fallback, audit capture.
- **Definition of Done:** Import tests pass; full `mix test` suite green. Gate unlocks Phase 7.

## Phase 7: LiveView Integration & UX Polish *(can begin once Phase 6 API stabilises)*
- **Goal:** Wire the importer into CurriculumLive with accessible UX.
- **Tasks**
  - [x] Add admin-only button, modal, and validation messaging in `CurriculumLive`.
  - [x] Invoke importer via `Task.Supervisor.async_nolink`; handle success/error/warnings, reload hierarchy, and navigate to new page.
  - [x] Implement aria-live announcements, focus trapping, and keyboard-only workflow per PRD §5.
  - [x] Tests: `mix test test/oli_web/live/workspaces/course_author/curriculum_live_import_test.exs` covering visibility, validation errors, success/warning flows, accessibility expectations.
- **Definition of Done:** LiveView tests and overall suite pass; manual accessibility smoke test documented. Gate unlocks Phase 8.

## Parallelisation Notes
- Phase 1 gates the rest; once complete, Phases 2 and 3 can proceed in parallel.
- Phase 4 depends on Phase 3, but can begin while Phase 2 finishes (HTTP client only needed for integration tests in Phase 6).
- Phase 5 requires output from Phases 3–4.
- Phase 6 starts after Phases 2–5 achieve DoD.
- Phase 7 may begin once Phase 6’s API is stable; LiveView work can progress alongside late-stage telemetry efforts in Phase 8.
- Phase 8 is partially parallel with Phase 7 but must finish before Phase 9.

## Phase Gate Summary
- **Gate A (post Phase 1):** Fixtures + helpers ready; approve deeper implementation work.
- **Gate B (post Phase 6):** Backend importer complete and tested; greenlight LiveView + observability work.
- **Gate C (post Phase 7/8):** Feature functionally integrated with telemetry/security sign-off; move to final QA.
- **Gate D (post Phase 9):** Release readiness confirmed; proceed to deployment window.
