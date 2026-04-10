# Module-Level Log Controls - Product Requirements Document

## 1. Overview

This work item adds an operational capability for Torus administrators to temporarily lower the effective log level for a specific Elixir module, without lowering the global application log level. The primary value is targeted production debugging for incidents such as LTI failures, where DEBUG or INFO logs are useful for a narrow code path but harmful when enabled system-wide.

## 2. Background & Problem Statement

Torus already allows an administrator to change logging behavior, but current controls operate broadly enough that enabling DEBUG or INFO can flood application logs, obscure the signal needed for investigation, and increase operational risk during incidents. Engineering currently has to rely on direct shell access and manual Logger calls to narrow logging in production. That workflow is slow, operationally awkward, and not appropriate for routine support investigations. Torus needs an admin-facing way to invoke Elixir Logger module-level overrides so investigations can be performed quickly and with controlled blast radius.

## 3. Goals & Non-Goals

### Goals

- Allow an authorized Torus administrator to set a lower Logger level for a specific Elixir module.
- Keep the change targeted so system-wide logging behavior remains unchanged for all other modules.
- Support operational debugging workflows in production, especially around intermittent LTI issues.
- Provide a safe administrative experience with clear inputs, validation, and visibility into the active override.

### Non-Goals

- Replacing Torus's existing global log-level controls.
- Building a full log viewer, log search UI, or incident management workflow.
- Allowing arbitrary users or section-level roles to change runtime Logger configuration.
- Guaranteeing permanent persistence of Logger overrides across deploys, restarts, or node replacement.
- Designing cluster-wide coordination of log overrides in the initial delivery.

## 4. Users & Use Cases

- Torus platform administrator: temporarily enable DEBUG or INFO logging for a single module while investigating a production incident.
- Torus support or operations engineer acting through admin permissions: adjust module-level logging during a live issue without opening an IEx shell on the host.

## 5. UX / UI Requirements

- The capability must be exposed through an admin-only operational surface that is consistent with existing Torus administration patterns.
- The admin must be able to specify the target module and desired level from constrained, validated inputs rather than free-form runtime code execution.
- The interface must show whether an override is being applied, updated, cleared, or rejected.
- The interface must make the scope clear: module-level override only, not a global log-level change.
- The control should live on the existing `OliWeb.Features.FeaturesLive` admin page.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Security: only appropriately authorized Torus administrators may create, modify, or clear runtime log-level overrides.
- Reliability: invalid module names, invalid log levels, and unsupported targets must fail safely without changing existing Logger configuration.
- Operational safety: the feature must minimize blast radius by targeting a single module and by allowing overrides to be cleared.
- Performance: the feature must not introduce broad log amplification beyond the explicitly targeted module or process.
- Auditability: operator actions should be visible through existing operational logging or admin feedback so the team can understand who changed logging and when.

## 9. Data, Interfaces & Dependencies

- Primary runtime dependency: Elixir `Logger.put_module_level/2`.
- The admin flow needs a way to accept a module identifier and a log level, resolve or validate the module, and invoke Logger with a supported level.
- The implementation depends on an existing admin authorization boundary in the Torus Phoenix application.
- Overrides apply only on the local node, mirroring current global log-level admin behavior.
- Overrides remain active until cleared or until the node restarts.

## 10. Repository & Platform Considerations

- Torus is a Phoenix application with administrative workflows in `lib/oli_web/` and runtime behavior in Elixir backend contexts under `lib/oli/`.
- Runtime logging changes affect production operations, so the implementation should favor explicit validation and small operational scope.
- Tests should cover authorization, validation, success paths, and clearing behavior using ExUnit and relevant Phoenix web tests.
- The code should preserve the repo's Elixir conventions, including clear control flow and minimal nesting.
- The work should not require direct shell access for normal use after delivery.
- The correct home for this control is the existing [lib/oli_web/live/features/features_live.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex) admin page.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Success is measured operationally by reduced need for ad hoc shell-based Logger changes during incident investigation.
- A useful indicator is whether admins can isolate module-specific logging for LTI incidents without materially increasing unrelated log volume.
- If practical within existing logging patterns, operator actions to set or clear overrides should emit an audit-friendly log or event.

## 13. Risks & Mitigations

- Incorrect module targeting could make an investigation ineffective: mitigate with validation and clear feedback on the exact module being targeted.
- Misuse by unauthorized or insufficiently trained users could affect production diagnostics: mitigate with strict admin-only access and explicit UI wording.
- Runtime overrides may behave differently across clustered nodes or after restart: mitigate by documenting runtime scope and designing for explicit operator expectations.
- Narrow targeting depends on operators knowing the relevant Elixir module names: mitigate with validation and clear feedback on the exact module being targeted.

## 14. Open Questions & Assumptions

### Open Questions

- N/A

### Assumptions

- Torus already has an authenticated admin-only interface capable of hosting this operational control.
- The control will live on the existing `OliWeb.Features.FeaturesLive` admin page.
- Operators can identify the relevant Elixir module names for the issue they are debugging.
- Runtime-local behavior is the intended initial scope, matching the current global log-level admin behavior.
- Overrides remain active until explicitly cleared or until the node restarts.

## 15. QA Plan

- Automated validation:
  - Backend tests for authorization, valid module-level override application, invalid module rejection, invalid level rejection, and clearing overrides.
  - Web or LiveView tests for the admin interaction surface that invokes the runtime change.
  - Regression coverage for the existing global log-level functionality so this work does not broaden current behavior.
- Manual validation:
  - As an admin, set a module override and confirm lower-level logs appear only for the targeted module.
  - Clear the override and confirm normal logging behavior resumes.
  - Verify non-admin users cannot access or use the control.

## 16. Definition of Done

- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] validation passes
