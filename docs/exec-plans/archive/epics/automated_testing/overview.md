# Torus Automated Testing Strategy

## Overview

A primary engineering objective for Torus over the next development cycles is to move toward **fully automated testing and continuous deployment**.

Today, large portions of system verification still rely on **manual QA cycles**, which can take **several days to a week** depending on available resources. This manual step is currently the primary blocker preventing us from moving to a **continuous deployment cadence**.

To achieve reliable continuous deployment, **all critical system behavior must be verified automatically**. This document outlines the intended strategy for achieving that goal.

---

## High-Level Strategy

Our primary testing focus is:

- **Scenario-based integration tests** for end-to-end application workflows
- **Targeted Phoenix LiveView tests** for individualized UI/server interaction coverage

For more complicated browser-driven interfaces and flows, we will use **Playwright**, but the strategy is to **minimize Playwright utilization wherever possible**.

The preferred testing hierarchy for Torus is:

1. Scenario tests first
2. LiveView tests where UI event wiring or server-rendered behavior needs direct coverage
3. Playwright only when real browser behavior or cross-system interaction must be exercised

This prioritizes determinism, lower maintenance cost, and a faster PR validation path.

## Test Classes By State Dependency

An important distinction in this strategy is whether a test has a required **external state setup dependency**. This is not limited to third-party systems like Canvas. It includes any test that can only run if required state already exists outside the test's own setup flow.

Our goal is to prefer tests with **zero external state setup dependency**.

### Class 1: Playwright With External State Setup Dependency

Examples:

- LTI launch from Canvas into Torus
- other workflows that require an existing external-system state before the test can start

These are the most operationally sensitive tests.

### Class 2: Playwright Without External State Setup Dependency

Examples:

- browser authoring and preview flows where the test world is created by scenario-driven setup

Our Playwright infrastructure now supports **scenario-driven world creation**, allowing these tests to create users, projects, pages, and similar prerequisites without relying on pre-existing external setup.

### Class 3: Scenario-Based Integration Tests

These tests never have external state setup dependencies. They create and control their own world entirely within the test workflow.

### Class 4: Unit Tests

These tests never have external state setup dependencies. They validate isolated modules and functions.

Only **Playwright** tests should ever fall into a category that may have external setup dependencies. Scenario tests and unit tests should remain fully self-contained.

## Execution Strategy

We will limit Class 1 and Class 2 tests as much as possible. The default PR validation path should emphasize Class 3 scenario coverage, Class 4 unit coverage, and targeted LiveView coverage where needed.

Class 1 and Class 2 Playwright tests will **not** be part of the standard test set that runs automatically when a PR opens. Instead, they will run in a separate workflow that is:

- manually invoked before a release
- scheduled nightly against `master`

Likely both modes will exist.

For environment targeting:

- Class 1 tests should run against a specific Torus instance appropriate to the purpose of the run
- release and hotfix verification can target `stellarator`
- nightly runs against `master` can target `tokamak`
- Class 2 Playwright tests can run against that same deployed environment

The intended release testing flow is:

1. Build is produced after the standard PR-path coverage has passed, including Class 3 scenario tests and lower-level test coverage
2. Release is deployed to the staging environment, such as `stellarator`
3. Class 1 and Class 2 Playwright suites are run against that deployed instance

This keeps the main engineering loop fast while reserving browser-heavy validation for the points in the lifecycle where it provides the most value.

# Current Testing Landscape

Torus already has strong automated testing foundations in several areas:

### Unit Tests

- ~6,000 Elixir unit tests
- Several hundred TypeScript unit tests
- These provide strong coverage of individual modules and functions

However, **unit tests alone are not sufficient** because they do not validate:

- multi-component interactions
- full application workflows
- end-to-end user behaviors

### Phoenix LiveView Tests

Many UI surfaces are implemented using **Phoenix LiveView**, and these views typically have corresponding **LiveView tests**.

These tests provide good coverage for:

- view behavior
- UI events
- server interactions

However, they still operate in **component isolation** and therefore are **not true integration tests**.

### Playwright Tests

We currently have some **Playwright browser tests** that validate specific authoring flows.

Playwright allows us to test:

- real browser behavior
- client-side UI
- JavaScript-driven interfaces
- third-party integrations

However, Playwright tests have several limitations:

- slower to execute
- brittle against UI changes
- prone to non-deterministic failures
- more expensive to maintain

Because of this, Playwright tests should be used **strategically and sparingly**.

---

# Target State

Our goal is to move toward a system where:

- **All critical flows are covered by automated tests**
- **No manual QA cycle is required before release**
- **Tests are deterministic and reliable**
- **Test execution time remains reasonable**
- **Tests are maintainable as the system evolves**

To achieve this, we will emphasize **integration testing at the application layer**, with limited browser testing only where necessary.

---

# Primary Integration Testing Mechanism: Scenario Testing

The **OLI Scenarios framework** will become the primary integration testing mechanism for Torus.

Scenario tests:

- are defined using **YAML**
- describe workflows **declaratively**
- execute against the **real application infrastructure**
- do **not use mocks or fixtures**

This approach allows us to exercise large parts of the system while remaining:

- fast
- deterministic
- stable
- easy to extend

### Key Properties

Scenario tests operate:

- **below the UI layer**
- **at the application boundary**
- using real services and persistence

Examples of supported operations include:

- creating projects
- defining course structures
- creating pages and containers
- creating course sections
- configuring resources

Each scenario is executed as an **ExUnit test**, meaning it integrates naturally with the existing test infrastructure.

We will mitigate the risk that scenario testing does not execute the UI by adding new LiveView tests where needed, and targeted Playwright tests.

---

# Strategy: Expand Scenario Coverage

Our primary effort will be to **expand scenario test coverage across the entire system**.

This involves two parallel efforts.

## 1. Expand Scenario Infrastructure

We will continue adding new scenario capabilities that expose additional application behaviors.

Examples might include:

- project configuration operations
- course publishing flows
- enrollment workflows
- assessment workflows
- gradebook operations
- analytics generation
- scheduling behaviors

The goal is that **any major application capability should be expressible as a scenario command**.

Some of this we will get "for free" since the scenario testing and expanding scenario infrastructure skills are present in our agentic AI harness.

---

## 2. Build Scenario Test Suites

Once infrastructure exists, we will create **scenario definitions that represent real system workflows**.

Examples of potential scenarios:

### Course Authoring

- create project
- add pages and containers
- configure activities
- publish project

### Course Delivery

- create section
- enroll students
- complete activities
- record grades

### Instructor Workflows

- create section
- configure scheduling
- view analytics
- manage enrollments

### Content Lifecycle

- create revision
- publish revision
- deploy to sections

These scenarios will represent **complete workflows**, not just individual operations.

---

# Role of Playwright Tests

Playwright tests remain necessary for validating areas where:

1. **Browser behavior matters**
2. **Client-side code is dominant**
3. **External systems are involved**

However, they will be used **minimally**.

## Appropriate Uses

Playwright tests are appropriate for:

### LMS / LTI Flows

Examples:

- LTI launch from an LMS
- authentication handshake
- grade passback

These interactions require:

- real HTTP redirects
- browser session handling
- cross-system communication

Scenario tests cannot simulate these properly.

---

### Third-Party Integrations

Examples:

- Stripe payment flows
- OAuth authentication
- other external service integrations

Where possible we will:

- use **test accounts**
- use **sandbox APIs**
- simulate realistic end-to-end flows

---

### Client-Side Application Surfaces

Some parts of the Torus system are **primarily implemented in client-side React / TypeScript**, including:

- page authoring interfaces
- activity editors
- rich interactive tools

These surfaces may require Playwright tests because:

- business logic lives in the browser
- behavior cannot be validated at the server layer

However, we should be careful not to over-test UI details.

Tests should focus on **core workflows**, not visual structure.

---

# Playwright Design Principles

To keep Playwright tests reliable and maintainable:

### Minimize Test Count

Only create tests for **flows that cannot be covered by scenario tests**.

---

### Focus on Critical Paths

Example flows:

- LMS launch
- grade passback
- major authoring flows
- payment flows

---

### Avoid UI Fragility

Tests should avoid:

- brittle selectors
- reliance on specific DOM structure
- unnecessary UI assertions

Instead, validate:

- outcomes
- data changes
- navigation success

---

### Keep Tests Deterministic

Where possible:

- mock external services
- use sandbox environments
- avoid timing-based assertions

---

### Minimize the Focus of a Playwright Test

Playwright tests should NOT use browser automation to seed data for their intended, main purpose.  The new, `Oli.Scenarios` playwright boostrap functionality should be used instead. This allows a deterministic, fast creation of the "world" (project, pages, activities, sections) that a Playwright test then can use to perform its browser testing.

# Testing Pyramid for Torus

The resulting testing strategy should resemble the following pyramid:

             ┌───────────────────┐
             │   Playwright E2E  │
             │  (minimal number) │
             └───────────────────┘
                    ▲
                    │
          ┌─────────────────────┐
          │ Scenario Integration │
          │      (primary)       │
          └─────────────────────┘
                    ▲
                    │
           ┌─────────────────┐
           │   Unit Tests    │
           │  (many tests)   │
           └─────────────────┘

---

# Immediate Next Steps

1. **Define core system workflows**
   - identify major flows requiring coverage

2. **Expand scenario infrastructure**
   - add commands for missing application capabilities

3. **Build scenario test suites**
   - encode workflows as YAML scenarios

4. **Identify Playwright coverage**
   - enumerate flows requiring browser-level validation

5. **Stabilize Playwright tests**
   - reduce nondeterminism
   - eliminate fragile selectors

6. **Integrate all tests into CI**
   - ensure full suite runs automatically

---

# Open Questions

Several areas require further discussion.

### Scope of Playwright Coverage

Questions:

- How much authoring UI should be covered?
- Should activity editors have browser tests?
- Are smoke tests sufficient?

---

### Third-Party Integration Strategy

We need to define:

- sandbox test environments
- credential management
- test account lifecycle

Examples include:

- Stripe
- LMS platforms
- OAuth providers

---

### Scenario DSL Expansion

We should determine:

- which application services need scenario support
- what abstractions should exist in the DSL

---

### CI Runtime Constraints

As scenario coverage expands we should monitor:

- test runtime
- parallelization strategies
- CI infrastructure limits

---

# Long-Term Vision

When this strategy is fully implemented, Torus will have:

- **full automated verification of all critical flows**
- **no manual QA requirement before release**
- **confidence to move toward continuous deployment**

This will allow the engineering team to:

- ship improvements faster
- reduce release risk
- scale development velocity.

---
