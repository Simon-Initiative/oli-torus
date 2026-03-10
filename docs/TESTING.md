# Testing

## Test Types

Torus uses layered testing. Choose the cheapest test type that gives high confidence for the behavior under change.

- Elixir unit tests: use ExUnit for isolated domain logic, pure functions, changesets, parsers, and service modules where setup can stay small and local.
- TypeScript unit tests: use Jest for browser-side utilities, reducers, hooks, activity logic, adaptivity helpers, and other client code that does not require a Phoenix-rendered UI.
- Phoenix LiveView tests: use `Phoenix.LiveViewTest` for server-driven interactive views, form validation, event handling, conditional rendering, and UI state transitions that live primarily in LiveView.
- `Oli.Scenarios` integration tests: use YAML-driven non-UI workflow tests for real authoring, publishing, section, enrollment, and learner flows that must exercise actual application code and persistence end to end without browser automation.

Guiding principle: if the behavior is pure or local, keep it in unit tests. If the behavior is UI orchestration in LiveView, keep it in LiveView tests. If the behavior is a realistic multi-step Torus workflow that spans domain boundaries but does not require a browser, prefer `Oli.Scenarios`.

## When Scenario Tests Are Necessary

Scenario coverage is usually warranted when one or more of these are true:

- the behavior crosses multiple domain steps such as authoring -> publish -> delivery -> learner interaction
- the regression risk is in workflow integration, not in a single function or single LiveView
- the test should execute real Torus infrastructure and persistence rather than fixtures, mocks, or browser clicks
- the feature affects projects, sections, publications, enrollments, page views, learner attempts, or similar end-to-end state transitions
- a browser test would mostly be validating backend workflow rather than UI-specific behavior

Scenario coverage is usually not the right choice when:

- the behavior is isolated business logic that fits in ExUnit
- the behavior is client-only logic that fits in Jest
- the behavior is mainly a LiveView rendering or event-handling concern
- the desired scenario would be a narrow one-off detail rather than a reusable workflow-level capability

## Scenario Rules

`Oli.Scenarios` tests are intentionally high-confidence integration tests.

- Use real directives and real application modules.
- Do not use fixtures, factories, or mocks to create the domain state under test.
- Prefer YAML assertions close to the workflow transitions being verified.
- Keep scenarios concise and focused on capability-level behavior.
- Validate scenario files with `Oli.Scenarios.validate_file/1` while authoring.

Scenario files live under `test/scenarios/`. Core framework documentation lives in `test/support/scenarios/README.md` and the topic docs under `test/support/scenarios/docs/`.

## Scenario Skills

Two repo-local skills support scenario-based testing in Torus:

- `build_scenario`: author or update `Oli.Scenarios` coverage using `.scenario.yaml` files and companion ExUnit runners
- `extend_scenario`: expand the scenario DSL and runtime when required workflow coverage cannot be expressed with current directives

If you are referring to `expand_scenario`, use `extend_scenario` in this repository; that is the local skill that expands scenario capability.

## Required Gates

At minimum, run the most targeted tests that exercise the changed behavior.

- For Elixir unit or integration changes: run the affected `mix test` target first, then broader suites as risk warrants.
- For TypeScript changes: run the affected Jest tests under `assets/`.
- For LiveView changes: run the targeted LiveView test module and verify the rendered state transitions under `Phoenix.LiveViewTest`.
- For scenario changes: validate the YAML file, then run the targeted ExUnit module or scenario runner that executes the scenario file.

When adding or changing scenario coverage:

- validate the scenario structure with `Oli.Scenarios.validate_file/1`
- fail on any scenario execution errors
- fail on any failed scenario verification

## Canonical References

- Broader testing strategy and Playwright positioning: `guides/process/testing.md`
- Scenario framework overview: `test/support/scenarios/README.md`
- Scenario examples and docs: `test/support/scenarios/docs/`, `test/scenarios/`
