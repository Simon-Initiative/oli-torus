# Torus Technical Documentation Plan

Last reviewed: 2026-02-23

## Purpose and Audience
This plan defines the scaffold and delivery sequence for a complete technical guide set for Torus.

Audience:
- Software architects
- Backend and frontend engineers
- SRE/operations contributors

Artifact:
- `docs/guides/technical/*` technical guide suite with clear ownership, lifecycle coverage, and operational depth.

## Current State and Scope
Current `docs/` content is feature- and epic-heavy (`docs/features/*`, `docs/epics/*`) with limited system-level technical guides.

This plan covers:
- Architecture boundaries and core domains
- Data model and lifecycle flows
- Integrations (LTI/LMS/API)
- Operations, security, testing, and troubleshooting

This plan excludes:
- Role-based end-user product guides
- Feature PRD/FDD artifacts under `docs/features` and `docs/epics`

## Proposed Documentation Scaffold
```text
docs/guides/technical/
  plan.md
  index.md
  architecture/
    system-context.md
    core-domains.md
    data-model-and-lifecycle.md
    request-and-event-flows.md
  integrations/
    lti-and-lms.md
    api-surface.md
  operations/
    jobs-caching-observability.md
    deployment-runtime.md
  security/
    authentication-authorization.md
    tenancy-and-data-protection.md
  quality/
    testing-and-verification.md
    troubleshooting-and-diagnostics.md
  glossary.md
```

## Guide Inventory and Source-of-Truth Map
| Guide | Primary goal | Key source-of-truth paths |
| --- | --- | --- |
| `index.md` | Entry point and navigation | `docs/README.md`, this plan |
| `architecture/system-context.md` | Boundaries and platform topology | `lib/oli/`, `lib/oli_web/`, `lib/oli_web/router.ex` |
| `architecture/core-domains.md` | Context ownership and interfaces | `lib/oli/authoring/`, `lib/oli/delivery/`, `lib/oli/resources/`, `lib/oli/publishing/`, `lib/oli/lti/`, `lib/oli/accounts.ex` |
| `architecture/data-model-and-lifecycle.md` | Entity lifecycle and invariants | `lib/oli/resources/`, `lib/oli/versioning/`, `lib/oli/publishing/`, `lib/oli/delivery/sections/` |
| `architecture/request-and-event-flows.md` | Critical runtime flows | `lib/oli_web/controllers/`, `lib/oli_web/live/`, `lib/oli_web/channels/`, `lib/oli_web/telemetry.ex` |
| `integrations/lti-and-lms.md` | LTI 1.3 and LMS integration contracts | `lib/oli/lti/`, `lib/oli_web/controllers/lti_controller.ex`, `lib/oli_web/controllers/launch_controller.ex`, `lib/oli_web/views/lti_view.ex` |
| `integrations/api-surface.md` | API boundaries and expectations | `lib/oli_web/controllers/api/`, `lib/oli_web/views/api/` |
| `operations/jobs-caching-observability.md` | Background execution and telemetry | `lib/oli_web/backgrounds.ex`, `lib/oli/notifications/`, `lib/oli/analytics/`, `lib/oli_web/telemetry.ex` |
| `operations/deployment-runtime.md` | Runtime dependencies and environments | `config/`, `mix.exs`, `docs/preview-environments.md` |
| `security/authentication-authorization.md` | AuthN/AuthZ and role assumptions | `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`, `lib/oli_web/plugs/`, `lib/oli/authoring/authors/`, `lib/oli/accounts/` |
| `security/tenancy-and-data-protection.md` | Institution/section scoping and sensitive data controls | `lib/oli/institutions/`, `lib/oli/delivery/sections/`, `lib/oli/encrypted/`, `lib/oli/consent/` |
| `quality/testing-and-verification.md` | Test strategy and confidence map | `test/`, `test/oli/`, `test/oli_web/` |
| `quality/troubleshooting-and-diagnostics.md` | Failure modes and diagnosis workflows | `lib/oli_web/endpoint.ex`, `lib/oli_web/telemetry.ex`, `lib/oli/analytics/`, `docs/runbooks/` |
| `glossary.md` | Consistent terminology baseline | `AGENTS.md`, `lib/oli/resources/`, `lib/oli/publishing/`, `lib/oli/delivery/` |

## Writing Standards and Template Contract
Each guide should follow:
- `/.agents/skills/doc-writer/references/writing-standards.md`
- `/.agents/skills/doc-writer/references/technical-guide-outline.md`
- `/.agents/skills/doc-writer/assets/templates/technical-guide-template.md`

Each guide must include:
- Purpose and audience
- Preconditions/constraints
- Concrete module/path references
- Failure modes and diagnostics
- Known limitations
- Related documentation
- `Last reviewed: YYYY-MM-DD`

## Delivery Plan
### Phase 1: Foundation and Navigation
Outputs:
- `docs/guides/technical/index.md`
- `docs/guides/technical/glossary.md`
- `docs/guides/technical/architecture/system-context.md`

Definition of done:
- Terminology aligned with Project/Publication/Section/Resource/Revision/Enrollment/Attempt
- Cross-links established across all three docs
- Architecture boundaries explicitly scoped by context ownership

### Phase 2: Core Architecture and Lifecycles
Outputs:
- `architecture/core-domains.md`
- `architecture/data-model-and-lifecycle.md`
- `architecture/request-and-event-flows.md`

Definition of done:
- Includes publication immutability and resource/revision behavior
- Includes multi-tenancy and role assumptions where relevant
- Captures at least one end-to-end flow from authoring to delivery

### Phase 3: External Interfaces and Operations
Outputs:
- `integrations/lti-and-lms.md`
- `integrations/api-surface.md`
- `operations/jobs-caching-observability.md`
- `operations/deployment-runtime.md`

Definition of done:
- Integration contracts distinguish stable behavior from implementation detail
- Operational run paths include failure and recovery guidance
- Each doc references concrete files/modules and runtime dependencies

### Phase 4: Security, Quality, and Diagnostics
Outputs:
- `security/authentication-authorization.md`
- `security/tenancy-and-data-protection.md`
- `quality/testing-and-verification.md`
- `quality/troubleshooting-and-diagnostics.md`

Definition of done:
- AuthN/AuthZ model and tenancy boundaries are explicit
- Testing strategy maps to code paths and risk areas
- Troubleshooting includes diagnostics entry points and likely causes

### Phase 5: Review and Maintenance Cadence
Outputs:
- Full guide set pass for consistency and link integrity
- Ownership table added to `index.md`
- Review cadence documented (quarterly or major release)

Definition of done:
- No broken internal links
- Terms are consistent across all guides
- Every guide includes Known Limitations and Related Documentation

## Ownership and Operating Model
Recommended ownership:
- Architecture: principal/staff engineering
- Integrations and security: domain owners for LTI/Auth platform
- Operations and quality: platform/reliability owners

Maintenance triggers:
- New major subsystem
- Significant auth/integration/runtime changes
- Release cycle checkpoints

## Risks and Mitigations
- Risk: drift between implementation and docs.
  - Mitigation: require doc touch in PR checklist for architecture-affecting changes.
- Risk: incomplete cross-context flow coverage.
  - Mitigation: anchor each flow to concrete router/controller/context/module paths.
- Risk: terminology inconsistency.
  - Mitigation: keep `glossary.md` canonical and link each guide to it.

## Known Limitations
- This artifact is a planning scaffold; full guide content is not authored here.
- Some module ownership boundaries may require validation with active domain owners before publishing final guides.

## Related Documentation
- `AGENTS.md`
- `docs/README.md`
- `docs/preview-environments.md`
- `docs/runbooks/*`
- `docs/features/*`
- `docs/epics/*`
