# MER-5799 Coverage Issues Filter - Functional Design Document

## 1. Executive Summary

MER-5799 adds project-scoped coverage thresholds and a LiveView filter that derives issue state from the existing request-scoped `ObjectiveCoverage` snapshot. It extends, rather than replaces, MER-5794 coverage rendering and MER-5797 search/patch conventions.

## 2. Requirements & Assumptions

- Functional requirements: FR-001 through FR-003 in `requirements.yml`.
- Non-functional requirements: in-memory evaluation, project authorization, accessibility, and no content mutation.
- Assumptions: thresholds are shared by project authors and default to 3 formative / 3 summative activities.

## 3. Repository Context Summary

- What we know: `ObjectiveCoverage.load/1` provides compact coverage data; `ObjectivesLive` owns async load, table rows, patches, and interaction state; `Project.attributes` embeds `ProjectAttributes` in the existing `projects.attributes` map.
- Resolved follow-up: MER-5919 owns the final pedagogy URL and activation of the prepared hidden Learn more affordance. Responsive behavior was reconciled during the final Figma review.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `ProjectAttributes` owns typed threshold defaults and validation.
- the Authoring course context persists authorized project settings.
- a small pure coverage-issue helper derives formative/summative issue flags for direct rows and parent rollups.
- `ObjectivesLive` combines search, coverage filter, sorting, paging, and expanded-row state before rendering.
- `Listing` renders feature-local warning decoration and messages; generic toolbar/filter primitives remain shared only when their API is broadly useful.

### 4.2 State & Data Flow

1. Load project attributes and `ObjectiveCoverage` once per LiveView lifecycle.
2. Apply thresholds to loaded objective and child counts; propagate child issue state to visible parents.
3. Apply Rafael's search criterion, Coverage Issues criterion, sort, then pagination in memory.
4. Persist filter/query state through the same patch parameter flow used by MER-5797.

### 4.3 Lifecycle & Ownership

Project thresholds survive reloads and are shared by authorized authors. Transient query, active-filter, expansion, and popover state belong to `ObjectivesLive`; derived issue state is recomputed after settings or coverage refresh.

### 4.4 Alternatives Considered

- New coverage queries per filter interaction: rejected; the existing normalized snapshot prevents N+1 work and matches the epic design.
- Per-user preference storage: rejected by Darren's explicit project-level direction.
- Separate URL/state path: rejected; it would conflict with MER-5797 composition semantics.

## 5. Interfaces

- `ProjectAttributes.changeset/2` accepts non-negative integer thresholds.
- a pure issue-classification interface accepts coverage counts and thresholds and returns formative/summative/any-issue flags.
- LiveView events update settings or active filter and patch using the shared table handler contract.

## 6. Data Model & Storage

- Add two fields to embedded `ProjectAttributes`, serialized in existing `projects.attributes`; no table or migration is needed for map keys.
- Missing fields read as recommended defaults for backward compatibility.

## 7. Consistency & Transactions

Persist both thresholds in one authorized project update. Recompute UI state from the successful persisted attributes; on validation failure retain existing settings and present form feedback.

## 8. Caching Strategy

N/A. Reuse the existing request-scoped coverage snapshot; introduce no cache.

## 9. Performance & Scalability Posture

Issue classification and filter composition are linear over loaded objective rows and require no additional database/content reads.

## 10. Failure Modes & Resilience

- Coverage-load failure keeps the existing explicit loading/error/retry behavior and does not fabricate zero coverage.
- Settings validation/persistence failure leaves the active persisted thresholds unchanged and reports an accessible error.
- The Learn more text is rendered with its final styling but remains hidden and non-interactive until MER-5919 supplies the destination and enables it.

## 11. Observability

Reuse ObjectiveCoverage load logging/telemetry and log settings update failures without project content or user-sensitive payloads.

## 12. Security & Privacy

Use existing author/project authorization for settings updates. Thresholds are non-sensitive project configuration; do not expose cross-project settings or coverage data.

## 13. Testing Strategy

- ExUnit tests for defaults, changeset validation, issue classification, child-to-parent propagation, and project persistence.
- LiveView tests for filter/query/sort composition, URL patch state, markers/messages, and accessible controls.
- Manual Figma comparison for light/dark, keyboard focus, responsive layout, and final MER-5797 integration.

## 14. Backwards Compatibility

Existing projects lacking map keys behave as 3/3. Existing search and manual expansion semantics remain owned by MER-5797.

## 15. Risks & Mitigations

- Draft PR changes: rebase after MER-5797 merge and resolve only the documented state/rendering seams.
- Visual ambiguity: treat Figma nodes 365-14554 and 365-17228 as source of truth and record missing behavior for product.

## 16. Open Questions & Follow-ups

- Resolved: no Learn more URL ships with this ticket. MER-5919 owns the
  knowledge-base article, destination, and visible activation. MER-5799
  retains a styled but hidden, non-interactive placeholder so the follow-up
  does not need to restructure the footer; see `phase-1-figma-brief.md` §5.
- Produce the governed full Figma brief before coding; no new shared primitive is assumed until that mapping is complete. **Done** — see `phase-1-figma-brief.md`.

## Decision Log

### 2026-09-08 - Preserve a hidden Learn more extension point

- Change: The component contract renders the final Learn more styling behind `hidden` rather than omitting the node entirely.
- Reason: MER-5919 will supply the URL and make the affordance visible.
- Evidence: `lib/oli_web/live/workspaces/course_author/objectives/coverage_settings_popover.ex` and `test/oli_web/live/workspaces/course_author/objectives/coverage_settings_popover_test.exs`.
- Impact: The current ticket exposes no incomplete navigation while minimizing follow-up layout churn.

## 17. References

- Jira MER-5799.
- `docs/exec-plans/current/epics/objectives-editor/core_data/informal.md`.
- MER-5794 and MER-5797 PRs.
- Learning Objectives Updates Figma nodes: 365-14554 (warning, light),
  365-17228 (warning, dark), 365-19034 (coverage filter applied),
  365-18532 (coverage filter settings open), 365-19751 (settings popover,
  light), 365-19793 (settings popover, dark), 329-532 (collapsed card with
  issue), 365-16457 (expanded, flagged sub-objective row, dark). Full
  detail in `phase-1-figma-brief.md`.
