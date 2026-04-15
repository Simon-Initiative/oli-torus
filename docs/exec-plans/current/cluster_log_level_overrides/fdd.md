# Cluster Log Level Overrides - Functional Design Document

## 1. Executive Summary
This work introduces a backend coordination boundary for runtime log overrides so `/admin/features` can apply and clear system-level and module-level overrides across the currently connected Torus cluster from a single authorized admin action. The design keeps node-local logger mutation isolated in one service, uses OTP-native RPC fan-out to reach the active node set, and returns aggregated cluster results that the LiveView can present as full success, partial success, or failure with failed-node details.

The simplest adequate approach is to add a new `Oli.RuntimeLogOverrides` service under `lib/oli/` and move all log-override reads and writes behind it. `FeaturesLive` becomes a thin UI client of that boundary: it requests cluster-aware status for initial render, calls backend apply/clear functions from event handlers, and renders cluster-scope messaging and aggregated state instead of treating the local node as authoritative.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` / `AC-001`: support cluster-wide system-level apply from one authorized admin action.
  - `FR-002` / `AC-002`: support cluster-wide module-level apply from one authorized admin action.
  - `FR-003` / `AC-003`: support cluster-wide system-level clear from one authorized admin action.
  - `FR-004` / `AC-004`: support cluster-wide module-level clear from one authorized admin action.
  - `FR-005` / `AC-005`: aggregate node outcomes and classify each operation as success, partial, or failure.
  - `FR-006` / `AC-006`: treat unreachable nodes as failed targets and never report those operations as full success.
  - `FR-007` / `AC-007` / `AC-008`: expose cluster-scoped messaging and cluster-aware active-state reporting in the admin UI.
  - `FR-008` / `AC-009`: keep fan-out and node-local mutation behind a backend coordination boundary.
  - `AC-010`: verification must cover service success paths, failure aggregation, unreachable nodes, and UI feedback.
- Non-functional requirements:
  - Preserve existing admin authorization boundaries.
  - Keep orchestration thin and operationally understandable.
  - Avoid persistence, retries, or control-plane complexity outside the active connected cluster.
  - Emit telemetry or structured operational signals for cluster actions.
- Assumptions:
  - The target node set is `[node() | Node.list()]` as seen by the node serving the LiveView event.
  - No automatic reconciliation is required for nodes that join later or restart after an override is applied.
  - Minimal UI additions for module-level override controls are acceptable because FR-002 and FR-004 require admin-triggered module operations from `/admin/features`.
  - Existing logger APIs (`Logger.configure/1`, `Logger.put_module_level/2`, `Logger.delete_module_level/1`) remain the node-local mutation mechanism.

## 3. Repository Context Summary
- What we know:
  - [`lib/oli_web/live/features/features_live.ex`](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex:1) currently reads `Logger.level()` during mount and directly calls `Logger.configure/1` in the `"logging"` event handler.
  - There is no existing runtime-log-override boundary under `lib/oli/`, and repo search did not find existing module-level override UI or service code.
  - Repo guidance puts operational/domain behavior in `lib/oli/` and keeps LiveViews focused on transport and rendering.
  - The application runs as a clustered Phoenix system, so OTP-native node coordination is the correct integration point.
- Unknowns to confirm:
  - The exact UI affordance preferred for module-level override entry on `/admin/features` if design review wants tighter constraints on the input form.
  - The final RPC timeout value that best fits observed cluster latency in staging.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- Add `Oli.RuntimeLogOverrides` as the public backend boundary for:
  - cluster-wide apply/clear for system and module overrides
  - node-local apply/clear helpers
  - cluster-aware state inspection
  - result normalization and aggregation
  - telemetry emission for admin-triggered operations
- Keep node-local mutation private to the service module through small pure helpers that call the Elixir `Logger` runtime APIs and shape a normalized result.
- Update `OliWeb.Features.FeaturesLive` to:
  - load cluster override state from `Oli.RuntimeLogOverrides.cluster_state/0` during mount
  - call service functions instead of `Logger.configure/1`
  - render cluster-scoped copy, aggregated current state, and action feedback returned by the service
  - add minimal module override controls if absent today
- Keep authorization unchanged by continuing to rely on the existing admin/authenticated LiveView route and mounts.

### 4.2 State & Data Flow
For a mutating admin action:
1. The LiveView receives an authorized `"logging"` or module-override event.
2. The LiveView calls the corresponding `Oli.RuntimeLogOverrides` cluster function.
3. The service computes the active node set from the connected cluster view.
4. The service fans out a constrained remote call to each node using `:erpc`.
5. Each node executes only a defined local override function and returns a normalized node result map.
6. The service aggregates node results into:
   - requested operation metadata
   - target node list and counts
   - per-node results
   - overall status: `:success | :partial | :failure`
   - updated cluster-aware active state snapshot
7. The LiveView converts the aggregate into flash/inline feedback and refreshes assigns from the returned state snapshot.

For state inspection:
1. The LiveView calls `cluster_state/0`.
2. The service fans out state reads to the same node set.
3. The service merges per-node snapshots into a cluster summary that can express uniform state or mixed state.

### 4.3 Lifecycle & Ownership
- `Oli.RuntimeLogOverrides` owns:
  - allowed operations
  - allowed levels
  - module identifier validation and normalization
  - RPC fan-out
  - result aggregation
  - cluster summary derivation
  - telemetry/log emission
- `FeaturesLive` owns:
  - form inputs and event wiring
  - user-facing copy
  - rendering success/partial/failure feedback
  - accessibility of the admin surface
- Logger runtime configuration remains process/node runtime state owned by the BEAM node and is never persisted in the database.

### 4.4 Alternatives Considered
- Keep direct logger mutation in `FeaturesLive` and add ad hoc RPC there.
  - Rejected because it violates FR-008, spreads operational logic into the UI layer, and makes testing/result shaping harder.
- Use `:rpc.multicall` or a custom HTTP callback.
  - Rejected because `:erpc` is the modern OTP-native primitive, keeps the surface internal to the cluster, and avoids extra HTTP endpoints.
- Persist overrides in the database and reconcile on node join.
  - Rejected as explicitly out of scope and operationally more complex than required.

## 5. Interfaces
- Public service API under `Oli.RuntimeLogOverrides`:
  - `cluster_apply_system_level(level, opts \\ []) :: {:ok, aggregate_result} | {:error, aggregate_result}`
  - `cluster_clear_system_level(opts \\ []) :: {:ok, aggregate_result} | {:error, aggregate_result}`
  - `cluster_apply_module_level(module, level, opts \\ []) :: {:ok, aggregate_result} | {:error, aggregate_result}`
  - `cluster_clear_module_level(module, opts \\ []) :: {:ok, aggregate_result} | {:error, aggregate_result}`
  - `cluster_state(opts \\ []) :: cluster_state_summary`
- Private/local helpers:
  - `apply_system_level_local(level) :: node_result`
  - `clear_system_level_local() :: node_result`
  - `apply_module_level_local(module, level) :: node_result`
  - `clear_module_level_local(module) :: node_result`
  - `local_state() :: node_state`
- Aggregate result shape:
  - `operation`: `:apply_system | :clear_system | :apply_module | :clear_module`
  - `requested_level`: log level or `nil`
  - `requested_module`: module or `nil`
  - `target_nodes`: list of nodes
  - `successful_nodes`: list of nodes
  - `failed_nodes`: list of `%{node: node, reason: term()}`
  - `status`: `:success | :partial | :failure`
  - `cluster_state`: normalized post-operation state summary
- Cluster state summary shape:
  - `nodes`: list of `%{node: node, system_level: atom(), module_levels: map()}`
  - `system_level`: `%{status: :uniform | :mixed, level: atom() | nil, exceptions: list()}`
  - `module_levels`: list of `%{module: module(), status: :uniform | :mixed, level: atom() | nil, exceptions: list()}`

## 6. Data Model & Storage
- No database schema changes.
- No persisted config or migration work.
- Runtime state is read from and written to Logger on each node only.
- The service may normalize module names as Elixir module atoms in memory, but must not create atoms from arbitrary user input. Input validation should accept only existing modules via safe conversion such as `Module.safe_concat/1` or equivalent guarded parsing of allowed module names already loaded in the VM.

## 7. Consistency & Transactions
- Cross-node apply/clear operations are best-effort coordinated actions, not distributed transactions.
- Consistency model:
  - success: every targeted node reports success
  - partial: at least one targeted node succeeded and at least one failed/unreachable
  - failure: no targeted node succeeded
- The service must never collapse partial completion into success.
- The authoritative post-action UI state is the aggregated cluster snapshot returned after aggregation, not the initiating node’s local logger state.
- No rollback is attempted on partial success because compensating cluster writes would add more risk and complexity than the PRD allows. Operators instead receive explicit failed-node details.

## 8. Caching Strategy
- No cache layer is needed.
- Cluster state is fetched live for mount and after mutating actions because the surface is operational, low-traffic, and requires accurate runtime visibility.

## 9. Performance & Scalability Posture
- Expected clusters are small enough that synchronous admin fan-out is acceptable.
- The service should issue RPC calls in one bounded pass and aggregate results without retries or polling loops.
- A configurable timeout should be applied per operation so degraded nodes fail fast enough for admin use.
- Payloads remain small because only operation metadata and compact node-state summaries are exchanged.
- If the node count grows materially, the design still degrades predictably: latency is bounded by RPC timeout and the user gets explicit partial/failure status rather than a hanging workflow.

## 10. Failure Modes & Resilience
- Unreachable node:
  - Represent as a failed node in the aggregate result.
  - Classify overall status as partial or failure.
- Logger API error on one node:
  - Capture the error reason in the node result and continue aggregating the other node outcomes.
- Invalid requested log level or module:
  - Reject locally before fan-out and return a validation error to the LiveView.
- State-read RPC failure during mount:
  - Render available cluster status with degraded messaging if partial reads succeed; otherwise render an explicit error state rather than local-only status.
- Post-action snapshot read fails:
  - Return the write result plus a degraded-state indicator so the UI does not overclaim certainty about final cluster state.

## 11. Observability
- Emit telemetry or structured logs for every cluster override action with:
  - operation type
  - requested level/module
  - target node count
  - success count
  - failure count
  - aggregate status
  - duration
- Use AppSignal-compatible structured operational data via the repo’s existing observability posture rather than inventing a new sink.
- Log lines must avoid dumping excessive exception payloads; include node names and summarized reasons.

## 12. Security & Privacy
- No new externally reachable endpoint is introduced.
- Only the already authorized admin LiveView path can trigger operations.
- Remote execution is constrained to predefined service functions; the UI never submits arbitrary MFA tuples or code for remote execution.
- Module parsing must avoid atom leaks and arbitrary module creation from user input.
- No user data, learner data, or institution data is added to the runtime override payloads.

## 13. Testing Strategy
- ExUnit service tests for `Oli.RuntimeLogOverrides`:
  - `AC-001`: cluster-wide system-level apply success.
  - `AC-002`: cluster-wide module-level apply success.
  - `AC-003`: cluster-wide system-level clear success.
  - `AC-004`: cluster-wide module-level clear success.
  - `AC-005`: partial success aggregation with failed-node details.
  - `AC-006`: unreachable-node handling and non-success classification.
  - `AC-008`: mixed cluster-state summarization.
  - local validation failures for invalid level/module input.
- Prefer behavior-focused tests with injectable RPC adapter seams or narrowly scoped test doubles rather than requiring real multi-node CI for every case.
- LiveView tests for [`lib/oli_web/live/features/features_live.ex`](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex:1):
  - `AC-007`: cluster-scoped runtime-only copy is rendered.
  - `AC-005`: partial/failure feedback with failed node details.
  - `AC-008`: cluster-aware current state rendering for uniform and mixed state.
  - `AC-009`: UI event handlers delegate to the service boundary rather than direct Logger mutation.
- Manual validation in clustered dev or staging:
  - apply and clear on multiple connected nodes
  - stop or disconnect one node and verify partial/failure behavior
  - verify nodes joining later do not inherit overrides and that copy makes this explicit

### 13.1 Acceptance Criteria Traceability
- `AC-001`: `cluster_apply_system_level/2` service tests and LiveView success feedback tests verify uniform cluster apply.
- `AC-002`: `cluster_apply_module_level/3` service tests verify module-level fan-out success.
- `AC-003`: `cluster_clear_system_level/1` service tests verify uniform cluster clear.
- `AC-004`: `cluster_clear_module_level/2` service tests verify module-level clear.
- `AC-005`: aggregate-result and LiveView feedback tests verify partial-success classification and failed-node visibility.
- `AC-006`: unreachable-node result tests verify disconnected targets are classified as failures and cannot yield full success.
- `AC-007`: LiveView render tests verify cluster-scoped and runtime-only copy.
- `AC-008`: cluster-state summarization and UI render tests verify mixed-node state is shown as cluster-aware rather than local-authoritative.
- `AC-009`: LiveView tests assert the backend boundary is called and direct logger mutation is not part of UI orchestration.
- `AC-010`: the combined service and LiveView suites above form the required automated verification set.

## 14. Backwards Compatibility
- Single-node environments continue to work; the active node set simply contains one node and aggregate status resolves naturally.
- No persisted behavior changes across deploys or restarts.
- Existing `/admin/features` route and authorization model remain intact.
- Any existing local-only mental model changes only in messaging: the UI now explicitly states cluster scope and runtime-only behavior.

## 15. Risks & Mitigations
- Mixed cluster state may be hard to present clearly: use a summarized uniform/mixed model with exception lists instead of a full per-node control table.
- Module-level UI scope may grow beyond “minimal”: constrain the initial UI to a simple module input plus apply/clear actions and defer richer management controls.
- RPC timeout choice may cause either slow UX or premature failures: make timeout configurable and validate it in staging before rollout.
- Testability of cluster behavior may drift if RPC is hard-coded: keep the RPC interaction behind a small adapter or helper seam inside the service.

## 16. Open Questions & Follow-ups
- Should mixed-state rendering show only exception nodes or all node states inline when a disagreement exists?
- Which modules should be considered valid targets for module-level overrides in the admin UI: any loaded application module, or a narrower allowlist?
- Should telemetry be emitted as first-class events only, or paired with structured info/error logs for easier incident inspection in existing log tooling?

## 17. References
- [`docs/exec-plans/current/cluster_log_level_overrides/prd.md`](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/cluster_log_level_overrides/prd.md:1)
- [`docs/exec-plans/current/cluster_log_level_overrides/requirements.yml`](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/cluster_log_level_overrides/requirements.yml:1)
- [`docs/exec-plans/current/cluster_log_level_overrides/informal.md`](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/cluster_log_level_overrides/informal.md:1)
- [`lib/oli_web/live/features/features_live.ex`](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex:1)
- [`ARCHITECTURE.md`](/Users/eliknebel/Developer/oli-torus/ARCHITECTURE.md:1)
- [`docs/BACKEND.md`](/Users/eliknebel/Developer/oli-torus/docs/BACKEND.md:1)
- [`docs/OPERATIONS.md`](/Users/eliknebel/Developer/oli-torus/docs/OPERATIONS.md:1)
- [`docs/TESTING.md`](/Users/eliknebel/Developer/oli-torus/docs/TESTING.md:1)
