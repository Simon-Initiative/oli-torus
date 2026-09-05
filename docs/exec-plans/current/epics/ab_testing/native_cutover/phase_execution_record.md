# Native Cut-Over Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/native_cutover`
Phase: `1-5`

## Scope from plan.md
- Hard cut-over new experiment behavior from UpGrade to native `Oli.Experiments`.
- Remove UpGrade authoring copy/export affordances, runtime assignment/mark/log calls, and active UpGrade config reads.
- Preserve non-migration behavior for legacy UpGrade-backed content.

## Implementation Blocks
- [x] Former `segment.json` and `experiment.json` routes return `410 Gone` and no longer build UpGrade payloads.
- [x] Experiment LiveViews use native-only copy, provider-neutral assigns, and no longer create `upgrade_decision_point` revisions.
- [x] Visible legacy UpGrade-backed groups render read-only with non-migration messaging.
- [x] Delivery alternatives strategy calls `Oli.Experiments.assign_condition/1` and `record_exposure/1`, with first-option fallback for no active native experiment.
- [x] Evaluated-attempt flows no longer schedule `Oli.Delivery.Experiments.LogWorker`.
- [x] UpGrade transport, JSON builders, log worker modules, and active `UPGRADE_EXPERIMENT_*` config reads were removed.

## Decisions
- JSON export handling: retain routes for one release with `410 Gone`.
- Legacy page handling: retain visible native-only/non-migration messaging and read-only legacy groups.
- Runtime module handling: delete old UpGrade transport/builders/worker after active references were removed.
- Operations cleanup order: deploy cut-over code first, remove obsolete UpGrade secrets second.

## Test Blocks
- [x] `mix format` passed.
- [x] `mix compile --warnings-as-errors` passed.
- [x] Reference search for active UpGrade config/env reads passed with no source hits.
- [x] Harness requirements trace and work-item validation passed.
- [x] Targeted ExUnit passed after Postgres.app trust authentication was allowed.
- [x] Broader `mix test` passed.

## Review Loop
- Round 1 findings:
  - Exposure persistence failure could have changed the rendered condition after native assignment.
- Round 1 fixes:
  - Exposure recording failures are now logged and do not override the assigned condition selection.

## Done Definition
- [x] Phase tasks implemented.
- [x] Formatting, compile, requirements trace, and harness validation pass.
- [x] Security/performance/Elixir review pass completed with the finding above fixed.
- [x] DB-backed ExUnit verification completed.
