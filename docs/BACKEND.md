# Backend

## Service Architecture

The backend is a single Phoenix application organized around domain contexts under `lib/oli/` and a web layer under `lib/oli_web/`. The backend owns the product model, persistence, authorization, publication workflow, LMS interoperability, analytics, and long-running operational concerns.

At a high level:

- `lib/oli/authoring`: project, content, collaboration, and editing workflows
- `lib/oli/resources` and `lib/oli/versioning`: resource/revision model and content history
- `lib/oli/publishing`: publication creation, snapshots, diffs, and update flows
- `lib/oli/delivery`: sections, enrollment, gating, attempts, evaluation, and learner runtime
- `lib/oli/activities`: activity definitions, state, transformers, and reporting
- `lib/oli/lti`: LMS interoperability and launch/reporting behavior
- `lib/oli/analytics`: xAPI pipelines, summaries, datasets, and backfill jobs
- `lib/oli/gen_ai`, `lib/oli/mcp`, `lib/oli/dashboard`: newer AI- and insights-related platform capabilities

The web layer in `lib/oli_web/` exposes those capabilities through controllers, APIs, LiveViews, templates, plugs, and channels.

## Runtime Model

`Oli.Application` supervises the main runtime pieces:

- Phoenix endpoint and PubSub
- Ecto repo
- Oban workers
- Cachex-backed caches
- xAPI upload pipeline
- scheduled cleanup jobs
- clustering support
- GenAI and MCP services

This is an application with significant background and operational behavior, not just request/response HTTP handling.

## Backend Boundaries

- Put domain rules in the relevant `lib/oli/` context, not in controllers, templates, or LiveViews.
- Use `lib/oli_web/` for transport, session, rendering, and interaction concerns.
- Respect the publication boundary: learner-visible sections should resolve against publications, not mutable authoring head revisions.
- Preserve institution, section, and role scoping in queries and authorization paths.
- Treat analytics, background jobs, and caches as supporting infrastructure around the core product model, not alternative sources of truth.

## Canonical References

- High-level system concepts: `docs/design-docs/high-level.md`
- Publication model: `docs/design-docs/publication-model.md`
- LTI implementation notes: `guides/lti/implementing.md`, `guides/lti/config.md`
- Server-side coding guidance: `guides/process/server-coding.md`
- Operational commands and workflows: `docs/TOOLING.md`, `docs/OPERATIONS.md`, `docs/TESTING.md`
- Backend review lenses: `.review/elixir.md`, `.review/security.md`, `.review/performance.md`

## Change Guidance

Use this file to locate the right backend boundary before making changes. Add deep technical detail to the established guides or to focused design docs near the work item rather than expanding this file into subsystem-by-subsystem reference material.
