# Override DOT Per Page — PRD

## 1. Overview
Feature Name: `override_dot`

Summary: This feature adds an explicit page-level switch for DOT visibility and trigger activation. Authors can enable or disable DOT per page for both basic and adaptive pages, while section-level assistant enablement remains a global prerequisite.

Links:
- `MER-4943.txt`
- `docs/epics/adaptive_page_improvements/override_dot/informal.md`
- `docs/epics/adaptive_page_improvements/plan.md`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - DOT visibility is controlled at section level and by existing page behavior rules.
  - There is no durable page-level override attribute in revision and section-resource data.
  - Scored adaptive and scored basic pages need explicit author control for formative scenarios.
- Affected users/roles:
  - Authors configuring page behavior.
  - Learners who should or should not see DOT on specific pages.
  - Section admins relying on section-level assistant controls.
- Why now:
  - `override_dot` is the first dependency in Lane 1 for adaptive-page AI work.
  - Later lane items assume deterministic page-level AI enablement.

## 3. Goals & Non-Goals
- Goals:
  - Add page-level `ai_enabled` support in revision and section-resource models.
  - Add authoring controls in Page Options and adaptive lesson properties.
  - Enforce delivery gating with both section-level and page-level checks.
  - Preserve expected defaults: scored pages disabled by default, practice pages enabled by default.
- Non-Goals:
  - No section-level assistant UX redesign.
  - No new activation-point types or trigger semantics beyond page-level enablement gating.
  - No changes to LLM prompt quality/routing behavior.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Course authors editing basic and adaptive pages in project authoring.
  - Learners viewing lesson pages in section delivery.
- Use Cases:
  - Author enables DOT on a scored adaptive page used as formative practice.
  - Author disables DOT on a practice page that should be student-solo.
  - Learner opens page and sees DOT only when both section and page allow it.

## 5. UX / UI Requirements
- Key Screens/States:
  - Curriculum/All Pages Page Options modal for page revisions.
  - Adaptive Author lesson property panel (`Lesson Appearance`) under `Enable Dark Mode`.
- Navigation & Entry Points:
  - Existing `Options` buttons in curriculum and all-pages tables.
  - Existing adaptive lesson right-side property editor.
- Accessibility:
  - Toggle must be keyboard reachable and screen-reader labeled.
  - Label text must be clear and consistent: `Enable AI Assistant (DOT)`.
- Internationalization:
  - Existing i18n posture is unchanged; this release uses current static label patterns.
- Screenshots/Mocks:
  - `MER-4943` Jira attachments and adaptive lesson panel guidance from informal doc.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale:
  - No dedicated performance/load/benchmark tests.
  - DOT gating path should remain O(1) checks from existing assigns/query context.
- Reliability:
  - Legacy pages without explicit `ai_enabled` must preserve old visible behavior by deterministic fallback.
  - Section-resource updates and migration paths must keep page-level AI flag synchronized with pinned revisions.
- Security & Privacy:
  - Section-level assistant authorization remains authoritative.
  - Page-level toggle must not bypass section-level disabled state.
- Compliance:
  - No additional PII is introduced.
  - Existing accessibility standards for controls and labels remain required.
- Observability:
  - Existing trigger/log paths remain available; no sensitive payload logging changes.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Add nullable boolean `ai_enabled` to `revisions`.
  - Add nullable boolean `ai_enabled` to `section_resources`.
  - Backfill existing rows with graded-aware defaults where possible.
- Context Boundaries:
  - `Oli.Resources.Revision` and `Oli.Resources.create_revision_from_previous/2`.
  - `Oli.Delivery.Sections.SectionResource`, section-resource creation/update/migration pipelines.
  - Authoring: options modal and adaptive lesson editor save path.
  - Delivery: lesson layout DOT rendering and page trigger fire checks.
- APIs / Contracts:
  - Authoring resource update payloads must accept and persist `ai_enabled`.
  - Import/export page JSON adds `aiEnabled` field.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Author/content admin | Change page-level DOT toggle | In project authoring surfaces only |
| Section admin | Toggle section-level assistant | Existing behavior unchanged |
| Learner | See DOT only when both gates pass | No direct toggle access |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - No role-claim contract changes.
- GenAI (if applicable):
  - DOT runtime visibility is further constrained by page `ai_enabled`.
- External services:
  - None.
- Caching/Perf:
  - No new cache required; use existing page/section context.
- Multi-tenancy:
  - Data remains scoped by project/section/resource.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature.

## 12. Analytics & Success Metrics
- KPIs:
  - Scored page DOT visibility matches page-level author setting.
  - No regression in section-level assistant disable behavior.
- Events:
  - Existing trigger invocation and dialogue visibility signals remain baseline indicators.

## 13. Risks & Mitigations
- Incorrect defaulting on legacy rows -> fallback logic uses `graded` when `ai_enabled` is nil.
- Incomplete section-resource propagation -> update all section-resource creation/migration paths and cover with tests.
- UI drift between basic/adaptive authoring -> enforce same label and equivalent semantics in both surfaces.

## 14. Open Questions & Assumptions
- Assumptions:
  - Darren’s technical guidance supersedes earlier narrower wording and applies to both basic and adaptive pages, scored and practice.
  - Page-level toggle should affect DOT visibility and page-level trigger firing.
- Open Questions:
  - Should section-level analytics explicitly track page-level AI toggle changes in future work?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Data model + propagation paths complete.
- Milestone 2: Authoring UI controls shipped for both basic and adaptive authoring.
- Milestone 3: Delivery gating and regression tests green.

## 16. QA Plan
- Automated:
  - Unit/integration tests for revision/section-resource propagation and migration.
  - LiveView tests for DOT visibility behavior on scored/practice pages.
  - Live tests for options modal persistence.
  - Authoring save-path tests for adaptive lesson toggle persistence.
- Performance Validation:
  - Verify no additional heavy queries in lesson render path; monitor existing AppSignal traces for lesson mount and trigger paths.
- Manual:
  - Verify toggle appears and saves in curriculum and all-pages options.
  - Verify adaptive lesson panel toggle appears below dark mode and persists.
  - Verify DOT hidden/visible matrix: section off, section on + page off, section on + page on.
  - Focus areas for manual testing: legacy pages (nil value fallback), scored adaptive with chrome, scored basic override.
- Oli.Scenarios Recommendation:
  - Status: Not applicable
  - Rationale: Change scope is concentrated in authoring form/state and delivery gating logic already covered by ExUnit/LiveView patterns.
  - Existing Coverage Signal: None found in touched areas for this specific behavior.

## 17. Definition of Done
- [ ] Requirements in `requirements.yml` are implemented and validated.
- [ ] Authoring and delivery behavior align with page-level AI enablement semantics.
- [ ] Migration and propagation paths are test-covered.
- [ ] Validation checks pass for PRD/FDD/plan.
