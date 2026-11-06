# GDPR compliance

## Cookie compliance requirements

- Receive users’ consent before you use any cookies except strictly necessary cookies.
- Provide accurate and specific information about the data each cookie tracks and its purpose in plain language before consent is received.
- Document and store consent received from users.
- Allow users to access your service even if they refuse to allow the use of certain cookies
- Make it as easy for users to withdraw their consent as it was for them to give their consent in the first place.

The Cookie Law does not require that records of consent be kept but instead, indicates that you should be able to prove that consent occurred — even if that consent has been withdrawn.

## Analytics consent implementation

Covered root layouts initialize consent before analytics, including chromeless lessons
without a footer. Analytics uses Basic Consent Mode: the GTM container and behavioral
events are blocked until explicit analytics acceptance. Advertising storage, user data
and personalization are always denied. Deployment and container requirements are in
`docs/runbooks/google-analytics.md`.

- A nonblocking banner names Google Analytics, links the configured Privacy Notice,
  and offers equally prominent Accept and Reject buttons plus Manage preferences.
- Both acceptance and rejection store a version-2 decision in `_cky_opt_choices` for
  365 days. `_cky_opt_in` records that a choice was made; it does not grant analytics.
- Missing, malformed, expired or older-version decisions deny analytics and prompt
  again. Existing functional preferences are preserved when analytics needs re-consent.
- Closing without choosing only sets the session cookie `_cky_opt_in_dismiss` for
  this policy version. It grants nothing and the banner can return in a later session.
- Desktop Cookie Preferences and the mobile `/cookie-preferences` page use the same
  browser storage, persistence and Consent Mode update path. Unsaved changes grant
  nothing. Saving updates the current page immediately without a reload.
- Signed-in withdrawals create an unacknowledged-denial marker in
  `_cky_pending_consent`, with session storage as a fallback when iframe cookies are
  blocked. That marker keeps measurement denied across navigation until the matching
  decision is confirmed by the server. Normal database precedence resumes afterwards.
  Failed saves expose an unsaved status and Retry action without enabling tracking.
- Manage preferences opens the detailed UI without dismissing an undecided banner.
  Cancelling returns to that banner; Close explicitly dismisses it for the session.
- Signed-in user choices are also stored in `consent_cookies`, with expiration and
  an updated audit timestamp. The database decision is authoritative at page load,
  including in LMS iframes that block third-party cookies. At login, a current browser
  decision replaces an outdated database decision; between current decisions the
  database wins. Author-only accounts use browser storage.
- Withdrawal blocks behavioral events immediately, disables configured GA4 measurement
  IDs and removes host-only and current-host `_ga` / `_ga_*` cookies. Parent-domain
  cookies remain intact because they may belong to sibling applications; legacy
  parent-domain cleanup requires an explicit, reviewed ownership allowlist. Necessary
  cookies remain enabled; no targeting choice or advertising use is offered.
- A blank `PRIVACY_POLICIES_URL` keeps measurement disabled. The default notice is
  the CMU Privacy Notice; deployments must review its applicability before rollout.
- Signed-in browsers that cannot retain either cookies or session storage keep
  measurement disabled. A temporary `_cky_consent_storage` necessary-cookie probe
  checks cookie availability only when session storage is unavailable, and is
  removed immediately.
