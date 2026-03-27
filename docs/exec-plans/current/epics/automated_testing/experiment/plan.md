# Automated Testing Experiment - Delivery Plan

Scope and reference artifacts:
- PRD: `/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/prd.md`
- FDD: `/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/fdd.md`

## Scope
Deliver a narrow V1 of agent-driven manual test automation centered on repository-managed schemas, YAML test assets, Python support tooling, repository-local agent skills under `.agents/skills/`, explicit execution-request preparation, canonical run-report generation, and deterministic S3 persistence. Keep the implementation outside core Phoenix request handling, avoid new database or UI surface area, and preserve the schema examples described in `information.md` while treating human-to-agent messaging as out of scope.

## Clarifications & Default Assumptions
- `information.md` remains the source artifact for the informal schema examples; its human-message examples are contextual only and not part of the repository tooling scope.
- The advanced runtime is the primary executor, but this work item still owns repository-local Python utilities the runtime may call for validation, conversion, normalization, and upload.
- This work item also owns the repository-local agent skills under `.agents/skills/` that expose those utilities to the runtime in a stable way.
- V1 should optimize for one representative smoke suite plus a small set of stable authoring and delivery cases, not broad inventory migration.
- Feature flags are not planned for this work item.
- Telemetry, issue tracking, and code review expectations are in scope by default per `harness.yml`.
- S3 upload verification may use a test bucket or MinIO-compatible target if that is the safest local path during implementation.

## Phase 1: Contracts And Repository Skeleton
- Goal: establish the repository structure, schema contracts, and traceable sample assets that unblock all later work.
- Tasks:
  - [ ] Create the `manual_testing/` directory structure for schemas, cases, suites, tools, and local results handling.
  - [ ] Define canonical `test_case`, `test_suite`, and `test_run` schemas from the examples in `information.md` and the FDD data model. This phase covers `AC-001`, `AC-005`, `AC-006`, and `AC-007`.
  - [ ] Add a minimal sample authoring case, delivery case, and smoke suite fixture to exercise schema shape and suite references. This phase supports `AC-003` and `AC-004`.
  - [ ] Document required runtime inputs for explicit execution preparation, environment selection, and credentials-source references without storing secrets. This phase supports `AC-003`, `AC-004`, and `AC-008`.
  - [ ] Open or link the Jira work item and note that security and performance review will be required during implementation review.
- Testing Tasks:
  - [ ] Add schema fixture validation tests for valid and invalid case, suite, and run documents. This verifies `AC-001`.
  - [ ] Add golden fixture tests for canonical run-report shape and failure-kind enumeration. This verifies `AC-005` and `AC-007`.
  - Command(s): `python3 -m unittest manual_testing.tests.test_schemas`
- Definition of Done:
  - Repository skeleton exists and is reviewable.
  - Schema contracts are explicit and backed by failing/passing fixtures.
  - Sample assets compile the intended V1 shape without unresolved placeholders.
- Gate:
  - Schema tests pass and reviewers agree the contracts are stable enough for tooling work.
- Dependencies:
  - None.
- Parallelizable Work:
  - Case and suite fixture authoring can proceed in parallel with schema authoring once required fields are agreed.

## Phase 2: Validation And Conversion Utilities
- Goal: provide deterministic Python support tooling for authored asset validation and spreadsheet-to-YAML conversion before runtime execution begins.
- Tasks:
  - [ ] Implement `manualtest.py validate` and `lint` support for case, suite, and run documents with actionable error output. This phase directly implements `AC-001`.
  - [ ] Implement CSV or spreadsheet conversion support that preserves source wording and records ambiguity warnings in output metadata. This phase directly implements `AC-002`.
  - [ ] Add provenance fields or metadata shaping needed for converted cases without bloating the authored schema.
  - [ ] Document how the advanced runtime can call validation and conversion utilities as optional helpers rather than mandatory orchestration steps.
- Testing Tasks:
  - [ ] Add Python unit tests for valid/invalid schema validation paths and duplicate-ID or malformed-structure lint behavior. This verifies `AC-001`.
  - [ ] Add conversion tests that preserve raw step and expected-result text and emit warnings for ambiguous input rows. This verifies `AC-002`.
  - Command(s): `python3 -m unittest manual_testing.tests.test_validate manual_testing.tests.test_convert`
- Definition of Done:
  - Validation and conversion utilities are callable independently of the advanced runtime.
  - Error and warning outputs are deterministic enough for runtime consumption and human debugging.
- Gate:
  - Validation and conversion tests pass, and converted fixtures are reviewable by QA without manual reconstruction.
- Dependencies:
  - Phase 1 contracts and fixtures.
- Parallelizable Work:
  - Conversion utility tests and documentation can proceed in parallel with lint rule implementation.

## Phase 3: Execution Request Preparation And Result Normalization
- Goal: define how explicit structured runtime inputs map to repository assets and produce normalized per-case execution results for the advanced runtime.
- Tasks:
  - [ ] Define the structured runtime input contract for suite or case targeting, environment selection, credentials-source references, documentation context paths, and optional release or run identifiers. This phase supports `AC-003` and `AC-004`.
  - [ ] Implement execution-request normalization helpers that resolve suite membership, case paths, environment metadata, documentation context paths, and credentials-source references. This phase supports `AC-003`, `AC-004`, and `AC-007`.
  - [ ] Implement canonical run-report synthesis from runtime observations, including per-step outcomes, per-assertion outcomes, notes, confidence, timing, and `failure_kind`. This phase directly implements `AC-005` and `AC-007`.
  - [ ] Add local result workspace writing under `manual_testing/results/` for one report per case and an optional suite summary. This phase supports `AC-004`, `AC-005`, and `AC-007`.
  - [ ] Implement repository-local agent skills under `.agents/skills/` that wrap Phase 1 through 3 tooling for validation, execution-request preparation, and result normalization. This phase supports `AC-003`, `AC-004`, `AC-005`, and `AC-007`.
- Testing Tasks:
  - [ ] Add unit tests for explicit target-resolution and execution-request behavior from representative structured inputs. This verifies `AC-003` and `AC-004`.
  - [ ] Add normalization tests using fake runtime result fixtures for passed, failed, blocked, and execution-error outcomes. This verifies `AC-005` and `AC-007`.
  - [ ] Add integration tests for suite expansion into one canonical report per case. This verifies `AC-004`.
  - [ ] Manually exercise the new `.agents/skills/` entry points against the Phase 3 utilities and confirm they accept structured inputs without human-message parsing. This verifies `AC-003` and `AC-004`.
  - Command(s): `python3 -m unittest manual_testing.tests.test_runtime_contract manual_testing.tests.test_report_normalization`
- Definition of Done:
  - The runtime-facing contract is explicit enough for a separate advanced runtime implementation to consume.
  - Canonical run reports can be produced deterministically from fake execution observations.
- Gate:
  - Reviewers confirm the explicit runtime-input contract is sufficient for agent-skill use and normalized run reports match the schema.
- Dependencies:
  - Phase 1 schema contracts and Phase 2 utility behavior.
- Parallelizable Work:
  - Command-contract documentation and normalization tests can proceed in parallel once the report schema is fixed.

## Phase 4: S3 Persistence, Telemetry, And Security Hardening
- Goal: complete the durable storage and observability path while enforcing secret-handling and operational boundaries.
- Tasks:
  - [ ] Implement upload support for canonical run reports and optional artifacts to deterministic S3 object keys. This phase directly implements `AC-006`.
  - [ ] Write upload metadata back into local reports and keep local artifacts intact when remote upload fails. This phase supports `AC-006` and `AC-007`.
  - [ ] Implement structured lifecycle event emission for validation, conversion, run start/finish, and upload outcomes without leaking secrets. This phase directly implements `AC-008`.
  - [ ] Add redaction safeguards for credentials, tokens, cookies, and other obviously sensitive note content before persistence or telemetry emission. This phase supports `AC-006`, `AC-007`, and `AC-008`.
  - [ ] Document configuration expectations for AWS S3 or MinIO-compatible verification targets.
- Testing Tasks:
  - [ ] Add upload-path and metadata tests using a test bucket abstraction or MinIO-compatible harness. This verifies `AC-006`.
  - [ ] Add failure-mode tests covering upload failure, retry boundaries, and local artifact retention. This verifies `AC-006` and `AC-007`.
  - [ ] Add event-emission and redaction tests for lifecycle telemetry. This verifies `AC-008`.
  - Command(s): `python3 -m pytest manual_testing/tests/test_upload.py manual_testing/tests/test_observability.py`
- Definition of Done:
  - Durable upload behavior is deterministic and leaves inspectable local results on failure.
  - Telemetry and logs are useful operationally and free of secret material.
- Gate:
  - Upload and observability tests pass, and reviewers sign off on security/privacy handling.
- Dependencies:
  - Phase 3 report normalization.
- Parallelizable Work:
  - Upload implementation and telemetry redaction tests can proceed in parallel once the run-report format is stable.

## Phase 5: End-To-End Smoke Coverage And Release Readiness
- Goal: prove the V1 flow against representative Torus paths and close the work item with implementation-ready verification evidence.
- Tasks:
  - [ ] Author or refine at least one authoring-focused case, one delivery-focused case, and one smoke suite suitable for real non-production execution. This phase verifies `AC-003` and `AC-004`.
  - [ ] Execute an end-to-end smoke run through the advanced runtime against a non-production environment using the `.agents/skills/` flow backed by the structured execution-request tooling. This phase verifies `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, and `AC-008`.
  - [ ] Review stored reports and artifacts with QA to confirm readability, triage usefulness, and command-flow ergonomics.
  - [ ] Capture any follow-on gaps such as runtime-specific integration, screenshot policy, or suite-summary schema decisions as new backlog items instead of expanding V1 scope.
  - [ ] Run final code review with mandatory security and performance lenses plus any Python/tooling-specific review needed by the changed files.
- Testing Tasks:
  - [ ] Run the most targeted Python test suites from earlier phases plus one end-to-end smoke execution in a controlled environment. This verifies `AC-001` through `AC-008`.
  - [ ] Perform manual QA review of generated YAML, canonical run reports, S3 objects, and telemetry traces. This verifies `AC-002`, `AC-005`, `AC-006`, and `AC-008`.
  - Command(s): `python3 -m pytest manual_testing/tests` and one real runtime-triggered smoke run command
- Definition of Done:
  - A representative end-to-end smoke flow completes through the intended structured runtime-input model.
  - Canonical reports, uploads, and telemetry are demonstrably usable for QA and release triage.
  - Follow-on work is explicitly separated from V1.
- Gate:
  - Stakeholders accept that V1 proves the agent-driven workflow with sufficient operational clarity to move into implementation or pilot usage.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Final documentation cleanup and code review preparation can happen in parallel with smoke-run scheduling once tooling is stable.

## Parallelization Notes
- Phase 1 schema work and fixture authoring can overlap after the minimal contract fields are chosen.
- Phase 2 conversion work can proceed in parallel with validation error-shaping once the schemas are stable.
- Within Phase 3, command grammar documentation and run-report normalization tests are safe to split.
- Within Phase 4, upload-path work and telemetry/redaction work are parallel-safe once the canonical run-report format is fixed.
- Phase 5 should stay mostly serial because it is the integration proof point for all previous phases.

## Phase Gate Summary
- Gate A: Schema contracts, fixtures, and repository skeleton are stable enough to support utility implementation.
- Gate B: Validation and conversion utilities pass targeted tests and are usable by the advanced runtime.
- Gate C: Structured execution-request contract and run-report normalization are explicit and tested.
- Gate D: S3 persistence, redaction, and telemetry behavior are verified under success and failure conditions.
- Gate E: A representative end-to-end smoke run proves the V1 workflow and closes `AC-001` through `AC-008`.
