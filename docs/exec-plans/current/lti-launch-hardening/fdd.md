# LTI Launch Hardening - Functional Design Document

## 1. Executive Summary
This design hardens Torus LTI 1.3 launches by moving login-request construction and launch-state ownership into Torus while keeping JWT validation, registration lookup, and protocol primitives anchored in `lti_1p3`. The implementation adds a server-owned launch-state service, a narrow browser helper page for the client-side OIDC and `postMessage` storage path, stable launch recovery and error rendering, and explicit propagation of validated launch context into post-launch routing so the current request, not the latest persisted launch blob, drives section resolution.

The simplest adequate design is a dual-path flow. Platforms that do not advertise the storage capability continue to use the existing Phoenix-session path. Platforms that do advertise it use a Torus intermediate page to obtain platform-stored state, complete launch validation without depending on a third-party session cookie round trip, and classify failures into stable user-visible and operator-visible categories.

## 2. Requirements & Assumptions
- Functional requirements:
  - Satisfy `FR-001` through `FR-010` in [requirements.yml](/Users/eliknebel/Developer/oli-torus-2/docs/exec-plans/current/lti-launch-hardening/requirements.yml).
  - Preserve registration, deployment, user provisioning, enrollment, and section-resolution boundaries already implemented in [lti_controller.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/lti_controller.ex).
- Acceptance-criteria traceability:
  - `AC-001` and `AC-002`: Torus owns login/request construction and the storage-capable path while `lti_1p3` remains the validation boundary.
  - `AC-003`: non-storage-capable launches stay on the legacy session path.
  - `AC-004` and `AC-005`: missing or blocked state enters deterministic recovery or stable browser-settings-oriented error handling.
  - `AC-006` and `AC-009`: telemetry and logs classify flow path and failure outcome without sensitive payloads.
  - `AC-007`: launch failures render stable sanitized pages without redirecting into generic 404 behavior.
  - `AC-008`: immediate routing uses the current validated `LaunchContext`, not the latest persisted launch blob.
  - `AC-010`: valid launches still resolve the correct registration, deployment, user, and section boundaries without tenant leakage.
- Non-functional requirements:
  - Keep state, nonce, and replay protections server-enforced.
  - Avoid logging raw `id_token`, session values, cookies, or full launch payloads.
  - Keep launch failures readable, static, sanitized, and accessible.
  - Preserve successful behavior for the legacy path.
- Assumptions:
  - Torus may add controller-rendered HTML and small browser-side scripts without introducing a React app for this flow.
  - The repository does not currently contain the harness-requested `ARCHITECTURE.md`, `harness.yml`, or `docs/{STACK,TOOLING,TESTING,PRODUCT_SENSE,FRONTEND,BACKEND,DESIGN,OPERATIONS}.md`; this FDD therefore uses repository equivalents such as [README.md](/Users/eliknebel/Developer/oli-torus-2/README.md), [guides/lti/implementing.md](/Users/eliknebel/Developer/oli-torus-2/guides/lti/implementing.md), [guides/lti/config.md](/Users/eliknebel/Developer/oli-torus-2/guides/lti/config.md), [guides/process/testing.md](/Users/eliknebel/Developer/oli-torus-2/guides/process/testing.md), and live code boundaries.
  - No feature-flag contract was found in repository harness configuration, so rollout is designed to be controlled by capability detection and deploy-time configuration if needed.

## 3. Repository Context Summary
- What we know:
  - [lti_controller.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/lti_controller.ex) currently delegates login URL generation to `Lti_1p3.Tool.OidcLogin.oidc_login_redirect_url/1`, stores only `state` in the Phoenix session, and validates launches with `Lti_1p3.Tool.LaunchValidation.validate/2`.
  - [delivery_web.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/delivery_web.ex) currently routes users using `LtiParams.get_latest_user_lti_params/1`, creating stale-context risk.
  - [lti_params.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli/lti/lti_params.ex) stores the full launch payload in `lti_1p3_params.params` and exposes helpers that other flows consume.
  - [section_specification.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/sections/section_specification.ex) creates LTI section specs from persisted launch params for a user/context pair.
  - Existing LTI controller tests in [lti_controller_test.exs](/Users/eliknebel/Developer/oli-torus-2/test/oli_web/controllers/lti_controller_test.exs) provide a strong ExUnit baseline for both successful and failing launch flows.
  - Existing docs in [guides/lti/implementing.md](/Users/eliknebel/Developer/oli-torus-2/guides/lti/implementing.md) and [guides/lti/config.md](/Users/eliknebel/Developer/oli-torus-2/guides/lti/config.md) confirm the current server-side OIDC flow and institution/registration/deployment model.
- Unknowns to confirm:
  - Which stored-launch consumers outside current `rg` results still require the full `params` blob for support or admin diagnostics.
  - Whether the current `lti_1p3` dependency already exposes enough low-level helpers to validate launches when state is supplied from Torus storage rather than session.
  - Which deployed LMS integrations actually advertise and complete the postMessage storage flow in production.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- Add `Oli.Lti.LaunchState` as the server-owned boundary for:
  - generating login state and nonce
  - persisting a short-lived launch state record keyed by state
  - recording flow mode (`legacy_session` or `client_storage`)
  - tracking validation outcome and recovery classification
  - providing sanitized metadata for logging and telemetry
- Keep [lti_controller.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/lti_controller.ex) as the HTTP entry point, but refactor it into explicit steps:
  - `login/2` asks `LaunchState` to classify the request and construct the OIDC request payload in Torus code.
  - `login/2` renders either a direct redirect for legacy launches or a Torus intermediary page for client-storage launches.
  - `launch/2` resolves state from the request/session/storage fallback, invokes `lti_1p3` validation with the resolved state, then delegates to a launch handling service.
  - failure branches call a dedicated error presenter instead of rendering raw library messages.
- Add a small controller/view/template set under `OliWeb.LtiHTML` for:
  - client-side OIDC helper page
  - browser-storage recovery page
  - stable sanitized launch-error page
- Add `Oli.Lti.LaunchContext` as an explicit normalized struct built from validated claims and passed through launch handling and immediate redirect logic.
- Keep `lti_1p3` responsible for:
  - JWT verification
  - registration/deployment lookup primitives
  - LTI protocol claim helpers
  - AGS/NRPS helpers already used in section updates

### 4.2 State & Data Flow
1. LMS calls `/lti/login` with standard OIDC initiation params.
2. Torus validates registration presence early and loads deployment/platform metadata needed to choose a flow.
3. Torus detects browser-message support in this order:
   - `lti_storage_target` present on the login request
   - successful `lti.capabilities` response advertising both `lti.get_data` and `lti.put_data`
   - if neither signal is present, Torus uses the legacy session-backed path
4. `LaunchState.create/2` persists a short-lived record containing:
   - state
   - nonce
   - issuer
   - client_id
   - target_link_uri
   - deployment hint if present
   - flow mode
   - request correlation id
   - expiry timestamp
5. Legacy path:
   - Torus also writes `state` to the Phoenix session for backwards compatibility.
   - Torus redirects to the platform auth endpoint with a Torus-constructed OIDC request.
6. Client-storage path:
   - Torus renders an intermediate helper page.
   - The page uses the platform storage/postMessage contract to place or recover launch state in the browser-supported channel and auto-continues to the platform auth endpoint.
7. LMS posts back to `/lti/launch` with `state` and `id_token`.
8. Torus resolves launch state in this order:
   - matching server-side `LaunchState` record by incoming `state`
   - Phoenix session state for legacy compatibility checks
   - browser-helper-supplied recovery params for the client-storage path
9. Torus invokes launch validation using the resolved state and builds a normalized `LaunchContext` from validated claims.
10. Launch handling provisions the user, updates section LTI service fields, persists normalized durable context, signs the user in, and redirects using `LaunchContext`.
11. On failure, Torus classifies the reason and renders either:
   - a recovery page for likely browser privacy/storage failures
   - a stable launch-error page for validation/configuration failures

### 4.3 Lifecycle & Ownership
- Launch state ownership:
  - Owned by `Oli.Lti.LaunchState`.
  - TTL-backed and single-use.
  - Deleted or marked consumed after successful validation.
- Durable launch context ownership:
  - Owned by `Oli.Lti.LtiParams`, but narrowed from “full raw launch blob as primary artifact” to “normalized context fields plus optional sanitized raw payload for support-only use”.
  - Immediate routing must consume `LaunchContext`, not re-query the latest persisted params row.
- Routing ownership:
  - [delivery_web.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/delivery_web.ex) gains a function that accepts `LaunchContext`.
  - `get_latest_user_lti_params/1` is removed from the LTI launch redirect flow.
  - Fallback to persisted `LtiParams` remains only for non-launch entry points that legitimately lack current validated claims.
- Error classification ownership:
  - Centralized in a dedicated launch error module, not ad hoc string rendering from controller branches.

### 4.4 Alternatives Considered
- Keep the current session-only flow and improve copy:
  - Rejected because it does not satisfy `FR-001`, `FR-004`, or `AC-001`.
- Fully replace `lti_1p3`:
  - Rejected because the PRD explicitly treats that as a non-goal and the current library still provides value for validation and claim helpers.
- Move the entire launch flow into frontend code:
  - Rejected because authorization, validation, and security boundaries need to remain in Phoenix and `lib/oli`.
- Simplest adequate choice:
  - Add a Torus-owned login/request-construction and launch-state boundary while preserving library validation and existing server-side launch handling.

## 5. Interfaces
- `Oli.Lti.LaunchState.create(login_params, opts) :: {:ok, launch_state}`
  - Inputs: OIDC initiation params, resolved registration, requested flow mode, request metadata.
  - Output: persisted state record with generated `state` and `nonce`.
- `Oli.Lti.LaunchState.resolve(state, conn, opts) :: {:ok, launch_state} | {:error, classification}`
  - Resolves a state record and determines whether the request is valid, missing, mismatched, expired, or already consumed.
- `Oli.Lti.OidcLogin.build_request(login_params, launch_state, registration) :: {:ok, redirect_url_or_form}`
  - Torus-owned request construction replacing direct use of `Lti_1p3.Tool.OidcLogin.oidc_login_redirect_url/1`.
- `Oli.Lti.LaunchContext.from_claims(lti_params) :: {:ok, launch_context} | {:error, classification}`
  - Extracts issuer, client_id, deployment_id, context_id, resource_link_id, roles, service endpoints, user subject, and launch presentation hints.
- `OliWeb.DeliveryWeb.redirect_user_from_launch(conn, launch_context, opts) :: Plug.Conn.t()`
  - Immediate post-launch routing interface using current validated context.
- `OliWeb.DeliveryWeb.redirect_user(conn, opts) :: Plug.Conn.t()`
  - Non-launch fallback entry point only; it must not rely on `get_latest_user_lti_params/1`.
- `Oli.Lti.LaunchErrors.classify(reason, context) :: classification`
  - Maps raw validation/handling failures into stable categories such as `missing_state`, `mismatched_state`, `unsupported_storage_capability`, `embedded_storage_blocked`, `invalid_registration`, and `launch_handler_failure`.
- HTTP/UI interfaces:
  - `GET|POST /lti/login`
  - `POST /lti/launch`
  - `GET /lti/launch/recover/:state` or equivalent helper endpoint for storage-assisted recovery
  - controller-rendered LTI helper/recovery/error templates

## 6. Data Model & Storage
- Add a new persistence model for launch state. Preferred shape:
  - table: `lti_launch_states`
  - fields:
    - `state` string, unique
    - `nonce` string
    - `issuer` string
    - `client_id` string
    - `target_link_uri` string
    - `deployment_hint` string nullable
    - `flow_mode` enum/string
    - `status` enum/string: `pending | consumed | failed | expired`
    - `request_id` string
    - `storage_supported` boolean nullable
    - `failure_classification` string nullable
    - `expires_at` utc_datetime
    - timestamps
- Update `lti_1p3_params` usage in [lti_params.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli/lti/lti_params.ex):
  - retain existing key fields (`issuer`, `client_id`, `deployment_id`, `context_id`, `sub`, `exp`)
  - narrow `params` toward a normalized durable subset for routing and section creation
  - retain persisted LTI launch details for admin observability, including the existing admin-facing rendering in [user_detail_view.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/live/users/user_detail_view.ex), but treat that payload as an observability artifact rather than the authoritative source for immediate routing decisions
- Add a virtual or persisted `LaunchContext` struct, not a broad schema, for in-request use.
- Data migration:
  - create `lti_launch_states`
  - no immediate destructive migration of `lti_1p3_params`
  - follow-up cleanup can remove raw blob dependencies once consumers are audited

## 7. Consistency & Transactions
- Successful launch handling remains wrapped in a single DB transaction similar to the existing `handle_valid_lti_1p3_launch/1` flow.
- Expand the transaction to include:
  - marking the launch state record consumed
  - persisting updated durable LTI context
  - provisioning/updating user
  - section update and enrollment
- Validation of JWT and classification may occur before the DB transaction, but any consumed-state mutation must be transactionally tied to success or terminal failure handling to prevent replay ambiguity.
- Launch state consumption rule:
  - a state transitions from `pending` to `consumed` exactly once on successful validated launch
  - retries against consumed state classify as replay/mismatched-state failures

## 8. Caching Strategy
- Reuse existing `lti_1p3` JWK/keyset caching behavior for platform keys.
- Do not cache validated launch context outside the request/redirect boundary; authoritative state remains DB-backed because launches are security-sensitive and one-time.
- Optional short-lived in-memory lookup for `lti_launch_states` by `state` is acceptable only as an optimization layered over DB truth.

## 9. Performance & Scalability Posture
- Launch volume is modest relative to page delivery, so a DB-backed short-lived state table is acceptable.
- The client-storage path adds one Torus-rendered intermediary page and one storage handshake but removes dependence on repeated failed launch retries caused by blocked cookies.
- Indexes required:
  - unique index on `state`
  - index on `expires_at`
  - optional composite index on `status, expires_at` for cleanup
- Background cleanup:
  - periodic purge of expired `lti_launch_states`
  - retention on failed classifications should be short and sanitized

## 10. Failure Modes & Resilience
- Missing state at launch:
  - classify as `missing_state`
  - if the request was eligible for client-storage recovery, render recovery flow
  - otherwise render stable launch error that also includes generic guidance to allow cookies or ask the LMS administrator to configure Torus to launch in a new tab
- Mismatched or consumed state:
  - classify as `mismatched_state`
  - no silent retry
- Storage capability not advertised:
  - fall back to legacy session path
- Storage capability advertised but browser storage handshake fails:
  - classify as `embedded_storage_blocked` or `recovery_failure`
  - render recovery page with generic allow-cookies/open-in-new-tab guidance
- Invalid registration or deployment:
  - preserve current registration form/deployment handling behavior
  - classify separately from browser/session failures
- Launch handler failure after valid JWT:
  - log classification and request id
  - show stable sanitized error page
- Error page masking by downstream 404 behavior:
  - avoid redirecting into unrelated routes once a launch failure is known
  - render directly in controller/template boundary

## 11. Observability
- Emit structured telemetry for:
  - `[:torus, :lti, :launch, :start]`
  - `[:torus, :lti, :launch, :validated]`
  - `[:torus, :lti, :launch, :recovery]`
  - `[:torus, :lti, :launch, :failure]`
- Required metadata:
  - `flow_mode`
  - `classification`
  - `storage_supported`
  - `embedded_context` when detectable
  - `issuer_hash` or issuer identifier already considered operationally safe
  - `client_id`
  - `deployment_id`
  - `request_id`
- Logging:
  - use structured `Logger` metadata, not interpolated raw maps
  - never log `id_token`, `login_hint`, cookies, session contents, or full launch claims
- AppSignal:
  - tag classified failures and flow mode so support can separate privacy failures from LMS configuration failures quickly

## 12. Security & Privacy
- Preserve CSRF/replay protections by keeping server-generated `state` and `nonce` authoritative even when browser storage assists the round trip.
- Treat `lti_launch_states` as sensitive operational data:
  - short TTL
  - single use
  - minimal stored inputs
- Sanitize all user-facing messages through a fixed taxonomy.
- Preserve current institution/registration/deployment scoping to avoid cross-tenant section resolution.
- Do not allow browser helper code to decide authorization or section ownership; it only assists state transport.
- Review `belongs_to(:user, Oli.Lti.Tool.Registration)` in [lti_params.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli/lti/lti_params.ex) during implementation because it appears semantically inconsistent with current user-based usage and may be a latent modeling issue adjacent to this work.

## 13. Testing Strategy
- ExUnit controller tests in [lti_controller_test.exs](/Users/eliknebel/Developer/oli-torus-2/test/oli_web/controllers/lti_controller_test.exs):
  - legacy login request construction still succeeds
  - storage-capable login renders helper path
  - successful client-storage launch validates without relying on session-only state
  - missing, mismatched, expired, and consumed state classifications
  - stable recovery page rendering
  - stable sanitized launch-error rendering
  - invalid registration/deployment still follow current flows
  - launch redirect behavior no longer depends on `get_latest_user_lti_params/1`
- Domain tests:
  - `LaunchState` creation, resolution, expiry, and consumption
  - `LaunchContext` normalization from claims
  - routing using explicit launch context instead of latest persisted params
- Regression tests:
  - [delivery_web.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/delivery_web.ex) immediate redirect path must use current validated context
  - [section_specification.ex](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/sections/section_specification.ex) remains correct for flows that still depend on persisted context
- Browser-flow coverage:
  - keep Playwright thin per [guides/process/testing.md](/Users/eliknebel/Developer/oli-torus-2/guides/process/testing.md)
  - add only one or two smoke flows if a real browser is needed to validate the helper page/postMessage behavior

## 14. Backwards Compatibility
- Platforms that do not advertise the storage capability stay on the current session-compatible path.
- Existing institutions, registrations, deployments, user provisioning, enrollment, AGS, and NRPS behavior remain unchanged.
- Persisted `lti_1p3_params` rows remain readable during migration; consumers are migrated off “latest launch blob” semantics incrementally.
- No user-visible workflow changes for unaffected launches beyond more stable error handling.

## 15. Risks & Mitigations
- `lti_1p3` low-level validation may still assume session-backed state:
  - mitigate by isolating the validation adapter early and confirming the minimum override needed before implementation expands.
- Some LMSs may partially advertise but not reliably complete storage-assisted flows:
  - mitigate with explicit capability gating, classification, and safe fallback/recovery.
- Narrowing persisted launch data could break support/admin tooling:
  - mitigate with an audit of current consumers and a transitional period where normalized context and raw payload coexist.
- Additional helper page complexity may create accessibility regressions:
  - mitigate with simple controller-rendered HTML, auto-continue, and clear `<noscript>` fallback messaging.

## 16. Open Questions & Follow-ups
- No open questions remain for this FDD phase.

## 17. References
- [PRD](/Users/eliknebel/Developer/oli-torus-2/docs/exec-plans/current/lti-launch-hardening/prd.md)
- [Requirements](/Users/eliknebel/Developer/oli-torus-2/docs/exec-plans/current/lti-launch-hardening/requirements.yml)
- [LTI controller](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/controllers/lti_controller.ex)
- [Delivery redirect boundary](/Users/eliknebel/Developer/oli-torus-2/lib/oli_web/delivery_web.ex)
- [LTI params schema](/Users/eliknebel/Developer/oli-torus-2/lib/oli/lti/lti_params.ex)
- [Section specification](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/sections/section_specification.ex)
- [Section lookup from LTI params](/Users/eliknebel/Developer/oli-torus-2/lib/oli/delivery/sections.ex)
- [LTI controller tests](/Users/eliknebel/Developer/oli-torus-2/test/oli_web/controllers/lti_controller_test.exs)
- [LTI implementation guide](/Users/eliknebel/Developer/oli-torus-2/guides/lti/implementing.md)
- [LTI configuration guide](/Users/eliknebel/Developer/oli-torus-2/guides/lti/config.md)
- [Testing strategy](/Users/eliknebel/Developer/oli-torus-2/guides/process/testing.md)
