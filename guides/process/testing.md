# Torus Testing Strategy

This document aligns Phoenix/Elixir engineers, React engineers, and QA on how we layer tests inside Torus and how Playwright complements the existing Oli.Scenarios and LiveView suites.

## 1. Goals
- Keep the product shippable by continuously validating the most critical author, instructor, and learner workflows end to end.
- Reserve expensive browser automation for the highest-value journeys; push narrower behaviors down into faster Elixir-based tests.
- Provide deterministic data, authentication, and tooling so developers and QA can add or debug Playwright tests as part of their normal workflow.

## 2. Layered Testing Model

| Layer | Tooling | Primary Owners | What It Covers | Notes |
| --- | --- | --- | --- | --- |
| Unit tests | Elixir ExUnit / TypeScript Jest | All engineers | Small, isolated functions and modules; pure logic and utilities | Fastest feedback
| Application logic | `Oli.Scenarios` (YAML → Elixir) | Backend devs | Workflows inside `lib/oli` (domain logic, DB, services) | Fast, deterministic; no UI.
| UI components | Phoenix LiveView tests | Backend + frontend devs | Individual LiveViews/components, validation rules, state edges | Keep selectors local to views.
| End-to-end flows | Playwright | Frontend devs + QA | Cross-page workflows, React-heavy screens, smoke coverage | Real browser + server; small but meaningful suite.

Guiding principle: if a behavior can be reliably covered in Oli.Scenarios or LiveView, keep it there. Playwright is the thin top layer for “does the system work when stitched together?”

## 3. Playwright Charter

### 3.1 Scope & Priorities
- Cross-page workflows that involve multiple UIs (React authoring, instructor scheduling, etc.).
- Persona-based smoke flows proving that Author, Instructor, and Student dashboards load with no blocking errors.
- System sanity checks (login, global nav, basic accessibility cues) to catch regressions earlier than staging.

### 3.2 Candidate Workflows
- **Author**: create project → add page → add question or author content → preview as student; upload and reuse media.
- **Instructor**: create section from project/product → configure schedule in React UI → confirm dates in section overview.
- **Student**: enroll (direct or via fixture) → land on home screen → open lesson → submit attempt → see score/feedback.
- **System smoke**: application boots, personas log in, core menus render, no fatal JS errors.

### 3.3 Explicitly Out of Scope for Playwright
- Exhaustive validation/error matrix (cover in LiveView or unit tests).
- Deep branching logic (cover in Oli.Scenarios where deterministic data is easier).
- Every permission edge case (prefer targeted backend tests).

## 4. Test Architecture & Conventions

```
assets/automation/
  playwright.config.ts
  package.json
  src/
    core/                # shared fixtures, waits, verification helpers
    systems/
      torus/
        pom/             # page objects grouped by domain (dashboard, project, course, etc.)
        tasks/           # workflow helpers that orchestrate multiple POMs
  tests/
    torus/               # Playwright specs (config, user_accounts, workflow suites)
    resources/           # login/config .env files, media fixtures
```

The page objects currently live in `assets/automation/src/systems/torus/pom/**`, mirroring Torus concepts (activities, project, scheduling, etc.), and reusable tasks that wire flows together live beside them under `tasks/`.

### 4.1 Page Objects Per View
- Each route-level screen (Phoenix LiveView or React root) gets one Page Object class that becomes the “API” for that view.
- Compose flows by chaining Page Objects; tests never reference DOM structure directly.
- Extract reusable widgets (date pickers, modals, activity editors) into helper classes when they appear in multiple views.

### 4.2 Selector Strategy
- Prefer semantic locators (`getByRole`, `getByLabel`, `getByText`).
- Introduce `data-testid` attributes only when semantic hooks are insufficient; keep naming consistent with page object methods.
- Avoid brittle CSS chains or LiveView-internal IDs.

### 4.3 Language & Standards
- TypeScript for Playwright config, fixtures, and tests.
- Keep page object methods high-level (e.g., `createNewProject`, `setScheduleDates`) so tests read like user stories.

## 5. Data, Environments, and Authentication

### 5.1 Environments
- **Local deterministic (default)**: start Phoenix in a dedicated `MIX_ENV=playwright`, run migrations, and seed the database using per-spec scenario YAMLs invoked from the Playwright suite. Point Playwright to `http://localhost:4001` (or similar) during CI/dev runs.
- **Shared staging (later phase)**: optional profile for release smoke runs; expect higher flake risk because data reset is harder.

### 5.2 Seeding Strategy
- Reuse Oli.Scenarios and existing seeds where possible to avoid duplicating fixtures.
- Provide a guarded `/test/scenario-yaml` endpoint plus YAML fixtures so tests can seed deterministic users/projects/sections (e.g., `author@playwright.test`) on demand.
- For per-test isolation, expose a limited helper (CLI task, RPC call, or test-only API) that can create/delete entities without resetting the world.

### 5.3 Authentication
- Avoid UI-driven login inside every test. Instead:
  - Use a Playwright `global-setup.ts` script to log in as Author/Instructor/Student and store cookies via `storageState` files for reuse.
  - Alternatively, enable a guarded `/test-login` endpoint in test env that sets the same session cookie Phoenix would issue.
- Seed deterministic persona accounts with known credentials and permissions.

## 6. LiveView vs React Considerations
- Playwright interacts with both; rely on auto-waiting plus semantic selectors to handle LiveView DOM patches.
- For React-heavy pages (drag-and-drop, async grids), add stable test IDs and wait on explicit network calls (`page.waitForResponse`) when necessary.
- Keep assertions user-visible (headings, toasts, summary text) rather than implementation-specific.

Following these steps ensures Torus keeps fast feedback via Oli.Scenarios and LiveView tests while adding high-confidence, browser-level validation for the most important user journeys.
