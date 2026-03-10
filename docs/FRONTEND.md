# Frontend

## Overview

Torus does not use a single monolithic SPA. The frontend is a set of focused React applications mounted into Phoenix-rendered pages and LiveView flows. This keeps routing, auth, and most page composition on the server while allowing richer client behavior where authoring and delivery need it.

The main entrypoint pattern is defined in `assets/src/apps/app.tsx`, where top-level apps are registered for server-side mounting through `window.Components`.

## Main Frontend Surfaces

- `assets/src/apps/AuthoringApp.tsx`: authoring shell for page and curriculum editing
- `assets/src/apps/DeliveryApp.tsx`: learner and instructor delivery experience with Redux-backed state
- `assets/src/apps/PageEditorApp.tsx`: page editing surface
- `assets/src/apps/ActivityBankApp.tsx`: activity bank workflows
- `assets/src/apps/SchedulerApp.tsx`: section scheduling UI
- `assets/src/apps/BibliographyApp.tsx`: bibliography management UI

## Frontend Boundaries

- Keep browser-side code focused on interaction, editing ergonomics, and local view state.
- Treat Phoenix and Elixir contexts as the source of truth for domain rules, persistence, authorization, and workflow transitions.
- Prefer extending an existing focused app over creating a broad new client shell unless the user flow genuinely needs one.
- Preserve the existing mixed model of React + LiveView + server-rendered templates rather than forcing all UI work into one rendering strategy.

## State And Integration

- Smaller apps can manage state locally; more complex apps use Redux, especially in delivery and some authoring flows.
- Client code integrates with Phoenix through mounted components, APIs, hooks, and server-provided context rather than independent frontend routing.
- Activity authoring and delivery live inside the broader frontend structure but are part of the shared platform model, not isolated microsites.

## Canonical References

- Client coding standards: `guides/process/client-coding.md`
- Activity concepts and structures: `guides/activities/overview.md`, `guides/activities/structures.md`
- Frontend build and toolchain commands: `docs/TOOLING.md`
- Frontend testing expectations: `docs/TESTING.md`
- UI review expectations: `.review/ui.md`

## Change Guidance

When changing frontend code, start by identifying the existing mounted app or LiveView surface that owns the behavior. Update the local app-level documentation or story-specific work items when a flow changes materially, but keep this file as a short map of frontend boundaries and entrypoints.
