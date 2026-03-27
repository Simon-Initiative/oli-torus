---
name: manual_testing_run
description: >
  Run a repository-authored manual test case in a web browser. Use when an
  OpenClaw agent is given an explicit manual-testing case file and needs to
  execute the case step by step, validate expected results, and capture factual
  evidence without inventing product behavior.
---

## Purpose
Execute one manual test case from `manual_testing/cases/` in a browser against a real Torus environment.

This skill is for runtime execution only. It does not parse human chat commands, expand suites, normalize reports, or choose what test to run. It starts from a specific test-case file path that has already been selected.

## Required Input
- path to one YAML manual test case under `manual_testing/cases/`
- target environment details supplied by the caller:
  - base URL or launch URL
  - credentials or authenticated browser context
  - any required project, course, section, or page identifiers

## Persistent Torus Memory
Maintain a persistent working document at:

- `manual_testing/skills/manual_testing_run/references/things_i_have_learned_about_using_torus.md`

This document is the OpenClaw agent's running memory for Torus UI navigation and behavior.

Use it to record practical findings such as:
- how specific authoring, delivery, or admin flows are actually reached
- which labels, buttons, menus, or breadcrumbs correspond to important actions
- where role differences appear in the UI
- which page patterns indicate basic vs adaptive pages or graded vs practice flows
- recurring pitfalls, redirects, loading behaviors, or environment-specific quirks

Do not store secrets, credentials, tokens, or private user data in this document.

## Read First
1. Read the provided test case completely before opening the browser.
2. Read the references that match the case domain:
   - always: `references/torus_overview.md`
   - always: `references/user_roles.md`
   - always: `references/things_i_have_learned_about_using_torus.md`
   - for `domain: authoring`: `references/authoring_flows.md`
   - for `domain: delivery`: `references/delivery_flows.md`
   - for UI recognition help: `references/ui_landmarks.md`
3. Read the Torus memory document before every test run, even if the case looks familiar.
4. Use the references plus the Torus memory document to understand likely user intent, navigation patterns, and UI landmarks before executing the case.

## Execution Workflow
1. Parse the test case and extract:
   - case ID, title, and domain
   - preconditions
   - ordered steps
   - expected results
   - notes
2. Check whether the provided environment details satisfy the preconditions.
   - If a precondition is not met, stop and report the case as blocked.
   - Do not guess missing credentials, IDs, or target URLs.
3. Open the browser and authenticate only with the access level intended for the case.
   - Do not use an elevated role when the case expects a learner-level or instructor-level flow.
4. Execute the steps in order.
   - Treat each step instruction as binding.
   - Use product context from the reference docs to interpret Torus navigation, page types, and labels.
   - If the UI wording differs slightly but the product state is clearly the same, note the difference and continue.
   - If the runtime reaches an ambiguous state, gather evidence before deciding pass or fail.
5. Validate every expected result against what the browser actually shows.
   - Prefer observable evidence: visible page title, navigation, editable controls, published state, learner content, error banners, or disabled actions.
   - Distinguish between a true failure, a blocked condition, and uncertainty.
6. Capture execution notes suitable for later report normalization.
   - per-step outcome
   - assertion outcome
   - factual notes about what was observed
   - screenshots or page captures when the runtime supports them, especially on failures
7. After each completed test suite, update `references/things_i_have_learned_about_using_torus.md`.
   - Add only durable findings that are likely to help future navigation or validation.
   - Prefer short factual notes over long narratives.
   - Record new UI landmarks, navigation shortcuts, role-specific differences, and misleading patterns that cost time during execution.
   - If a finding is environment-specific or uncertain, label it clearly rather than presenting it as a universal rule.

## Operating Rules
- Stay inside the scope of the provided test case. Do not deepen the scenario unless the case explicitly requires it.
- Do not mutate data beyond what is needed to satisfy the step being executed.
- Do not hand-wave missing context. If the case cannot be completed because a project, section, role, or page is unavailable, mark it blocked.
- Do not treat human-message interpretation as part of this skill.
- Do not rewrite the case while executing it.
- Always consult the Torus memory document before running a test case.
- Always preserve and extend the Torus memory document as you learn how to use the UI.
- Update the Torus memory document after each completed test suite with any reusable findings.

## Expected Output For The Caller
Return structured execution findings that can later be normalized by repository tooling. At minimum include:
- overall status: `passed`, `failed`, `blocked`, or `error`
- ordered step results
- assertion results tied to the case's `expected` entries when possible
- concise factual notes
- references to screenshots or captured evidence when available

## Reference Navigation
- Product framing and terminology: `references/torus_overview.md`
- Roles, permissions, and motivations: `references/user_roles.md`
- Persistent navigation memory: `references/things_i_have_learned_about_using_torus.md`
- Authoring-centric navigation and UI: `references/authoring_flows.md`
- Delivery-centric navigation and UI: `references/delivery_flows.md`
- Shared UI landmarks and recognition cues: `references/ui_landmarks.md`
