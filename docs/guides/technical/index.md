# Torus Technical Guide Index

Last reviewed: 2026-02-23

## Purpose and Audience
This guide index is the entry point for Torus system-level technical documentation.

Audience:
- Software architects
- Backend and frontend engineers
- Platform/reliability engineers

## Scope
This guide set documents:
- System boundaries and domain ownership
- Data and lifecycle invariants
- Runtime and integration behavior
- Security, operations, quality, and diagnostics

This guide set does not replace feature specs in `docs/features/*` or `docs/epics/*`.

## Reading Order
1. [Glossary](./glossary.md)
2. [System Context](./architecture/system-context.md)
3. `architecture/core-domains.md` (planned)
4. `architecture/data-model-and-lifecycle.md` (planned)
5. `architecture/request-and-event-flows.md` (planned)
6. `integrations/lti-and-lms.md` (planned)
7. `integrations/api-surface.md` (planned)
8. `operations/jobs-caching-observability.md` (planned)
9. `operations/deployment-runtime.md` (planned)
10. `security/authentication-authorization.md` (planned)
11. `security/tenancy-and-data-protection.md` (planned)
12. `quality/testing-and-verification.md` (planned)
13. `quality/troubleshooting-and-diagnostics.md` (planned)

## Current Guide Status
| Guide | Status | Owner role |
| --- | --- | --- |
| `plan.md` | Complete | Architecture |
| `index.md` | Complete | Architecture |
| `glossary.md` | Complete | Architecture |
| `architecture/system-context.md` | Complete | Architecture |
| Remaining scaffolded guides | Planned | Domain owners |

## Source-of-Truth Anchors
Primary code boundaries for this suite:
- `lib/oli/` (core contexts and business logic)
- `lib/oli_web/` (router, controllers, LiveViews, channels, plugs)
- `lib/oli/application.ex` (OTP supervision, runtime dependencies, background processing)
- `test/` (verification strategy and behavior evidence)

## Maintenance Cadence
Update this index when:
- A guide is added, renamed, or retired
- Ownership changes
- Core runtime boundaries change

Recommended review cadence:
- Quarterly
- Every major release with architecture-impacting changes

## Known Limitations
- Most linked guides are intentionally scaffolded and not yet authored in Phase 1.
- Ownership is role-based; named individuals are not assigned in this document.

## Related Documentation
- [Plan](./plan.md)
- [Glossary](./glossary.md)
- [System Context](./architecture/system-context.md)
- `docs/README.md`
- `docs/features/*`
- `docs/epics/*`

