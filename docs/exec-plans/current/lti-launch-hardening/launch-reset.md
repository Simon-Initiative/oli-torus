# LTI Launch Reset

## Purpose

This note reframes the current LTI work as a launch-lifecycle redesign, not a sequence of tactical fixes.
The immediate goal is to make the launch flow deterministic in embedded LMS contexts.
The broader goal is to reduce the number of critical steps that depend on browser-managed cross-site cookies or Phoenix session state.

## What Should Happen

An ideal LTI 1.3 launch in Torus has five clear stages:

1. LMS initiates login against Torus using the tool OIDC initiation endpoint.
2. Torus validates the registration/deployment boundary and creates a short-lived launch attempt record.
3. Torus redirects the browser to the LMS authorization endpoint with Torus-owned state and nonce.
4. LMS posts the signed `id_token` back to Torus.
5. Torus validates the launch, provisions the user/session, resolves the section from the validated launch context, and redirects directly into the target experience.

In that model:

- The current launch request is the authoritative source of truth for routing.
- User-facing registration/recovery/error pages are side flows, not part of the critical security boundary.
- Cross-origin browser behavior may affect convenience, but it should not be the primary state carrier for launch correctness.

## Why The Current Flow Feels Broken

The current implementation mixes three state transport models:

- session-backed launch state
- signed launch state
- browser/client-storage-assisted recovery behavior

It also uses the browser session for adjacent flows that are reached from the embedded launch path:

- invalid registration redirects
- registration form rendering
- registration form submission CSRF
- authenticated redirect after launch

That creates a brittle system where one browser/storage quirk can surface as several different symptoms:

- missing issuer on the registration form
- CSRF failures on registration submit
- generic launch failure pages
- redirect to the user sign-in page after a nominally valid launch
- intermittent success on retry without any config change

Those are all signs that launch-critical and launch-adjacent state boundaries are not clearly separated.

## Design Principles

The target design should follow these principles:

- Server-owned launch state is authoritative.
- The current validated launch context is authoritative for immediate redirect decisions.
- Browser session state is an optimization and compatibility layer, not a required transport for launch correctness.
- Registration and recovery pages must tolerate missing browser session state.
- Error pages must be terminal and diagnostic, not intermediate.
- Each route should have one responsibility: login initiation, launch completion, registration capture, or recovery.

## Target Architecture

### 1. Explicit Launch Attempt Boundary

Introduce a first-class launch attempt model owned by Torus.
This can be a signed token, a database row, or a hybrid, but it must have one contract:

- created at `/lti/login`
- resolved exactly once at `/lti/launch`
- carries only launch-correlation fields
- records flow path and outcome classification

Preferred contents:

- `state`
- `nonce`
- `issuer`
- `client_id`
- `deployment_id` hint
- `target_link_uri`
- `flow_mode`
- `request_id`
- `expires_at`
- `status`

### 2. Clean Route Separation

The route contract should be:

- `/lti/login`
  - validates initiation inputs
  - creates launch attempt
  - chooses legacy vs storage-assisted path
  - redirects or renders helper
- `/lti/launch`
  - completes validation
  - provisions user/session
  - redirects from validated launch context
  - renders only terminal launch errors
- `/lti/register_form`
  - purely registration UI
  - receives issuer/client/deployment explicitly
  - does not assume embedded session continuity
- `/lti/register`
  - purely pending-registration capture
  - does not rely on CSRF/session state from an LMS iframe
- `/lti/launch/recover` or helper-specific endpoint
  - limited to storage-assisted recovery
  - never performs business routing on its own

### 3. LaunchContext As The Redirect Contract

Post-launch redirect behavior should depend only on a normalized `LaunchContext` built from the validated `id_token`.

That context should include:

- issuer
- client_id
- deployment_id
- context_id
- resource_link_id
- roles
- presentation hints
- service endpoints relevant to section updates

Nothing in the immediate redirect path should consult a user-global "latest launch" record.

### 4. Registration As A Separate Onboarding Flow

Registration should not be treated as a launch-state recovery mechanism.

When launch reaches an unknown registration or deployment:

- Torus should classify that explicitly.
- Torus should route to registration with explicit parameters on the URL or in a signed onboarding token.
- The registration flow should preserve enough context to prefill correctly, but it should not reuse launch-session assumptions.

### 5. Error Taxonomy With Stable Terminal States

Every failed launch should resolve to one stable classification:

- invalid registration
- invalid deployment
- missing state
- mismatched or consumed state
- launch validation failed
- storage blocked
- launch handler failure

Each classification should have:

- user-facing copy
- structured telemetry
- operator-facing logging metadata
- a clear terminal rendering path

## Recommended Restructure

### A. Make Launch State Single-Source

Pick one primary launch-state mechanism and demote the others to compatibility layers.

Recommendation:

- primary: Torus-owned launch attempt record keyed by `state`
- compatibility: signed envelope and/or session mirror if needed for staged migration

Why:

- easier to reason about replay and expiry
- easier to classify consumed/missing/mismatched state
- easier to instrument and debug
- avoids spreading launch correctness across cookies, helper pages, and controller assumptions

### B. Stop Using Session As A Required Transport In Embedded Flows

Session may still exist, but embedded launch correctness should not depend on it for:

- registration prefill
- registration submit
- launch-state lookup
- immediate redirect after successful launch

### C. Make The Browser Helper Optional And Narrow

The helper page should exist only to assist LMS/browser constraints around login initiation.
It should not be asked to recover unrelated registration or routing state.

### D. Decouple User Session Creation From Immediate Redirect Failure Analysis

When `/lti/launch` succeeds, Torus should log whether:

- launch validation succeeded
- user session cookie was written
- next redirect target was generated

That gives a clean way to distinguish:

- handshake failure before session creation
- successful launch but lost authenticated redirect

## Migration Plan

### Phase 0: Freeze and Observe

- Stop adding more local fixes that increase session coupling.
- Add instrumentation around:
  - login initiation
  - launch attempt creation
  - launch attempt resolution
  - session creation after valid launch
  - post-launch redirect target
- Capture real failure classifications in dev/staging before more changes land.

### Phase 1: Canonical Launch Attempt Model

- Introduce `LaunchAttempt` as the canonical launch boundary.
- Create it during `/lti/login`.
- Resolve it during `/lti/launch`.
- Record status transitions: `pending`, `validated`, `consumed`, `failed`, `expired`.
- Keep current session/signed-state behavior only as compatibility while this lands.

Exit criteria:

- All launch classifications can be explained in terms of launch-attempt state.
- `/lti/launch` no longer needs to guess between multiple authoritative state sources.

### Phase 2: LaunchContext-Only Redirect Path

- Normalize validated claims into `LaunchContext`.
- Make immediate redirect decisions exclusively from `LaunchContext`.
- Remove `get_latest_user_lti_params/1` and similar stale-context lookups from launch-driven routing.

Exit criteria:

- A successful launch is routed entirely from current validated claims.

### Phase 3: Separate Registration From Launch State

- Treat invalid registration/deployment as onboarding failures, not launch-state failures.
- Move registration prefill inputs onto explicit request params or a signed onboarding token.
- Ensure registration GET and POST are independently functional in embedded contexts.

Exit criteria:

- Registration works even when the browser drops embedded session state.

### Phase 4: Simplify Login Initiation Paths

- Keep one legacy path and one storage-assisted path.
- Remove any overlapping fallback logic that reintroduces ambiguity.
- Ensure helper-page logic is limited to launch initiation concerns.

Exit criteria:

- `/lti/login` chooses exactly one flow per request.
- Each flow has a deterministic next hop and error contract.

### Phase 5: Harden Successful Launch To Section Redirect

- Verify user session establishment independently from launch validation.
- Add diagnostics for authenticated redirect failure versus launch failure.
- If needed, introduce a signed post-launch handoff route that can complete auth/redirect without relying on immediately replayed cross-site cookies.

Exit criteria:

- We can tell whether a failed learner landing page is a launch failure or a post-auth cookie/session failure.

### Phase 6: Remove Transitional Complexity

- Remove obsolete session-only launch assumptions.
- Remove compatibility branches that no longer serve real traffic.
- Update docs and admin/support guidance to match the final flow.

Exit criteria:

- There is one documented launch lifecycle and the code matches it.

## Immediate Next Steps

Before resuming feature work, the codebase should answer these questions explicitly:

- What is the single authoritative launch-state source today?
- Which routes in the current launch+registration journey still require session continuity?
- Which failures happen before valid `id_token` validation versus after valid user/session creation?
- Which LMS/browser combinations require the storage-assisted path in practice?

## Decision

Treat LTI launch recovery, registration recovery, and authenticated post-launch redirect as three separate problems with separate contracts.
The current flow feels broken because those contracts are partially merged.
The migration path should reduce coupling first, then optimize compatibility behavior.
