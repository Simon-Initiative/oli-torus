# LTI Launch Hardening - Functional Design Document

## 1. Executive Summary

This design replaces the current Phoenix-session-centered LTI launch handshake with a database-backed `launch_attempts` boundary that is authoritative across `/lti/login`, `/lti/launch`, and the invalid-registration or invalid-deployment registration-request handoff. The design keeps `lti_1p3` as the lower-level protocol and validation layer, adds standards-aligned storage-assisted launch support when `lti_storage_target` is advertised, preserves the legacy cookie or session-based path when it is not advertised, and removes immediate post-launch routing dependence on `get_latest_user_lti_params/1`.

The simplest adequate approach is:

- persist a single `launch_attempts` row during `/lti/login`
- choose either storage-assisted or legacy session flow from explicit LMS capability signals
- resolve and atomically transition the same attempt during `/lti/launch`
- compute the redirect destination from the current validated launch plus persisted launch-attempt routing fields
- redirect to `/lti/register_form` with explicit `issuer`, `client_id`, and optional `deployment_id` URL parameters when registration or deployment cannot be found
- retain `lti_1p3_params` only for durable business context and observability, not as the immediate redirect authority

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001`, `FR-014`: support storage-assisted launch when advertised and preserve the legacy cookie or session path when `lti_storage_target` is not advertised.
  - `FR-002`, `FR-015`, `FR-003`: create one database-backed launch-attempt authority with `expires_at`, multi-node safety, and deterministic classification.
  - `FR-004`, `FR-005`: route immediately from the current validated launch and remove immediate redirect dependence on `get_latest_user_lti_params/1`.
  - `FR-006`, `FR-016`, `FR-017`: keep admin registration-request handoff explicit, URL-parameter-based, session-independent, and single-use.
- `FR-007`, `FR-008`, `FR-009`: narrow helper paths and classify failures into stable user-facing outcomes.
- `FR-010`, `FR-018`, `FR-011`: improve launch telemetry, explicitly record the transport method as `lti_storage_target` or `session_storage`, and improve keyset and `kid` diagnostics.
  - `FR-012`, `FR-013`: keep `lti_1p3` as the lower-level validation layer and require upstream release `0.12.0` before the final Torus PR.
- Non-functional requirements:
  - `AC-001`, `AC-010`: storage-assisted launches must not depend solely on Phoenix session continuity, while non-supporting LMSs must keep the legacy path.
  - `AC-002`, `AC-003`, `AC-011`, `AC-014`: launch-attempt state must be shared across nodes, atomically classified, and cleaned up after expiry for active or unconsumed flows.
  - `AC-004`: immediate redirect must use current-launch context, not `get_latest_user_lti_params/1`.
  - `AC-005`, `AC-012`, `AC-013`: invalid registration or deployment handoff must be explicit, single-use, and not require reconstruction after refresh.
- `AC-006`, `AC-007`, `AC-015`, `AC-008`: user-facing failures must be stable and sanitized, with non-sensitive diagnostics and telemetry that explicitly identify the transport method.
  - `AC-009`: any vendored `lti_1p3` changes must be upstreamed and shipped through Hex before final merge.
- Assumptions:
  - The existing `/lti/register_form` GET route remains the correct CSRF-safe presentation surface for the institution registration form.
  - Torus can add one new database table plus cleanup worker without introducing external state infrastructure.
  - The current `lti_1p3` library boundary can support the new flow by moving state ownership and login-path orchestration into Torus while leaving token validation and registration lookup in the library.

## 3. Repository Context Summary

- What we know:
  - Current `/lti/login` and `/lti/launch` live in [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex#L30) and currently store `state` plus pending registration params in the Phoenix session.
  - Immediate redirect logic in [delivery_web.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/delivery_web.ex#L22) reads `LtiParams.get_latest_user_lti_params/1`, which is the stale-context behavior this design removes.
  - Durable `lti_1p3_params` records in [lti_params.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/lti/lti_params.ex#L9) are keyed by issuer, client, deployment, context, and subject and can remain as a durable business-context store, but not as the immediate redirect authority.
  - Invalid registration and deployment already converge on `/lti/register_form` in [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex#L673), which is a natural place to remove session dependence without changing the UX boundary.
  - Existing LTI error rendering is server-side template driven in `lib/oli_web/templates/lti/`, which aligns with stable terminal outcomes.
- Unknowns to confirm:
  - Which exact `lti_1p3` login-path functions need to be bypassed, extended, or replaced for standards-aligned storage-assisted flow selection.
  - Whether any downstream flows outside `DeliveryWeb.redirect_user/2` still depend on latest-user launch lookups for behavior that must be preserved separately.
  - Whether launch-attempt lookup should use Phoenix signed params, `Phoenix.Token`, or a short signed opaque id in the registration-form query string.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `Oli.Lti.LaunchAttempts`:
  - new domain module in `lib/oli/lti/launch_attempts.ex`
  - owns creation, lookup, state transition, expiry checks, and cleanup selection
  - exposes narrow operations such as `create_launch_attempt/1`, `resolve_for_launch/2`, `mark_launch_result/2`, `prepare_registration_handoff/2`, and `cleanup_expired/0`
  - persists `transport_method` as one of `lti_storage_target` or `session_storage`
- `Oli.Lti.LaunchAttempt`:
  - new Ecto schema in `lib/oli/lti/launch_attempt.ex`
  - persists launch lifecycle and minimal routing plus handoff data
- `OliWeb.LtiController`:
  - becomes the transport layer that calls `LaunchAttempts` and `lti_1p3`
  - no longer stores launch authority in Phoenix session
  - uses session only for the legacy login-path requirement if the lower-level validation call still needs session-carried state for LMSs without `lti_storage_target`
- `OliWeb.DeliveryWeb`:
  - adds a new redirect entrypoint that accepts current launch resolution data instead of loading latest-user launch params
  - retains existing redirect rendering outcomes for configured section, unconfigured section, and independent learner cases
- `Oli.Lti.LtiParams`:
  - remains for durable LTI context persistence and downstream business behavior
  - is no longer consulted for immediate launch redirect
- cleanup worker:
  - new Oban worker or scheduled runtime task that deletes active or unconsumed attempts whose `expires_at` has passed

### 4.2 State & Data Flow

1. `/lti/login`
   - Parse LMS capability signals, including whether `lti_storage_target` is advertised.
   - Create `launch_attempt` with generated state, nonce, flow mode, transport method, issuer, client id, deployment id if present, target link URI, and expiry.
   - If `lti_storage_target` is advertised:
     - Torus constructs the storage-assisted continuation response and includes an opaque attempt reference.
     - The browser helper stores or retrieves the state and nonce through the standards-aligned path and returns to launch.
   - If `lti_storage_target` is not advertised:
     - Torus follows the existing legacy login behavior and continues to populate the Phoenix session with the state required by the current `lti_1p3` validation boundary.
2. `/lti/launch`
   - Resolve the attempt reference and atomically verify that the attempt is active, unexpired, and not already terminal.
   - Validate the launch with `lti_1p3` using the appropriate current-flow state source.
   - On `invalid_registration` or `invalid_deployment`, transition the attempt into a registration-handoff terminal state and redirect to `/lti/register_form` with explicit `issuer`, `client_id`, and optional `deployment_id` query parameters.
   - On other failures, classify the terminal outcome and render `lti_error.html.heex`.
   - On success, persist user, roles, durable `lti_1p3_params`, section updates, enrollment, and `resolved_section_id`, then redirect from the current launch resolution data.
3. `/lti/register_form`
   - GET reads explicit `issuer`, `client_id`, and optional `deployment_id` query parameters.
   - Render the form with those values and check for an existing pending registration using the same values.
   - Refresh is not supported. Invalid submit re-renders from submitted form values.

### 4.3 Lifecycle & Ownership

- Launch-attempt ownership:
  - created at `/lti/login`
  - active until launch or registration handoff consumes it
  - terminal states include `launch_succeeded`, `invalid_registration`, `invalid_deployment`, `missing_state`, `mismatched_state`, `expired`, `consumed`, `storage_blocked`, `validation_failure`, `launch_handler_failure`, and `post_auth_landing_failure`
- Redirect ownership:
  - immediate redirect is derived from current validated launch claims plus section resolution and role checks
  - latest-user launch lookups are explicitly removed from the redirect path
- Registration-form handoff ownership:
  - initial render comes from explicit URL parameters
  - subsequent invalid submit rendering comes from posted form values
  - no long-lived onboarding artifact is introduced

### 4.4 Alternatives Considered

- Keep the current Phoenix-session-centered design:
  - rejected because it remains fragile in embedded contexts and node-local session continuity is the core problem
- Introduce Redis or another TTL cache:
  - rejected because the PRD explicitly prefers no new infrastructure service and the database already satisfies multi-node state ownership
- Add a separate onboarding-context artifact:
  - rejected because invalid registration and deployment already converge on one registration-request surface and explicit URL parameters are sufficient for the single-use handoff
- Continue redirecting from `get_latest_user_lti_params/1`:
  - rejected because it can select stale context across launches and conflicts with `AC-004`

## 5. Interfaces

- `GET|POST /lti/login`
  - input: existing OIDC login params plus optional storage-assisted LMS capability fields
  - output:
    - storage-assisted continuation response when `lti_storage_target` is advertised
    - existing redirect behavior for legacy flow when it is not
- `POST /lti/launch`
  - input: LMS launch POST, state, id token, and attempt reference
  - output:
    - successful authenticated redirect from current launch context
    - stable `lti_error` render
    - redirect to `/lti/register_form?issuer=...&client_id=...&deployment_id=...` for invalid registration or deployment
- `GET /lti/register_form`
  - input: explicit query parameters including `issuer`, `client_id`, and optional `deployment_id`
  - output:
    - registration form or registration pending page rendered from URL-provided handoff fields
- `POST /lti/request_registration`
  - no design change to route contract
  - hidden fields continue to carry issuer, client id, and deployment id after the first render
- internal interfaces:
  - `LaunchAttempts.create_launch_attempt(attrs) -> {:ok, attempt}`
  - `LaunchAttempts.resolve_active_attempt(ref) -> {:ok, attempt} | {:error, classification}`
  - `LaunchAttempts.transition_attempt(id, from_state, to_state, attrs) -> {:ok, attempt}`
  - `LaunchAttempts.cleanup_expired() -> {:ok, count}`
  - `DeliveryWeb.redirect_from_launch(conn, launch_resolution, opts) -> conn`

## 6. Data Model & Storage

- New table: `lti_launch_attempts`
- Required columns:
  - `id`
  - `state_token`
  - `nonce`
  - `flow_mode` with values like `legacy_session` or `storage_assisted`
  - `transport_method` with values `session_storage` or `lti_storage_target`
  - `lifecycle_state`
  - `failure_classification`
  - `handoff_type`
  - `issuer`
  - `client_id`
  - `deployment_id`
  - `context_id`
  - `resource_link_id`
  - `message_type`
  - `target_link_uri`
  - `roles`
  - `launch_presentation`
  - `resolved_section_id`
  - `user_id`
  - `expires_at`
  - `launched_at`
  - `consumed_at`
  - timestamps
- Indexes:
  - unique index on `state_token`
  - index on `expires_at`
  - index on `lifecycle_state`
  - composite index on issuer, client id, deployment id for operational queries
- Existing `lti_1p3_params` table remains unchanged in the first implementation phase except that redirect code stops depending on its “latest row wins” query.

## 7. Consistency & Transactions

- Attempt creation at `/lti/login` is one insert transaction.
- `/lti/launch` resolution must use an atomic transition:
  - load the attempt with row lock or conditional update
  - verify unexpired and still active
  - mark terminal classification only once
- Successful launch handling keeps the existing transaction pattern in `handle_valid_lti_1p3_launch/1`, but expands the transaction to include launch-attempt completion metadata.
- Registration handoff:
  - invalid registration or deployment transitions the attempt to a terminal handoff state before redirecting
  - GET `/lti/register_form` renders from URL parameters, not from attempt-bound handoff state
- Cleanup:
  - worker deletes only attempts whose `expires_at` has passed and whose lifecycle state is still active or otherwise eligible for cleanup under the chosen policy

## 8. Caching Strategy

N/A. The design intentionally avoids new cache-based authority for launch state. Existing Cachex-based keyset caching remains in place for platform keys, but launch-attempt correctness does not depend on node-local caches.

## 9. Performance & Scalability Posture

- Launch-attempt writes add one row insert per login and one update per launch outcome, which is acceptable relative to the normal launch transaction cost.
- The table is short-lived and should stay small if `expires_at` cleanup runs regularly.
- Indexing `state_token` and `expires_at` keeps launch and cleanup queries bounded.
- The design removes some cross-node failure modes at the cost of more predictable database I/O, which is the right tradeoff for correctness.
- No additional synchronous external network dependency is introduced beyond existing LMS and keyset validation boundaries.

## 10. Failure Modes & Resilience

- Missing or mismatched state:
  - classify as stable terminal failure and render `lti_error`
- Expired or already-consumed attempt:
  - classify distinctly and render stable launch failure
- Storage-assisted capability advertised but helper flow fails:
  - classify as `storage_blocked` or helper-path failure and render stable recovery or terminal page
- Invalid registration or deployment:
  - redirect to single-use registration-request form handoff
- Successful validation followed by redirect-resolution failure:
  - classify as `post_auth_landing_failure` rather than folding into generic launch failure
- Registration form refresh:
  - not supported after the first render from URL-parameter handoff
- Cleanup job failure:
  - does not break active launches immediately but should produce telemetry and error logs for operational follow-up

## 11. Observability

- Emit structured logs and telemetry for:
  - attempt created
  - launch path selected
  - transport method selected
  - validation started
  - validation failed with classification
  - registration handoff prepared
  - registration form rendered
  - launch completed
  - redirect target resolved
  - cleanup run started, completed, failed
  - keyset lookup diagnostics including requested `kid`, available cached kids, and cache freshness context
- Include correlation identifiers:
  - attempt id or public ref
  - issuer
  - client id
  - deployment id when present
  - flow mode
  - transport method
  - lifecycle classification
- Exclude:
  - raw id tokens
  - cookies
  - session contents
  - registration secrets
  - raw login hints

## 12. Security & Privacy

- State and nonce remain server-generated and validated.
- Registration-form query parameters should be limited to non-secret configuration identifiers such as issuer, client id, and deployment id.
- Launch-attempt rows store only minimal needed routing and diagnostic fields rather than full raw launch blobs.
- User-facing errors remain sanitized and stable.
- Registration-request handoff remains on a CSRF-safe GET render followed by normal form POST.
- Multi-tenant boundaries remain enforced through existing institution, registration, deployment, and section resolution logic.

## 13. Testing Strategy

- ExUnit:
  - launch-attempt schema and state-transition tests
  - `/lti/login` tests for storage-assisted versus legacy flow selection
  - `/lti/launch` tests for success, invalid registration, invalid deployment, missing state, mismatched state, expired attempt, consumed attempt, validation failure, and post-auth landing failure
  - redirect tests for `DeliveryWeb.redirect_from_launch/3` or equivalent current-launch-based redirect logic
  - registration-form tests proving GET handoff from URL parameters and invalid-submit re-render from posted params
  - cleanup worker tests
  - keyset diagnostic logging tests where practical
- LiveView:
  - only if the registration form’s existing LiveView-dependent tech-support behavior requires it
- Scenario coverage:
  - consider one scenario-level test if the end-to-end launch -> registration request or launch -> course setup workflow crosses enough boundaries to justify it
- Traceability:
  - FDD satisfies `AC-001` through `AC-014` by explicit design mapping in this document and in the implementation test plan

## 14. Backwards Compatibility

- No feature flag is planned for this work item.
- LMSs without `lti_storage_target` continue on the legacy login and session path.
- Existing `/lti/register_form` and `/lti/request_registration` routes remain in place.
- Existing `lti_1p3_params` persistence remains available for durable context and downstream workflows.
- Final merge must restore the Hex dependency on `lti_1p3 0.12.0` rather than a vendored path dependency.

## 15. Risks & Mitigations

- Route and helper complexity could make the launch flow harder to reason about:
  - keep `LaunchAttempts` as the single authority and keep controller logic thin
- Single-use registration handoff could surprise support during manual reproduction:
  - document the behavior clearly and rely on URL-provided context plus logs rather than refreshable state
- The legacy flow still depends on session continuity when LMS capability is absent:
  - preserve it only as fallback and make that path visible in telemetry
- `lti_1p3` boundary changes may reveal hidden assumptions about where state is stored:
  - isolate the Torus-owned orchestration boundary first and upstream only the minimal library changes needed
- Redirect resolution could still accidentally read latest-user state through an overlooked path:
  - centralize redirect behavior in one current-launch-based function and remove the old helper from the immediate launch path

## 16. Open Questions & Follow-ups

- Confirm the minimal upstream `lti_1p3` changes required for storage-assisted login orchestration and state validation.
- Confirm whether any non-delivery flows still depend on `get_latest_user_lti_params/1` and need a separate migration path.

## 17. References

- [prd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prd.md)
- [requirements.yml](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/requirements.yml)
- [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex)
- [delivery_web.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/delivery_web.ex)
- [lti_params.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/lti/lti_params.ex)
- [guides/lti/implementing.md](/Users/eliknebel/Developer/oli-torus/guides/lti/implementing.md)
- [guides/lti/config.md](/Users/eliknebel/Developer/oli-torus/guides/lti/config.md)
