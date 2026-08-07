# Native Cut-Over And UpGrade Removal - Functional Design Document

## 1. Executive Summary
Cut over new A/B testing behavior from UpGrade to the native `Oli.Experiments` domain by removing UpGrade authoring entry points, disabling UpGrade JSON export routes, replacing learner-runtime UpGrade calls with native domain APIs, and removing active UpGrade configuration from native execution paths.

This design is intentionally a hard cut-over. Existing UpGrade-backed experiment revisions, learner assignments, and historical analytics are not migrated into native records. They may remain as historical content/data, but they do not become native experiments and must not be used as a runtime assignment source after cut-over.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: New experiment creation must route to native definitions through `Oli.Experiments`, not `upgrade_decision_point` alternatives revisions or UpGrade import/export JSON.
  - FR-002: Delivery assignment, exposure marking, and reward/outcome logging for native experiments must not call UpGrade HTTP endpoints.
  - FR-003: Existing and in-progress UpGrade definitions, learner assignments, and historical analytics must not be imported or translated into native experiment records.
  - FR-004: UpGrade-specific authoring copy, toggles, and JSON download controls must be removed or replaced with native-only messaging.
  - FR-005: Native A/B testing runtime must not require `UPGRADE_EXPERIMENT_*` credentials or `:upgrade_experiment_provider` configuration.
- Acceptance criteria mapping:
  - AC-001: Sections 4 and 5 route new creation through native authoring APIs only.
  - AC-002: Sections 4, 5, 10, and 13 define removal/proof for `init`, `assign`, `mark`, and `log` UpGrade calls.
  - AC-003: Sections 4, 6, 12, and 14 define the non-migration rule and historical-artifact treatment.
  - AC-004: Sections 4 and 5 remove or disable UpGrade JSON export/import controls and routes.
  - AC-005: Sections 6, 8, 10, and 14 remove active runtime dependence on UpGrade credentials for native behavior.
- Non-functional requirements:
  - Cut-over must avoid split-brain assignment sources. A native experiment is assigned only by `Oli.Experiments`.
  - Removed runtime paths must fail closed and be observable rather than silently falling back to UpGrade.
  - Learner-facing alternatives fallback must remain stable when no active native experiment applies.
  - Security review must confirm no obsolete UpGrade secrets are needed or exposed by native runtime paths.
  - Performance review must focus on the native replacement paths, not on preserving UpGrade call latency.
- Assumptions:
  - `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md` is the source of truth for native domain ownership and `Oli.Experiments` API shape.
  - Native delivery runtime replacement may be implemented in the adjacent delivery-runtime slice, but this cut-over work owns removing the UpGrade paths and preventing new UpGrade-backed behavior.
  - Existing `has_experiments` project and section booleans may remain during transition as coarse native gates, but they must no longer mean "call UpGrade".
  - Existing alternatives revisions with content strategy `"upgrade_decision_point"` are legacy artifacts after cut-over.

## 3. Repository Context Summary
- What we know:
  - Current UpGrade runtime is concentrated in `lib/oli/delivery/experiments.ex`, which calls `/api/init`, `/api/assign`, `/api/v1/mark`, and `/api/log`.
  - `lib/oli/resources/alternatives/decision_point_strategy.ex` currently calls `Oli.Delivery.Experiments.enroll/3` and caches the selected condition in section extrinsic state.
  - `lib/oli/delivery/experiments/log_worker.ex` schedules UpGrade correctness logs from evaluated activity attempts.
  - `lib/oli/delivery/experiments/experiment_builder.ex` and `lib/oli/delivery/experiments/segment_builder.ex` generate UpGrade import JSON.
  - `lib/oli_web/controllers/experiment_controller.ex` exposes JSON download endpoints.
  - `lib/oli_web/live/experiments/experiments_live.ex` and `lib/oli_web/live/workspaces/course_author/experiments_live.ex` expose UpGrade copy, enablement toggles, alternatives editing, and JSON download buttons.
  - `Oli.Authoring.Experiments.get_latest_experiment/1` locates alternatives revisions whose content strategy is `"upgrade_decision_point"`.
  - Runtime config currently reads `UPGRADE_EXPERIMENT_PROVIDER_URL`, `UPGRADE_EXPERIMENT_USER_URL`, and `UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN` into `:upgrade_experiment_provider`.
- Unknowns to confirm:
  - Whether legacy UpGrade authoring pages should be removed from navigation entirely or retained as a read-only historical notice for projects that already contain legacy revisions.
  - Whether obsolete `UPGRADE_EXPERIMENT_*` environment variables should be removed from all deployment manifests in this slice or staged by operations after code no longer reads them.
  - Whether `Oli.Delivery.Experiments` should be deleted immediately or left as a deprecated module that raises for any attempted runtime call until downstream references are gone.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` is the only native A/B testing domain boundary for new behavior. Delivery, authoring, and analytics callers must use its public APIs and must not call `Oli.Delivery.Experiments`, UpGrade JSON builders, or UpGrade controller routes.

Authoring cut-over:
- Replace the UpGrade enable/toggle flow in both experiment LiveViews with a native entry point that calls the authoring APIs defined by `Oli.Experiments`.
- Stop creating alternatives revisions with content strategy `"upgrade_decision_point"` for new experiments.
- Remove the visible UpGrade login/link copy and JSON download buttons.
- For legacy UpGrade-backed revisions discovered by `Oli.Authoring.Experiments.get_latest_experiment/1`, render only historical/non-migration messaging or hide them from the native workflow. Do not offer conversion, import, export, or activation.
- Remove or disable `ExperimentController` download actions and router routes for `segment.json` and `experiment.json`. If retained temporarily, they must return a 410-style response and must not call the builders.

Runtime cut-over:
- Replace `Oli.Resources.Alternatives.DecisionPointStrategy` calls to `Oli.Delivery.Experiments.enroll/3` with `Oli.Experiments.assign_condition/1` and exposure recording according to the domain contract.
- Stop using UpGrade-specific section extrinsic state as the authoritative sticky assignment store for native experiments. Native assignments in experiment-owned tables are authoritative.
- Preserve first-option fallback when `Oli.Experiments` returns no active native experiment, inactive experiment, or a controlled fallback response.
- Replace `Oli.Delivery.Experiments.LogWorker.maybe_schedule/3` usage in evaluated attempt flows with native reward/outcome recording from `Oli.Experiments`, or remove scheduling until the delivery-runtime reward handoff is in place.
- Remove HTTP transport functions for UpGrade init/assign/mark/log from active runtime code.

Configuration cut-over:
- Remove `:upgrade_experiment_provider` from runtime decisions and native enablement checks.
- Remove `UPGRADE_EXPERIMENT_*` from active deployment configuration once code references are gone.
- Keep any operations cleanup explicit in deployment notes so removing secrets does not surprise environments still running pre-cut-over code.

### 4.2 State & Data Flow
New native authoring flow:
1. Author opens the A/B testing surface.
2. The UI displays native A/B testing controls or links to the native lifecycle flow.
3. Creating a new experiment calls `Oli.Experiments.create_experiment/1` with project scope, alternatives decision-point identity, conditions, and policy configuration.
4. The result is a native experiment definition owned by `Oli.Experiments`.
5. Legacy UpGrade revisions are not queried as candidates for native creation and are not copied into native tables.

Native delivery flow:
1. Alternatives rendering builds an `AssignConditionRequest` from section, publication, enrollment, user, alternatives group, and available conditions.
2. `Oli.Experiments.assign_condition/1` returns a sticky native decision, `:no_experiment`, or a scoped error.
3. Delivery renders the selected condition, or renders first-option fallback when no active native experiment applies.
4. Delivery records exposure through `Oli.Experiments.record_exposure/1` only after the assigned content is applied.
5. Evaluated attempts record native outcomes/rewards through `Oli.Experiments` without scheduling UpGrade log jobs.

Legacy UpGrade data flow:
1. Existing UpGrade-backed alternatives revisions may remain in resource history.
2. Existing UpGrade assignments and analytics remain outside Torus native persistence.
3. No backfill job, import job, or one-time migration reads UpGrade and writes native experiment records.

### 4.3 Lifecycle & Ownership
`Oli.Experiments` owns native experiment definitions, lifecycle state, assignments, exposures, outcomes, rewards, and policy state. `Oli.Delivery.Experiments` no longer owns runtime behavior after cut-over.

The legacy `has_experiments` fields may be reused as coarse project/section native gates only if renamed or documented in implementation as provider-neutral. If they remain named `has_experiments`, code should avoid variable names such as `is_upgrade_enabled` and avoid deriving external-provider availability from those flags.

Legacy UpGrade experiment content remains historical. It should not be activated, edited as a native experiment, assigned to new native participants, or used to seed native condition weights.

### 4.4 Alternatives Considered
- Migrate existing UpGrade definitions and assignments into native records: rejected because the PRD explicitly requires no migration and fresh native participants.
- Keep UpGrade as a fallback provider when native assignment fails: rejected because it creates split-brain assignment sources and violates FR-002.
- Hide only the UI while leaving JSON builders and routes available: rejected because hidden routes would continue supporting new UpGrade-backed workflows.
- Keep `Oli.Delivery.Experiments` as a provider adapter behind `Oli.Experiments`: rejected for post-cut-over runtime because native behavior must not call UpGrade. A short-lived deprecated module may remain only to fail closed while references are removed.
- Add a feature flag for cut-over: rejected for this work item because `harness.yml` defaults feature flags to excluded and the PRD states no feature flags are present. Normal deployment sequencing is the rollout mechanism.

## 5. Interfaces
- Native authoring interface:
  - `Oli.Experiments.create_experiment/1`, `update_experiment/2`, and lifecycle APIs from the domain contract.
  - LiveViews pass project/author scope and native decision-point/condition data to those APIs.
- Native delivery interface:
  - `Oli.Experiments.assign_condition/1` replaces `Oli.Delivery.Experiments.enroll/3`.
  - `Oli.Experiments.record_exposure/1` replaces UpGrade `mark/2`.
  - `Oli.Experiments.record_outcome/1` or `record_reward/1` replaces UpGrade `log/3`.
- Removed or disabled UpGrade interfaces:
  - `Oli.Delivery.Experiments.init/2`, `assign/1`, `mark/2`, `log/3`, and `enroll/3`.
  - `Oli.Delivery.Experiments.ExperimentBuilder.build/1`.
  - `Oli.Delivery.Experiments.SegmentBuilder.build/1`.
  - `OliWeb.ExperimentController.experiment_download/2` and `segment_download/2`.
  - Router routes for `/:project_id/experiments/segment.json` and `/:project_id/experiments/experiment.json`.
- UI contract:
  - UpGrade names, login links, "Enable A/B testing with UpGrade", "Download Segment JSON", and "Download Experiment JSON" are removed from native workflows.
  - Any legacy notice must state that old UpGrade experiments and learner assignments are not imported into native A/B testing.
- Configuration contract:
  - Native A/B testing does not read `:upgrade_experiment_provider`.
  - Native A/B testing does not require `UPGRADE_EXPERIMENT_PROVIDER_URL`, `UPGRADE_EXPERIMENT_USER_URL`, or `UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN`.

## 6. Data Model & Storage
- No migration copies UpGrade definitions, assignments, segments, metrics, or historical analytics into native tables.
- Native records use the `experiment_*` tables defined by the domain contract.
- Existing `has_experiments` columns on projects and sections may remain for compatibility during implementation, but new code must treat them as provider-neutral gates or replace them in the authoring lifecycle slice.
- Existing alternatives revisions with `"strategy": "upgrade_decision_point"` remain in resource history and working publications unless a separate cleanup task removes or archives them. They are not native experiment definitions.
- Existing section extrinsic state values written for alternatives preferences remain historical cache data. Native assignment must read native assignment records instead of trusting legacy UpGrade-cached condition values.
- If implementation removes obsolete modules/routes, no database storage change is required for UpGrade removal itself.

## 7. Consistency & Transactions
- New native experiment creation must be persisted through `Oli.Experiments` transactions so definitions, decision points, conditions, and policy config are consistent.
- Delivery assignment and exposure consistency are owned by `Oli.Experiments` as defined in the domain contract; the cut-over must not add a second persistence path.
- Do not dual-write assignment, mark, or reward data to UpGrade and native tables.
- Do not read UpGrade state to decide native assignment.
- If a legacy route or module remains during transition, it must fail closed before side effects. It must not generate export JSON or make external HTTP requests.
- Removing UpGrade log scheduling from evaluation flows must not rollback or affect normal evaluation persistence.

## 8. Caching Strategy
- Native sticky assignment must come from experiment-owned assignment records, not section extrinsic state written by the old UpGrade path.
- Existing UpGrade-cached alternatives preferences may remain unread or be ignored for native experiments.
- No additional cross-request cache is required for cut-over.
- If active native experiment definitions are cached by later runtime work, cache invalidation belongs to `Oli.Experiments` lifecycle transitions and must not depend on UpGrade configuration.

## 9. Performance & Scalability Posture
- Removing UpGrade HTTP calls should reduce external latency and eliminate remote-provider availability from learner delivery.
- Native assignment remains on the delivery hot path, so performance proof should focus on indexed native lookups and sticky assignment reuse from `Oli.Experiments`.
- Removing UpGrade log jobs reduces Oban work tied to external logging; native reward processing may still use Oban if the delivery-runtime slice selects asynchronous reward handoff.
- UI removal has negligible performance impact.
- Performance review should verify no remaining runtime branch performs HTTP calls to UpGrade and no native flow blocks on obsolete credential lookup.

## 10. Failure Modes & Resilience
- Legacy UpGrade route requested after cut-over: return a clear removed/disabled response, such as 410 Gone or an authorization-safe not-found response, and log a bounded operational event.
- Native assignment returns no active experiment: delivery uses first-option fallback.
- Native assignment returns invalid scope or condition mismatch: delivery uses controlled fallback where learner continuity is required and telemetry records the error type.
- Legacy `Oli.Delivery.Experiments` function accidentally called: fail closed with an explicit error and AppSignal/telemetry capture during transition, or remove the module so compile/test failures expose references.
- Missing UpGrade environment variables: native behavior continues normally.
- Existing UpGrade-backed project opened by an author: UI does not offer migration or JSON export; it displays native-only/historical messaging if product chooses to keep a visible notice.
- Reward handoff fails after evaluation: evaluation result remains persisted; native reward retry/error behavior follows the delivery-runtime design and must not call UpGrade.

## 11. Observability
- Emit or preserve native telemetry from `Oli.Experiments` for assignment, fallback, exposure, reward/outcome recording, and policy errors as defined in the domain contract.
- Add a bounded telemetry/log event for any attempted access to removed UpGrade export routes or deprecated UpGrade runtime functions during the transition window.
- AppSignal should surface native assignment/reward failures and any unexpected deprecated UpGrade calls.
- Success metrics:
  - Zero runtime HTTP calls to UpGrade from native experiment assignment, exposure, and reward paths.
  - Zero successful UpGrade JSON exports from native authoring surfaces.
  - Native assignment/exposure/reward events are visible through `Oli.Experiments` telemetry.
  - Native runtime works with `UPGRADE_EXPERIMENT_*` unset.
- Logs must not include learner names, LMS identifiers, API tokens, raw activity responses, or exported experiment payloads.

## 12. Security & Privacy
- Removing UpGrade runtime calls reduces exposure of external-provider credentials and learner assignment data.
- Native APIs must continue to enforce project, section, publication, user, enrollment, and institution scope before creating assignments or recording outcomes.
- Legacy JSON export routes must not leak project experiment structure after cut-over.
- Obsolete `UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN` must not be required by native behavior and should be removed from active secret configuration after rollout.
- Non-migration avoids copying historical UpGrade learner assignment or analytics data into new native tables without an explicit data-governance review.
- Any legacy notice must avoid exposing operational details or external credentials.

## 13. Testing Strategy
- Static/reference tests:
  - Test that `Oli.Delivery.Experiments` HTTP calls are no longer reachable from native delivery paths, or remove the module and rely on compile failures for stale references.
  - Test that `Oli.Delivery.Experiments.ExperimentBuilder` and `SegmentBuilder` are deleted or no longer called by routes/controllers.
  - Test that runtime does not require `:upgrade_experiment_provider` for native experiments.
- LiveView/controller tests:
  - Verify both experiment LiveViews no longer render UpGrade copy, login link, enable-UpGrade label, or JSON download buttons.
  - Verify new experiment creation routes through native authoring APIs.
  - Verify legacy UpGrade-backed projects show no migration/import/export affordance.
  - Verify former JSON download routes are removed or return the selected disabled response.
- Delivery/runtime tests:
  - Verify alternatives decision-point selection calls `Oli.Experiments.assign_condition/1` and never `Oli.Delivery.Experiments.enroll/3`.
  - Verify exposure recording uses native APIs rather than UpGrade `mark/2`.
  - Verify evaluated attempt flows do not schedule UpGrade log jobs and route reward/outcome handoff through native APIs or do nothing until the delivery-runtime handoff lands.
  - Verify first-option fallback when no active native experiment applies.
- Scenario tests:
  - Add `Oli.Scenarios` coverage when implementation spans authoring, publication, section delivery, enrollment, and learner attempts.
  - Cover native-only creation, publish/delivery assignment, and no-UpGrade-call proof through observable behavior or test doubles.
- Security and performance review:
  - Search for remaining `upgrade_experiment_provider`, `UPGRADE_EXPERIMENT`, `Oli.Delivery.Experiments`, `ExperimentBuilder`, and `SegmentBuilder` references.
  - Run targeted ExUnit/LiveView tests and `mix format`.
- Harness validation:
  - Run requirements trace verification and FDD validation after doc updates.

## 14. Backwards Compatibility
- Backwards compatibility is intentionally limited. Existing UpGrade experiments are not migrated and do not keep runtime compatibility after cut-over.
- Historical project content and database rows may remain readable as ordinary Torus resource history, but they are not native experiment sources.
- New native experiments start with new native participants; existing UpGrade learner assignments are ignored.
- Removing JSON export/import workflows is a deliberate breaking change for UpGrade-backed authoring.
- Existing sections that previously relied on UpGrade should not silently continue experimenting through UpGrade. They should either use native experiments or fall back according to native delivery behavior.
- Deployment should remove obsolete credentials only after the cut-over code is deployed to avoid breaking older running releases.

## 15. Risks & Mitigations
- Risk: Hidden UpGrade call sites remain in delivery. Mitigation: remove or deprecate `Oli.Delivery.Experiments`, search all references, and add tests around alternatives selection and evaluated attempt flows.
- Risk: Authors expect existing UpGrade experiments to become native. Mitigation: use explicit native-only/non-migration messaging and avoid import or conversion affordances.
- Risk: Legacy extrinsic state biases native assignment. Mitigation: native assignment reads experiment-owned records and ignores UpGrade-cached preferences.
- Risk: Removing config breaks an older deployed release. Mitigation: stage secret cleanup after code rollout and document the deployment ordering.
- Risk: Native authoring is exposed before native runtime is ready. Mitigation: gate new native creation on `Oli.Experiments` API readiness and coordinate with delivery-runtime acceptance tests.
- Risk: Route removal breaks bookmarked JSON URLs. Mitigation: return a clear disabled response during one release if product wants a softer operational transition.

## 16. Open Questions & Follow-ups
- Confirm whether legacy UpGrade experiment pages should be hidden entirely or retained with read-only native-only/non-migration messaging.
- Confirm whether `Oli.Delivery.Experiments` should be deleted in the cut-over PR or temporarily left as a fail-closed deprecated module to expose unexpected calls in production telemetry.
- Confirm the exact disabled response for former JSON export routes: route removal, 404, or 410 Gone.
- Confirm the operations owner and deployment step for removing `UPGRADE_EXPERIMENT_*` secrets from active environments.
- Follow-up with the authoring-lifecycle slice to replace any remaining provider-neutral `has_experiments` UX with native lifecycle language and controls.

## 17. References
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/PRODUCT_SENSE.md`
- `docs/STACK.md`
- `docs/TESTING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/prd.md`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/prd.md`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/requirements.yml`
- `lib/oli/authoring/experiments.ex`
- `lib/oli/delivery/experiments.ex`
- `lib/oli/delivery/experiments/log_worker.ex`
- `lib/oli/delivery/experiments/experiment_builder.ex`
- `lib/oli/delivery/experiments/segment_builder.ex`
- `lib/oli/resources/alternatives/decision_point_strategy.ex`
- `lib/oli_web/controllers/experiment_controller.ex`
- `lib/oli_web/live/experiments/experiments_live.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
- `config/config.exs`
- `config/runtime.exs`
