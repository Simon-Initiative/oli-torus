# Native Authoring And Experiment Lifecycle - Product Requirements Document

## 1. Overview
Define the native authoring and lifecycle requirements for creating, configuring, starting, pausing, completing, and archiving MVP A/B testing experiments. This slice gives authors and permitted administrators predictable controls for non-adaptive and Thompson Sampling experiments after the native runtime model is stable.

## 2. Background & Problem Statement
The current authoring surface is UpGrade-shaped and includes JSON export workflows that do not fit native A/B testing. Native authoring must let users manage experiment definitions and lifecycle states while preserving content versioning, assignment stability, and validation rules once learners have assignments.

## 3. Goals & Non-Goals
### Goals
- Replace UpGrade-specific authoring copy and JSON download workflows with native experiment authoring.
- Support create, edit, start, pause, complete, and archive behaviors where required for MVP.
- Allow configurable condition weights for simple A/B/N experiments.
- Support MVP controls for weighted random versus Thompson Sampling where product requirements allow author choice.
- Enforce validation rules for condition changes after assignments exist.

### Non-Goals
- Provide full UpGrade admin UI parity.
- Implement preview users or preview assignments unless needed for initial native authoring.
- Support advanced segments, factorial designs, feature flags, or additional adaptive algorithms.

## 4. Users & Use Cases
- Authors: define alternatives experiments and publish content that can be used in native experiments.
- Learning engineers and researchers: configure condition weights or Thompson Sampling behavior for studies.
- Administrators: manage permissions and lifecycle transitions for experiments that affect delivery.
- Instructors: understand whether experiments are active in their sections when surfaced by later reporting.

## 5. UX / UI Requirements
- Authoring flows must use native A/B testing language and remove UpGrade-specific labels and JSON workflow affordances.
- Lifecycle controls must make active, paused, completed, and archived states clear.
- Validation errors must explain why assigned conditions cannot be changed unsafely.
- Thompson Sampling controls must expose only MVP-safe configuration and guardrail states.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Permission checks must prevent unauthorized experiment creation, lifecycle changes, or destructive edits.
- Authoring must respect published content immutability and not mutate published revisions.
- UI flows must be accessible within existing Phoenix LiveView or focused React patterns.

## 9. Data, Interfaces & Dependencies
- Depends on A/B testing-owned persistence and lifecycle validation.
- Depends on delivery runtime semantics for active, paused, and inactive experiment states.
- Depends on Thompson Sampling policy state and guardrail semantics where adaptive experiments are authorable.
- Uses authoring-facing context APIs rather than direct table access.

## 10. Repository & Platform Considerations
- Use existing authoring LiveView or React entry points rather than creating a broad new frontend shell.
- Backend validations must live in domain contexts, with web code handling forms, rendering, and events.
- UI changes require relevant frontend/LiveView tests and review against UI, security, and performance guidance.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track lifecycle transition attempts, validation failures, and successful native experiment creation.
- Success is measured by authors being able to configure and manage MVP native experiments without UpGrade workflows.

## 13. Risks & Mitigations
- Risk: Authors change conditions after assignments exist and destabilize delivery. Mitigation: require lifecycle-aware validation.
- Risk: Thompson Sampling options expose unsafe tuning. Mitigation: keep MVP controls minimal and guardrail-backed.
- Risk: UI diverges from existing authoring patterns. Mitigation: reuse established LiveView/React authoring surfaces.

## 14. Open Questions & Assumptions
### Open Questions
- Should MVP native experiments be authored at project level, section level, or both?
- Which roles can start, pause, complete, or archive experiments?

### Assumptions
- Authoring controls are introduced after native runtime semantics are defined.
- Native authoring does not import existing UpGrade experiments.

## 15. QA Plan
- Automated validation:
  - LiveView, controller, or frontend tests for form behavior, lifecycle transitions, permissions, and validation errors.
  - ExUnit tests for lifecycle validation and unsafe condition edits after assignments.
- Manual validation:
  - Create non-adaptive and Thompson Sampling experiments through the native authoring surface and verify lifecycle state changes.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
