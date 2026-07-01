# Product Overhaul PRD (High Level)

Epic: `MER-4032`
Scope baseline date: 2026-02-12

## Problem Statement

Current "Product" naming and behaviors are inconsistent with intended usage as course section templates. This causes UX confusion, weak discoverability, and technical coupling that makes template-specific behavior hard to evolve safely.

## Goals

- Rename and standardize "Product" semantics to "Template(s)" across authoring/admin surfaces.
- Improve template overview workflows (cover previews, template preview, defaults, usage visibility).
- Resolve known correctness bugs in template/remix flows.
- Enable template-scoped curriculum extensions while preserving project/section isolation.

## Non-Goals

- Full redesign of unrelated authoring or delivery navigation.
- Rewriting publication architecture beyond scope required for template-safe behavior.
- Changing existing completed or closed-won't-do tickets in this epic.

## Users

- Authors building and maintaining templates.
- Admins managing template metadata, visibility, and usage across institutions.
- Instructors and learners indirectly impacted by section generation and remix updates.

## Functional Requirements (High Level)

1. Terminology and UI alignment
- Replace product terminology and labels with template terminology in actionable flows.
- Ensure headings, controls, and navigation language are coherent in authoring and admin.

2. Template overview enhancements
- Add/refine links and actions for template-level settings and management.
- Support richer media/preview interactions and visibility into usage.
- Preserve navigation consistency (including breadcrumbs).

3. Remix/curriculum correctness
- Fix page removal/reintroduction update behavior without regressing publication updates.
- Correct curriculum numbering behavior and add exclusion controls.

4. Visibility and governance
- Support public visibility control at template granularity rather than project-only level.

5. Template structure extensibility
- Support adding containers directly in templates with appropriate revision scoping.
- Ensure scope-aware querying prevents cross-template or cross-section leakage.

## Key Technical Constraints

- "Products/Templates" are implemented as sections in code paths; leverage existing section mechanics where possible.
- Publication/update pipeline is high risk; bug fixes must be test-first and minimally invasive.
- Resource/revision and section_resource behavior must preserve data isolation boundaries.

## Dependencies

- Existing section preview and enrollment mechanisms.
- Existing curriculum/resource models and authoring queries.
- Existing notification, table/filter, and CSV capabilities where reusable.

## Risks

- Scope leakage exposing resources from unrelated templates/sections.
- Regressions in publishing and content update behavior.
- UI drift between preview experiences and true runtime surfaces.

## Mitigations

- Reuse canonical rendering paths for previews where exact fidelity matters.
- Introduce revision scope semantics and enforce scope filters consistently.
- Require focused regression tests in publication/remix-sensitive paths.

## Acceptance (Epic-Level)

- All actionable child tickets in `To Do`/`Analyzing` have technical guidance or feature-spec direction.
- Feature-spec-required tracks have documented informal specs.
- Remaining actionable tickets explicitly marked as requiring no additional guidance.
