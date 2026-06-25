# Native Cut-Over And UpGrade Removal - Product Requirements Document

## 1. Overview
Define the product and operational requirements for cutting over from UpGrade to native A/B testing for all new experiment behavior. This slice ensures new experiments are native-only, legacy UpGrade runtime paths are removed or disabled, and existing UpGrade-backed experiments are explicitly not migrated.

## 2. Background & Problem Statement
Torus currently uses UpGrade for assignment, marking decision points, logging metrics, and authoring JSON export workflows. Continuing the dependency creates infrastructure and maintenance burden. The MVP requires a hard cut-over to native A/B testing while treating native experiments as new records with new participants.

## 3. Goals & Non-Goals
### Goals
- Route all new experiment authoring to native definitions.
- Remove or disable UpGrade JSON export/import and runtime assignment, mark, and log support for new behavior.
- Make the non-migration rule explicit for existing and in-progress UpGrade experiments.
- Ensure native participants start fresh for native experiments.

### Non-Goals
- Migrate UpGrade experiment definitions, learner assignments, or historical analytics.
- Preserve UpGrade runtime compatibility after cut-over.
- Deliver new authoring lifecycle UX beyond the gates needed to prevent new UpGrade-backed experiments.

## 4. Users & Use Cases
- Authors: stop creating UpGrade-backed experiments and create only native experiments once the new workflow is available.
- Administrators: understand that old UpGrade experiments are not imported into native records.
- Engineers and operators: remove runtime UpGrade dependency paths without ambiguous dual-write behavior.

## 5. UX / UI Requirements
- UpGrade-specific copy, JSON download affordances, and import/export workflow entry points must be removed or clearly disabled when native cut-over is active.
- Any replacement messaging must explain the native-only rule without promising migration.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Cut-over behavior must avoid split-brain assignment sources.
- Removed runtime paths must fail closed rather than silently calling UpGrade.
- Operational cleanup must not expose secrets or leave obsolete UpGrade configuration in active use.

## 9. Data, Interfaces & Dependencies
- Depends on native domain APIs, persistence, experiment identity rules, and assignment records from `domain_contract`.
- Touches current UpGrade runtime and authoring entry points under delivery experiments and experiment LiveViews.
- Native records are authoritative for new experiments only.

## 10. Repository & Platform Considerations
- Backend changes are expected in Elixir delivery and authoring contexts, with LiveView or template changes for removed workflows.
- Security and performance review are required for changed runtime paths.
- Jira should track this as an MVP dependency-removal work item with explicit non-migration scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Success is measured by absence of runtime UpGrade assignment, mark, or log calls for native experiments.
- Operational telemetry should make failed native assignment or reward paths visible after cut-over.

## 13. Risks & Mitigations
- Risk: Existing UpGrade experiment owners expect migration. Mitigation: document and surface the non-migration rule clearly.
- Risk: Hidden runtime paths continue to call UpGrade. Mitigation: remove configuration and add targeted tests around former entry points.
- Risk: Native authoring is enabled before runtime is ready. Mitigation: depend on the domain contract and coordinate with delivery runtime readiness.

## 14. Open Questions & Assumptions
### Open Questions
- Which existing UI routes should be removed versus retained with native-only messaging?
- What operational cleanup is required for UpGrade credentials and environment variables?

### Assumptions
- Native cut-over is hard, not a dual-run or gradual migration.
- Old UpGrade-backed experiments may remain historical artifacts but are not active native experiment sources.

## 15. QA Plan
- Automated validation:
  - ExUnit and LiveView tests for disabled UpGrade creation/export paths and native-only routing.
  - Tests that former runtime entry points no longer call UpGrade for native experiments.
- Manual validation:
  - Confirm authoring pages no longer expose UpGrade JSON workflows.
  - Confirm native experiment creation is the only supported new path.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
