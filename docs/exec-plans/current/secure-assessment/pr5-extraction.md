# PR 5: Restricted assessment navigation and layout

This extraction starts from master after PR 4 (#6909). The reference implementation
is `secure-assessment-prototype`; only assessment presentation and its tests move
into this PR.

`OliWeb.Components.SecureAssessment.restrict_navigation?/1` derives the presentation
contract from the authenticated, server-held session scope. There is no instructor
setting or public launch parameter for this contract. PR 4 remains responsible for
authorization, revocation, and the CSRF-protected exit endpoint.

The shared shell supplies one assessment landmark, a keyboard skip link, flash
messages, and a POST exit form. Basic prologue, lesson, and review layouts omit
course navigation, outline/notes panels, assistant access, and unrelated controls.
Blocking messages retain their explanation without a support link out of the
assessment.

Scoped adaptive delivery uses the native renderer even when the page requests
course chrome, avoiding nested assessment shells in an iframe. Adaptive parameters
remove adjacent-page destinations and keep fallback destinations on the same
assessment prologue. The assistant bridge is disabled by the server-derived
`restrictNavigation` prop. Attempt content, timers, submission, review, and state
remain available. Protected adaptive review omits the assistant for ordinary
sessions too, because model authorization does not permit that child to mount.
Ordinary sessions retain the existing course layouts and navigation.

Verification covers scoped basic and adaptive lessons, adaptive pages configured
with course chrome, both basic review modes, adaptive review with persisted state,
gated and ungated prologues, keyboard landmarks, CSRF form fields, ordinary-session
navigation, and the existing exit/revocation authorization regression suite.
Production Moodle/SEB admission and editable-setting activation belong to PR 6.

## Verification results

- Delivery prologue, lesson, review, and scoped authorization suites: 227 tests,
  zero failures.
- Legacy page controller and view suites: zero failures (39 pre-existing excluded
  cases).
- Adaptive height, assistant bridge, and lesson-finished dialog suites: 13 tests,
  zero failures.
- Changed TypeScript passes ESLint and Prettier; the diff passes whitespace checks.
- Security and performance review followed `.review/security.md` and
  `.review/performance.md`; the presentation contract adds no database queries and
  uses the existing CSRF-protected, session-specific exit endpoint.

Browser-level visual and screen-reader checks were not performed.
