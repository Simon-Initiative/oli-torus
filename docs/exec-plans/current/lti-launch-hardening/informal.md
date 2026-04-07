# Informal Work Summary: LTI Launch and Registration Reset

## Why this work exists

The current Torus LTI registration and launch flow has become difficult to reason about and appears fragile in real LMS usage. We have seen multiple classes of failures that suggest the flow is too dependent on browser-managed cross-site session continuity and that several adjacent concerns are coupled together in ways that make the system brittle.

This work is also grounded in the formal standards and platform guidance around cookie-restricted embedded LTI launches:

- The 1EdTech implementation guide for LTI OIDC Login with LTI Client Side postMessages explains that OIDC launch validation normally relies on cookies, but iframe-based LTI launches can fail when those cookies are blocked, and describes a browser-message-based state/nonce transport as the standards-aligned alternative.
- D2L/Brightspace has published platform guidance describing the same class of cookie problem and the corresponding `window.postMessage`-based solution for embedded LTI launches.

Observed issues include:

- registration form context being lost in embedded LMS launches
- CSRF/session failures during registration submission
- intermittent launch failures that recover on retry without configuration changes
- launches sometimes ending at the Torus sign-in page rather than the intended authenticated landing
- production reports of keyset cache lookup failures where a key appears present in cache but launch validation still reports the `kid` as missing

The goal is not to keep patching symptoms one at a time. The goal is to redesign the launch lifecycle so that it is explicit, deterministic, diagnosable, and less dependent on iframe/browser cookie behavior.

## High-level intent

We want to restructure the Torus LTI flow around a few clear ideas:

- launch state should have a single authoritative server-owned boundary
- the current validated launch should be the only authority for immediate post-launch routing
- registration should remain an onboarding flow, but be technically decoupled from launch-state transport assumptions
- helper/recovery paths should be narrow and should not become general-purpose state transport layers
- launch failures, registration failures, and post-auth landing failures should be separate categories with separate diagnostics

## What “good” looks like

An ideal Torus LTI launch should work like this:

1. The LMS initiates login against Torus.
2. Torus creates a launch attempt with state/nonce and enough correlation data to finish the launch.
3. Torus redirects or uses a narrow helper path to continue the OIDC flow.
4. The LMS posts the signed launch back to Torus.
5. Torus validates the launch, provisions the user/session, resolves the section from the validated launch context, and redirects directly into the intended experience.

If the launch cannot proceed:

- invalid registration/deployment should move into onboarding/admin resolution
- blocked/missing launch state should produce a stable launch recovery or error outcome
- successful launch followed by a failed authenticated landing should be distinguishable from a true launch failure

## Core redesign themes

### 1. Canonical launch state

We want one canonical launch-state mechanism.

This boundary should:

- be created during `/lti/login`
- be resolved during `/lti/launch`
- track state, nonce, initiation metadata, expiry, flow mode, and outcome
- support deterministic classification of missing, mismatched, consumed, or expired launches

Whether the implementation is database-backed, signed-token-backed, or hybrid can be decided during design, but the codebase should have one documented authority.

This should be evaluated in the context of the client-side OIDC and postMessage guidance from the 1EdTech spec rather than as an ad hoc Torus-only workaround.

### 2. Current validated launch context drives redirect behavior

We want immediate redirect behavior after launch to be driven only by the current validated launch claims in the current request.

We do not want immediate LTI redirect behavior to depend on user-global “latest launch” persistence.

### 3. Registration is technically decoupled from launch-state transport

Registration remains an onboarding flow, not part of LTI validation itself. But today it is still reached through launch failure handling and has inherited some browser/session assumptions from that path.

We want registration to:

- receive its needed context explicitly
- work in embedded LMS conditions
- not rely on launch session continuity
- not rely on launch recovery or helper behavior to function

### 4. Error contracts are explicit

We want stable, terminal classifications for:

- invalid registration
- invalid deployment
- missing state
- mismatched or consumed state
- storage/cookie blocked
- launch validation failure
- launch handler failure
- post-auth landing/session continuity failure

These should map cleanly to user-facing copy, logs, and telemetry.

The cookie-related classifications in particular should remain aligned to the standards and platform framing:

- embedded launches may fail because browser cookies are unavailable
- platforms may advertise storage-assisted launch behavior using `lti_storage_target`
- tools may need to use `postMessage` storage semantics to preserve OIDC state and nonce in iframe contexts

### 5. Keyset/key provider correctness is part of launch reliability

This work should also capture the need to investigate and harden the keyset cache / key provider path.

There is a production issue where launches intermittently fail with a missing `kid` error even though the corresponding key appears present in the keyset cache. This has been reported for a subset of Brightspace users.

We want:

- better telemetry and structured logging around cache lookups and misses
- exact capture of lookup URL, requested `kid`, available cached `kid`s, cache age/TTL, and cached key shape
- investigation into whether the issue is caused by lookup mismatch, representation mismatch, stale overwrite, or another correctness bug

This should be treated as a launch-adjacent reliability problem at the protocol validation boundary.

## Dependency and library intent

### `lti_1p3`

We expect to keep using `lti_1p3` as the lower-level protocol and validation library.

If changes are needed during implementation, they can be made against the checked-out library under `.vendor/lti_1p3` while developing.

Before the final Torus PR is submitted:

- required `lti_1p3` changes should be merged upstream
- a new `lti_1p3` release should be cut as version `0.12.0`
- Torus should revert `mix.exs` back to using the released Hex dependency rather than the local path

## Expected outcomes

By the end of this effort, we want:

- a launch lifecycle that can be described cleanly and implemented consistently
- reduced dependence on browser session continuity in embedded LMS flows
- launch, onboarding, and authenticated landing treated as separate runtime concerns
- strong observability around flow selection and failure classification
- enough production diagnostics to isolate persistent keyset-cache/key-provider failures
- a clear dependency story around `lti_1p3`

## External context references

- 1EdTech implementation guide: `https://www.imsglobal.org/spec/lti-cs-oidc/v0p1`
  - This guide explains the cookie problem in embedded OIDC launch flows and the client-side postMessage storage approach for state and nonce.
- Brightspace context article: `https://community.d2l.com/brightspace/kb/articles/27427-lti-cookie-problem-windows-postmessage-solution`
  - This is useful platform-specific context for the Brightspace/D2L browser-cookie issue and the Windows postMessage-based mitigation approach.

## Useful inputs for regenerated planning docs

If this document is transplanted to another branch and used to regenerate planning artifacts, the new PRD/FDD/plan should explicitly cover:

- launch-state redesign around a canonical launch attempt boundary
- routing from current validated launch context only
- registration decoupling from launch-state transport assumptions
- helper/recovery path narrowing
- stable launch/onboarding/post-auth error taxonomy
- keyset cache / key provider diagnostics and investigation
- `.vendor/lti_1p3` to Hex-release workflow
