# A/B Testing Authoring And Experiment Lifecycle - Product Requirements Document

## 1. Overview
Define the authoring and lifecycle requirements for creating, configuring, starting, pausing, completing, and archiving MVP weighted random A/B testing experiments. This slice gives authors and permitted administrators predictable controls for non-adaptive experiments after the runtime model is stable, while leaving Thompson Sampling unavailable until the dedicated adaptive-policy slice enables it.

## 2. Background & Problem Statement
The A/B testing authoring surface must let users manage experiment definitions and lifecycle states while preserving content versioning, assignment stability, and validation rules once learners have assignments. UI and implementation work should present this as an A/B Testing feature, without exposing provider-migration terminology, prior-provider names, or JSON import/export workflows.

## 3. Goals & Non-Goals
### Goals
- Present A/B testing authoring as a first-class Torus feature without prior-provider terminology, migration framing, or JSON download workflows.
- Support create, edit, start, pause, complete, and archive behaviors where required for MVP.
- Allow configurable condition weights for simple A/B/N experiments.
- Prevent Thompson Sampling selection until the dedicated adaptive-policy slice implements policy behavior and adaptive authoring controls.
- Enforce validation rules for condition changes after assignments exist.

### Non-Goals
- Provide full external experimentation platform admin UI parity.
- Implement preview users or preview assignments unless needed for initial A/B testing authoring.
- Support advanced segments, factorial designs, feature flags, or additional adaptive algorithms.

## 4. Users & Use Cases
- Authors: define alternatives experiments and publish content that can be used in A/B testing experiments.
- Learning engineers and researchers: configure condition weights for non-adaptive studies.
- Administrators: manage permissions and lifecycle transitions for experiments that affect delivery.
- Instructors: understand whether experiments are active in their sections when surfaced by later reporting.

## 5. UX / UI Requirements
- Authoring flows must use plain A/B Testing language and avoid provider-migration terminology, prior-provider labels, the term "native", and JSON workflow affordances.
- Lifecycle controls must make active, paused, completed, and archived states clear.
- Validation errors must explain why assigned conditions cannot be changed unsafely.
- Thompson Sampling controls must be absent or disabled with "Coming soon" copy and must not be submittable from this slice.

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
- Uses authoring-facing context APIs rather than direct table access.
- Experiments are authored at the project level. Sections consume project-authored experiment configuration during delivery and may retain section-level visibility or enablement state derived from the project.

## 10. Repository & Platform Considerations
- Use existing authoring LiveView or React entry points rather than creating a broad new frontend shell.
- Backend validations must live in domain contexts, with web code handling forms, rendering, and events.
- UI changes require relevant frontend/LiveView tests and review against UI, security, and performance guidance.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track lifecycle transition attempts, validation failures, and successful experiment creation.
- Success is measured by authors being able to configure and manage MVP A/B testing experiments without prior-provider or JSON workflows.

## 13. Risks & Mitigations
- Risk: Authors change conditions after assignments exist and destabilize delivery. Mitigation: require lifecycle-aware validation.
- Risk: Users expect Thompson Sampling to be available from the first authoring release. Mitigation: keep any adaptive affordance disabled with "Coming soon" copy and route implementation to the Thompson Sampling slice.
- Risk: UI diverges from existing authoring patterns. Mitigation: reuse established LiveView/React authoring surfaces.

## 14. Open Questions & Assumptions
### Open Questions
- None.

### Assumptions
- Authoring controls are introduced after runtime semantics are defined.
- MVP A/B testing experiments are authored at the project level, matching the prior authoring model.
- A/B testing authoring starts from current Torus experiment records and does not expose prior-provider import workflows.
- Accepted project collaborators, content admins, account admins, and system admins can start, pause, complete, and archive experiments.
- Thompson Sampling authoring is a follow-up slice that replaces the disabled/coming-soon affordance with selectable adaptive configuration.

## 15. QA Plan
- Automated validation:
  - LiveView, controller, or frontend tests for form behavior, lifecycle transitions, permissions, validation errors, and disabled or absent Thompson Sampling controls.
  - ExUnit tests for lifecycle validation and unsafe condition edits after assignments.
- Manual validation:
  - Create non-adaptive weighted random experiments through the A/B testing authoring surface and verify lifecycle state changes.
  - Verify Thompson Sampling cannot be selected, submitted, or activated from this slice.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## 17. Decision Log
### 2026-06-30 - Defer Thompson Sampling Authoring
- Change: Limited this work item to weighted random authoring and lifecycle controls, with Thompson Sampling absent or disabled as "Coming soon".
- Reason: The epic sequence now places Thompson Sampling after the weighted random authoring lifecycle slice.
- Evidence: `docs/exec-plans/current/epics/ab_testing/plan.md`; `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/plan.md`.
- Impact: Adaptive selection, priors, guardrails, and Thompson Sampling activation move to `docs/exec-plans/current/epics/ab_testing/thompson_sampling/`.
