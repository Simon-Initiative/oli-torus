# MER-5416 Automated Basic Page Authored Content - Functional Design Document

## 1. Executive Summary
`MER-5416` needs a reusable automation pattern that alternates scenario-driven state creation with browser-driven authoring and then returns to scenario-based assertions. The v1 design keeps orchestration on the Playwright/TypeScript side and treats `Oli.Scenarios` as the authoritative backend mechanism for setup and post-authoring assertions.

The selected design introduces a linear workflow runner in `assets/automation` with two step types:
- `scenario`
- `playwright_action`

This is the simplest design that satisfies `FR-001`, `FR-002`, `FR-003`, `FR-004`, `FR-005`, `FR-006`, `FR-007`, and `FR-008` while keeping the first PR focused on proving the pattern (`AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, `AC-008`, `AC-009`).

## 2. Requirements & Assumptions
- Functional requirements:
  - Provide a reusable two-phase automation pattern where Playwright can run after scenario setup and before a second scenario assertion phase (`FR-001`, `FR-002`, `AC-001`).
  - Limit the first implementation slice to infrastructure plus one or two representative `MIXED` groups so the pattern is proven before the full matrix expands (`FR-003`, `AC-004`, `AC-005`).
  - Reuse the existing authoring Playwright helpers and keep the resulting pattern durable for later grouped slices (`FR-004`, `FR-005`, `AC-006`, `AC-009`).
  - Keep scenario-driven setup deterministic and validate authored state across persisted, preview, and delivery surfaces (`FR-006`, `FR-007`, `AC-002`, `AC-003`, `AC-008`).
  - Document the infrastructure and follow-up grouping strategy explicitly (`FR-008`, `AC-009`).
- Non-functional requirements:
  - Existing scenario-seeded Playwright specs must remain compatible (`AC-006`).
  - The first slice must preserve the author-preview interpretation and not drift into instructor-preview semantics (`AC-007`).
  - The v1 pattern should be simple, linearly debuggable, and avoid speculative branching or distributed orchestration.
- Assumptions:
  - The first PR proves the pattern rather than maximizing `MIXED` row count.
  - Post-Playwright assertions can be expressed through scenario YAML plus hooks or small scenario-surface extensions instead of a brand-new standalone assertion framework.
  - A TypeScript-side runner is cheaper and lower-risk than making Elixir the orchestrator in v1 because Playwright already owns browser lifecycle, selectors, and debugging ergonomics.

## 3. Repository Context Summary
- What we know:
  - Playwright scenario setup already exists through `assets/automation/src/core/fixture/my-fixture.ts`, `assets/automation/src/core/seedScenario.ts`, and `lib/oli_web/controllers/playwright_scenario_controller.ex`.
  - The current backend contract executes one scenario YAML per request and returns structured outputs for projects, sections, products, users, and merged params.
  - Existing course-authoring specs already exercise basic page editing and author preview, but they do not support a reusable `scenario -> browser -> scenario` alternation pattern.
  - Torus's publication model requires learner delivery assertions to resolve through a published section context rather than mutable authoring state.
  - The current `MIXED` matrix is much larger than current coverage, so grouped expansion after the first PR is required.
- Unknowns to confirm:
  - Whether author-preview assertions can be expressed entirely through hooks on existing preview routes or require a small scenario-surface addition.
  - Which representative groups will provide the best signal in PR 1.
  - Whether the existing `/test/scenario-yaml` route can remain unchanged and simply be called multiple times, or whether it needs a small response/params extension for better workflow outputs.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Workflow runner` in `assets/automation/src/core/workflows/`
  - Reads a workflow declaration.
  - Executes steps sequentially.
  - Maintains a serializable workflow state and step outputs.
  - Is exposed to specs through a new fixture helper that extends `assets/automation/src/core/fixture/my-fixture.ts` rather than replacing `seedScenario(...)`.
- `Scenario step adapter`
  - Reuses the existing scenario execution endpoint.
  - Loads YAML from disk and posts it with resolved params.
  - Stores returned outputs under the step id.
- `Playwright action step adapter`
  - Resolves a named action from a local TypeScript action registry.
  - Runs against the current Playwright test context, page, helpers, and POMs.
  - Returns small serializable outputs for downstream steps.
- `Action registry`
  - Maps stable `playwright_action` names to implementations.
  - Prevents the workflow DSL from naming arbitrary spec files or test cases.
- `Scenario assertions`
  - Stay in the existing `Oli.Scenarios` world.
  - Use scenario directives and hooks for preview and delivery checks.
- `Documentation`
  - Durable infrastructure usage and DSL contract live in `assets/automation/WORKFLOWS.md`.

### 4.2 State & Data Flow
1. The Playwright spec loads a workflow declaration and runtime params such as `RUN_ID`.
2. Step `scenario setup` executes and returns outputs such as section slug, project slug, user email, or named page identifiers.
3. The runner stores those outputs under the step id.
4. Step `playwright_action` interpolates params from prior step outputs, performs browser authoring, and returns compact outputs such as page title, page slug, or variant name.
5. Step `scenario assert` interpolates params from prior step outputs and executes scenario-based preview or delivery assertions.
6. The workflow fails fast on the first failing step and reports the failing step id, type, and error context.

This satisfies the need for multi-step alternation without introducing branching, concurrency, or non-serializable shared state in v1. The runner is not restricted to a fixed three-step pattern; it accepts an arbitrary-length linear sequence of steps (`AC-001`, `AC-004`, `AC-006`).

### 4.3 Lifecycle & Ownership
- Workflow declaration ownership:
  - test-local workflow files live beside the owning authoring specs or under a dedicated course-authoring workflow test directory.
- Step execution ownership:
  - TypeScript runner owns orchestration.
  - Elixir remains the owner of scenario semantics and backend state creation/assertion behavior.
- Fixture ownership:
  - `my-fixture.ts` keeps `seedScenario(...)` for setup-only specs and gains `runWorkflow(...)` for workflow-driven specs.
- Output ownership:
  - each step owns its `outputs` map
  - the runner owns interpolation and aggregation
- Browser ownership:
  - Playwright keeps ownership of browser/session/page lifecycle
  - no Elixir-side browser orchestration is introduced in v1
- Durable contract ownership:
  - `assets/automation/WORKFLOWS.md` documents how to write and use workflows
  - `mer-5416` work-item docs describe why this pattern exists and how it rolls out across PRs

### 4.4 Alternatives Considered
- `Elixir as orchestrator`
  - rejected for v1
  - reason: browser execution would have to become a subprocess or external worker concern, increasing complexity before the pattern is proven
- `Top-level workflow steps for arbitrary hooks`
  - rejected for v1
  - reason: existing scenario `hook:` support already provides a custom assertion escape hatch inside scenario steps, so a second custom step type is unnecessary initially
- `Workflow steps naming arbitrary Playwright tests/specs`
  - rejected
  - reason: naming arbitrary specs tightly couples the workflow DSL to Playwright file structure and reduces refactor safety; an action registry is the simpler adequate contract
- `Single hard-coded before/after helpers instead of a workflow`
  - rejected
  - reason: it would solve only the first case and fail to satisfy the requirement for repeated alternation and grouped follow-up slices (`FR-001`, `FR-005`)

## 5. Interfaces
- Workflow declaration shape, v1:
  - top-level `workflow` list
  - arbitrary number of ordered steps
  - each item must have:
    - `id`
    - exactly one step type:
      - `scenario`
      - `playwright_action`
- Scenario step shape:
  - `file`
  - optional `params`
- Playwright action step shape:
  - `action`
  - optional `params`
- Workflow state shape:
  - `params`: global workflow params
  - `steps.<step_id>.outputs`: serializable per-step outputs
- Interpolation:
  - support global params and prior outputs using simple `${...}` placeholders
  - no branching expressions or computed functions in v1
- Playwright runner API:
  - new helper exposed from the existing fixture surface, expected as `runWorkflow(...)`, that a spec can call with:
    - workflow path
    - runtime params
    - Playwright fixture context
- Backend scenario contract:
  - continue using `/test/scenario-yaml`
  - allow repeated calls within one Playwright test run

Every acceptance criterion can map cleanly to these contracts: workflow orchestration (`AC-001`), preview and delivery assertion routing (`AC-002`, `AC-003`), first-slice reusability (`AC-004`, `AC-005`), compatibility (`AC-006`), author-preview semantic clarity (`AC-007`), end-to-end validation (`AC-008`), and durable grouped follow-up usage (`AC-009`).

## 6. Data Model & Storage
- No production domain tables or runtime data model changes are required for the workflow runner itself.
- New workflow declarations are file-based test artifacts under `assets/automation/`.
- New TypeScript interfaces define:
  - workflow file schema
  - workflow state
  - scenario step result
  - playwright action result
- `assets/automation/WORKFLOWS.md` is part of the durable infrastructure contract and should be updated in the first implementation PR.
- Scenario assertions may require additional scenario-level helper code or hook modules in `test/scenarios/` and `test/scenarios/features/`, but that is test infrastructure rather than production storage.

## 7. Consistency & Transactions
- Scenario setup and scenario assertion phases each execute atomically within their own request and scenario engine invocation.
- The workflow runner does not attempt to create a cross-step distributed transaction.
- Consistency boundary is:
  - Playwright mutates state through normal authoring UI requests
  - subsequent scenario steps observe the committed backend state produced by those requests
- Fail-fast behavior prevents later assertions from running on top of already failed or incomplete browser mutations.

## 8. Caching Strategy
N/A

The workflow runner should not introduce any new caches in v1. Each step should use current backend and browser behavior directly for correctness and debuggability.

## 9. Performance & Scalability Posture
- The v1 runner is intentionally linear and small-scale.
- Browser-heavy coverage remains in release or targeted automation lanes, not the default fast path, which keeps the extra scenario phase operationally acceptable.
- Reusing one Playwright test context across multiple sequential steps avoids spawning unnecessary browser sessions.
- The first PR should keep the number of grouped cases intentionally low so feedback on runner shape arrives before broader expansion.

## 10. Failure Modes & Resilience
- Scenario step fails before browser step:
  - workflow stops
  - report setup error and scenario summary
- Playwright action fails:
  - workflow stops
  - report action id, resolved params, and browser-side error
- Post-Playwright scenario assertion fails:
  - workflow stops
  - report assertion-step failure distinctly from authoring-step failure
- Interpolation references missing outputs:
  - treat as runner configuration error
  - fail before invoking the step
- Existing scenario-seeded specs not using the new runner:
  - remain unaffected because the new runner is additive and does not replace `seedScenario`

## 11. Observability
- Reuse existing scenario response summaries and errors from `PlaywrightScenarioController`.
- Add runner-level step logging in TypeScript:
  - workflow id/path
  - step id
  - step type
  - start/end/failure status
- Preserve browser-native debugging support:
  - Playwright trace/screenshots when already enabled by test configuration
- `assets/automation/WORKFLOWS.md` should document expected runner error surfaces so future contributors can debug missing outputs, step failures, and interpolation issues.

## 12. Security & Privacy
- Continue using the existing internal scenario token gate for backend scenario execution.
- Do not introduce a new general-purpose endpoint for arbitrary code execution.
- Step outputs must remain limited to the minimum identifiers needed for downstream test steps; avoid serializing unnecessary sensitive data.
- No production-user privacy posture changes are introduced by this work item because all behavior remains inside the existing internal test infrastructure.

## 13. Testing Strategy
- Architecture validation:
  - add targeted TypeScript tests for workflow parsing/interpolation if current automation infrastructure supports them cheaply
- Backend validation:
  - add targeted ExUnit or scenario tests for any new scenario hooks/directives used for author-preview or learner-delivery assertions
- End-to-end validation:
  - add the first workflow-driven Playwright specs for one or two representative `MIXED` groups
  - prove `scenario -> playwright_action -> scenario` alternation works at least twice in one workflow
- Regression validation:
  - run the affected new workflow-driven specs
  - run at least one existing scenario-seeded Playwright spec to confirm additive compatibility (`AC-006`)
- Documentation validation:
  - update `assets/automation/WORKFLOWS.md` in the first implementation PR (`AC-009`)

## 14. Backwards Compatibility
- Existing uses of `seedScenario` remain valid and unchanged (`AC-006`).
- Existing course-authoring POMs and helper tasks remain the base layer; the new runner wraps them rather than replacing them (`FR-004`).
- Workflow runner adoption is opt-in per spec, which keeps the first PR narrow and avoids mass migration pressure.

## 15. Risks & Mitigations
- Risk: workflow DSL grows too quickly into a mini-language.
  - Mitigation: keep v1 to linear steps, two step types, simple interpolation, and no branching.
- Risk: author-preview assertions secretly rely on instructor-preview routes.
  - Mitigation: keep author-preview semantics explicit in workflow naming, scenario files, and acceptance tests (`AC-007`).
- Risk: outputs become ad hoc and inconsistent across steps.
  - Mitigation: define a small serializable output contract and document it in `assets/automation/WORKFLOWS.md`.
- Risk: first PR chooses groups that are too trivial to prove the pattern.
  - Mitigation: choose one or two representative groups with enough settings/edit/persist/render depth to validate the full loop (`AC-004`, `AC-008`).

## 16. Open Questions & Follow-ups
- Which groups should PR 1 use to maximize signal with manageable complexity?
- Does author preview need a small new scenario surface, or can hooks against existing preview boundaries fully cover it?
- Should follow-up PR planning live in `plan.md` as one grouped rollout or as explicit per-group phases?
- Follow-up: produce `plan.md` with PR-by-PR slices once this FDD is accepted.

## 17. References
- `docs/exec-plans/current/epics/automated_testing/mer-5416/prd.md`
- `docs/exec-plans/current/epics/automated_testing/mer-5416/requirements.yml`
- `docs/exec-plans/current/epics/automated_testing/mer-5416-approach.md`
- `docs/exec-plans/current/epics/automated_testing/plan.md`
- `lib/oli_web/controllers/playwright_scenario_controller.ex`
- `assets/automation/src/core/fixture/my-fixture.ts`
- `assets/automation/src/core/seedScenario.ts`
- `assets/automation/tests/torus/course_authoring/course-authoring.spec.ts`
- `docs/design-docs/publication-model.md`
