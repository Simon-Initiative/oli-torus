# LTI Launch Hardening - Functional Design Document

## 1. Executive Summary

This design keeps the Phoenix-session-centered LTI launch handshake as the only supported launch transport and focuses on hardening the surrounding behavior. The final shape keeps `lti_1p3` as the lower-level protocol and validation layer, removes immediate post-launch routing dependence on `get_latest_user_lti_params/1`, keeps registration-request handoff explicit and URL-parameter-based, preserves stable terminal error behavior for embedded browser-state failures, and improves telemetry plus diagnostics without retaining the storage-assisted prototype path.

The simplest adequate approach is:

- keep `/lti/login` as a session-backed redirect to the LMS authorization URL
- validate `/lti/launch` against the session-backed state already established by `/lti/login`
- compute the immediate redirect destination from the current validated launch claims rather than latest durable user launch params
- redirect to `/lti/register_form` with explicit `issuer`, `client_id`, and optional `deployment_id` URL parameters when registration or deployment cannot be found
- retain `lti_1p3_params` only for durable business context and authenticated LTI-user redirect behavior, not as the immediate launch redirect authority
- preserve the static LTI error surface and iframe-safe registration behavior from the broader hardening work

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-004`, `FR-005`: route immediately from the current validated launch and remove immediate redirect dependence on `get_latest_user_lti_params/1`.
  - `FR-006`, `FR-016`, `FR-017`: keep admin registration-request handoff explicit, URL-parameter-based, session-independent, and single-use.
  - `FR-007`, `FR-008`, `FR-009`: classify failures into stable user-facing outcomes.
  - `FR-010`, `FR-018`, `FR-011`: improve launch telemetry, explicitly record the transport method as `session_storage`, and improve keyset plus `kid` diagnostics.
  - `FR-012`, `FR-013`: keep `lti_1p3` as the lower-level validation layer.
- Non-functional requirements:
  - `AC-004`: immediate redirect must use current-launch context, not `get_latest_user_lti_params/1`.
  - `AC-005`, `AC-012`, `AC-013`: invalid registration or deployment handoff must be explicit, single-use, and not require reconstruction after refresh.
- `AC-006`, `AC-007`, `AC-015`, `AC-008`: user-facing failures must be stable and sanitized, with non-sensitive diagnostics and telemetry that explicitly identify the transport method.
- Assumptions:
  - The existing `/lti/register_form` GET route remains the correct CSRF-safe presentation surface for the institution registration form.
  - The current `lti_1p3` library boundary can support the hardened session-backed flow without adding a new launch-state store.
  - The archived storage-assisted prototype remains documented in [prototype-checkpoint.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prototype-checkpoint.md), but it is not part of the supported implementation target.

## 3. Repository Context Summary

- What we know:
  - Current `/lti/login` and `/lti/launch` live in [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex#L30) and currently store `state` plus pending registration params in the Phoenix session.
  - Immediate redirect logic depends on `get_latest_user_lti_params/1`, which is the stale-context behavior this design removes in favor of a current-launch redirect module.
  - Durable `lti_1p3_params` records in [lti_params.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/lti/lti_params.ex#L9) are keyed by issuer, client, deployment, context, and subject and can remain as a durable business-context store, but not as the immediate redirect authority.
  - Invalid registration and deployment already converge on `/lti/register_form` in [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex#L673), which is a natural place to remove session dependence without changing the UX boundary.
  - Existing LTI error rendering is server-side template driven in `lib/oli_web/templates/lti/`, which aligns with stable terminal outcomes.
- Unknowns to confirm:
  - Which exact `lti_1p3` login-path functions need to be bypassed, extended, or replaced for standards-aligned storage-assisted flow selection.
  - Whether any downstream flows outside the immediate launch redirect path still depend on latest-user launch lookups for behavior that must be preserved separately.
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
- `OliWeb.LtiRedirect`:
  - owns current-launch redirect resolution and authenticated LTI-user redirect behavior
  - resolves destinations from current system state using launch-attempt routing fields instead of loading latest-user launch params
  - retains existing redirect rendering outcomes for configured section, unconfigured section, and independent learner cases
- `Oli.Lti.LtiParams`:
  - remains for durable LTI context persistence and downstream business behavior
  - is no longer consulted for immediate launch redirect
- landing boundary:
  - successful launches redirect to a signed `/lti/landing` route rather than directly to the final destination
  - the landing route checks whether the authenticated Torus session survived on the first embedded GET
  - if the session survived, the route continues to the normal destination
  - if the session did not survive, the route either renders a “Continue in a new window” page or a terminal embedded-browser privacy error depending on feature flag
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
   - On success, persist user, roles, durable `lti_1p3_params`, section updates, enrollment, and `resolved_section_id`, then redirect to the signed landing route.
3. `/lti/landing`
   - Verify the signed landing token and load the successful launch attempt.
   - If the authenticated Torus session survived and matches the launch user, continue to the resolved launch destination.
   - If a new-window continuation request is present, create the Torus session from the successful attempt and continue to the resolved launch destination.
   - Otherwise, render the new-window fallback page or terminal embedded-session-unavailable error based on feature flag.
4. `/lti/register_form`
   - GET reads explicit `issuer`, `client_id`, and optional `deployment_id` query parameters.
   - Render the form with those values and check for an existing pending registration using the same values.
   - Refresh is not supported. Invalid submit re-renders from submitted form values.

### 4.3 Lifecycle & Ownership

- Launch-attempt ownership:
  - created at `/lti/login`
  - active until launch or registration handoff consumes it
  - terminal states include `launch_succeeded`, `invalid_registration`, `invalid_deployment`, `missing_state`, `mismatched_state`, `expired`, `consumed`, `storage_blocked`, `validation_failure`, `launch_handler_failure`, `post_auth_landing_failure`, and `iframe_session_unavailable`
- Redirect ownership:
  - immediate redirect is derived from current validated launch claims plus section resolution and role checks
  - successful launches are mediated through the landing route so Torus can detect embedded session loss before attempting protected delivery
  - latest-user launch lookups are explicitly removed from the immediate launch redirect path
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
    - storage-assisted continuation response when `lti_storage_target` is advertised and feature enabled
    - existing redirect behavior for legacy flow when it is not
- `POST /lti/launch`
  - input: LMS launch POST, state, id token, and attempt reference
  - output:
    - redirect to the signed landing boundary after successful authenticated launch handling
    - stable `lti_error` render
    - redirect to `/lti/register_form?issuer=...&client_id=...&deployment_id=...` for invalid registration or deployment
- `GET /lti/landing`
  - input: signed `landing_token` and optional `continue_in_new_tab=true`
  - output:
    - redirect to the current resolved destination when session continuity is available or explicitly re-established in a new window
    - fallback landing page with a “Continue in a new window” action when enabled and embedded session continuity is unavailable
    - stable `lti_error` render for embedded-session-unavailable when the new-window fallback feature is disabled
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
  - `LtiRedirect.launch_destination(attempt, opts) -> {:redirect, path} | :course_not_configured | {:error, msg}`

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
- Feature-flag state remains in the existing feature-state mechanism and includes:
  - `lti-storage-target` default enabled
  - `lti-new-tab-fallback` default disabled

## 7. Consistency & Transactions

- Attempt creation at `/lti/login` is one insert transaction.
- `/lti/launch` resolution must use an atomic transition:
  - load the attempt with row lock or conditional update
  - verify unexpired and still active
  - mark terminal classification only once
- Successful launch handling keeps the existing transaction pattern in `handle_valid_lti_1p3_launch/1`, but expands the transaction to include launch-attempt completion metadata.
- Landing continuation:
  - signed landing token verification is read-only
  - explicit new-window continuation can create the authenticated Torus session from the successful launch attempt before redirecting
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
- Launch succeeds but embedded Torus session does not survive on the first landing GET:
  - render the new-window fallback page or terminal embedded-browser privacy error based on feature-flag state
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
  - landing continued normally
  - landing rendered new-window fallback
  - landing rendered embedded-session-unavailable error
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
- Registration-request handoff remains on a GET render followed by normal form POST, without depending on iframe-stable Phoenix CSRF session continuity for the LTI registration endpoints.
- Multi-tenant boundaries remain enforced through existing institution, registration, deployment, and section resolution logic.

## 13. Testing Strategy

- ExUnit:
  - launch-attempt schema and state-transition tests
  - `/lti/login` tests for storage-assisted versus legacy flow selection
  - `/lti/login` tests for feature-flag-controlled fallback from `lti_storage_target` to `session_storage`
  - `/lti/launch` tests for success, invalid registration, invalid deployment, missing state, mismatched state, expired attempt, consumed attempt, validation failure, and post-auth landing failure
  - landing tests for successful continuation, new-window fallback rendering, and embedded-session-unavailable rendering
  - redirect tests for `LtiRedirect` current-launch-based redirect logic
  - registration-form tests proving GET handoff from URL parameters and invalid-submit re-render from posted params
  - cleanup worker tests
  - keyset diagnostic logging tests where practical
  - regression tests for stable LTI error rendering and iframe-safe registration behavior
- LiveView:
  - only if the registration form’s existing LiveView-dependent tech-support behavior requires it
- Scenario coverage:
  - consider one scenario-level test if the end-to-end launch -> registration request or launch -> course setup workflow crosses enough boundaries to justify it
- Traceability:
  - FDD satisfies `AC-001` through `AC-014` by explicit design mapping in this document and in the implementation test plan

## 14. Backwards Compatibility

- Feature flags used by this work item:
  - `lti-storage-target` default enabled
  - `lti-new-tab-fallback` default disabled
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
- Even a successful storage-assisted launch can still lose the first embedded Torus session:
  - isolate that boundary in the landing route and keep the recovery UX explicit and feature-flag controlled
- `lti_1p3` boundary changes may reveal hidden assumptions about where state is stored:
  - isolate the Torus-owned orchestration boundary first and upstream only the minimal library changes needed
- Redirect resolution could still accidentally read latest-user state through an overlooked path:
  - centralize redirect behavior in one current-launch-based function and remove the old helper from the immediate launch path

## 16. Open Questions & Follow-ups

- Confirm the minimal upstream `lti_1p3` changes required for storage-assisted login orchestration and state validation.
- Confirm whether any non-delivery flows still depend on `get_latest_user_lti_params/1` and need a separate migration path.

## 17. Follow-On Design: Remove Storage-Assisted Launch Support

### 17.1 Scope

The follow-on slice removes the storage-assisted launch path from Torus and also removes the database-backed launch-attempt persistence that was primarily introduced to support that path. The resulting design keeps a single LTI launch transport: the legacy session-backed path, while preserving the stable error handling, redirect improvements, telemetry, and registration-request fixes from the earlier work.

The archival prototype checkpoint for the removed design is recorded in [prototype-checkpoint.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prototype-checkpoint.md).

### 17.2 Components To Remove

- `lti_storage_target` capability-driven transport selection in `OliWeb.LtiController`
- storage-assisted helper rendering and browser-side storage orchestration
- `Oli.Lti.LaunchAttempt` schema, `Oli.Lti.LaunchAttempts` domain API, and related cleanup worker behavior
- signed landing continuation behavior that exists only to recover from partial cookieless launch flow
- the landing fallback page and related new-window recovery UX
- the `lti-storage-target` and `lti-new-tab-fallback` feature flags

### 17.3 Components To Keep

- session-backed `/lti/login` and `/lti/launch` flow with the retained hardening and classification improvements
- redirect resolution improvements that avoid stale latest-user launch routing
- explicit registration-form handoff through URL parameters
- stable launch error taxonomy and terminal rendering
- the LTI layout hardening that removes the tech support modal `live_render` from `lti.html.heex` so terminal error pages stay static and do not redirect into unintended 404s
- the embedded missing-state browser-privacy error behavior and LMS-admin guidance to configure Torus to open in a new window
- telemetry, logging, and keyset diagnostics that do not depend on persisted launch-attempt state
- iframe-safe registration form behavior and related regression fixes

### 17.4 Resulting Design Shape

1. `/lti/login`
   - always selects `session_storage`
   - stores the legacy session state needed for launch validation
   - always redirects directly to the LMS authorization URL without the storage-assisted helper page
2. `/lti/launch`
   - validates via `lti_1p3`, applies stable failure classification, and continues to use the retained redirect improvements
   - does not depend on persisted `launch_attempt` state or post-launch landing continuation behavior
3. Redirect and registration behavior
   - immediate redirect continues to avoid stale latest-user launch routing
   - registration-request handoff remains URL-parameter based and session-independent
4. Error and observability behavior
   - stable launch errors, structured telemetry, and diagnostic logging remain in place

### 17.5 Verification Focus

- Remove tests that exist only for storage-assisted helper behavior and post-launch continuation fallback behavior.
- Remove tests that exist only for persisted launch-attempt state and cleanup-worker behavior.
- Keep and update tests that prove:
  - session-backed launch behavior
  - stable launch classification
  - non-stale redirect resolution
  - URL-parameter registration handoff
  - stable terminal error rendering
  - iframe-safe registration form behavior

## 17. References

- [prd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prd.md)
- [requirements.yml](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/requirements.yml)
- [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/controllers/lti_controller.ex)
- [lti_redirect.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/lti_redirect.ex)
- [lti_params.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/lti/lti_params.ex)
- [guides/lti/implementing.md](/Users/eliknebel/Developer/oli-torus/guides/lti/implementing.md)
- [guides/lti/config.md](/Users/eliknebel/Developer/oli-torus/guides/lti/config.md)
