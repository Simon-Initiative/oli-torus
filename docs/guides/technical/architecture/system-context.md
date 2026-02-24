# Torus Technical Guide: System Context

Last reviewed: 2026-02-23

## Purpose and Audience
This guide explains where core Torus subsystems sit, which boundaries they own, and how major runtime paths connect.

Audience:
- Software architects
- Backend/frontend engineers onboarding to core platform flows

## System Context
Torus is a Phoenix/Elixir platform with two primary runtime planes:
- Domain/business logic in `lib/oli/`
- Web/runtime edge in `lib/oli_web/`

High-level architecture boundaries:
- Domain contexts (`Oli.*`) own content, publishing, delivery, accounts, analytics, and integrations.
- Web layer (`OliWeb.*`) owns HTTP routing, LiveView endpoints, API controllers, channels, and plugs.
- Runtime supervision and background systems are composed in `lib/oli/application.ex`.

## Architecture and Design
### Core runtime entry points
- Application supervision tree: `lib/oli/application.ex`
- HTTP/WebSocket endpoint: `lib/oli_web/endpoint.ex`
- Routing and pipeline composition: `lib/oli_web/router.ex`

### Layer responsibilities
- `lib/oli/`: contexts and data invariants (examples: `Oli.Authoring`, `Oli.Resources`, `Oli.Publishing`, `Oli.Delivery`, `Oli.Accounts`)
- `lib/oli_web/controllers/`: request orchestration and response composition
- `lib/oli_web/live/`: interactive authoring/delivery UI
- `lib/oli_web/controllers/api/`: API-facing endpoint surface
- `lib/oli_web/channels/`: state/event channels for real-time use cases

### Runtime capabilities visible in the supervision tree
- Postgres access via `Oli.Repo`
- Oban background jobs (`{Oban, oban_config()}`)
- Telemetry supervisor (`OliWeb.Telemetry`)
- Phoenix PubSub and Presence
- Cachex-backed caches and delivery coordination
- LTI keyset caching (`Oli.Lti.KeysetCache`)

## Data Model and Lifecycle
At system-context level, lifecycle is defined by domain handoff:
1. Authoring in project/revision space
2. Publishing to immutable publication snapshot
3. Delivery through section-scoped learner interactions
4. Attempt/evaluation and analytics aggregation

Key invariants to preserve across guides:
- Resource/revision separation (stable identity vs version)
- Publication immutability in delivery
- Section-enrollment scoping for learner-facing data

## Runtime Flows
### HTTP and LiveView flow
1. Request enters `OliWeb.Endpoint`.
2. Router pipeline in `OliWeb.Router` applies session/auth/context plugs.
3. Controller or LiveView route dispatches to domain contexts in `lib/oli/`.
4. Response and telemetry events are emitted (`Plug.Telemetry`, `OliWeb.Telemetry` metrics).

### LTI launch flow (boundary-level)
1. Request enters routes under LTI pipelines in `OliWeb.Router`.
2. LTI controllers (`lti_controller.ex`, `launch_controller.ex`) validate and map launch context.
3. Delivery/section routing continues via delivery-protected pipelines.

### API flow
1. Request enters `:api` pipeline in router.
2. API controller under `lib/oli_web/controllers/api/` validates and dispatches.
3. API view under `lib/oli_web/views/api/` serializes response.

## Integrations
System-context integration boundaries:
- LMS and LTI 1.3 flows: `lib/oli/lti/`, `lib/oli_web/controllers/lti_controller.ex`, `lib/oli_web/controllers/launch_controller.ex`
- External protocols/channels: HTTP API and Phoenix channels
- Analytics pipeline touchpoints: `lib/oli/analytics/` and xAPI modules

Detailed contracts are documented in planned integration guides.

## Security and Permissions
Top-level auth/authz boundaries:
- User/author authentication plugs and helpers in `lib/oli_web/user_auth.ex` and `lib/oli_web/author_auth.ex`
- Router pipelines enforce role/section/project constraints via plugs
- Domain contexts enforce scoped access for institution/section/project operations

## Operations
System-level operational points:
- Telemetry metrics exposed via `lib/oli_web/telemetry.ex`
- Background and scheduled work in `lib/oli/application.ex` (Oban + recurring cleanup jobs)
- Endpoint/runtime middleware in `lib/oli_web/endpoint.ex`

## Testing and Verification
System-context verification sources:
- Context tests under `test/oli/`
- Web/controller/live tests under `test/oli_web/`
- Cross-flow scenario tests under `test/oli/scenarios/`

## Troubleshooting
Common boundary-level diagnostics:
- Routing/pipeline issues: inspect `lib/oli_web/router.ex` for pipeline order and plugs.
- Session/auth failures: inspect `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`.
- Background/runtime issues: inspect supervisor startup and child definitions in `lib/oli/application.ex`.
- Endpoint behavior mismatch: inspect parser/session/SSL configuration in `lib/oli_web/endpoint.ex`.

## Known Limitations
- This is a system-context guide, not a full domain deep dive.
- Some subsystem ownership details need explicit codification in future domain guides.

## Related Documentation
- [Technical Guide Index](../index.md)
- [Glossary](../glossary.md)
- [Technical Plan](../plan.md)
- `docs/runbooks/*`
- `docs/features/*`

