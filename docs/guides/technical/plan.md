# Torus Technical Handbook — Documentation Plan

Last updated: 2026-02-20

## Goal
Create a developer-focused technical handbook under `docs/manuals/technical` that explains how Torus is structured, how major subsystems interact, where key code lives, and how to safely extend the platform.

## Scope
- In scope:
  - System architecture, runtime topology, code organization, and cross-cutting technical concerns.
  - Backend (Elixir/Phoenix), frontend (TypeScript/React), data/storage, background jobs, integrations, and testing architecture.
  - Developer extension points and operational diagnostics.
- Out of scope:
  - End-user product documentation.
  - Step-by-step onboarding that already exists in `guides/starting/**`.
  - Feature PRD/FDD content in `docs/features/**` and `docs/epics/**` except as references.

## Source Analysis Summary
Primary source surfaces reviewed to shape this plan:
- Existing architectural docs: `guides/design/high-level.md`, `guides/design/publication-model.md`, `guides/design/attempt.md`, `guides/design/attempt-handling.md`, `guides/design/page-model.md`, `guides/design/genai.md`, `guides/design/scoped_feature_flags.md`, `guides/design/gdpr.md`.
- App/runtime configuration and supervision: `mix.exs`, `lib/oli/application.ex`, `config/*.exs`.
- Web boundary and request pipelines: `lib/oli_web/router.ex`, `lib/oli_web/controllers/**`, `lib/oli_web/live/**`, `lib/oli_web/plugs/**`, `lib/oli_web/channels/**`.
- Core backend domains: `lib/oli/**` contexts (authoring, delivery, resources, activities, publishing, lti, analytics, gen_ai, mcp, etc.).
- Frontend architecture: `assets/src/apps/**`, `assets/src/components/**`, `assets/src/state/**`, `assets/src/data/**`, `assets/src/phoenix/**`.
- Storage and schema evolution: `priv/repo/migrations/**`, `priv/clickhouse/migrations/**`, `lib/oli/repo/**`.
- Testing architecture: `test/oli/**`, `test/oli_web/**`, `test/scenarios/**`, `guides/process/testing.md`.

## Handbook Information Architecture (Target Files)
Create the handbook as a set of focused markdown files:

1. `docs/manuals/technical/README.md`
- Handbook entry point, audience, navigation, and doc conventions.

2. `docs/manuals/technical/01-system-overview.md`
- Monolith boundaries, runtime model, request/data flow, major subsystems.

3. `docs/manuals/technical/02-backend-architecture.md`
- Phoenix layer, contexts in `lib/oli/**`, supervision, background jobs, caching.

4. `docs/manuals/technical/03-frontend-architecture.md`
- App entry points, React/TS layering, LiveView interop, state and persistence patterns.

5. `docs/manuals/technical/04-data-model-and-storage.md`
- Postgres model, resource/revision/publication model, ClickHouse analytics path, migrations.

6. `docs/manuals/technical/05-delivery-and-authoring-lifecycle.md`
- Authoring -> publication -> section delivery flow and lifecycle invariants.

7. `docs/manuals/technical/06-activity-framework.md`
- Activity registration, model/evaluation/rendering paths, extension workflow.

8. `docs/manuals/technical/07-integrations-and-interop.md`
- LTI 1.3, ingest/import/export paths, external tools, MCP/GenAI integration surfaces.

9. `docs/manuals/technical/08-observability-and-operations.md`
- Telemetry, logs, background workers, scaling, failure modes, operational playbooks.

10. `docs/manuals/technical/09-testing-and-quality.md`
- Test pyramid in this repo (ExUnit, LiveView, scenarios, Jest, Playwright), CI expectations.

11. `docs/manuals/technical/10-security-and-compliance.md`
- AuthN/AuthZ model, tenancy boundaries, data protection, GDPR-relevant system behavior.

12. `docs/manuals/technical/11-developer-workflows.md`
- Safe change patterns, feature flags, schema changes, rollout/rollback guidance.

13. `docs/manuals/technical/glossary.md`
- Canonical definitions (resource, revision, publication, section, attempt, etc.).

14. `docs/manuals/technical/architecture-decision-index.md`
- Pointer index to major architecture decisions in existing docs/specs.

## Writing Principles
- Code-first accuracy: every substantive claim should map to a code path or concrete doc reference.
- Stable mental model first: explain system invariants and boundaries before implementation detail.
- Avoid duplication: link to existing guides/features/epics when they are the canonical deep dive.
- Keep docs maintainable: prefer short sections with "where in code" pointers.

## Execution Plan

## Phase 0: Bootstrap Handbook Skeleton
- Create `docs/manuals/technical/` and all target markdown files as stubs.
- Add front matter/section template and consistent heading structure.
- Add an index in `README.md` with status per chapter (`draft`, `reviewing`, `published`).
- Definition of Done:
  - Full file skeleton exists and is linked from `docs/manuals/technical/README.md`.

## Phase 1: Core Architecture Foundation
- Write `01-system-overview.md`, `02-backend-architecture.md`, `03-frontend-architecture.md`.
- Include explicit module/path references for each subsystem.
- Add one architecture diagram per file (Mermaid acceptable) to clarify boundaries and runtime flows.
- Definition of Done:
  - A new engineer can identify where to implement a backend vs frontend change.

## Phase 2: Domain and Data Deep Dives
- Write `04-data-model-and-storage.md`, `05-delivery-and-authoring-lifecycle.md`, `06-activity-framework.md`.
- Validate publication/revision semantics against `guides/design/publication-model.md` and live code in `lib/oli/resources/**`, `lib/oli/publishing/**`, `lib/oli/delivery/**`.
- Include extension checklists for adding new resource or activity behavior safely.
- Definition of Done:
  - Handbook captures the canonical content/versioning and activity mental models.

## Phase 3: Integrations, Ops, and Quality
- Write `07-integrations-and-interop.md`, `08-observability-and-operations.md`, `09-testing-and-quality.md`, `10-security-and-compliance.md`.
- Cover LTI, ingest, analytics/xAPI, Oban jobs, telemetry, scaling/caching, and test strategy.
- Document failure/diagnostic playbooks with pointers to concrete modules/tasks.
- Definition of Done:
  - Engineers can trace an issue from user symptom to likely subsystem and validation path.

## Phase 4: Developer Enablement and Navigation
- Write `11-developer-workflows.md`, `glossary.md`, `architecture-decision-index.md`.
- Add "common change recipes" (new LiveView page, new API endpoint, schema migration, activity updates).
- Ensure all chapters cross-link and link back to code/docs sources.
- Definition of Done:
  - Handbook is navigable end-to-end and supports day-to-day implementation decisions.

## Phase 5: Review, Validation, and Publication
- Perform technical review pass by subsystem owners (backend, frontend, platform/ops).
- Verify all code references resolve and examples still compile mentally against current code.
- Run markdown lint/format pass if repository standards require it.
- Publish chapter status as `published` in `docs/manuals/technical/README.md`.
- Definition of Done:
  - Handbook is internally reviewed, link-valid, and ready for team use.

## Dependency and Parallelization Notes
- Phase 0 is a hard prerequisite for all writing.
- Phase 1 should land before Phase 2/3 to establish shared terminology.
- Phase 2 and Phase 3 can proceed in parallel once Phase 1 drafts exist.
- Phase 4 should start after Phase 2 and 3 reach at least review-ready state.

## Acceptance Criteria
- A complete handbook structure exists under `docs/manuals/technical`.
- Each chapter includes:
  - Purpose and scope.
  - "Where in code" section with concrete paths.
  - Key invariants and failure modes.
  - Pointers to deeper references.
- Cross-cutting coverage includes:
  - Multi-tenancy boundaries.
  - Publication/versioning invariants.
  - Feature flag and rollout practices.
  - Test strategy and operational diagnostics.

## Risks and Mitigations
- Risk: Documentation drifts from fast-moving features.
  - Mitigation: add ownership + quarterly doc review cadence in `README.md`.
- Risk: Duplicating or conflicting with `guides/design/**`.
  - Mitigation: handbook provides system map and links out to canonical deep dives.
- Risk: Too much implementation detail makes docs hard to maintain.
  - Mitigation: prioritize architecture and invariants; keep low-level examples minimal.

## Maintenance Plan
- Assign chapter owners by domain (backend, frontend, platform).
- Require handbook updates in PRs that change architecture-relevant behavior.
- Add a lightweight quarterly audit checklist:
  - Broken links/code paths.
  - Stale diagrams.
  - New major subsystems missing from index.

## Suggested First Delivery Slice
1. Publish Phase 0 skeleton + `README.md`.
2. Complete `01-system-overview.md` and `05-delivery-and-authoring-lifecycle.md` first.
3. Use those two chapters to validate format and depth before writing the remaining chapters.
