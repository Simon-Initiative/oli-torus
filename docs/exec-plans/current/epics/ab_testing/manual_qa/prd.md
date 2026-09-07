# End-To-End Manual QA Verification - Product Requirements Document

## 1. Overview
Create and execute a repeatable manual QA verification script for the MVP A/B testing workflow from authoring through instructor and student delivery. The script must cover both non-adaptive weighted assignment and Thompson Sampling adaptive use cases.

## 2. Background & Problem Statement
Automated tests will cover domain, runtime, authoring, analytics, and policy behavior, but the MVP also needs a human-readable release verification path across roles. A manual QA script gives reviewers a repeatable way to validate authoring, delivery, instructor/research visibility, student content rendering, and adaptive evidence before broad rollout.

## 3. Goals & Non-Goals
### Goals
- Document setup steps for project, section, instructor, and multiple student users.
- Verify non-adaptive A/B/N assignment, stickiness, fallback, exposure recording, reward handoff, and visibility.
- Verify Thompson Sampling reward flow, posterior state changes, sticky assignment after updates, and monitoring evidence.
- Capture pass/fail evidence expectations and cleanup steps.
- Complete the first QA run against the native MVP implementation.

### Non-Goals
- Automate every browser step.
- Run load, long-duration, or statistically rigorous distribution validation.
- Cover advanced parity or additional adaptive policies outside MVP.

## 4. Users & Use Cases
- QA reviewers: execute a scripted validation path before release.
- Authors and learning engineers: confirm native experiment setup works for baseline and adaptive experiments.
- Instructors: confirm delivery/reporting surfaces behave as expected.
- Students: confirm assigned alternative content renders consistently.
- Engineers and operators: inspect evidence when failures occur.

## 5. UX / UI Requirements
- The script must identify exact authoring, instructor, and student surfaces to visit.
- Evidence expectations must be clear enough for another reviewer to repeat the run.
- Screenshots or notes must avoid exposing unnecessary learner data.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- The script must be repeatable in a stable local, test, or QA environment.
- Test data setup must avoid relying on private production learner data.
- The verification run must be clear about known cleanup and reset steps.

## 9. Data, Interfaces & Dependencies
- Depends on native delivery runtime replacement, authoring lifecycle, Thompson Sampling, and analytics/monitoring.
- Requires a canonical course/project, section, instructor account, and multiple student accounts or test users.
- Uses visible UI surfaces plus approved identifiers or analytics snapshots for evidence.

## 10. Repository & Platform Considerations
- Manual QA documentation should live in the work item and can later inform scenario or browser automation.
- Automated coverage from earlier slices remains required; this script is a release-verification complement.
- Jira should track the first completed run and any defects found during execution.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Success is measured by a completed QA run that records pass/fail status for non-adaptive and Thompson Sampling workflows.
- Evidence should include assignment/exposure/reward/posterior observations from approved UI, analytics, or monitoring surfaces.

## 13. Risks & Mitigations
- Risk: Manual script becomes stale. Mitigation: anchor steps to role workflows and update it when MVP surfaces change.
- Risk: QA depends on fragile data. Mitigation: define canonical fixtures or setup steps.
- Risk: Adaptive behavior is misunderstood in a short run. Mitigation: verify posterior updates and reward evidence, not long-term optimality.

## 14. Open Questions & Assumptions
### Open Questions
- What canonical course, section, instructor, and student fixtures should the script use?
- Which environment should host the first completed QA run?

### Assumptions
- MVP authoring, runtime, Thompson Sampling, and analytics slices are implemented before the first completed run.
- Manual QA does not replace automated test gates.

## 15. QA Plan
- Automated validation:
  - Validate any referenced setup scripts or scenario fixtures where applicable.
  - Ensure linked automated tests from prior slices have passed before manual execution.
- Manual validation:
  - Execute the full script for one non-adaptive experiment and one Thompson Sampling experiment.
  - Record pass/fail evidence, defects, environment, user roles, and cleanup status.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
