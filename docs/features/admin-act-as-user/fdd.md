# Admin Act-as-User (Masquerade) — Functional Design Document

## 1. Executive Summary
This design introduces a system-admin-only masquerade flow that allows an admin to act as a selected user from the admin user detail screen. The implementation adds a confirmation step before session mutation so impersonation is always deliberate. Once started, the effective authenticated user becomes the selected user, while original admin identity is retained in dedicated masquerade session metadata for auditing and control. A global visual treatment is applied across layouts: a bright magenta viewport border and persistent bottom status bar with acting identity and stop action. The feature is guarded by a system-level feature flag in the existing global feature toggle system. Start and stop actions emit audit events with exact timestamps and identities for compliance visibility in the existing audit log UI. The design reuses existing auth/session primitives in `OliWeb.UserAuth` and `OliWeb.AuthorAuth` to avoid introducing a parallel authentication stack. A dedicated web-layer module handles session mutation and recovery to keep responsibility boundaries clear and future-proof for `author` masquerade subjects. Key risks are privilege leakage and session restoration correctness, mitigated via explicit effective-principal rules and integration tests across controller and LiveView routes. Performance impact is minimal because steady-state requests continue using existing user-token resolution with only lightweight session metadata checks.

## 2. Requirements & Assumptions
- Functional Requirements:
  - FR-001/FR-002: Add `Act as user` entry in admin user detail and mandatory confirmation screen.
  - FR-003/FR-004: Establish masquerade session with effective user + preserved admin metadata.
  - FR-005/FR-006: Show global chrome while active and provide deterministic stop/restore flow.
  - FR-007: Capture start/stop audit events.
  - FR-008/FR-010: Restrict to system admin and gate everything behind system-level feature flag.
  - FR-009: Behavior consistent across controller and LiveView surfaces.
  - FR-011: Internals must support future `author` masquerade.
- Non-Functional Requirements:
  - Start/stop latency p95 < 250ms.
  - Added per-request masquerade overhead < 2ms p95.
  - Stop idempotent; no partial session state on failed start.
  - No unauthorized starts/stops; all transitions audited.
- Explicit Assumptions:
  - `Oli.Features` is the correct system-level flag mechanism for this capability.
  - `audit_log_events.event_type` remains string-backed; adding new enum atoms requires app code changes only.
  - Root/layout templates are sufficient injection points for global chrome across primary app surfaces.
  - Admin author session should remain active during masquerade to allow explicit stop and attribution.

## 3. Torus Context Summary
- What we know:
  - Admin user detail entry exists at `lib/oli_web/live/users/user_detail_view.ex` with actions rendered by `lib/oli_web/live/users/user_actions.ex`.
  - Auth/session behavior is split across `lib/oli_web/author_auth.ex` and `lib/oli_web/user_auth.ex`; user context is session-token based and reused by controller and LiveView mount flows.
  - Session context consumed by many views is initialized via `lib/oli_web/live_session_plugs/set_ctx.ex` and `lib/oli_web/common/session_context.ex`.
  - Audit logging is centralized in `lib/oli/auditing.ex` with event typing in `lib/oli/auditing/log_event.ex`.
  - System-level feature toggles are managed by `lib/oli/features.ex` and surfaced in `lib/oli_web/live/features/features_live.ex`.
  - Admin user detail route exists at `/admin/users/:user_id` in `lib/oli_web/router.ex`.
- Unknowns to confirm:
  - Whether any niche routes bypass shared layouts and need extra chrome injection points.
  - Whether current authorization checks that rely on `is_admin` need explicit suppression during masquerade for strict "act exactly as user" semantics.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.Accounts.Masquerade` (new context module):
  - Owns session contract, start/stop semantics, and subject model (`subject_type`, `subject_id`) with `:user` in v1.
  - Provides pure contract functions used by web layer.
- `OliWeb.MasqueradeController` (new):
  - Handles `start` and `stop` actions because session mutation must occur in HTTP conn.
  - Enforces feature flag + system admin authorization guardrails.
  - Writes audit events via `Oli.Auditing.capture/4`.
- `OliWeb.Users.MasqueradeConfirmView` (new LiveView or controller-rendered page):
  - Renders confirmation UI (`Act as <user>` details + proceed/cancel).
  - No session mutation; only navigates to start action.
- `OliWeb.Plugs.FetchMasquerade` (new plug):
  - Reads session masquerade metadata and assigns normalized `:masquerade` payload to `conn.assigns`.
  - Used by layouts and request-time policy helpers.
- `OliWeb.LiveSessionPlugs.SetMasquerade` (new on_mount helper):
  - Mirrors conn masquerade payload into socket assigns for LiveView-driven rendering consistency.
- Layout/UI layer:
  - Shared partial/component renders border + bottom bar from `assigns[:masquerade]`.
  - Stop button points to controller `DELETE /admin/masquerade`.

### 4.2 State & Message Flow
1. System admin opens `/admin/users/:user_id`.
2. `Act as user` action (feature-flag + role gated) navigates to `/admin/users/:user_id/act_as`.
3. Confirmation view shows user name, email, independent learner status, and `Proceed`/`Cancel`.
4. `Proceed` submits to `POST /admin/masquerade/users/:user_id/start`.
5. Controller validates:
  - Feature enabled.
  - Current author is system admin.
  - Target user exists and is eligible.
6. Controller invokes `Oli.Accounts.Masquerade.start/3`:
  - Snapshot original user session keys (`user_token`, `current_user_id`) into `masquerade_original_*`.
  - Generate target `user_token` via existing account session token mechanism.
  - Replace effective user session keys with target user token/id.
  - Persist masquerade metadata (`active`, `subject_type=user`, `subject_id`, `admin_author_id`, `started_at`).
7. Controller logs audit `:masquerade_started` with admin + target metadata and redirects to user-facing landing path.
8. On every request/mount, auth reads effective user as target; plug/on_mount expose `:masquerade` for chrome rendering.
9. `Stop acting as user` sends `DELETE /admin/masquerade`.
10. Controller invokes `Oli.Accounts.Masquerade.stop/2`:
  - Restore original user session keys if present, else clear user session keys.
  - Remove masquerade metadata.
11. Controller logs audit `:masquerade_stopped` and redirects to admin user detail page.

### 4.3 Supervision & Lifecycle
- No new long-lived OTP processes required.
- Runtime state is session-scoped and request-scoped.
- Lifecycle boundaries:
  - Start: explicit endpoint only.
  - Active: maintained by session.
  - Stop: explicit stop endpoint + auth logout hooks (`UserAuth.log_out_user/2`, `AuthorAuth.log_out_author/2`) call `Masquerade.maybe_stop_for_logout/2` to ensure stop audit for explicit logout paths.

### 4.4 Alternatives Considered
- Swap only `conn.assigns.current_user` without replacing session token:
  - Rejected because many LiveView and controller paths derive user from `session["user_token"]`; behavior drift risk is high.
- Dedicated DB table for active masquerade sessions:
  - Rejected for v1 due unnecessary complexity; session state + audit events satisfy requirements.
- Keep full admin privileges while acting:
  - Rejected because requirement expects behavior to match target user experience.

## 5. Interfaces
### 5.1 HTTP/JSON APIs
- `GET /admin/users/:user_id/act_as`
  - Confirmation screen.
  - Guards: authenticated admin + feature flag + system admin role.
- `POST /admin/masquerade/users/:user_id/start`
  - Starts masquerade.
  - Params: `user_id` path param.
  - Responses: redirect success; forbidden/not-found on guard failure.
- `DELETE /admin/masquerade`
  - Stops active masquerade.
  - Idempotent: safe when not active.

### 5.2 LiveView
- `OliWeb.Users.UsersDetailView`:
  - Add action entry and event/navigation to confirmation route.
  - Action visibility requires `Accounts.has_admin_role?(current_author, :system_admin)` and feature flag enabled.
- Confirmation view:
  - Handles `cancel` navigation and submit-to-start action.
- Global chrome rendering:
  - Layout templates read `@masquerade` assign; for LiveView views this assign comes from conn initial render and `SetMasquerade` on_mount for connected updates.

### 5.3 Processes
- No new GenServer/Registry required.
- Contract functions (new module):
  - `Oli.Accounts.Masquerade.start(conn, admin_author, target_user) :: {:ok, conn} | {:error, reason}`
  - `Oli.Accounts.Masquerade.stop(conn, admin_author) :: {:ok, conn, stop_details}`
  - `Oli.Accounts.Masquerade.active?(session_or_assigns) :: boolean`
  - `Oli.Accounts.Masquerade.subject(session_or_assigns) :: %{type: :user, id: integer} | nil`

## 6. Data Model & Storage
### 6.1 Ecto Schemas
- `Oli.Auditing.LogEvent`:
  - Add event types:
    - `:masquerade_started`
    - `:masquerade_stopped`
  - Update `event_description/1` for readable audit text.
- No new DB tables in v1.
- Session keys (server-side session store):
  - `masquerade_active` (boolean)
  - `masquerade_subject_type` (`"user"`)
  - `masquerade_subject_id` (integer)
  - `masquerade_admin_author_id` (integer)
  - `masquerade_started_at` (ISO8601)
  - `masquerade_original_user_token` (nullable binary)
  - `masquerade_original_current_user_id` (nullable integer)

### 6.2 Query Performance
- No new hot-path DB queries.
- Start/stop incur bounded queries already needed for target user/admin lookup and token operations.
- Audit write is one insert at start and one at stop.

## 7. Consistency & Transactions
- Start/stop are session mutation operations plus audit inserts.
- Ordering requirement:
  - Start: mutate session then insert start audit; on audit failure, keep session but log warning and return success (consistent with existing audit non-blocking posture in adjacent modules).
  - Stop: restore session then insert stop audit; same non-blocking audit failure handling.
- Idempotency:
  - Stopping when inactive should return no-op success with no second stop audit.

## 8. Caching Strategy
- No distributed cache required.
- Session is source of truth for active masquerade state.
- `conn.assigns[:masquerade]` and `socket.assigns[:masquerade]` are per-request/per-mount derived cache.

## 9. Performance and Scalability Plan
### 9.1 Budgets
- Start/stop endpoint processing p95 < 250ms.
- Added request overhead from masquerade checks p95 < 2ms.
- Zero increase in steady-state query count for non-start/stop requests.

### 9.2 Hotspots & Mitigations
- Hotspot: layout rendering checks on every request.
  - Mitigation: constant-time session key reads, no DB lookups for chrome display.
- Hotspot: privilege branching complexity during masquerade.
  - Mitigation: central helper `Masquerade.effective_admin?/1` and explicit tests for guarded routes.
- Hotspot: token churn if repeatedly switching users.
  - Mitigation: keep one active masquerade and require stop before starting another.

## 10. Failure Modes & Resilience
- Feature disabled mid-session:
  - On next request, `FetchMasquerade` forces stop and clears state; emits stop audit with reason `flag_disabled`.
- Invalid target user at start:
  - Reject start, flash error, no session mutation.
- Corrupt/incomplete masquerade session keys:
  - Fail closed by clearing masquerade keys and restoring/clearing user session deterministically.
- Logout while masquerading:
  - Logout hooks call stop helper first to record end event, then continue normal logout.

## 11. Observability
- Telemetry events:
  - `[:oli, :masquerade, :start]` metadata: `%{admin_author_id, subject_type, subject_id}`
  - `[:oli, :masquerade, :stop]` metadata: `%{admin_author_id, subject_type, subject_id, reason, duration_seconds}`
  - `[:oli, :masquerade, :denied]` metadata: `%{reason}`
- Structured logs:
  - Warning logs for invalid session recovery and audit write failures.
- AppSignal:
  - Counters for start, stop, denied, and recovery paths.

## 12. Security & Privacy
- Authorization:
  - Start/confirm/stop routes require authenticated author + system admin role.
- Effective principal safety:
  - During active masquerade, user-facing auth checks consume effective user context, not admin bypass.
- Tenant isolation:
  - No cross-tenant elevation; effective access remains target user's existing permissions.
- Auditability:
  - Start/stop with explicit actor and target IDs.
- Privacy:
  - Audit details store IDs and minimal identifying fields required by support/compliance.

## 13. Testing Strategy
- Unit tests:
  - `Oli.Accounts.Masquerade` start/stop contracts, restoration behavior, idempotency, invalid state cleanup.
- Controller tests:
  - Start/stop authorization and feature flag gating.
  - Session keys written/restored as expected.
- LiveView tests:
  - `Act as user` action visibility and confirmation content.
  - Global chrome render conditions while masquerading.
- Integration tests:
  - Cross-route behavior (controller + LiveView) ensuring effective user semantics.
- Audit tests:
  - Start and stop audit events emitted once with expected fields.

## 14. Backwards Compatibility
- No breaking changes to existing login flows.
- Existing sessions remain unaffected when feature flag is disabled.
- Audit UI continues to function; it gains two additional event types.
- Existing admin user management actions remain unchanged except added action entry.

## 15. Risks & Mitigations
- Risk: admin authorization leaks while acting.
  - Mitigation: central effective-principal helper and strict route tests for admin-only access while masquerading.
- Risk: missing end audits for abnormal browser/session termination.
  - Mitigation: capture on explicit stop and logout; record this residual limitation in docs.
- Risk: layout inconsistency across less-common templates.
  - Mitigation: enumerate and patch all root/primary layouts in implementation checklist.

## 16. Open Questions & Follow-ups
- Should v1 enforce maximum masquerade duration and auto-stop policy?
- Should admin be blocked from visiting `/admin/*` pages while masquerading to enforce stricter "exact user view" semantics?
- Should stop reason taxonomy be standardized in audit details (`manual_stop`, `logout`, `flag_disabled`, `recovery_cleanup`)?
- Follow-up for phase 2: implement `subject_type = author` using same contracts and UI.

## 17. References
- Plug.Conn | https://hexdocs.pm/plug/Plug.Conn.html | Accessed 2026-02-19
- Phoenix LiveView on_mount | https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-life-cycle | Accessed 2026-02-19
- Phoenix Controller Redirects | https://hexdocs.pm/phoenix/Phoenix.Controller.html | Accessed 2026-02-19
- Torus User Detail LiveView | lib/oli_web/live/users/user_detail_view.ex | Accessed 2026-02-19
- Torus UserAuth | lib/oli_web/user_auth.ex | Accessed 2026-02-19
- Torus AuthorAuth | lib/oli_web/author_auth.ex | Accessed 2026-02-19
- Torus Auditing Context | lib/oli/auditing.ex | Accessed 2026-02-19
- Torus System Features | lib/oli/features.ex | Accessed 2026-02-19
