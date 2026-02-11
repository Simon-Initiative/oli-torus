# AGENTS.md

This guide is for AI agents contributing to the Playwright-based automation that lives in `assets/automation`. It summarizes how the framework is laid out, how page objects/tasks are composed, and how to run the suites safely.

## Current Layout
| Path | Purpose |
| --- | --- |
| `package.json`, `tsconfig.json`, `playwright.config.ts` | Tooling, path aliases (`@core`, `@pom`, `@tasks`, `@fixture`), and runner defaults (Chrome channel, HTML report, sequential workers).
| `src/core/` | Shared helpers (`Utils`, `Waiter`, `Verifier`), data utilities (`FileManager`), decorators, fixture glue, and widgets like `Table`.
| `src/systems/torus/pom/` | Page Object Models for Torus. Subfolders break down domains (`activities`, `content`, `course`, `dashboard`, `home`, `page`, `product`, `project`, `types`). Files ending with **PO** wrap entire pages, **CO** wraps reusable components/widgets, and `types/` centralizes enums and value maps.
| `src/systems/torus/tasks/` | High-level workflows ("tasks") that string page objects into business actions (login, curriculum authoring, publishing, admin operations, student journeys). The `data/` folder contains canned copy for assertions.
| `src/core/fixture/my-fixture.ts` | Custom Playwright test fixture that boots all task objects, utilities, and optional before/after hooks. Tests import this via `@fixture/my-fixture`.
| `tests/torus/` | Spec files (currently `config.spec.ts` and `user_accounts/user-accounts.spec.ts`).
| `tests/resources/` | `media_files/` uploads and documentation for secrets placement.

## How Page Objects And Tasks Work
- **Naming:** Complete pages are suffixed `PO` (e.g., `pom/home/LoginPO.ts`), while reusable widgets use `CO` (component object) such as the `MenuDropdownCO`. Enumerations in `pom/types/` standardize labels (activity types, toolbar actions, licenses, languages, user roles) so locators stay centralized.
- **Structure:** Each page object encapsulates Playwright locators plus intent-driven actions and assertions. Example: `pom/project/OverviewProjectPO.ts` exposes nested getters (`details`, `advancedActivities`, `publishingVisibility`, `projectAttributes`) so tasks can toggle activities, set visibility, or update metadata without re-declaring selectors.
- **Component Composition:** Higher-level POs delegate to smaller COs where a UI widget is reused across flows (sidebar navigation, dropdown menus, select dialogs, media selectors, etc.). This keeps locators for shared controls in one place.
- **Tasks:** Files in `src/systems/torus/tasks/` instantiate the necessary POs in their constructors and provide readable, stepped methods that orchestrate a workflow. For example, `ProjectTask.searchAndEnterProject` uses the author dashboard POs, waits for editors to be ready, and leverages `OverviewProjectPO` helpers; `CurriculumTask` coordinates curriculum-level actions, toolbar interactions, media uploads, and activity toggles; `AdministrationTask`, `StudentTask`, and `HomeTask` focus on role-specific behaviors.
- **Step Decoration:** Methods that should appear as named Playwright steps are annotated with `@step('Some text with {placeholders}')` from `src/core/decoration/step.ts`. The decorator inspects argument names and values to inject human-readable step text into reports, aiding debugging.

## Fixtures, Data, And Utilities
- **Fixture (`my-fixture.ts`):** Extends `@playwright/test` to auto-navigate to the configured base URL before each test, instantiate all tasks (`HomeTask`, `ProjectTask`, etc.), and optionally close the browser (controlled via runtime config defaults). Import `{ test }` from `@fixture/my-fixture` inside every spec to gain access to these fixtures.
- **Scenario seeding:** The fixture exposes `seedScenario(relativePath, params)` which reads a YAML file next to the current spec, templates `${PARAM}` placeholders, and `POST`s it to `/test/scenario-yaml` using the Playwright project base URL and a runtime-configured token (defaults to `my-token`). Specs are responsible for setting runtime config to keep credentials aligned with their scenario YAML.
- **Runtime data:** Specs define their own runtime user credentials (with run-specific IDs) and seed scenario YAMLs directly in `beforeAll`. Media uploads pull files from `tests/resources/media_files/` through `FileManager.mediaPath`.
- **Utilities:**
  - `Utils` centralizes patterns like force-click loops, incremental IDs, modal handling, custom formatting, and slow typing.
  - `Verifier` wraps `@playwright/test` expectations with domain wording for clearer error messages.
  - `Waiter` abstracts `waitForLoadState` / locator waits to keep tasks simple.
  - `Table` provides structured table reads/writes to keep selectors tidy.

## Preparing Seed Data
- Prefer per-test YAML seeding: create a scenario file next to your spec (e.g., `author_project_setup.yaml`) and call `await seedScenario('./author_project_setup.yaml', { run_id })`. The helper automatically resolves the path relative to the spec and injects params into `${run_id}` placeholders before calling the backend.

## Running The Tests
1. **Install dependencies (first run):**
   ```bash
   cd assets/automation
   npm install
   npx playwright install chrome
   ```
2. **Execute suites:**
   - `npm run test-config` – runs `tests/torus/config.spec.ts` headlessly to ensure required Torus data (projects, multimedia assets) exists, publishing projects when missing.
   - `npm run test-config:headed` – same suite but launches a visible browser for debugging.
   - `npm run test-useraccounts` – executes `tests/torus/user_accounts/user-accounts.spec.ts` validating login and admin/student flows.
   - `npm run test-all` – placeholder that currently matches `test-useraccounts`; extend this script as more suites land.
   - `npm run pw <pattern>` – pass any spec glob/pattern to the raw Playwright runner.
4. **Debugging aids:**
   - HTML reports open automatically on completion due to the `['html', { open: 'always' }]` reporter config; rerun via `npm run show-report`.
   - Screenshots and traces are captured on every failure (see `use.trace = 'on'` and `use.screenshot = 'on'`).
   - Capture traces/screenshots are on by default; adjust in `playwright.config.ts` if you need lighter runs locally.

## Adding Or Updating Coverage
- Favor expanding existing tasks before touching specs; tests should read like business workflows (`homeTask.login('author')`, `curriculumTask.uploadMediaFile(...)`). If a flow is unique, add a new task alongside the others and expose it via the fixture.
- New UI areas should receive a dedicated `PO` or `CO` placed under the appropriate domain folder. Keep locators private and expose high-level methods/assertions. Reuse type helpers in `pom/types` to avoid hard-coded copy and to keep selectors resilient.
- When a task needs new assertions, consider whether it belongs inside a page object (UI-specific) or in the task (cross-page flow). Use the `@step` decorator to make logs readable.
- Keep scenario YAMLs and runtime login data in specs aligned (emails, passwords, names). Place any new upload assets under `tests/resources/media_files/` so `FileManager` can resolve them.

Following these conventions keeps the E2E suite maintainable as Torus grows; treat `assets/automation` as its own mini-project with clear separation between helpers, page objects, tasks, and specs.
