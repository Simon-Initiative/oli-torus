# Module-Level Log Controls - Functional Design Document

## 1. Executive Summary

Extend the existing admin feature page at `/admin/features` to support two new local-node operational controls: module-level log overrides and process-level log overrides. The implementation should add a narrow backend service responsible for validating targets, applying overrides through Elixir Logger, clearing overrides, and reporting active local override state back to the LiveView. The design intentionally avoids persistence, cross-node coordination, and generalized runtime code execution. This design satisfies [AC-001](#ac-001) [AC-002](#ac-002) [AC-003](#ac-003) [AC-004](#ac-004) [AC-005](#ac-005) [AC-006](#ac-006) [AC-007](#ac-007) [AC-008](#ac-008) and [AC-009](#ac-009).

## 2. Requirements & Assumptions

- Functional requirements:
  - Add an admin workflow to set and clear a module-level Logger override for a validated Elixir module on the current node. [AC-001](#ac-001) [AC-002](#ac-002) [AC-006](#ac-006)
  - Add an admin workflow to set a process-level Logger override for an existing local process identified by PID or registered name. [AC-007](#ac-007)
  - Reject unauthorized actions, invalid modules, invalid levels, and unresolved process targets without mutating Logger configuration. [AC-003](#ac-003) [AC-004](#ac-004) [AC-008](#ac-008)
  - Show current override state or action confirmation in the admin UI. [AC-005](#ac-005)
  - Clearly separate process-level controls from module-level controls and label process targeting as local-node and existing-process only. [AC-009](#ac-009)
- Non-functional requirements:
  - Keep blast radius local to the handling node and do not introduce persistence or cluster synchronization.
  - Keep the design operationally explicit, testable, and safe for production use.
  - Preserve the current global log-level control behavior on the same page.
- Assumptions:
  - The current `FeaturesLive` authorization is sufficient for these controls.
  - Node-local behavior is acceptable because the existing global log-level control is already node-local.
  - Operators can provide valid module names, registered names, or PIDs for processes that already exist.
  - A small amount of ephemeral in-memory state may be tracked for UI display without needing durability across restart.

## 3. Repository Context Summary

- What we know:
  - The current admin page is [lib/oli_web/live/features/features_live.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex) and already exposes a global Logger level control through `Logger.configure/1`.
  - The route already exists at [lib/oli_web/router.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/router.ex) and should not need a new entry point.
  - Torus runs many long-lived OTP processes and multiple Oban workers, making process-level targeting useful for live debugging of a single execution path.
  - No existing repository abstraction for runtime log overrides was found, so a new small backend module is warranted.
- Unknowns to confirm:
  - The cleanest implementation for clearing a process-level override in the targeted process context.
  - Whether any existing admin audit mechanism should be reused directly or if normal Logger output plus flash feedback is sufficient for first delivery.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `OliWeb.Features.FeaturesLive` remains the sole admin UI surface.
  - Add a module override form and an advanced process override form.
  - Render current local override state and action feedback.
  - Delegate validation and mutation to a backend service rather than calling Logger APIs inline.
- New backend service module, proposed as `Oli.RuntimeLogOverrides`.
  - Validate module identifiers and log levels.
  - Resolve process targets from PID strings or registered names.
  - Apply module-level overrides through `Logger.put_module_level/2`.
  - Apply process-level overrides by executing `Logger.put_process_level(self(), level)` inside the target process context.
  - Clear module and process overrides through the same service.
  - Maintain an in-memory registry of overrides applied through the admin UI for display and clear actions.
- Target process adapter behavior:
  - For live processes, perform a synchronous call into the target process when possible.
  - Preferred first mechanism: `:sys.replace_state/2` is not appropriate because Logger state is outside process state.
  - Practical mechanism: use `:erpc.call(node(pid), Kernel, :send, ...)` is also insufficient because Logger must be called from the target process itself.
  - Design choice: install a tiny helper message contract via `:erlang.trace` or generic message injection is too invasive.
  - Simpler adequate design: support process-level override only for processes implementing a new optional helper message contract is not acceptable because the PRD requires general existing-process support.
  - Therefore the service should use `Process.info(pid, :dictionary)` only for inspection, but actual mutation must be done by executing code in the target process. The simplest safe cross-process technique available in BEAM is `:rpc` to node, not process. Since Logger only accepts `self()`, generic process-level override across arbitrary existing processes is not directly available through a clean public API.
  - Architectural conclusion: process-level support should target registered local processes under Torus control that can be extended to handle a standard control message, plus explicit PID entry for those same compatible processes. The first implementation should wire this support for `GenServer`-based Torus processes where a control hook can be added safely.

### 4.2 State & Data Flow

- Module override set flow:
  - Admin submits module name and level in `FeaturesLive`.
  - LiveView calls `Oli.RuntimeLogOverrides.set_module_level/2`.
  - Service validates module string, converts to existing module atom, validates level, calls `Logger.put_module_level(module, level)`, records the override in ETS or Agent state, and returns the updated local override list.
  - LiveView updates assigns and shows confirmation. [AC-001](#ac-001) [AC-002](#ac-002) [AC-005](#ac-005)
- Module override clear flow:
  - Admin selects an active module override and clears it.
  - LiveView calls `Oli.RuntimeLogOverrides.clear_module_level/1`.
  - Service removes the Logger override by restoring `:none` or the Logger default mechanism and removes the local tracking entry.
  - LiveView refreshes state and shows confirmation. [AC-006](#ac-006)
- Process override set flow:
  - Admin submits either a PID string or registered name plus a level.
  - LiveView calls `Oli.RuntimeLogOverrides.set_process_level/2`.
  - Service resolves the process target, verifies compatibility with the control contract, sends a synchronous control message into the process, the process executes `Logger.put_process_level(self(), level)`, acknowledges success, and the service records the active override in local state.
  - LiveView updates assigns and shows confirmation. [AC-007](#ac-007) [AC-005](#ac-005)
- Process override clear flow:
  - Admin clears an active process override.
  - Service sends the same control message with `:none` and removes the local tracking entry after acknowledgement.
- Page load flow:
  - On mount, `FeaturesLive` loads current global level and local active override state from `Oli.RuntimeLogOverrides.list_overrides/0`.
  - Because overrides are node-local and in-memory, only overrides applied on the current node since boot will be displayed.

### 4.3 Lifecycle & Ownership

- `FeaturesLive` owns UI rendering, forms, flash messages, and page-level state.
- `Oli.RuntimeLogOverrides` owns validation, Logger API calls, target resolution, and local active override tracking.
- A small supervised process should own the active override registry.
  - Preferred implementation: a named GenServer backed by a simple map keyed by `{:module, module}` and `{:process, pid_or_name}`.
  - This process is local to the node and started under [lib/oli/application.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/application.ex).
- Compatible target processes own their own process-level Logger mutation by handling a standard control message such as `{:runtime_log_override, ref, level, from}` and replying after calling `Logger.put_process_level(self(), level)`.
- Long-lived Torus-managed `GenServer` processes and selected worker processes are the intended process-level targets in the first implementation. Arbitrary foreign PIDs are out of scope if they do not support the control contract, even if the UI accepts PID input.

### 4.4 Alternatives Considered

- Directly call Logger APIs from `FeaturesLive`.
  - Rejected because validation, state tracking, and process target handling would become tangled in UI code.
- Persist overrides in the database.
  - Rejected because PRD explicitly scopes overrides to runtime-local behavior until cleared or restart.
- Implement arbitrary PID-level mutation for any process in the VM.
  - Rejected as a general mechanism because Elixir `Logger.put_process_level/2` only accepts `self()`, so safe mutation requires code running in the target process. A helper message contract is the simplest adequate design.
- Add cluster-wide propagation.
  - Rejected because the PRD fixes scope to local-node behavior.

## 5. Interfaces

- `Oli.RuntimeLogOverrides.list_overrides/0 :: %{modules: list(map), processes: list(map)}}`
  - Returns current local tracked override state for UI rendering. [AC-005](#ac-005)
- `Oli.RuntimeLogOverrides.set_module_level(module_name, level) :: {:ok, state} | {:error, reason}`
  - Validates module name and level, applies `Logger.put_module_level/2`, records state. [AC-001](#ac-001) [AC-004](#ac-004)
- `Oli.RuntimeLogOverrides.clear_module_level(module_name) :: {:ok, state} | {:error, reason}`
  - Clears a tracked module override. [AC-006](#ac-006)
- `Oli.RuntimeLogOverrides.set_process_level(target, level) :: {:ok, state} | {:error, reason}`
  - Resolves PID string or registered name, verifies compatibility, requests in-process mutation, records state. [AC-007](#ac-007) [AC-008](#ac-008)
- `Oli.RuntimeLogOverrides.clear_process_level(target) :: {:ok, state} | {:error, reason}`
  - Requests in-process reset to `:none` and removes tracked state.
- Optional behavior for compatible target processes:
  - `handle_call({:runtime_log_override, level}, from, state)` or equivalent helper function to run `Logger.put_process_level(self(), level)` and reply.
- `FeaturesLive` events:
  - `"set_module_log_level"`
  - `"clear_module_log_level"`
  - `"set_process_log_level"`
  - `"clear_process_log_level"`

## 6. Data Model & Storage

- No database schema changes.
- Add a supervised in-memory registry process.
- Proposed registry entry shapes:
  - Module entry: `%{type: :module, target: Oli.Some.Module, target_label: "Oli.Some.Module", level: :debug, updated_at: DateTime.t()}`
  - Process entry: `%{type: :process, target: pid(), target_label: "#PID<...>" | "RegisteredName", level: :debug, compatibility: :supported, updated_at: DateTime.t()}`
- Registry contents are advisory UI state, not the source of truth for Logger internals.
- On node restart the registry is empty and all overrides are lost by design.

## 7. Consistency & Transactions

- No database transactions are required.
- Each override mutation is a single local runtime action plus a local registry update.
- Service ordering:
  - Validate input.
  - Apply Logger mutation.
  - Update registry only after successful Logger mutation.
- Clear ordering:
  - Request reset in Logger.
  - Remove registry entry only after successful acknowledgement.
- If registry update fails after Logger mutation, return an error and log it loudly; the operator can refresh or retry. This mismatch should be rare and visible.

## 8. Caching Strategy

- N/A

## 9. Performance & Scalability Posture

- Override operations are low-frequency admin actions and should have negligible throughput impact.
- The main performance risk is induced log volume, not the control path itself.
- UI reads from a small in-memory registry and should remain constant-time at practical scale.
- The design avoids cluster fan-out, database writes, and broad runtime scans.

## 10. Failure Modes & Resilience

- Invalid module string:
  - Reject with a specific error and do not mutate Logger. [AC-004](#ac-004)
- Invalid level:
  - Reject with a specific error and do not mutate Logger. [AC-004](#ac-004)
- Unauthorized user:
  - Existing admin authorization blocks page access and any event path should still guard server-side mutations. [AC-003](#ac-003)
- Unresolved PID or registered name:
  - Reject with a specific error and do not mutate Logger. [AC-008](#ac-008)
- Resolved process lacks the control contract:
  - Reject with `:unsupported_process_target` and explain that only compatible local processes can be targeted safely in this implementation.
- Target process exits before applying the override:
  - Return failure, do not add a registry entry.
- Node restart:
  - Overrides disappear and UI state resets. This is expected by design.

## 11. Observability

- Emit Logger info or notice entries when an admin sets or clears module and process overrides, including admin identifier, target, level, and node.
- Emit warning entries for invalid target attempts and unsupported process targets.
- Reuse normal flash feedback in the LiveView for immediate operator confirmation. [AC-005](#ac-005)
- If an existing audit log mechanism can be reused without significant coupling, record admin override actions there as well; otherwise rely on detailed Logger entries plus UI flash messages for first delivery.
- No new telemetry events are required for first delivery.

## 12. Security & Privacy

- Restrict access to existing Torus admin-only authorization boundaries. [AC-003](#ac-003)
- Never evaluate arbitrary code or dynamically create atoms from untrusted strings without safeguards.
  - Module parsing should accept only existing loaded modules and use `String.to_existing_atom/1` on validated `Elixir.*` names.
  - Registered-name resolution should only allow existing local atom names and should not create new atoms from user input.
- Process-level targeting must remain local-node only and should not expose process internals beyond minimal target identity needed for debugging. [AC-009](#ac-009)

## 13. Testing Strategy

- Backend unit tests for `Oli.RuntimeLogOverrides`:
  - Valid module set path. [AC-001](#ac-001)
  - Module override does not change global Logger level. [AC-002](#ac-002)
  - Invalid module and invalid level rejection. [AC-004](#ac-004)
  - Module clear path. [AC-006](#ac-006)
  - Valid process resolution by PID string and registered name. [AC-007](#ac-007)
  - Invalid and unsupported process target rejection. [AC-008](#ac-008)
- LiveView tests for `FeaturesLive`:
  - Admin sees the new forms and active override state. [AC-005](#ac-005)
  - Non-admin cannot invoke the control surface. [AC-003](#ac-003)
  - Process control UI is visually and textually separated from module control. [AC-009](#ac-009)
- Integration-style tests with a small compatible test GenServer:
  - Apply and clear process-level override through the service.
  - Confirm the target process acknowledges mutation and the registry reflects the change.
- Regression tests:
  - Existing global log-level control continues to function unchanged.

## 14. Backwards Compatibility

- Existing `/admin/features` behavior remains intact.
- Existing global Logger level controls remain unchanged.
- No schema, API, or route migrations are introduced.
- The page gains new controls, but all changes are additive.

## 15. Risks & Mitigations

- Generic process-level control is not possible for arbitrary PIDs through a pure external call path: mitigate by formalizing a supported-process control contract and documenting the boundary clearly.
- Operators may expect process overrides to survive restart: mitigate with explicit local runtime messaging in the UI.
- The admin page may become crowded: mitigate by grouping controls into distinct sections with concise explanatory copy.
- Registry state could drift from actual Logger state after process exit or crash: mitigate by pruning dead process entries on read and on clear attempts.

## 16. Open Questions & Follow-ups

- N/A

## 17. References

- [prd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/module-level-log-controls/prd.md)
- [requirements.yml](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/module-level-log-controls/requirements.yml)
- [features_live.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex)
- [application.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/application.ex)
- [Logger.put_module_level/2 docs](https://hexdocs.pm/logger/Logger.html#put_module_level/2)
- [Logger.put_process_level/2 docs](https://hexdocs.pm/logger/Logger.html#put_process_level/2)

### AC Reference Index

- `AC-001`: Module-level override can be set by an authorized admin.
- `AC-002`: Module-level override remains scoped and does not change the global level.
- `AC-003`: Unauthorized users cannot create, update, or clear overrides.
- `AC-004`: Invalid modules and levels are rejected safely.
- `AC-005`: Admin UI shows active override state or applied-change confirmation.
- `AC-006`: Module-level override can be cleared.
- `AC-007`: Process-level override can be set for an existing local process via PID or registered name.
- `AC-008`: Invalid or unresolved process targets are rejected safely.
- `AC-009`: Process-level controls are clearly labeled as local-node and existing-process only.
