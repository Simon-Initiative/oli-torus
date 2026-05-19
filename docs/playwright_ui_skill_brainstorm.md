# Playwright UI Skill Brainstorm

## Goal

Capture the findings from validating the `MER-5254` Assessments tile against Figma using a real local browser, and turn those findings into a reusable skill/workflow for future UI tickets.

This document is intentionally broader than a ticket note. The aim is to define a repeatable developer workflow for:

- logging into the right product surface
- navigating to a target route
- dismissing global overlays like cookie consent
- reaching a stable browser state
- validating real UI against Figma
- optionally iterating with agents until the UI is accepted

## What Slowed Us Down

### 1. Browser automation was available, but not immediately ergonomic

Observed:

- `npx playwright` CLI was available.
- The plain `node` runtime in the repo could not directly resolve `playwright`.
- `@playwright/test` was installable via `npx`, but ad hoc execution from temp files was awkward.
- We had to discover a workable invocation path before we could automate the browser.

Impact:

- Multiple iterations were spent proving how to actually drive a real browser in this environment instead of validating the UI itself.

Implication for a skill:

- The skill should provide a single standard execution path for browser automation.
- The user should not pay the setup cost every time a ticket needs UI validation.

### 2. Missing runtime context blocked direct navigation

Observed:

- We did not initially know whether the app was already running.
- We did not know the correct base URL/port.
- We did not know the target section slug.
- We did not yet have valid login credentials.

Impact:

- A lot of time went into reaching the actual page under test.

Implication for a skill:

- The skill should bootstrap browser context explicitly.
- It should ask for or infer:
  - target surface: `student`, `instructor`, `author`, `admin`
  - route or URL to validate
  - entity context such as section slug or project slug
  - credentials, unless defaults exist

### 3. A clean browser is not the same as a ready browser

Observed:

- The cookie consent modal blocked login clicks.
- An early selector matched a hidden support input instead of the visible login field.
- The browser needed route-specific selectors and overlay handling before meaningful interaction could happen.

Impact:

- Several iterations were wasted on global UI chrome instead of the target screen.

Implication for a skill:

- The skill should include standard global UI bootstrapping:
  - accept cookies if present
  - dismiss common modals if present
  - target only visible inputs/buttons

### 4. Existing repo automation knowledge was underused initially

Observed:

- The repo already contains Playwright automation and Page Object Models.
- `assets/automation/src/systems/torus/pom/home/LoginPO.ts` already knows:
  - the cookie consent selector
  - the login field selectors
  - the sign-in button selector

Impact:

- We rediscovered things the codebase already knew.

Implication for a skill:

- The skill should consult existing POMs/helpers before inventing selectors.
- This should be a first-class step, not an afterthought.

## Main Product Insight

For `MER-5254`, validating the Assessments tile required a real browser session, not just code inspection.

The useful workflow was:

1. run the app
2. log in as the correct role
3. accept cookies
4. navigate to the dashboard route
5. expand an assessment row
6. capture text/screenshot
7. compare to Figma

That sequence is likely reusable across many UI tickets, not just this one.

## Theme Parity Matters

One important validation finding: visual comparison only makes sense when both sides are in the same theme context.

Observed:

- The Figma node reviewed for the Assessments tile was in `dark`.
- The first browser inspection landed in `light`.
- That mismatch can create misleading differences in:
  - background/surface contrast
  - chip emphasis
  - border visibility
  - perceived grouping and hierarchy

Why this matters:

- Comparing `Figma dark` against `browser light` is not a reliable validation pass.
- It can generate false positives that look like implementation defects but are actually just theme differences.

Skill implication:

- The skill should explicitly identify the theme used by the design source.
- The browser validation should then match that theme before any comparison is reported.
- If theme parity cannot be guaranteed, the report should say so clearly and downgrade visual conclusions accordingly.

Recommended rule:

- compare dark with dark
- compare light with light
- do not treat cross-theme visual diffs as trustworthy UI bugs by default

## Skill Concept

### Proposed purpose

A generic skill for browser-assisted local UI validation.

Working name ideas:

- `validate_ui_locally`
- `playwright_local_validation`
- `figma_ui_compare`
- `ui_browser_context`

### Core responsibilities

The skill should:

1. establish browser context
2. authenticate into the correct surface
3. navigate to the requested route
4. stabilize the page
5. inspect/capture the target area
6. compare the rendered result with Figma or the requested design source
7. report high-signal differences

### Inputs the skill should gather or infer

- target surface:
  - `student`
  - `instructor`
  - `author`
  - `admin`
- route or URL to validate
- environment base URL if not obvious
- app-running confirmation if needed
- credentials, unless defaults are configured
- optional entity identifiers:
  - section slug
  - project slug
  - resource id
  - container id
- optional Figma link/node

### Defaults that would make it fast

The skill should support project-local defaults such as:

- base URL
- standard test accounts per role
- known overlays to dismiss
- route helpers or route templates
- reusable selectors from existing Playwright POMs

Example defaults:

- instructor: `instructor@test.com`
- student: `student@test.com`
- author: `author@test.com`
- admin: `admin@test.com`

These are examples only. The actual defaults should be confirmed from repo/local practice.

## Session Strategy

### Important principle

Session validity depends on role.

If the current session is for `instructor` and the next request is for `admin`, the skill must not blindly reuse the old session.

### Expected behavior

The skill should track session metadata such as:

- role
- username
- base URL
- browser/context id
- saved storage state path

Then:

- if new request matches the current session context:
  - reuse it
- if new request changes role or invalidates the session assumptions:
  - start a new browser context or load a different saved session

### Why this matters

This prevents:

- contaminated validations
- incorrect access assumptions
- accidental cross-role reuse

## Proposed Skill Workflow

### Phase 1: Resolve Context

- Determine if the app is already running.
- Determine the correct base URL.
- Determine the target role/surface.
- Gather credentials or use configured defaults.
- Determine the route to validate.

### Phase 2: Bootstrap Browser

- Launch browser/context.
- Accept cookies if present.
- Reuse or establish session.
- Persist `storageState` if useful for follow-up steps.

### Phase 3: Navigate and Stabilize

- Navigate to requested route.
- Wait for key selectors.
- Handle common overlays/popups.
- Confirm the page is in the intended state.

### Phase 4: Inspect and Capture

- Expand/open any needed UI state.
- Capture screenshot(s).
- Extract relevant text/DOM structure.
- Optionally capture element-level screenshots for smaller diffs.

### Phase 5: Compare

- Compare the live result with Figma visually and structurally.
- Report the highest-signal differences first.
- Distinguish between:
  - layout differences
  - spacing/alignment differences
  - typography differences
  - color/state differences
  - missing/extra UI elements
  - interaction/state differences

## Good Candidate for Persisted Helpers

This skill probably should not rely on one-off inline scripts forever.

It would benefit from reusable helpers such as:

- login by role
- accept cookie consent
- route navigation by product context
- save/load storage state
- screenshot target element
- dump visible inputs/buttons for debugging

These helpers could live in:

- repo-local scripts
- a skill `scripts/` directory
- or existing automation support code reused from `assets/automation`

## Brainstorm: Multi-Agent Workflow

The user suggested an agent-based workflow. That idea is strong and likely worth exploring.

### High-level concept

A single ticket could move through several specialized agents:

1. context agent
2. navigation/inspection agent
3. Figma comparison agent
4. implementation/fix agent
5. re-validation agent

### Possible roles

#### Agent 1: Context Setter

Responsibilities:

- resolve target role
- resolve credentials/defaults
- decide whether current session can be reused
- establish or switch session

Outputs:

- authenticated browser context or saved `storageState`
- navigation target metadata

#### Agent 2: Route Navigator

Responsibilities:

- open the exact route
- handle global overlays
- drive the UI into the target state
- capture screenshots/DOM/text

Outputs:

- stable page state
- raw evidence artifacts

#### Agent 3: Figma Validator

Responsibilities:

- inspect relevant Figma node(s)
- compare live screenshot/DOM to Figma intent
- produce a prioritized difference list

Outputs:

- validation report
- severity-ranked mismatch list

#### Agent 4: Fix Agent

Responsibilities:

- implement targeted UI adjustments
- preserve repo patterns
- keep changes scoped to validated mismatches

Outputs:

- code changes

#### Agent 5: Re-Validation Agent

Responsibilities:

- rerun browser flow
- recapture screenshots
- confirm whether mismatches are resolved

Outputs:

- pass/fail result
- residual mismatches

### Iterative loop

Possible loop:

1. context setup
2. navigate + capture
3. compare against Figma
4. if acceptable, stop
5. if not acceptable, patch
6. revalidate
7. repeat until accepted or blocked

### Important guardrails

If this becomes multi-agent, it should still avoid:

- duplicate browser setup work
- repeated login when session can be safely reused
- vague “looks off” reports
- implementation without evidence

## What Would Make This Practical

### 1. A shared browser/session artifact

Whether via Playwright `storageState` or another persistent context, the workflow needs a reusable authenticated state.

### 2. Role-aware context switching

Switching from instructor to admin should be automatic and explicit.

### 3. Repo-aware selectors

The workflow should favor existing automation selectors/POMs wherever possible.

### 4. Figma-aware validation format

Validation should not be generic. It should say things like:

- tile body is too wide relative to Figma
- metrics row wraps differently
- status chip spacing differs
- CTA placement does not match visual grouping

### 5. Clear artifact outputs

Useful outputs include:

- full-page screenshot
- target-element screenshot
- extracted text
- compared Figma node reference
- summarized difference report

## Suggested Next Step

Before building the full skill, define a small but real first slice:

- one reusable browser bootstrap flow
- one role-aware login helper
- one navigation helper
- one capture helper
- one comparison/report format

Then validate it on a second ticket, not just `MER-5254`.

If it generalizes there too, the multi-agent version becomes worth the extra complexity.

## Second Iteration Conversation Notes

The ideas below came from a later brainstorming pass after hitting real friction with `Figma MCP + Playwright CLI` while trying to validate the Assessments tile.

These are not final decisions. They are candidate directions for a second iteration of the workflow design.

### Proposed Two-Stage Strategy

#### Stage 1: Fast visual implementation loop now

Preferred stack:

- `Figma MCP`
- `Browser MCP`

Assumption:

- a human prepares the browser context manually:
  - correct URL
  - correct logged-in user
  - correct role
  - correct theme
  - correct app state/data

Goal:

- replicate and validate the design quickly
- minimize operational friction
- focus on layout, spacing, visual hierarchy, and interaction states

Why this stage makes sense:

- it avoids spending large amounts of time on login/navigation/bootstrap
- it maximizes speed during active feature implementation
- it is well suited to Jira feature tickets where the UI already exists but needs to be aligned with Figma

#### Stage 2: Smarter context bootstrap later

Preferred stack:

- `Playwright`
- plus either `Browser MCP` or a Playwright-native visual validation layer

Goal:

- allow Codex to build context more autonomously from a colloquial request

Example future capability:

- user says something like:
  - "validate the instructor dashboard route for this section in dark mode"
  - or "log in as admin and check the settings page against Figma"

And the system can:

- infer the role
- use the right credentials/default account
- log in
- navigate to the route
- handle cookies/theme/common overlays
- possibly create or seed some context
- leave the app in the target state for validation

### Important Distinction

This conversation clarified that Playwright is especially strong at:

- building context from scratch
- automating long flows
- preparing the app state reproducibly

Examples:

- create an instructor profile
- create a course
- invite students
- walk a longer E2E setup flow

Browser MCP is especially strong at:

- operating on an already-open browser tab
- inspecting a real rendered UI quickly
- doing fine-grained visual validation once the app is already in the right state

### Likely Medium-Term Shape

The likely evolution path is:

1. use `Figma MCP + Browser MCP` for immediate productivity
2. later add Playwright helpers/scripts/knowledge so Codex can establish context autonomously
3. optionally decide later whether final Figma comparison should remain Browser-MCP-driven, Playwright-driven, or hybrid

### Candidate Hybrid Workflow

One promising future workflow:

1. Playwright prepares the context
2. Browser MCP takes over for visual inspection and iterative adjustment
3. optionally Playwright later gains screenshot-driven validation for repeatable checks

Alternative future workflow:

1. Playwright prepares the context
2. Playwright also captures screenshots/evidence
3. a validator compares those results against Figma

This choice does not need to be made immediately.

### Why Not Solve Everything at Once

The conversation suggested avoiding an overbuilt first version.

Recommended incremental approach:

- first solve speed of visual implementation
- then solve context automation
- only then consider fully automated validation loops

This preserves momentum and avoids investing too early in a workflow whose best shape is still being discovered through real ticket work.
