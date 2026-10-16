# PR 6: Moodle/SEB verified launch integration

## Base and scope

This worktree starts from `feat/secure-assessment-restricted-layout` at
`b89bfaeb99`. It extracts the final verified-launch behavior from
`secure-assessment-prototype` while preserving the integration base's launch
identity validation, deployment-aware section resolution, role parsing, security
headers, and ordinary launch regression tests.

## Implementation

- `lib/oli/lti/secure_launch.ex` validates Moodle's signed SEB assertion after
  ordinary LTI validation and binds it to the authenticated learner, registered
  deployment, section context, and resolved graded section resource.
- `lib/oli_web/lti_redirect.ex` resolves authoritative section resources, locking
  the selected row inside the launch transaction. Legacy projection migration is
  retained. Older LMS revision slugs still resolve through resource identity to
  the section's currently published revision.
- `lib/oli_web/controllers/lti_controller.ex` performs user/enrollment updates,
  target resolution, admission, policy/enrollment recheck, and token insertion in
  the transaction. It installs the token only after commit and redirects using
  the same resolved destination. Rejections preserve existing browser credentials
  and other sessions.
- `lib/oli/lti/launch_errors.ex` adds confined launch errors. Admission telemetry
  contains only bounded outcome/classification labels, without assertions, tokens,
  learner IDs, or configuration identifiers.
- `Oli.Delivery.SecureAssessments.settings_available?/0` now follows instance
  capability. `SUPPORTS_SECURE_DELIVERY` still defaults to false; the intermediate
  readiness gate is removed now that verified entry is implemented.
- `docs/secure-torus-lti-spike.md` documents the current assertion contract,
  session lifecycle, capability activation, trust boundary, and rollout checks.
  The obsolete execution-record reference is removed.

## Verification

- Secure assertion, LTI controller, direct-link resolver, assessment settings,
  capability, and transactional admission suites: 147 tests, zero failures.
- Existing scoped account, authorization, prologue, lesson, and review suites
  against the assembled branch: 231 tests, zero failures.
- Checks include valid/missing/stale/future/malformed assertions, invalid JWTs,
  wrong target/deployment, ungraded targets, disabled capability, actual database
  insertion failure, ordinary course/direct launches, remember-me clearing,
  credential preservation, and telemetry/log redaction.
- Formatting and whitespace checks pass. Security/performance review follows
  `.review/security.md` and `.review/performance.md`. Authoritative target lookup
  uses a bounded query; token insertion remains under the selected-resource lock.

## Rollout boundary

Real Moodle/SEB launch, resume, submission, review, exit, relaunch, and grade-passback
checks were not performed in this extraction. Keep instance capability disabled
until these are verified with the deployed Moodle plugin using the setup in
`guides/lti/moodle-local.md`. The plugin is maintained outside this repository.
Torus trusts Moodle's signed assertion and does not independently attest SEB or
continuously verify the browser.
