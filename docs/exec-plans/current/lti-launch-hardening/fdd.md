# LTI Launch Hardening - Functional Design Document

## 1. Executive Summary
This design resets the Torus LTI launch lifecycle around clear server-owned boundaries instead of continuing to patch a mixed session, signed-state, and browser-helper flow. The target model introduces an explicit Torus-owned launch attempt boundary, uses the current validated launch context as the only authority for immediate post-launch routing, treats registration as a separate onboarding flow rather than launch recovery, and limits browser-assisted behavior to login initiation compatibility only. The result should be a launch flow that is deterministic in embedded LMS contexts, diagnosable when it fails, and less dependent on browser-managed cross-site session continuity.

## 2. Requirements & Assumptions
- Functional requirements:
  - Satisfy `FR-001` through `FR-010` in [requirements.yml](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/docs/exec-plans/current/lti-launch-hardening/requirements.yml).
  - Preserve existing registration, deployment, authorization, enrollment, and section-resolution behavior while reducing critical dependence on browser session state.
  - Use the current validated launch context for immediate routing and remove launch-path dependence on `get_latest_user_lti_params/1`.
- Acceptance-criteria traceability:
  - `AC-001`, `AC-002`, and `AC-003`: covered by the explicit `LaunchAttempt` boundary plus deterministic legacy versus storage-assisted path selection.
  - `AC-004`, `AC-005`, `AC-006`, and `AC-007`: covered by explicit launch-state ownership, stable terminal failure taxonomy, and separate recovery versus onboarding contracts.
  - `AC-008`: covered by making `LaunchContext` the only authority for immediate post-launch routing.
  - `AC-009`: covered by lifecycle instrumentation and structured launch-attempt telemetry.
  - `AC-010`: covered by preserving registration, deployment, user provisioning, enrollment, and section-resolution boundaries within the validated launch path.
- Non-functional requirements:
  - Keep state, nonce, replay protection, registration lookup, deployment lookup, and JWT verification server-side.
  - Avoid logging raw `id_token`, cookies, session contents, full claims, or other sensitive launch payload data.
  - Render stable, sanitized, terminal error states for failed launches.
  - Preserve current successful behavior for compatible legacy launches while migration is in progress.
- Assumptions:
  - Browser privacy and third-party cookie restrictions are a primary source of intermittent launch failures in embedded LMS contexts.
  - Torus can introduce a first-class launch attempt abstraction without replacing `lti_1p3` as the JWT and protocol validation layer.
  - Registration can be treated as an onboarding subflow without weakening launch security semantics.
  - Any `lti_1p3` changes required during implementation may be made against the checked-out library under `.vendor/lti_1p3`, then merged and released upstream as `0.12.0` before the Torus PR is finalized.
  - Before the final Torus PR is submitted, `mix.exs` should be restored from the local path dependency back to the released Hex package version of `lti_1p3`.

## 3. Repository Context Summary
- What we know:
  - [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/controllers/lti_controller.ex) currently owns `/lti/login`, `/lti/launch`, registration redirects, recovery rendering, and several adjacent concerns.
  - [delivery_web.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/delivery_web.ex) now supports redirecting from `LaunchContext`, but launch-adjacent flows still show evidence of session-coupled behavior.
  - [register.html.eex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/templates/lti/register.html.eex) is part of the embedded launch journey even though registration is not itself a launch-validation concern.
  - [router.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/router.ex) currently splits LTI entry, registration form rendering, and registration submission across different pipelines with different session and CSRF assumptions.
  - [launch_errors.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli/lti/launch_errors.ex) already provides a useful stable error taxonomy that can serve as the public-facing failure contract.
  - Existing controller coverage in [lti_controller_test.exs](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/test/oli_web/controllers/lti_controller_test.exs) is strong enough to anchor a migration if the contracts are made explicit.
- Unknowns to confirm:
  - Whether a signed-only state envelope is sufficient long term or whether a persisted launch-attempt store is needed for single-use semantics and operability.
  - Which current admin/support consumers still require full persisted launch blobs versus normalized durable context.
  - Which LMS/browser combinations in real traffic require the storage-assisted path and which continue to succeed on the legacy path.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.Lti.LaunchAttempt`
  - Owns the canonical launch attempt boundary created at `/lti/login` and resolved at `/lti/launch`.
  - Encapsulates launch correlation data, expiry, flow mode, and outcome classification.
- `Oli.Lti.LaunchContext`
  - Owns normalized in-request launch context derived from validated claims.
  - Becomes the only contract used for immediate post-launch redirect behavior.
- `OliWeb.LtiController`
  - Continues to expose the HTTP entry points, but each route must have one concern:
    - `/lti/login`: validate initiation input, create launch attempt, choose flow, redirect or render helper.
    - `/lti/launch`: resolve launch attempt, validate launch, provision user/session, redirect from `LaunchContext`, or render terminal error.
    - `/lti/register_form`: render registration UI with explicit onboarding inputs.
    - `/lti/register`: capture pending registration without requiring launch-session continuity.
    - `/lti/launch/recover` or equivalent helper endpoint: assist storage-related recovery only.
- `lti_1p3`
  - Remains the lower-level boundary for JWT verification, nonce/state validation primitives where applicable, registration/deployment matching helpers, and service claim helpers.
- `OliWeb.DeliveryWeb`
  - Owns redirecting from validated `LaunchContext`.
  - Must not consult user-global “latest launch” state during the immediate launch path.

### 4.2 State & Data Flow
1. LMS initiates login against `/lti/login`.
2. Torus validates initiation inputs and resolves known registration/deployment context as far as possible.
3. Torus creates a short-lived launch attempt record or equivalent authoritative envelope containing state, nonce, initiation metadata, flow mode, and expiry.
4. Torus selects exactly one login path:
   - legacy redirect path
   - storage-assisted helper path
5. LMS posts `id_token` and `state` to `/lti/launch`.
6. Torus resolves the launch attempt from the incoming state.
7. Torus validates the launch through `lti_1p3` using the resolved launch attempt boundary.
8. Torus normalizes validated claims into `LaunchContext`.
9. Torus provisions or updates the user, persists approved durable launch context, signs the user in, and redirects from `LaunchContext`.
10. On failure, Torus renders one terminal classification:
   - invalid registration
   - invalid deployment
   - missing state
   - mismatched or consumed state
   - storage blocked
   - validation failed
   - launch handler failure
11. Registration remains a separate onboarding branch reached only after explicit invalid-registration or invalid-deployment classification.

### 4.3 Lifecycle & Ownership
- Authoritative launch state:
  - Owned by `LaunchAttempt`.
  - Created once at login.
  - Resolved once at launch.
  - Single-use or effectively single-use.
- Immediate routing state:
  - Owned by current-request `LaunchContext`.
  - Never inferred from historical user-global launch rows.
- Durable historical launch data:
  - Owned by `LtiParams` or successor persistence layer only for approved observability, support, and follow-on workflows.
  - Not authoritative for the immediate redirect path.
- Registration state:
  - Owned by explicit request params or a signed onboarding token.
  - Must not rely on embedded session continuity.

### 4.4 Alternatives Considered
- Continue patching the mixed flow:
  - Rejected because each fix introduces more special-case coupling between launch, registration, and session behavior without simplifying the model.
- Session-only launch state:
  - Rejected because embedded third-party cookie behavior is the primary instability source.
- Signed-state only with no server-owned attempt model:
  - Viable as a migration step, but weaker operationally for one-time consumption, classification, and observability.
- Full `lti_1p3` replacement:
  - Rejected because the library still provides value at the protocol boundary and full replacement is outside scope.

## 5. Interfaces
- `Oli.Lti.LaunchAttempt.create(initiation_params, opts) :: {:ok, launch_attempt}`
- `Oli.Lti.LaunchAttempt.resolve(state, opts) :: {:ok, launch_attempt} | {:error, classification}`
- `Oli.Lti.LaunchAttempt.consume(launch_attempt, outcome) :: :ok | {:error, reason}`
- `Oli.Lti.LaunchContext.from_claims(validated_claims) :: {:ok, launch_context} | {:error, classification}`
- `OliWeb.DeliveryWeb.redirect_user_from_launch(conn, launch_context, opts) :: Plug.Conn.t()`
- `Oli.Lti.LaunchErrors.classify(reason, context) :: classification`
- HTTP route contracts:
  - `GET|POST /lti/login`
  - `POST /lti/launch`
  - `GET /lti/register_form`
  - `POST /lti/register`
  - `GET /lti/launch/recover` or equivalent helper-support endpoint if needed

## 6. Data Model & Storage
- Preferred model: `lti_launch_attempts`
  - `state`
  - `nonce`
  - `issuer`
  - `client_id`
  - `deployment_id_hint`
  - `target_link_uri`
  - `flow_mode`
  - `status`
  - `request_id`
  - `storage_supported`
  - `failure_classification`
  - `expires_at`
  - timestamps
- Transitional allowance:
  - signed envelope and session mirror may coexist during migration, but `LaunchAttempt` must remain the documented source of truth.
- Durable launch context:
  - Keep `lti_1p3_params` or equivalent store for approved historical/support uses.
  - Narrow runtime assumptions so those records are not consulted during immediate redirect.
- Registration onboarding context:
  - carry `issuer`, `client_id`, and `deployment_id` explicitly on the request or in a signed onboarding token rather than only in session.

## 7. Consistency & Transactions
- A successful validated launch should complete within one transaction boundary covering:
  - launch attempt consumption
  - user provisioning/update
  - LTI params persistence updates
  - section/service updates
  - enrollment
- JWT verification and initial classification may occur before the transaction.
- Launch attempt status must transition deterministically to avoid ambiguous replay behavior.

## 8. Caching Strategy
- Reuse current platform key and JWK caching.
- Do not treat session cookies as authoritative cache for launch correctness.
- Optional in-memory optimization around `LaunchAttempt` is acceptable only if database or signed-envelope truth remains authoritative.

## 9. Performance & Scalability Posture
- Launch traffic volume is low enough that a short-lived attempt store is operationally acceptable.
- The key optimization target is correctness and diagnosability, not removing a single read or write.
- Required indexes:
  - unique on `state`
  - lookup on `expires_at`
  - optional lookup on `status, expires_at` for cleanup

## 10. Failure Modes & Resilience
- Invalid registration:
  - classify explicitly and enter registration onboarding with explicit context.
- Invalid deployment:
  - classify explicitly and preserve deployment-focused onboarding or admin guidance.
- Missing or mismatched state:
  - resolve against `LaunchAttempt`; do not guess between multiple sources of truth.
- Storage/cookie blocked:
  - render recovery or stable terminal error with browser/privacy guidance.
- Successful launch followed by sign-in redirect:
  - classify separately as post-auth session continuity failure if the launch validated and session creation succeeded but the redirected request is unauthenticated.
- Registration form failures:
  - must not be allowed to masquerade as launch validation failures.

## 11. Observability
- Emit structured lifecycle events for:
  - launch login initiated
  - launch attempt created
  - launch attempt resolved
  - launch validated
  - launch consumed
  - launch failed with classification
  - post-launch redirect target chosen
  - post-launch authenticated landing failure if detected
- Required metadata:
  - request_id
  - flow_mode
  - classification
  - storage_supported
  - embedded_context
  - issuer/client/deployment identifiers considered operationally safe
- Exclude:
  - raw `id_token`
  - cookie contents
  - session values
  - full raw claims

## 12. Security & Privacy
- State and nonce remain server-authoritative.
- Browser helper logic never makes authorization or routing decisions.
- Registration onboarding context should use explicit non-secret inputs or signed transport, not hidden session-only assumptions.
- User-facing error pages must remain sanitized and terminal.
- Replay and one-time consumption semantics should be clearer under `LaunchAttempt` than under the current mixed model.

## 13. Testing Strategy
- Domain tests:
  - launch attempt issuance, resolution, expiry, tamper detection, and one-time consumption semantics
  - `LaunchContext` normalization
- Controller tests:
  - legacy login path
  - storage-assisted login path
  - successful launch through validated `LaunchContext`
  - invalid registration/deployment onboarding transition
  - missing/mismatched/consumed state
  - stable terminal launch errors
  - registration form GET and POST in embedded/no-session conditions
- Integration scenarios:
  - successful embedded launch
  - blocked-cookie or blocked-storage launch
  - successful launch followed by authenticated redirect continuity

## 14. Backwards Compatibility
- Preserve existing successful legacy launches during migration.
- Preserve existing registration, deployment, enrollment, and section update behavior unless an explicit redesign decision says otherwise.
- Allow transitional coexistence of signed-state and session mirrors while the canonical launch attempt model is adopted.

## 15. Risks & Mitigations
- Migration complexity:
  - Mitigation: migrate by explicit contracts and route separation rather than in-place behavior drift.
- Dependency-boundary churn:
  - Mitigation: allow local changes under `.vendor/lti_1p3` during implementation, release them upstream as `0.12.0`, and only then restore Torus to the Hex dependency before PR submission.
- Hidden consumers of persisted launch blobs:
  - Mitigation: audit before narrowing durable context.
- Partial rollout ambiguity:
  - Mitigation: instrument flow mode and launch-attempt status in every path.
- Embedded browser inconsistency:
  - Mitigation: remove session as a required transport for correctness-critical and onboarding-adjacent steps.

## 16. Open Questions & Follow-ups
- Should `LaunchAttempt` be database-backed from the start or should the signed envelope remain the first migration layer?
- Do we need a first-class post-auth handoff endpoint to distinguish successful launch validation from lost authenticated redirect state?
- Which admin/support screens still require raw persisted LTI claim blobs instead of normalized context?
- Should registration onboarding move to a signed onboarding token to keep URLs cleaner once the contract is stable?

## 17. References
- [prd.md](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/docs/exec-plans/current/lti-launch-hardening/prd.md)
- [launch-reset.md](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/docs/exec-plans/current/lti-launch-hardening/launch-reset.md)
- [requirements.yml](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/docs/exec-plans/current/lti-launch-hardening/requirements.yml)
- [lti_controller.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/controllers/lti_controller.ex)
- [delivery_web.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/delivery_web.ex)
- [router.ex](/Users/eliknebel/Developer/oli-torus/.worktrees/lti-launch-hardening-and-telemetry/lib/oli_web/router.ex)
