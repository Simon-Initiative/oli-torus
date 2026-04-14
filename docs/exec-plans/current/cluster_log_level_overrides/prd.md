# Cluster Log Level Overrides - Product Requirements Document

## 1. Overview
Enable authorized administrators to apply and clear runtime log-level overrides across the active Torus cluster from `/admin/features`, with explicit cluster-scope messaging and actionable feedback when one or more nodes fail. This work item covers backend cluster orchestration, cluster-aware override status reporting, and the minimal admin UI changes needed to make clustered behavior understandable and safe to operate.

## 2. Background & Problem Statement
The current admin log-level override behavior is node-local. The LiveView handling `/admin/features` mutates logger state on only the node that receives the event, which means clustered deployments can end up with different runtime log settings on different nodes at the same time.

That inconsistency creates three operational problems:

- operators cannot trust that a requested override applies to the traffic they are investigating
- the UI can imply success even when only one node changed
- debugging and incident response become harder because cluster-wide logging state is not visible or coordinated

The feature needs a coordinated cluster-aware flow without widening scope into persistence, per-node management, or broader remote administration.

## 3. Goals & Non-Goals
### Goals
- Allow an authorized admin to apply system-level and module-level log-level overrides across all currently connected Torus nodes from a single action.
- Allow an authorized admin to clear system-level and module-level log-level overrides across all currently connected Torus nodes from a single action.
- Make cluster scope explicit in the `/admin/features` UI so operators understand the blast radius and the limits of the action.
- Return operation feedback that distinguishes full success, partial success, and failure, including enough node detail for operators to act.
- Show active override state in a cluster-aware way rather than as only the local node's runtime state.
- Keep node-local logger mutation logic encapsulated behind a backend coordination boundary so UI code does not fan out directly to other nodes.

### Non-Goals
- Per-node override management, editing, or retry controls in the admin UI.
- Persistence of overrides across deploys, node restarts, or cluster topology changes.
- Cross-cluster, cross-environment, or external-control-plane coordination.
- Arbitrary execution of remote code outside the constrained runtime-log-override API.
- A redesign of the broader `/admin/features` page beyond the messaging and feedback needed for clustered overrides.

## 4. Users & Use Cases
- System administrator: raises the system log level to `debug` during incident investigation and expects every reachable Torus node in the active cluster to change.
- System administrator: applies a module-level override to isolate behavior in a specific subsystem and needs confidence that the override is consistent across nodes serving that subsystem's traffic.
- System administrator: clears a previously applied override and expects all reachable nodes to return to the default runtime state.
- System administrator: receives partial-failure feedback when one or more nodes cannot be updated and uses the reported node list to continue debugging safely.
- Operator on a clustered environment: inspects the admin UI and can tell that overrides are cluster-scoped, ephemeral, and limited to currently connected nodes.

## 5. UX / UI Requirements
- The `/admin/features` surface must label runtime log override controls and state as cluster-scoped rather than node-local.
- The UI must communicate that apply and clear actions target all currently connected Torus nodes.
- The UI must communicate that overrides are runtime-only and do not persist across restarts or deploys.
- After an apply or clear action, operator feedback must distinguish:
  - full success across all reachable nodes
  - partial success where at least one node succeeded and at least one node failed or was unreachable
  - full failure where no node successfully applied the requested change
- Partial-failure and failure feedback must identify which nodes failed or were unreachable so operators can take follow-up action.
- Active override state shown in the page must summarize cluster-aware state rather than presenting only the local node as authoritative.
- The UX may use aggregated summaries with node lists instead of a full per-node management table, as long as the failed or unreachable nodes are visible in feedback and state reporting.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: cluster fan-out operations must fail safely and must never report full success when one or more target nodes failed or were unreachable.
- Security: only the existing authorized admin path may invoke clustered override operations, and the remote action surface must remain limited to defined runtime log override functions.
- Performance: clustered apply and clear actions should remain synchronous enough for admin use on a normal Torus cluster, while aggregating per-node results without uncontrolled retries or blocking loops.
- Operability: returned status data must be explicit enough for incident response without requiring operators to inspect individual node shells.
- Maintainability: cluster orchestration should remain a thin coordination layer around encapsulated node-local logger mutation logic.
- Accessibility: updated messaging and feedback on `/admin/features` must remain readable and operable within the existing admin LiveView surface.

## 9. Data, Interfaces & Dependencies
- The current `/admin/features` implementation in `lib/oli_web/live/features/features_live.ex` directly mutates system log level through `Logger.configure/1`; this work item should replace direct UI-owned mutation with a backend coordination boundary.
- The implementation likely needs a backend service module, such as a new or expanded `Oli.RuntimeLogOverrides` boundary, to own:
  - apply system-level override on a single node
  - apply module-level override on a single node
  - clear system-level override on a single node
  - clear module-level override on a single node
  - fan out those operations across connected nodes and aggregate per-node results
  - report cluster-aware effective state for UI consumption
- Cluster coordination may use `:erpc` or another OTP-native RPC mechanism that can target the current connected node set and return per-node outcomes.
- The UI should consume aggregated cluster result data and should not issue its own node-by-node fan-out logic.
- Dependencies include Phoenix LiveView for the admin surface, Elixir `Logger` runtime configuration APIs, and the connected Erlang node topology available to the running cluster.
- Because there is no persistence in scope, nodes that join after an override is applied may not inherit the current override; the UI and operator messaging must make that limitation clear.

## 10. Repository & Platform Considerations
- Backend logic belongs under `lib/oli/` as a runtime/operational service boundary, not in the LiveView event handler.
- UI changes belong in the existing admin LiveView surface under `lib/oli_web/live/features/features_live.ex` and related tests.
- This is a Phoenix application running clustered nodes, so the design should prefer OTP-native coordination primitives over custom HTTP callbacks or browser-driven orchestration.
- The current implementation already exposes system log level controls on `/admin/features`; this work item should normalize system-level and module-level override behavior behind one consistent backend boundary.
- Automated verification should primarily use ExUnit for orchestration logic and LiveView tests for UI messaging and operator feedback.
- Manual verification should assume a clustered dev or staging environment because single-node local development cannot fully validate the target behavior.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit operational telemetry or structured logs for clustered override apply and clear attempts, including requested operation type, cluster node count, and aggregated success or failure outcome.
- Track whether admin override actions complete as full success, partial success, or failure so operational regressions can be detected in AppSignal or logs.
- Success for this work item is operational: an admin can reliably use `/admin/features` to change logging across the active cluster without guessing which node handled the request.

## 13. Risks & Mitigations
- Risk: partial cluster failures leave nodes in inconsistent logging states.
  - Mitigation: aggregate per-node results explicitly, surface failed or unreachable nodes in feedback, and never represent partial completion as full success.
- Risk: synchronous cluster fan-out increases admin action latency on larger clusters.
  - Mitigation: keep orchestration thin, bound the RPC surface to required operations only, and report results without adding retry storms or extra UI-driven polling.
- Risk: operators assume overrides persist after restarts or on nodes that join later.
  - Mitigation: state clearly in the UI that overrides are runtime-only, cluster-scoped to currently connected nodes, and non-persistent.
- Risk: implementation spreads logger mutation logic across UI and backend layers.
  - Mitigation: move system-level and module-level mutation into one runtime override boundary consumed by the LiveView.
- Risk: unreachable-node handling is mistaken for success because the request itself returned.
  - Mitigation: treat unreachable nodes as failed targets in result aggregation and in acceptance tests.

## 14. Open Questions & Assumptions
### Open Questions
- Should cluster-aware active-state reporting show only aggregated summaries plus node exceptions, or does the final UX need inline per-node status rows for currently active failures?
- What exact module-level override behaviors already exist outside `FeaturesLive`, and should they be fully migrated into the shared runtime override boundary as part of this work item?
- What timeout and error-shaping behavior is appropriate for RPC calls so the admin action remains usable on slower or partially degraded clusters?

### Assumptions
- Only authorized administrators who can already use `/admin/features` may invoke the clustered override actions.
- The active target set is the current connected Torus cluster known to the node handling the admin request.
- Nodes that are disconnected, unreachable, or join later are out of scope for automatic reconciliation because persistence is explicitly excluded.
- Aggregated feedback plus explicit failed-node details is sufficient unless design review later requires a richer per-node display.
- The existing system log-level buttons on `/admin/features` will remain the entry point, with copy and state adjusted for cluster-aware behavior rather than replaced by a new admin surface.

## 15. QA Plan
- Automated validation:
  - add backend tests covering cluster-wide apply success for system-level and module-level overrides
  - add backend tests covering cluster-wide clear success for system-level and module-level overrides
  - add backend tests covering partial failure and unreachable-node aggregation
  - add LiveView tests covering cluster-scope messaging, success feedback, partial-failure feedback, and safe handling when not all nodes succeed
  - add tests covering cluster-aware active-state presentation in the UI
- Manual validation:
  - verify apply and clear behavior in a clustered dev or staging environment with multiple connected nodes
  - verify that disconnecting or stopping one node produces partial-failure or failure feedback instead of false full success
  - verify the UI copy makes cluster scope and non-persistence explicit
  - verify operators can identify failed or unreachable nodes from the page feedback alone

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
