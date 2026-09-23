# Secure Torus LTI recognition

The original deployment-wide spike gate has been replaced by resource policy and
session-local admission. `TORUS_SEB_REQUIRED_LAUNCHES` is obsolete and ignored.
Do not use it to configure secure delivery.

## Configuration and entry

`SUPPORTS_SECURE_DELIVERY=true` enables instance support; it defaults to false.
An authorized instructor can mark a graded assessment `secure_delivery=true`
through Assessment Settings. Only that assessment requires secure delivery.
Ordinary course launches and independent browser sessions remain ordinary.

Keep instance support disabled for rollout until the secure-assessment execution
plan's renderer, dependency, review and integration work is complete.

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

`POST /secure-assessment/exit` requires normal browser CSRF protection, revokes only
the presented token, disconnects its LiveView/channel connections, and redirects
to a minimal signed-out page. Exit never submits an unfinished attempt. A later
secure launch can resume under existing attempt rules. Closing the browser is not
treated as a reliable server-side revocation event and cannot lock out other sessions.

Bounded telemetry uses `[:oli, :secure_assessment, :admission]` and
`[:oli, :secure_assessment, :exit]`. No claims, tokens, configuration identifiers,
answers or learner/resource IDs are metric dimensions.

Implementation and verification: see
`docs/exec-plans/current/secure-assessment/phase-4-execution.md`.
Manual SEB/Moodle/Torus and grade-passback validation remain required before rollout.
