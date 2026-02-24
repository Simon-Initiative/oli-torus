# Torus Technical Glossary

Last reviewed: 2026-02-23

## Purpose and Audience
This glossary defines canonical technical terms used across Torus architecture guides.

Audience:
- Software architects
- Engineers across backend/frontend/platform

## Core Domain Terms
### Project
Authoring workspace for course development and collaboration.

Primary references:
- `lib/oli/authoring.ex`
- `lib/oli/authoring/course/project.ex`

### Resource
Stable content container identity used across versions.

Primary references:
- `lib/oli/resources/resource.ex`
- `lib/oli/resources.ex`

### Revision
Versioned snapshot of a resource’s content and metadata.

Primary references:
- `lib/oli/resources/revision.ex`
- `lib/oli/versioning/`

### Publication
Immutable published snapshot of project content for delivery.

Primary references:
- `lib/oli/publishing.ex`
- `lib/oli/publishing/publications/publication.ex`

### Section
Delivery instance where learners are enrolled and content is consumed.

Primary references:
- `lib/oli/delivery.ex`
- `lib/oli/delivery/sections/`

### Enrollment
User membership relationship to a section with role and participation scope.

Primary references:
- `lib/oli/delivery/sections/enrollment.ex`
- `lib/oli/delivery/sections/`

### Attempt
Learner interaction/evaluation record for delivered content or activities.

Primary references:
- `lib/oli/delivery/attempts/`
- `lib/oli_web/controllers/api/attempt_controller.ex`

## Platform and Integration Terms
### LTI 1.3 Launch
LMS-initiated entry flow into Torus with signed launch context.

Primary references:
- `lib/oli_web/controllers/lti_controller.ex`
- `lib/oli_web/controllers/launch_controller.ex`
- `lib/oli/lti/`

### Deep Link
LTI flow used to select and return Torus resources into an LMS.

Primary references:
- `lib/oli_web/controllers/lti_html/`
- `lib/oli/lti/platform_external_tools/`

### API Surface
HTTP endpoints under Torus API controllers used by internal clients and integrations.

Primary references:
- `lib/oli_web/controllers/api/`
- `lib/oli_web/views/api/`

## Runtime Terms
### Context
Elixir boundary module that owns business logic and data operations.

Primary references:
- `lib/oli/*.ex` context entry points (for example `lib/oli/resources.ex`, `lib/oli/publishing.ex`)

### LiveView
Server-rendered interactive UI process used across authoring and delivery flows.

Primary references:
- `lib/oli_web/live/`
- `lib/oli_web/router.ex`

### Telemetry
Metrics/events instrumentation for request timing, DB, pipeline, and feature execution.

Primary references:
- `lib/oli_web/telemetry.ex`
- `lib/oli_web/router.ex`

### Oban Job
Background job executed by Oban worker queues.

Primary references:
- `lib/oli/application.ex`
- `lib/oli/lti/keyset_refresh_worker.ex`

### Cachex Cache
In-memory cache instance used for selected content/runtime acceleration.

Primary references:
- `lib/oli/application.ex`
- `lib/oli/conversation/page_content_cache.ex`

## Usage Rules
- Use these terms consistently across all technical guides.
- Do not overload `resource` and `revision`; keep container/version distinction explicit.
- Treat `publication` as immutable in delivery discussions.

## Known Limitations
- This glossary is technical-only and does not include role-specific UI language.
- Some terms have feature-specific variants that are documented in feature specs.

## Related Documentation
- [Technical Guide Index](./index.md)
- [System Context](./architecture/system-context.md)
- [Technical Plan](./plan.md)
- `AGENTS.md`

