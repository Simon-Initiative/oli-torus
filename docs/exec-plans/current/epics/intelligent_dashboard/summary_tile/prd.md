# Summary Tile - Product Requirements Document

## 1. Overview
Add a top-of-dashboard summary section to the Instructor Intelligent Dashboard that presents scoped headline metrics plus an AI recommendation. The section must sit directly below the global content filter, update when the selected scope changes, tolerate partial oracle availability, and expose recommendation feedback and regeneration controls consistent with Darren Siegel's Jira guidance for `MER-5249`.

Links: `docs/exec-plans/current/epics/intelligent_dashboard/summary_tile/informal.md`, `docs/exec-plans/current/epics/intelligent_dashboard/prd.md`, `docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/prd.md`, `docs/exec-plans/current/epics/intelligent_dashboard/ai_infra/prd.md`, `https://eliterate.atlassian.net/browse/MER-5249`

## 2. Background & Problem Statement
- Instructors currently lack a single summary surface that combines scoped dashboard metrics with an actionable recommendation.
- The tile must support incremental rendering because Darren's technical direction defines four optional oracle inputs and allows each subcomponent to appear as its data becomes available.
- The original Jira description says feedback details are excluded from this ticket, but Darren's later comment explicitly brings thumbs up, thumbs down, and regenerate into the feature scope. The PRD treats Darren's comment as authoritative technical scope.
- The implementation depends on recommendation infrastructure from `MER-5305` and on concrete dashboard oracle contracts from the Intelligent Dashboard data lane.

## 3. Goals & Non-Goals
### Goals
- Render the Summary section directly below the global content filter in the Learning Dashboard.
- Show scoped summary metrics for average student progress, average class proficiency, and average assessment score only when each metric is applicable.
- Support incremental rendering from optional oracle-backed subcomponents without breaking layout when one or more payloads are absent, delayed, or still loading.
- Render the AI recommendation with beginning-course, thinking, populated, and failure-safe states.
- Expose thumbs up, thumbs down, and regenerate controls in the recommendation area, with regenerate disabled while a regeneration request is in flight.
- Keep tile data shaping outside the UI so LiveView components consume stable summary view models instead of raw oracle payloads.

### Non-Goals
- Building the recommendation generation pipeline, rate-limiting, or cache invalidation internals covered by `MER-5305`.
- Implementing the additional-feedback modal and downstream qualitative feedback workflow covered by `MER-5250`.
- Redesigning the dashboard shell, global filter behavior, or non-summary tiles.

## 4. Users & Use Cases
- Instructor: opens the Learning Dashboard and immediately sees a top-level summary for the currently selected course, unit, module, or section scope.
- Instructor: changes the global content filter and sees the summary metrics and recommendation update without a browser refresh.
- Instructor: views only the metric cards that are valid for the selected scope and sees the remaining cards expand responsively.
- Instructor: triggers recommendation regeneration and sees the regenerate control disabled plus a thinking state until the request resolves.

## 5. UX / UI Requirements
- Place the Summary section directly below the global content filter.
- Match the Figma summary treatment, including the gradient background, tile hierarchy, spacing, and thinking-state visuals referenced from Jira.
- Render up to three metric cards: Average Student Progress, Average Class Proficiency, and Average Assessment Score.
- Hide metric cards that are not applicable for the selected scope rather than rendering empty placeholders.
- Provide metric-definition tooltips that open on hover and keyboard focus and remain screen-reader-associated with their triggers.
- Render the recommendation area with an AI icon, the label `AI Recommendation`, accessible announcement semantics, and beginning-course fallback copy when no meaningful activity exists.
- Keep all recommendation controls keyboard-operable with visible focus styling.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: partial oracle failure must degrade only the affected subcomponent; the full summary surface must continue rendering.
- Reliability: failed regeneration must preserve the previous recommendation until a replacement is available.
- Accessibility: tooltip triggers, recommendation labeling, and recommendation controls must satisfy WCAG 2.1 AA keyboard and screen-reader expectations.
- Security and privacy: the tile must remain instructor-scoped and must not expose raw student PII in recommendation content, logs, or telemetry.
- Performance: no dedicated load-testing requirement is added for this work item, but the tile must rely on existing oracle and cache paths rather than ad hoc UI queries.
- Internationalization: all fixed UI strings introduced by the tile should be externalizable for localization.

## 9. Data, Interfaces & Dependencies
- Summary rendering depends on four optional oracle slots from Darren's Jira guidance: `progress`, `proficiency_progress`, `assessment`, and `recommendation`.
- Existing concrete oracle modules already present in the repo and relevant to summary composition are:
  - `Oli.InstructorDashboard.Oracles.ProgressBins`
  - `Oli.InstructorDashboard.Oracles.ProgressProficiency`
  - `Oli.InstructorDashboard.Oracles.Grades`
  - `Oli.InstructorDashboard.Oracles.ObjectivesProficiency`
  - `Oli.InstructorDashboard.Oracles.ScopeResources`
- Existing bindings in `lib/oli/instructor_dashboard/oracle_bindings.ex` confirm the current canonical module names for lane-1 concrete oracles.
- Recommendation data and interaction contracts come from `MER-5305` (`ai_infra`) and must be consumed through a stable recommendation view model rather than provider-specific UI logic.
- The tile should define non-UI projection modules that translate raw oracle results into:
  - metric card view models
  - recommendation view model
  - loading and applicability state for each subcomponent
- The FDD must finalize which concrete oracle oracles feed each visible metric because Darren's oracle slot names do not map one-to-one to every existing module name in the repo today.

## 10. Repository & Platform Considerations
- Implement the surface inside the existing Phoenix LiveView-driven instructor dashboard flow rather than introducing a new SPA.
- Keep domain and projection logic under `lib/oli/` or instructor-dashboard domain modules, with UI orchestration in `lib/oli_web/`.
- Preserve the existing mixed rendering model described in `ARCHITECTURE.md`, `docs/FRONTEND.md`, and `docs/BACKEND.md`.
- Use targeted LiveView or ExUnit coverage for projection logic and state transitions, following `docs/TESTING.md`.
- Jira remains the system of record for scope input; this PRD is derived from Jira description, design links, and Darren's comment per `docs/ISSUE_TRACKING.md`.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Observe successful summary renders and regeneration failures through the existing telemetry and AppSignal posture documented in `docs/OPERATIONS.md`.
- Track recommendation interaction outcomes at minimum for:
  - regenerate clicked
  - regenerate succeeded
  - regenerate failed
  - thumbs feedback submitted
- Primary success signals:
  - instructors consistently receive a scoped summary without page refresh
  - regeneration requests complete without stale-content regressions
  - partial-data states remain usable and non-misleading

## 13. Risks & Mitigations
- Oracle-slot ambiguity could cause projection drift: record exact module bindings and payload assumptions in the FDD before implementation.
- Scope conflict between Jira text and Darren's comment could reopen review churn: explicitly treat Darren's comment as the controlling technical clarification for this ticket.
- Hidden-card layouts could regress visually when one or two metrics are unavailable: cover responsive states in LiveView tests and manual QA against Figma.
- Recommendation UI could become tightly coupled to backend generation details: consume only normalized recommendation contracts from `MER-5305`.

## 14. Open Questions & Assumptions
### Open Questions
- Which concrete oracle source should be canonical for the summary's average class proficiency metric in v1: `ObjectivesProficiency`, `ProgressProficiency`, or a summary-specific projection across both?

### Assumptions
- Darren Siegel's Jira comment is authoritative for technical scope and overrides the earlier note excluding feedback-related details from `MER-5249`.
- The tile will render recommendation feedback controls, but the additional-feedback modal and broader qualitative workflow remain owned by `MER-5250`.
- `MER-5305` has landed with the recommendation oracle bound at `:oracle_instructor_recommendation`, and the summary tile now reconciles the merged backend payload through a dedicated adapter/projection boundary.
- Summary-specific data shaping belongs in non-UI projection modules and not in HEEx templates.

## 15. QA Plan
- Automated validation:
  - projection tests for applicability, loading, and beginning-course fallback behavior
  - LiveView tests for summary placement, scope-change updates, hidden-card layout states, and regenerate disabled-in-flight behavior
  - tests covering recommendation control event routing and failure-safe preservation of the previous recommendation
- Manual validation:
  - compare light, dark, and thinking states against the Jira-linked Figma designs
  - verify tooltip focus behavior and screen-reader labeling for recommendation content
  - verify scope changes across course, unit, module, and section views without full-page refresh

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
