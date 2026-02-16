# Drift Mapping

Use this matrix to convert implementation drift into spec updates.

## Behavior/Requirements drift

- Signal: business rules, user-visible behavior, or test expectations changed.
- Update:
  - `prd.md`: acceptance criteria, scope, assumptions.
  - `plan.md`: phase-to-AC mapping if changed.

## Interface/API drift

- Signal: endpoint/params/response/events changed.
- Update:
  - `fdd.md`: interfaces/contracts and integration notes.
  - `prd.md`: only if acceptance outcomes changed.

## Data model/migration drift

- Signal: migration added/modified; schema/constraints/indexes changed.
- Update:
  - `fdd.md`: data model, migrations, operational risk.
  - `plan.md`: rollout/backfill steps if needed.

## Execution-order drift

- Signal: phase sequence or dependencies changed during implementation.
- Update:
  - `plan.md`: reordered phases, dependencies, verification steps.

## Security/performance drift

- Signal: authz, rate limiting, caching, performance tradeoffs changed.
- Update:
  - `fdd.md`: risk controls and operational expectations.
  - `prd.md`: only when acceptance criteria explicitly changed.
