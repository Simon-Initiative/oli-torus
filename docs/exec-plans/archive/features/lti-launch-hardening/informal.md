# Informal Work Summary: LTI Cookieless Launch Support, Lifecycle Hardening, and Telemetry

## Why this work exists

Torus currently has an LTI 1.3 launch flow that behaves unreliably in embedded LMS contexts when browser privacy controls interfere with third-party or iframe cookie behavior. The main failure pattern is that launch correctness, registration onboarding, and the post-authenticated landing path still depend too heavily on browser-managed session continuity.

Observed symptoms include:

- intermittent launch failures that recover on retry without configuration changes
- launches that land on the Torus sign-in page instead of the intended authenticated destination
- registration onboarding context being lost mid-flow
- registration submission failures caused by embedded session or CSRF assumptions
- user-facing failures that do not clearly distinguish browser-state problems from LMS configuration problems

We also need stronger operational evidence for a second class of reliability issue around intermittent keyset lookup failures during token validation. Those failures appear launch-adjacent, are hard to diagnose in production, and need better telemetry even if the root cause ends up outside the new state-transport design.

## Design intent

This work should redesign the Torus LTI launch lifecycle around one authoritative server-owned per-launch state boundary.

That means:

- `/lti/login` creates a canonical launch attempt with explicit lifecycle state
- `/lti/launch` resolves and consumes that launch attempt as the single authority for the current launch
- immediate post-launch routing is driven only by the current validated launch context
- registration onboarding remains a separate flow and is decoupled from launch-state transport assumptions
- helper and recovery behavior is intentionally narrow rather than acting as a hidden secondary state system

The design should support standards-aligned cookieless or storage-assisted embedded launch behavior where the LMS advertises it, using the 1EdTech client-side OIDC guidance and platform-specific Brightspace/D2L guidance as inputs.

## What good looks like

An ideal hardened launch lifecycle should behave like this:

1. The LMS initiates `/lti/login`.
2. Torus creates a durable launch attempt that stores correlation data, state, nonce, flow mode, and expiry in a server-owned boundary that works in multi-node deployments.
3. Torus chooses the correct continuation path:
   - storage-assisted embedded flow when supported
   - existing server-session path when still valid and appropriate
   - stable recovery or terminal error when the launch cannot proceed safely
4. The LMS submits the authenticated launch to `/lti/launch`.
5. Torus validates the launch using `lti_1p3`, classifies the lifecycle outcome, provisions the session, and routes immediately from the current validated launch context.

If the launch cannot proceed:

- invalid registration and invalid deployment should land in explicit onboarding or admin-resolution outcomes
- missing, mismatched, expired, consumed, or storage-blocked launch attempts should produce stable classified failures
- post-authenticated landing failures should be distinct from launch-validation failures

## Core product requirements to preserve

- `lti_1p3` remains the lower-level validation and protocol layer
- any temporary changes against `.vendor/lti_1p3` during development must be merged upstream and released as `lti_1p3` `0.12.0` before the final Torus PR ships
- the final Torus PR must restore `mix.exs` to the Hex dependency, not the vendored path dependency
- immediate redirect behavior must stop consulting `get_latest_user_lti_params/1`; that function should be removed or deprecated

## Stable failure categories needed

The redesigned flow should classify failures into stable terminal categories, including:

- invalid registration
- invalid deployment
- missing state
- mismatched state
- expired or already-consumed launch state
- storage blocked or unavailable
- launch validation failure
- launch handler failure
- post-auth landing failure

These categories should map consistently to:

- user-facing error pages
- logs
- telemetry
- support and admin diagnosis

## Observability intent

This work should materially improve launch telemetry and logging so production failures can be attributed to exact lifecycle stages and non-sensitive metadata, including:

- launch path chosen
- embedded versus top-level context when detectable
- launch-attempt identifiers and lifecycle outcome
- failure classification
- current request correlation and recovery path usage
- keyset lookup and `kid` mismatch diagnostics without leaking secrets or raw tokens

## External references

- 1EdTech client-side OIDC guidance: `https://www.imsglobal.org/spec/lti-cs-oidc/v0p1`
- Brightspace/D2L cookie guidance: `https://community.d2l.com/brightspace/kb/articles/27427-lti-cookie-problem-windows-postmessage-solution`
