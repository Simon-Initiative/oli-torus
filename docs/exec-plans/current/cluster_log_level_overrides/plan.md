# Cluster Log Level Overrides - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/cluster_log_level_overrides/prd.md`
- FDD: `docs/exec-plans/current/cluster_log_level_overrides/fdd.md`

## Scope

Implement cluster-aware runtime log override management for `/admin/features` by introducing a backend coordination boundary under `lib/oli/`, moving system-level and module-level override reads and writes behind that service, updating the admin LiveView to render cluster-scoped state and feedback, and adding automated and manual verification for success, partial-failure, and unreachable-node behavior. The plan excludes persistent overrides, per-node management UI, retries, and any coordination beyond the currently connected Torus cluster.

## Clarifications & Default Assumptions

- The authoritative work-item artifacts are `docs/exec-plans/current/cluster_log_level_overrides/prd.md`, `docs/exec-plans/current/cluster_log_level_overrides/fdd.md`, and `docs/exec-plans/current/cluster_log_level_overrides/requirements.yml`.
- The active target set for every operation is the currently connected cluster as seen by the node serving the LiveView request, typically `[node() | Node.list()]`.
- `Oli.RuntimeLogOverrides` is the planned backend boundary and should absorb both existing system-level behavior and the module-level override behavior already introduced for `/admin/features`.
- Cluster state and operation results should be summarized for the UI; a full per-node management table is not required unless implementation reveals that summary-plus-exceptions is insufficient.
- Observability work must be planned explicitly because `harness.yml` marks telemetry as an adopted default, and issue-tracking follow-through should be called out because Jira is the repository system of record.
- Performance work for this slice focuses on bounded synchronous RPC fan-out, timeout handling, and explicit degraded-state reporting rather than new caching or retries.
- Check off the task checkboxes in this plan as implementation progresses so phase status remains accurate.

## Phase 1: Service Boundary And Cluster Coordination

- Goal: Establish the backend runtime override boundary, normalize node-local operations, and implement cluster fan-out plus result aggregation.
- Tasks:
  - [x] Add or extend `Oli.RuntimeLogOverrides` under `lib/oli/` as the single public boundary for system-level and module-level apply, clear, and state-read operations. [FR-001] [FR-002] [FR-003] [FR-004] [FR-008]
  - [x] Move any remaining direct logger mutation logic out of `FeaturesLive` and behind node-local helper functions in the service. [FR-008] [AC-009]
  - [x] Implement safe validation for requested levels and requested modules without creating arbitrary atoms from user input. [FR-002] [FR-004]
  - [x] Implement cluster fan-out using an OTP-native RPC seam, with a bounded timeout and normalized per-node result shaping. [FR-001] [FR-002] [FR-003] [FR-004] [FR-005] [FR-006]
  - [x] Implement aggregate classification as `:success`, `:partial`, or `:failure`, including explicit failed-node or unreachable-node details. [FR-005] [FR-006] [AC-005] [AC-006]
  - [x] Implement cluster-aware state inspection that can summarize uniform versus mixed system-level and module-level overrides across nodes. [FR-007] [AC-008]
  - [x] Add telemetry or structured operational logging for cluster override attempts, node counts, outcome classification, and duration in line with `docs/OPERATIONS.md`. [FR-005]
- Testing Tasks:
  - [x] Add ExUnit coverage for cluster-wide system apply and clear success paths. [AC-001] [AC-003]
  - [x] Add ExUnit coverage for cluster-wide module apply and clear success paths. [AC-002] [AC-004]
  - [x] Add ExUnit coverage for partial-success aggregation, unreachable-node handling, and mixed-state summarization. [AC-005] [AC-006] [AC-008]
  - [x] Add ExUnit coverage for invalid level or module validation and safe input handling.
  - [x] Run targeted backend tests for the runtime override service.
  - Command(s): `mix test test/oli/...runtime_log_overrides*_test.exs`; `mix format`
- Definition of Done:
  - A single backend API owns runtime log override reads, writes, cluster fan-out, and result aggregation.
  - Partial and unreachable-node outcomes are represented explicitly and cannot be misreported as full success.
  - Backend tests cover the core success, failure, and validation paths required by the PRD and FDD.
- Gate:
  - No LiveView integration work should be considered complete until the service contract, timeout behavior, and aggregate result semantics are stable and tested.
- Dependencies:
  - None.
- Parallelizable Work:
  - Service API design, telemetry event shaping, and test-double or RPC seam setup can proceed in parallel once the aggregate result contract is agreed.

## Phase 2: Admin LiveView Integration And Cluster-Aware UX

- Goal: Make `/admin/features` a thin client of the backend boundary and render cluster-scoped controls, state, and operator feedback without regressing authorization or existing admin workflows.
- Tasks:
  - [x] Update `lib/oli_web/live/features/features_live.ex` to load cluster-aware runtime override state from `Oli.RuntimeLogOverrides` during mount. [FR-007] [AC-008]
  - [x] Refactor system-level and module-level event handlers to delegate all apply and clear actions to the backend boundary instead of local logger APIs. [FR-008] [AC-009]
  - [x] Update the page copy to state clearly that override actions are cluster-scoped, runtime-only, and limited to currently connected nodes. [FR-007] [AC-007]
  - [x] Render success, partial, and failure feedback with failed-node or unreachable-node details that operators can act on. [FR-005] [FR-006] [AC-005] [AC-006]
  - [x] Render cluster-aware active state summaries for system-level and module-level overrides, including mixed-state exceptions where nodes disagree. [FR-007] [AC-008]
  - [x] Preserve existing admin-only access assumptions and avoid widening the remote execution surface beyond the constrained runtime override functions.
- Testing Tasks:
  - [x] Add LiveView coverage for cluster-scoped and runtime-only copy on `/admin/features`. [AC-007]
  - [x] Add LiveView coverage for system-level and module-level success, partial-failure, and full-failure feedback. [AC-001] [AC-002] [AC-003] [AC-004] [AC-005] [AC-006]
  - [x] Add LiveView coverage for cluster-aware state rendering in both uniform and mixed-state cases. [AC-008]
  - [x] Add regression coverage proving the LiveView calls the backend boundary rather than mutating Logger state directly. [AC-009]
  - [x] Run the targeted LiveView test module for `/admin/features`.
  - Command(s): `mix test test/oli_web/live/...features*_test.exs`; `mix format`
- Definition of Done:
  - `/admin/features` presents clustered override behavior clearly and safely for operators.
  - The UI no longer treats the local node as authoritative for override state or action results.
  - LiveView tests cover the copy, feedback, state presentation, and service-delegation behavior required by the acceptance criteria.
- Gate:
  - UI signoff requires passing LiveView tests and a manual review that the page messaging makes cluster scope and non-persistence unambiguous.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Copy refinement and render-state formatting can proceed in parallel with event-handler rewiring once the aggregate service result shape is fixed.

## Phase 3: Hardening, Observability, And Operational Readiness

- Goal: Close the cross-cutting operational gaps around telemetry, performance posture, degraded-state handling, and rollout guidance before final verification.
- Tasks:
  - [x] Verify the service emits telemetry or structured logs suitable for AppSignal and operational debugging, including operation type, target node count, success or failure counts, aggregate status, and duration. [FR-005]
  - [x] Confirm timeout behavior and degraded-state messaging remain usable for a small clustered deployment without retries or blocking loops. [FR-006]
  - [x] Review the remote call surface to ensure only predefined runtime override functions are executable and module parsing does not leak atoms or broaden privileges.
  - [x] Capture any Jira or rollout follow-through needed for operator visibility, staging validation, or release notes in line with `docs/ISSUE_TRACKING.md`.
  - [x] Reconcile the work-item artifacts if implementation discoveries require updates to PRD, FDD, or requirements traceability.
- Testing Tasks:
  - [x] Add or finalize automated assertions for telemetry or structured log emission where practical.
  - [x] Run the combined targeted backend and LiveView suites after hardening changes.
  - [x] Run compile and formatting gates on the touched backend surface.
  - Command(s): `mix test test/oli test/oli_web/live`; `mix compile`; `mix format`
- Definition of Done:
  - Observability is explicit enough for operations and aligned with repository guidance.
  - Security-sensitive input and RPC boundaries have been reviewed and constrained as designed.
  - The slice is ready for clustered manual validation without unresolved rollout ambiguity.
- Gate:
  - Final verification should not begin until observability, timeout behavior, and work-item reconciliation are complete.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Jira or rollout follow-through and documentation reconciliation can proceed in parallel with telemetry assertion finishing work once behavior is stable.

## Phase 4: Verification, Proof, And Handoff

- Goal: Prove the implementation against the acceptance criteria and leave the work item ready for review and development completion.
- Tasks:
  - [x] Run the consolidated targeted automated test set for the runtime override service and `/admin/features`.
  - [ ] Perform manual validation on a clustered dev or staging environment covering full success, partial failure, unreachable-node handling, and cluster-aware state refresh after apply and clear actions. [AC-001] [AC-002] [AC-003] [AC-004] [AC-005] [AC-006] [AC-008]
  - [x] Verify the page copy accurately communicates cluster scope, runtime-only behavior, and the limitation that later-joining nodes do not inherit existing overrides. [AC-007]
  - [x] Prepare proof references in tests and implementation notes for each acceptance criterion in `requirements.yml`. [AC-010]
  - [x] Ensure final review preparation includes the required Torus security and performance review lenses for the resulting code changes.
- Testing Tasks:
  - [x] Run requirements and work-item validation commands required by the harness skill.
  - [x] Re-run any focused failing or newly added test modules until the targeted suite is green.
  - [x] Record the exact commands and proof locations needed for handoff.
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/cluster_log_level_overrides --action verify_plan`; `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/cluster_log_level_overrides --action master_validate --stage plan_present`; `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/cluster_log_level_overrides --check plan`
- Definition of Done:
  - Automated coverage and clustered manual validation together demonstrate the required success, degraded, and UI-feedback behaviors.
  - Acceptance-criteria proof is traceable from `requirements.yml` to code and tests.
  - The work item is ready for implementation execution or final review without unresolved planning gaps.
- Gate:
  - Handoff is complete only when harness validation passes and manual cluster validation has been captured or explicitly scheduled.
- Dependencies:
  - Phase 3.
- Parallelizable Work:
  - Proof collection and requirements-trace updates can proceed in parallel with clustered manual validation once the code and automated tests are stable.

## Parallelization Notes

- Phase 1 backend orchestration and Phase 2 render-state exploration can overlap at the contract-definition level, but LiveView mutation wiring should wait until the aggregate result shape is stable.
- Telemetry design should start in Phase 1 so result payloads and timing data do not need a second service refactor in Phase 3.
- Clustered manual validation is intentionally deferred until after automated coverage and degraded-state messaging are stable, because single-node local workflows cannot prove the target behavior.
- Keep the service contract narrow so UI work, observability work, and review-proof collection can proceed independently once the backend API is fixed.

## Phase Gate Summary

- Gate A: `Oli.RuntimeLogOverrides` owns cluster fan-out, validation, aggregate classification, and cluster-state reads, with backend tests proving core success and failure semantics.
- Gate B: `/admin/features` delegates all runtime override work to the backend boundary and renders cluster-scoped copy, feedback, and state correctly.
- Gate C: Observability, timeout behavior, security-sensitive input handling, and rollout or Jira follow-through are complete.
- Gate D: Harness validation, targeted automated tests, and clustered manual verification provide traceable proof for the full work item.
