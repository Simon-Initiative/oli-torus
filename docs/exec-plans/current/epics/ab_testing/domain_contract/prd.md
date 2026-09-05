# A/B Testing Domain Boundary And API Contract - Product Requirements Document

## 1. Overview
Define the native A/B testing domain boundary, operational persistence, telemetry contracts, and context APIs that all later MVP work depends on. The outcome is an implementation-ready contract for experiment definitions, decision points, conditions, sticky assignment state, experiment event emission, reward feedback, analytics query boundaries, and algorithm state without committing Torus to a separately deployed service.

## 2. Background & Problem Statement
Torus currently depends on UpGrade runtime HTTP calls and UpGrade-shaped authoring/export flows for a narrow alternatives experimentation workflow. Replacing that dependency requires native operational state for delivery correctness and native telemetry for research evidence, but direct table access from delivery, authoring, or analytics would recreate long-term coupling inside the monolith. The first MVP slice must establish the data ownership and API boundary before runtime, authoring, analytics, and Thompson Sampling work proceeds.

## 3. Goals & Non-Goals
### Goals
- Establish A/B testing as a dedicated Torus domain/context with owned operational persistence, experiment telemetry contracts, and stable context APIs.
- Define domain language, identifiers, request/response shapes, and ownership rules for all MVP workflows.
- Define assignment algorithm contracts for weighted deterministic random assignment and Thompson Sampling.
- Preserve multi-tenant scoping and publication/delivery boundaries from the start.

### Non-Goals
- Build authoring UI, analytics dashboards, or full lifecycle controls.
- Extract A/B testing into an external service or separately deployed runtime.
- Implement advanced UpGrade parity such as factorial experiments, feature flags, or stratified sampling.

## 4. Users & Use Cases
- Engineers: implement delivery, authoring, analytics, and adaptive policy work against stable context APIs.
- Authors and learning engineers: rely on future native experiment behavior that is not coupled to UpGrade.
- Administrators and operators: inspect owned experiment data and operational evidence without depending on external UpGrade availability.

## 5. UX / UI Requirements
- N/A

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Domain APIs must preserve institution, project, section, user, and enrollment scoping.
- Assignment-related contracts must support local, transactional runtime behavior.
- API shapes must avoid leaking private Ecto schemas or table-shaped payloads across Torus domains.
- The boundary must be reviewable under security and performance review lenses before dependent slices implement runtime behavior.

## 9. Data, Interfaces & Dependencies
- Owned PostgreSQL persistence covers low-volume operational state: experiment definitions, decision points, conditions, lifecycle state, sticky assignment state required for delivery correctness, and current adaptive policy state required for runtime assignment.
- Experiment event history for assignment, exposure, outcome/reward observation, and policy-update audit evidence is emitted as xAPI and served for analytics through ClickHouse.
- Context APIs cover delivery assignment/exposure telemetry, authoring/lifecycle commands, analytics query boundaries, and reward/outcome feedback.
- Algorithm behavior contracts include assignment selection and reward recording semantics.
- The contract depends on existing alternatives resources, section/project experiment flags, publication immutability, and delivery enrollment identity.

## 10. Repository & Platform Considerations
- Backend domain logic belongs under `lib/oli/` with Phoenix web code in `lib/oli_web/` acting as transport or UI orchestration only.
- Runtime operational state should use Ecto/PostgreSQL where transactional delivery correctness requires it, and should avoid using PostgreSQL as a heavy event log or dashboard/export analytics source.
- Experiment events should use the existing xAPI/S3/ClickHouse infrastructure so large analytics queries and dataset exports do not scan operational tables.
- Scenario tests are expected for workflow-level integration once later slices consume the boundary.
- Jira should track this slice as the first MVP work item because other child work depends on it.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Success is measured by downstream slices consuming context APIs without direct experiment table access.
- Domain API calls should expose enough telemetry hooks for later runtime latency, error, reward-processing, and assignment monitoring.

## 13. Risks & Mitigations
- Risk: The boundary becomes a heavy pseudo-service that slows implementation. Mitigation: define a Torus context API and owned persistence boundary, not a separate runtime.
- Risk: API contracts leak schemas and make later refactors unsafe. Mitigation: require stable IDs and domain request/response types.
- Risk: Analytics needs force direct joins against private PostgreSQL tables. Mitigation: define approved ClickHouse-backed query contracts and keep PostgreSQL event rows, if any, transitional or operational only.

## 14. Open Questions & Assumptions
### Open Questions
- What exact module namespace should own the native A/B testing domain?
- Which analytics reads need ClickHouse projections versus context-owned query functions?
- Which operational PostgreSQL records are required for delivery correctness and idempotency, and which event records should move entirely to xAPI?

### Assumptions
- Existing and in-progress UpGrade experiments are not migrated.
- MVP assignment is individual and enrollment-based.
- Thompson Sampling uses binary rewards and needs current runtime policy state in PostgreSQL plus auditable policy-update evidence in xAPI/ClickHouse.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for context API contracts, validation, scoping, and ownership rules.
  - Migration/schema tests where persistence is introduced.
- Manual validation:
  - Engineering review confirms delivery, authoring, and analytics consumers can meet MVP needs without direct table access.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
