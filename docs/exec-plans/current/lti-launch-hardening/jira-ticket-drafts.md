# Jira Ticket Drafts: LTI Launch Hardening

## Ticket 1

### Title
LTI cookieless launch support, launch lifecycle hardening, and improved launch telemetry/error handling

### Type
Epic or large Story

### Summary
Redesign the Torus LTI launch lifecycle so embedded LMS launches do not rely on cross-site cookie continuity as the only state transport, while improving launch observability and making failure states stable and diagnosable.

### Detailed Description
Torus currently has an LTI launch flow that appears fragile in embedded LMS contexts, especially when browser privacy controls interfere with third-party or iframe cookie behavior. We have seen a mix of symptoms that suggest launch state, registration onboarding, and post-authenticated landing are too tightly coupled to browser-managed session continuity.

These failures show up as:

- intermittent launch failures that recover on retry without configuration changes
- launch flows that land on the Torus sign-in page instead of the intended authenticated destination
- registration form issues when launch-derived context is lost
- registration submission failures caused by embedded session/CSRF assumptions
- ambiguous user-facing error states that do not clearly distinguish browser/session problems from LMS configuration problems

We want to redesign the launch flow around a single authoritative server-owned per-launch state boundary. The current validated launch should become the only authority for immediate post-launch routing. Registration onboarding should remain a separate flow, but it should be technically decoupled from launch-state transport assumptions. Error pages and recovery handling should be stable, terminal, and explicitly classified.

This work should be informed by:

- 1EdTech LTI Client Side OIDC guidance: `https://www.imsglobal.org/spec/lti-cs-oidc/v0p1`
- Brightspace/D2L context on cookie problems and postMessage-based mitigation: `https://community.d2l.com/brightspace/kb/articles/27427-lti-cookie-problem-windows-postmessage-solution`

The design should continue to use `lti_1p3` as the lower-level validation/protocol layer. If changes are needed in the library, they can be implemented against the checked-out copy in `.vendor/lti_1p3` during development, but before the final Torus PR is submitted those changes must be merged upstream, released as `lti_1p3` `0.12.0`, and Torus must revert `mix.exs` back to using the Hex package.

### Goals
- Support standards-aligned cookieless / storage-assisted embedded LTI launch behavior.
- Reduce reliance on browser session continuity for launch correctness.
- Ensure immediate post-launch routing uses the current validated launch context only.
- Separate launch failure, onboarding failure, and post-auth landing failure into explicit categories.
- Improve launch telemetry and logging so production failures can be attributed to specific lifecycle stages.
- Ensure launch failures render stable, actionable user-facing error states.

### Scope
- `/lti/login` and `/lti/launch` lifecycle redesign
- canonical per-launch state mechanism
- immediate redirect behavior driven only by the current validated launch
- helper/recovery path simplification and narrowing
- launch failure classification and user-facing error rendering
- launch lifecycle logging and telemetry improvements
- registration/onboarding decoupling where required by the launch redesign
- any required coordinated changes to `.vendor/lti_1p3`

### Out of Scope
- keyset-cache correctness investigation beyond the telemetry/hooks needed for general launch observability
- broad LMS administration UX redesign outside the necessary launch/onboarding flow changes

### Dependencies / Notes
- May require coordinated upstream `lti_1p3` changes.
- Final Torus PR must not ship with the `.vendor/lti_1p3` path dependency in place.
- Should be treated as the primary architecture workstream in this initiative.

### Acceptance Criteria
- Embedded launches that advertise the supported storage-assisted capability no longer depend on the Phoenix session cookie as the only launch-state transport.
- Launch routing uses the current validated launch context and does not consult `get_latest_user_lti_params/1` in the immediate launch redirect path.
- Launch failures are classified into stable categories such as invalid registration, invalid deployment, missing state, mismatched state, storage blocked, validation failure, or launch handler failure.
- User-facing launch errors are stable, sanitized, and do not redirect into unrelated 404 or sign-in experiences when the launch itself has already failed.
- Logging and telemetry clearly identify launch path, failure classification, and relevant non-sensitive lifecycle metadata.
- Any `lti_1p3` changes required for this work are released upstream as `0.12.0`, and Torus is restored to the Hex dependency before the final PR.

## Ticket 2

### Title
Fix LTI registration form prepopulation and embedded registration flow reliability

### Type
Bug

### Summary
Ensure the “Register Your Institution” flow correctly prepopulates and preserves LMS-supplied registration context such as issuer, client ID, and deployment ID, and remains functional in embedded LMS contexts.

### Detailed Description
The institution registration flow is part of the onboarding path used when Torus receives an LTI launch for an unknown registration or deployment. Although registration is an onboarding flow rather than launch validation itself, it still relies on launch-derived context in order to prepopulate the form correctly and provide the administrator with the right values.

We have already seen failures where this flow broke because embedded LMS/browser conditions caused context to be lost between the launch failure and the registration form:

- the registration form did not preserve or use the LMS-provided issuer
- selecting LMS defaults could fail because expected values were missing
- registration form submission could fail in embedded contexts due to session/CSRF assumptions

This ticket should capture the work required to make registration prepopulation reliable and explicit. The registration flow should preserve and use LMS-supplied details such as issuer, client ID, and deployment ID in a way that does not depend on embedded session continuity. The form should render, prefill, and submit successfully when reached from an LMS launch failure path.

This ticket should also capture the distinction that registration is onboarding and should have its own stable transport contract, rather than borrowing launch-state/session assumptions.

### Goals
- Preserve LMS-provided issuer, client ID, and deployment ID when routing into registration.
- Ensure the registration form prepopulates correctly from launch-derived onboarding inputs.
- Make the registration GET and POST flows functional in embedded LMS/browser contexts.
- Avoid browser console/runtime failures caused by missing prepopulation data.

### Scope
- registration failure redirect path from LTI launch/login
- registration form prepopulation inputs
- registration form rendering behavior
- registration submission behavior in embedded contexts
- regression coverage for launch-to-registration onboarding transitions

### Out of Scope
- the full cookieless launch lifecycle redesign
- keyset cache correctness investigation
- broader institution administration UX changes outside this onboarding flow

### Dependencies / Notes
- This ticket complements the broader launch-hardening work but should be tracked independently because the registration flow has its own behavior and failure modes.
- If the registration prepopulation and embedded-flow fixes are already implemented in a branch, this ticket should still exist to represent the work and its regression coverage explicitly.

### Acceptance Criteria
- When an LTI login or launch fails due to invalid registration or deployment, Torus carries issuer, client ID, and deployment ID into the registration onboarding flow explicitly.
- The “Register Your Institution” form prepopulates using LMS-provided values where appropriate.
- Selecting LMS defaults on the registration form does not fail because prepopulation context is missing.
- Registration form submission succeeds in embedded LMS conditions without relying on fragile session continuity assumptions.
- Automated regression coverage exists for the registration onboarding path.

## Ticket 3

### Title
Investigate and fix LTI keyset cache / key provider lookup failures in production

### Type
Bug

### Summary
Investigate and resolve intermittent production launch failures where the requested `kid` is reported missing from the keyset cache even though the key appears present in the cached keyset, with current reports concentrated among a subset of Brightspace launches.

### Detailed Description
Production reports indicate that some Brightspace users intermittently fail to launch into Torus because the key provider reports that a `kid` cannot be found in the cached keyset, even though inspection of the cache appears to show that the key is present. Waiting for a background refresh does not reliably resolve the problem. Current reports suggest that only a minority of launches succeed for affected users.

Example symptom:

- launch validation reports that key `1d69a095-6f95-4513-9829-53c701158a99` cannot be found in the keyset cache
- inspection of the cache shows a JWK entry with the same `kid`

This suggests a correctness issue in the key lookup path rather than a simple refresh/TTL issue. Potential failure modes include:

- exact `key_set_url` mismatch between lookup and cached entry
- exact `kid` mismatch or normalization issue
- cached key representation mismatch (for example string-key versus atom-key maps)
- stale overwrite or lookup-path bug

We have already added better logging and telemetry around cache lookup behavior, including:

- requested `key_set_url`
- requested `kid`
- available cached `kid`s
- cache age and TTL
- cached key count
- cached key shape summary
- lookup result classification

This ticket should use that instrumentation to identify the true cause in production and then implement the fix at the correct boundary, whether that is in Torus’s cache/provider wrapper or in the underlying `lti_1p3` interaction boundary.

### Goals
- Reproduce or isolate the root cause of the intermittent `kid` lookup failure.
- Use production-safe telemetry/logging to identify whether the bug is caused by lookup mismatch, representation mismatch, or another correctness issue.
- Implement a durable fix.
- Add regression coverage for the discovered failure mode.

### Scope
- keyset cache lookup path
- key provider behavior
- Brightspace-specific launch context if it helps reproduction
- telemetry/logging needed to diagnose the problem
- regression tests for the resolved failure mode

### Out of Scope
- broader cookieless launch lifecycle redesign, except where shared instrumentation overlaps

### Dependencies / Notes
- This work should coordinate with the broader launch-hardening effort where telemetry/logging overlap.
- The final fix may land in Torus, `.vendor/lti_1p3`, or both depending on root cause.
- If the root cause is in `.vendor/lti_1p3`, the same upstream-release expectation applies: merge upstream, release, and restore Torus to the Hex dependency before final PR submission.

### Acceptance Criteria
- Production-safe logs/telemetry capture enough data to determine why a lookup missed when a key appeared present.
- The true root cause is identified and documented.
- A fix is implemented and covered by regression tests.
- Affected launches no longer fail because of false “kid not found in keyset cache” errors.
- If the fix requires `lti_1p3` changes, those changes follow the agreed `.vendor` to upstream release workflow.

## Ticket 4

### Title
Add LTI Dynamic Registration v1.0 support for Torus as an LTI tool

### Type
Story or Epic

### Summary
Implement tool-side support for LTI Dynamic Registration v1.0 so LMS administrators can register Torus using standards-based discovery and client registration instead of relying only on manual configuration.

### Detailed Description
Torus currently supports manual LTI 1.3 registration and onboarding flows, including a registration form and static developer-key style metadata for specific LMS integrations. However, it does not currently support the LTI Dynamic Registration v1.0 flow in which the platform initiates registration, the tool discovers the platform configuration from an `openid_configuration` URL, and the tool submits a standards-compliant client registration request to the platform’s `registration_endpoint`.

This means Torus can already act as an LTI tool for configured integrations, but it cannot yet participate in the standards-based automated registration flow defined by 1EdTech for LTI tools and platforms.

Supporting this requires adding a dedicated dynamic-registration path with clear separation of responsibilities:

- receive a platform-initiated registration request at a Torus tool endpoint
- validate and retrieve the platform’s OpenID configuration from the provided `openid_configuration` URL
- optionally use a provided `registration_token` when calling the platform registration endpoint
- build and submit a standards-compliant OIDC dynamic client registration payload with the LTI-specific tool configuration metadata
- persist the resulting registration details returned by the platform, including the issued `client_id` and any registration-specific metadata that Torus needs for later launches
- provide a completion experience that can notify the platform that registration is finished using the expected HTML5 `postMessage` close signal

This work should be aligned with the LTI Dynamic Registration v1.0 specification and should make deliberate decisions about how dynamic registration interacts with Torus’s existing registration approval and onboarding model.

Relevant specification:

- 1EdTech LTI Dynamic Registration v1.0: `https://www.imsglobal.org/spec/lti-dr/v1p0`

The design should continue to use `lti_1p3` as the lower-level protocol layer where appropriate. If generic dynamic-registration support is best implemented in the library, those changes can be made in `.vendor/lti_1p3` during development, but before the final Torus PR is submitted they must be merged upstream, released, and Torus must revert `mix.exs` back to using the Hex package.

### Goals
- Support standards-based LTI Dynamic Registration for Torus as an LTI tool.
- Reduce reliance on LMS-specific manual configuration paths where dynamic registration is supported.
- Ensure Torus can consume platform-provided discovery metadata and register itself correctly with the platform.
- Persist dynamic registration results in a form that is usable by subsequent LTI login and launch flows.
- Provide stable completion, logging, and error handling for the registration lifecycle.

### Scope
- tool-side registration initiation endpoint
- OpenID configuration discovery and validation
- client registration request construction and submission
- support for optional `registration_token`
- persistence of registration response data needed for later launches
- registration completion UX including the close-window `postMessage` signal
- logging and telemetry for the dynamic registration lifecycle
- any required coordinated changes to `.vendor/lti_1p3`

### Out of Scope
- implementing platform-side dynamic registration APIs for Torus as an LTI platform
- redesigning unrelated manual registration administration workflows beyond the changes needed to coexist with dynamic registration
- keyset cache investigation except where registration telemetry or persistence overlaps

### Dependencies / Notes
- This work should explicitly decide whether dynamically registered integrations become immediately active or enter an approval/pending state inside Torus.
- The existing static metadata output and manual registration workflow may still need to coexist with the new dynamic path.
- If generic discovery or registration client logic is added to `.vendor/lti_1p3`, the final Torus PR must not ship with the path dependency in place.

### Acceptance Criteria
- Torus exposes a tool-side endpoint that can receive a platform-initiated dynamic registration request containing `openid_configuration` and optional `registration_token`.
- Torus validates the supplied discovery URL and retrieves the platform OpenID configuration required for registration.
- Torus submits a standards-compliant client registration request to the platform’s `registration_endpoint`, including the required OIDC and LTI tool metadata.
- Successful registration responses are persisted with the data Torus needs for subsequent LTI login and launch handling.
- Registration failures are surfaced through stable, diagnosable error handling and logging.
- Successful completion can notify the platform using the expected close-window `postMessage` behavior.
- Automated coverage exists for successful registration, invalid discovery input, and failed registration responses.
- Any required `lti_1p3` changes follow the agreed `.vendor` to upstream release workflow before the final Torus PR is submitted.
