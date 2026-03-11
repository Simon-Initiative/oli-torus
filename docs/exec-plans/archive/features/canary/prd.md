# Canary Feature Rollout PRD

## Overview

Introduce a staged canary rollout layer on top of the existing Scoped Feature Flag framework so that selected product capabilities can graduate from *internal only* → *5%* → *50%* → *full* availability, while still honoring project- and section-level scoping. The system must also honor publisher-level exemptions to opt specific publishers out (or in) regardless of stage.

## Goals

- Allow product teams to expose high-risk features gradually, reducing blast radius.
- Provide deterministic user-level gating (internal flag, fixed percentage cohorts).
- Preserve existing scoped enablement semantics for features that are *not* canaried.
- Give publishers optional control to opt out or be explicitly included.
- Maintain auditability and transparency in the rollout state.

## Non-Goals

- Dynamic percentage sliders beyond 5% and 50%; MVP uses fixed steps.
- Automated experimentation or metric-based promotion.
- Bulk user cohort management beyond the `is_internal` flag.

## Stakeholders

- Product Management (rollout coordination, approvals).
- Engineering (backend feature flag service, UI updates).
- Customer Success / Support (publisher coordination, exemption management).
- QA / Internal Users (early adopters).

## Rollout States

| State          | Description                                                                 | Entry Mechanism                      |
|----------------|-----------------------------------------------------------------------------|--------------------------------------|
| `off`          | Feature inaccessible regardless of scoping.                                 | Default, or manual downgrade.        |
| `internal_only`| Accessible only to actors with `is_internal = true`, unless exempted.       | Manual promotion from `off`.         |
| `five_percent` | Same as `internal_only` plus 5% of non-internal actors.                     | Manual promotion from `internal_only`.|
| `fifty_percent`| Internal users plus 50% of non-internal actors.                             | Manual promotion from `five_percent`.|
| `full`         | Everyone gains access unless publisher exemption denies it.                 | Manual promotion from `fifty_percent`.|

Percentage cohorts must be sticky per user/author and per feature—once a user is counted in the 5% or 50% cohorts, they remain included through that stage.

## Interaction with Scoped Feature Flags

1. **Feature Definition**
   - Features in `Oli.ScopedFeatureFlags.DefinedFeatures` specify a `rollout_mode` metadata field:
     - `:scoped_only` (default): behaves exactly as the current system.
     - `:canary`: participates in staged rollout.

2. **Scoped Enablement**
   - For `:scoped_only` features, project/section entries in `scoped_feature_flag_states` determine access; no canary logic applies.
   - For `:canary` features, a row in `scoped_feature_flag_states` signals that the scope (project or section) is opted into the canary lifecycle. Without the row, the feature is effectively off for that resource.

3. **Runtime Access Check (`can_access?/3`)**
   - Validate scope enablement via existing `enabled?/2`. If not enabled, deny.
   - Resolve rollout stage from the highest-precedence rollout policy: project → section → global default.
   - Evaluate publisher exemptions (see below) before applying stage logic.
   - Apply stage rules:
     - `off`: deny.
     - `internal_only`: allow when `actor.is_internal` true and publisher not exempt.
     - `five_percent` / `fifty_percent`: allow internal users; for others, bucket deterministically using SHA-256 hash of `{feature, actor_type, actor_id}` and compare to stage threshold (5 or 50). Cache cohort outcomes with bounded TTL.
     - `full`: allow unless publisher exemption denies.

4. **Auditing**
   - All enable/disable and stage transitions leverage existing auditing hooks, capturing actor, scope, new state, and optional notes.

## Publisher-Level Exemptions

- Maintain a `scoped_feature_exemptions` table keyed by `{feature_name, publisher_id}` with `effect` values:
  - `:deny`: publisher users never see the feature, regardless of stage (including internal-only).
  - `:force_enable`: publisher users always see the feature when the scope is opted in, regardless of percentage (still respects `off`).
- Exemptions override stage logic but do not bypass scoped enablement (projects/sections must still opt in).
- Admin UI supports:
  - Listing current exemptions per feature.
  - Adding/removing exemptions with confirmation prompts.
  - Displaying status badges when a section/project belongs to an exempt publisher.

## Data Model Updates

- `authors` / `users`: add `is_internal` boolean (default `false`).
- `scoped_feature_rollouts`: store stages (`off`, `internal_only`, `five_percent`, `fifty_percent`, `full`), effective scope (`project`, `section`, `global`), optional schedule metadata, and audit fields.
- `scoped_feature_exemptions`: store per-publisher overrides with timestamps and actor references.

## UI & Workflow Requirements

- **Feature Management UI** (existing LiveView component):
  - Display rollout stage control for `:canary` features (progressive buttons `Off → Internal → 5% → 50% → Full`).
  - Show whether the current project/section is opted in and the inherited global stage.
  - Highlight publisher exemption status with clear messaging.
  - Provide Audit action logs (recent transitions, by whom, when).

- **Publisher Admin**:
  - Add section listing exemptions. This should be visible on the "Publisher" details screen.
  - Allow toggling `deny` / `force_enable` per feature with audit notes.

- **Account Management**:
  - Surfaces `is_internal` in admin forms and supports bulk editing (CSV import optional).

## Technical Considerations

- Deterministic hashing for cohorts must be stable across releases (document hash algorithm/version).
- Deterministic hashing must be stable across 5% and 50% increments. In other words, if a user sees a feature at 5%, they MUST see it at 50%.
- Cache cohort decisions via Cachex or ETS with 1-hour TTL; recompute on cache miss.
- Ensure transitions are monotonic forward by default; demotions require confirmation with reason.
- Telemetry events for access decisions (`feature`, `stage`, `publisher`, `result`) to monitor rollout health.

## Acceptance Criteria

1. A canary-marked feature can be promoted through the defined stages, with internal users gaining access first, followed by fixed 5% and 50% cohorts, culminating in full rollout.
2. Publisher exemptions correctly override stage decisions (deny or force enable) and are visible in the admin UI.
3. Scoped-only features continue to behave exactly as before.
4. Each access check produces consistent results for the same user/feature combination.
5. Audit logs capture all state transitions, scope enablement changes, and exemption edits.

## Open Questions

- Do we need scheduling (time-based) transitions in MVP or manual only?
- Should `force_enable` bypass percentage stages entirely or just guarantee inclusion during percentages?
- What is the minimum latency requirement for updating internal-user flags (e.g., hourly sync vs immediate)?
