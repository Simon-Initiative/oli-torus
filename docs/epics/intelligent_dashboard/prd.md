# Instructor Intelligent Dashboard Epic - Master PRD

Last updated: 2026-02-09
Epic: `MER-5198`
Related docs: `docs/epics/intelligent_dashboard/overview.md`, `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/plan.md`, `docs/epics/intelligent_dashboard/data_oracles/prd.md`, `docs/epics/intelligent_dashboard/data_coordinator/prd.md`, `docs/epics/intelligent_dashboard/data_cache/prd.md`, `docs/epics/intelligent_dashboard/data_snapshot/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/README.md`

## 1. Overview

Build a next-generation instructor dashboard that helps instructors quickly understand student learning status, identify who needs support, and take action using AI-assisted recommendations and outreach.

This PRD is intentionally epic-level. Detailed implementation PRDs for individual features/workstreams will follow.

## 2. Problem Statement

Instructors currently spend too much time navigating multiple pages to answer core questions:
- Who is struggling or inactive?
- Which learning objectives need attention?
- Which assessments need intervention?
- What should I do next?

The epic addresses this with:
- a new Learning Dashboard landing experience,
- scoped analytics tiles,
- AI recommendations and AI-assisted email workflows,
- and exportable dashboard data.

## 3. Goals

- Deliver a fast, usable dashboard that becomes the instructor’s default operational surface for active sections.
- Provide actionable tile-based insights that stay consistent with existing Torus data definitions.
- Enable scoped analysis by course container (`Entire Course`, `Unit`, `Module`, etc.).
- Provide context-aware AI recommendations and drafting assistance with instructor control.
- Support accessible, shareable CSV export of dashboard data.
- Establish a durable data platform that supports future tiles without tile-specific query sprawl.

## 4. Non-Goals (Epic Level)

- Replacing all existing Insights/Overview pages in this release.
- Full pedagogical automation or autonomous instructor actions.
- Student-facing dashboard surfaces.
- Final tuning of all thresholds/policies (some are intentionally configurable in follow-on work).

## 5. Users and Primary Use Cases

- Primary user: Instructor.
- Secondary users: Admin/internal product/engineering stakeholders validating quality and rollout.

Primary use cases:
- Open course instructor experience and immediately view Learning Dashboard (`MER-5246`).
- Switch scope to a unit/module and see all dashboard insights update (`MER-5248`).
- Review summary and AI recommendation, provide feedback, and regenerate if needed (`MER-5249`, `MER-5250`).
- Inspect progress/support/objective/assessment tiles and drill into detailed pages (`MER-5251`, `MER-5252`, `MER-5253`, `MER-5254`, `MER-5255`, `MER-5256`).
- Draft and send contextual AI-assisted emails (`MER-5257`).
- Customize dashboard layout and tile presentation (`MER-5258`, `MER-5259`).
- Export scoped dashboard data as CSV ZIP (`MER-5266`).

## 6. Functional Requirements (Epic-Level)

| ID | Requirement | Jira Trace |
|---|---|---|
| FR-001 | Instructor interface defaults to `Insights -> Learning Dashboard` for existing sections, while preserving current first-entry behavior after initial course creation. | `MER-5246` |
| FR-002 | Dashboard supports global content-container filtering with persistence and previous/next navigation semantics. | `MER-5248` |
| FR-003 | Dashboard includes a summary region with scoped key metrics and AI recommendation output. | `MER-5249` |
| FR-004 | AI recommendation interactions support thumbs feedback, optional qualitative feedback, and controlled regeneration. | `MER-5250` |
| FR-005 | Progress tile visualizes completion/progress with threshold controls, schedule-aware behavior, and drill-through. | `MER-5251` |
| FR-006 | Student Support tile classifies and filters students by support categories and activity status, with actionable selection/emailing. | `MER-5252` |
| FR-007 | Challenging Objectives tile surfaces low-proficiency objectives/sub-objectives with navigable drill-through. | `MER-5253` |
| FR-008 | Assessments tile provides completion status, score distribution/summary metrics, and actions for student outreach and question review. | `MER-5254` |
| FR-009 | Student Support list supports profile quick access from row hover interaction. | `MER-5255` |
| FR-010 | Student Support parameters are configurable (performance thresholds and inactivity window) with deterministic precedence behavior. | `MER-5256` |
| FR-011 | Email workflows support context-aware AI subject/body generation, tone-controlled regeneration, editable draft fields, and explicit send action. | `MER-5257` |
| FR-012 | Dashboard supports tile groups (Engagement/Content), collapse/expand, reorder, and conditional group rendering behavior. | `MER-5258` |
| FR-013 | Dashboard tiles support constrained resize/expand interactions with stable layout reflow and persisted state. | `MER-5259` |
| FR-014 | Dashboard data can be exported as a ZIP containing scoped CSV datasets aligned to on-screen metrics. | `MER-5266` |
| FR-015 | Dashboard data access is provided by a reusable oracle/data-source framework (not tile-specific query code), enabling incremental per-tile hydration based on declared dependencies. | `MER-5248`, `MER-5266`, `MER-5251`-`MER-5254` |
| FR-016 | Dashboard and tile interactions satisfy defined accessibility behaviors (keyboard operation, focus management, semantic labeling, screen reader announcements). | `MER-5248`-`MER-5250`, `MER-5257`, `MER-5266` |

## 7. Non-Functional Requirements

### 7.1 Performance

- NFR-PERF-001: Performance budgets are enforced for these scale profiles:
  - `Small`: 20 learners.
  - `Normal`: 200 learners.
  - `Large`: 2,000 learners.
- NFR-PERF-002: Dashboard shell render (visible chrome + loading skeletons) must achieve p95 <= 300ms and p99 <= 450ms across all scale profiles.
- NFR-PERF-003: Filter/tile control interaction acknowledgment (UI response, not data completion) must achieve p95 <= 60ms and p99 <= 100ms.
- NFR-PERF-004: Cached-scope hydration for required tile data must achieve p95 <= 150ms and p99 <= 250ms.
- NFR-PERF-005: Uncached-scope first meaningful tile render must achieve:
  - `Small`: p95 <= 300ms
  - `Normal`: p95 <= 500ms
  - `Large`: p95 <= 700ms
- NFR-PERF-006: Uncached-scope full required tile hydration must achieve:
  - `Small`: p95 <= 750s
  - `Normal`: p95 <= 1.0s
  - `Large`: p95 <= 1.5s
- NFR-PERF-007: Data pipeline must bound work under rapid scope changes using one in-flight and one queued scope request (latest request replaces queued); stale results are discarded.
- NFR-PERF-008: Aggregate analytics queries used by dashboard oracles - where possible - must be ClickHouse-first and meet p95 <= 150ms and p99 <= 300ms per oracle query under `Large` profile benchmarks.
- NFR-PERF-009: Query execution must remain bounded and deterministic per uncached scope build; adding a tile must not introduce uncontrolled per-tile query fan-out.

### 7.2 Extensibility

- NFR-EXT-001: New tiles must declare required/optional oracle dependencies and consume oracle projections.
- NFR-EXT-002: LiveView and tile components must not introduce direct analytics queries.
- NFR-EXT-003: Oracle contracts must support versioning and safe extension without breaking existing tile consumers.

### 7.3 Reliability and Correctness

- NFR-REL-001: Stale async results must never overwrite newer scope selections.
- NFR-REL-002: Cache invalidation must keep displayed/exported data within accepted freshness windows.
- NFR-REL-003: CSV export data must be sourced from the same scoped snapshot contract used by dashboard tiles.

### 7.4 Testability

- NFR-TEST-001: Oracle modules and projection helpers must be covered by automated unit tests.
- NFR-TEST-002: LiveView async/incremental behavior (loading, completion ordering, stale result suppression, rapid filter cycling) must be covered by automated LiveView tests.
- NFR-TEST-003: End-to-end critical flows must be covered by browser automation (Playwright or equivalent), including filter changes, tile hydration, and CSV export initiation.
- NFR-TEST-004: Accessibility behavior for critical interactive controls must be testable through automated checks plus targeted manual verification.

## 8. Data and Architecture Requirements

- Use the oracle-based data platform defined in the `data_oracles`, `data_coordinator`, `data_cache`, and `data_snapshot` feature specs.
- Data orchestration must live in `Oli` namespace modules, outside UI components.
- Tile rendering must be dependency-driven: required oracles gate full render; optional oracles may enrich partial render.
- Cache strategy must include oracle-level caching and assembled projection reuse.
- CSV generation must follow transform-from-snapshot architecture, avoiding separate analytics query paths when snapshot data is available.
- High-cardinality aggregate analytics paths for dashboard oracles must use ClickHouse as the primary query engine; Postgres remains for transactional/entity lookups.

## 9. Acceptance Criteria (Epic-Level)

- AC-001: Instructors can enter a section and use the Learning Dashboard as the primary insight surface with scoped filtering and responsive interaction behavior.
- AC-002: Core tiles (summary/progress/support/objectives/assessments) deliver actionable, scoped information and correct drill-through behavior.
- AC-003: AI recommendation and AI email experiences operate with explicit instructor control and context relevance.
- AC-004: Dashboard layout controls (section ordering/collapse and tile sizing) are usable, persistent, and stable.
- AC-005: CSV export produces a valid ZIP with expected datasets derived from the same scoped dashboard data model.
- AC-006: Measured production-like performance and reliability meet NFR targets.
- AC-007: Automated test suites cover critical data orchestration, LiveView behavior, and key end-to-end user journeys.

## 10. Traceability by Workstream

- AI Platform: `MER-5249`, `MER-5250`, `MER-5257` (informed by `MER-5218` POC).
- Dashboard Tiles: `MER-5251`, `MER-5252`, `MER-5253`, `MER-5254`, `MER-5255`, `MER-5256`.
- Dashboard Chrome/Layout: `MER-5246`, `MER-5258`, `MER-5259`.
- Data Scope/Export: `MER-5248`, `MER-5266`.

## 11. Risks and Mitigations

- Risk: Performance degradation with large sections and rapid filter changes.
  - Mitigation: Oracle caching, bounded async queue, deterministic query plans, telemetry-driven tuning.
- Risk: Tile-specific query accretion reduces maintainability.
  - Mitigation: Enforce oracle contract and “no tile-level analytics query” rule.
- Risk: AI outputs are low-quality or untrusted by instructors.
  - Mitigation: Recommendation feedback loop, regeneration, explicit non-prescriptive messaging, clear fallback states.
- Risk: Accessibility regressions across dense interactive UI.
  - Mitigation: Shared a11y patterns, test automation coverage, manual audits before rollout gates.

## 12. Open Questions

- What production-like benchmark dataset and load-generation harness will be the certification baseline for p95/p99 performance gates?
- What exact cache TTL and invalidation triggers are required for “fresh enough” instructor decisions?
- Which rollout strategy/feature-flag stages should gate exposure across institutions or sections?
