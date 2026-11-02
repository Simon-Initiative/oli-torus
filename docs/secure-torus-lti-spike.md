# Secure Torus LTI recognition

The original deployment-wide spike gate has been replaced by resource policy and
session-local admission. `TORUS_SEB_REQUIRED_LAUNCHES` is obsolete and ignored.
Do not use it to configure secure delivery.

## Configuration and entry

`SUPPORTS_SECURE_DELIVERY=true` enables instance support; it defaults to false.
An authorized instructor can mark a graded assessment `secure_delivery=true`
through Assessment Settings. Only that assessment requires secure delivery.
Ordinary course launches and independent browser sessions remain ordinary.

Keep instance support disabled until the Moodle/SEB deployment has passed the
rollout checks below. Enabling support activates both verified admission and the
instructor's secure-delivery control; there is no separate readiness flag.

The initial adapter accepts a direct resource launch from the Moodle SEB plugin.
After normal LTI signature, state, nonce, registration and deployment checks, the
current signed custom claim must contain:

- `torus_resource_type`: exactly `page`.
- `torus_resource_id`: the selected page's revision slug.
- `secure_delivery`: exactly `seb`.
- `secure_activity_id` and `seb_configuration_id`: non-empty strings.
- `secure_verified_at`: decimal Unix seconds, no more than 300 seconds old or
  30 seconds in the future.

Torus binds the current learner, context, registered deployment and selected
section resource. It rechecks capability, graded policy and enrollment while
issuing a scoped token transactionally. The cookie is installed only after commit.
Missing or invalid evidence on a protected target fails without issuing a token;
unprotected ordinary entry does not depend on the secure assertion or former selector.

This verifies the LMS-signed assertion, not independent or continuous browser
attestation. No new diagnostic-bypass exclusion or replay store is introduced;
existing LTI validation and assertion freshness remain mandatory.

## Session lifecycle

A secure token confines only its own browser session. Other tokens are not revoked
or confined. Secure entry clears this browser's remember-me cookie. Reload and
reconnect use the same persisted scope and existing authentication expiry.

Required research consent remains available during secure entry, with its return
destination restricted to the scoped assessment. Course welcome onboarding and
required course surveys are deferred in the matching scoped section; secure entry
does not mark either requirement complete. Ordinary sessions retain those redirects.

`POST /secure-assessment/exit` requires normal browser CSRF protection, revokes only
the presented token, disconnects its LiveView/channel connections, and redirects
to a minimal signed-out page. Exit never submits an unfinished attempt. A later
secure launch can resume under existing attempt rules. Closing the browser is not
treated as a reliable server-side revocation event and cannot lock out other sessions.

Bounded telemetry uses `[:oli, :secure_assessment, :admission]` and
`[:oli, :secure_assessment, :exit]`. No claims, tokens, configuration identifiers,
answers or learner/resource IDs are metric dimensions.

Implementation and automated verification are recorded in
`docs/exec-plans/current/secure-assessment/pr6-extraction.md`.

## Rollout verification

Use `guides/lti/moodle-local.md` for local Moodle HTTPS trust and setup. Before
enabling support in a production instance, verify the deployed Moodle plugin's
signed assertion contract with real SEB launches. Exercise secure entry, unfinished
attempt resume, submission, permitted review, exit, a later secure relaunch, and LMS
grade passback. Confirm missing/invalid assertions fail on protected pages and that
ordinary launches and independent browser sessions continue to work.

Torus trusts the Moodle plugin to emit the assertion only after its SEB checks.
Moodle plugin changes are maintained separately from this repository.
