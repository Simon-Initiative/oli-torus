# Secure assessment: session-only confinement

Status: proposed implementation design, revised September 22, 2026. Documentation only; application changes are not implemented here.

## requirements

1. **Assessment setting:** Add a non-null `secure_delivery` boolean to `SectionResource`, defaulting to `false`. It may be enabled only for graded pages and has no student exceptions.
2. **Instance capability:** Read `SUPPORTS_SECURE_DELIVERY` as a runtime boolean, defaulting to `false` when unset.
3. **Settings visibility:** Display the **Secure Delivery** editable column in Assessment Settings only when `SUPPORTS_SECURE_DELIVERY=true`; otherwise omit it entirely.
4. **Settings enforcement:** Prevent users from enabling secure delivery on unsupported instances through any update, bulk or copy path. Preserve the setting through supported course copies and publication updates.
5. **Block ordinary-session assessment access:** When an assessment has `secure_delivery=true`, block student access to its prologue, delivery, attempt start/resume and answer/submission APIs from a normal launch or any session without matching secure admission. A normal LTI launch, course enrollment or direct URL is insufficient. Initially, admission requires a validated direct LTI resource launch for that exact page in its configured section, with Moodle's signed SEB verification assertion and instance support enabled. The only exception is permitted read-only review of submitted attempts (requirement 13); ordinary access to the rest of the course remains unaffected.
6. **Session-only confinement:** Restrict only the authentication session created by verified secure entry. Never attach confinement to the learner account, enrollment or assessment attempt.
7. **No cross-session lockout:** Secure sessions must never restrict or revoke another ordinary session or block an ordinary launch, in the same or another section, regardless of browser closure, abandonment, submission, expiry or dangling tokens.
8. **Ordinary launch independence:** A valid ordinary launch creates an ordinary session, even when the same browser supplies an old secure cookie. Existing secure sessions and saved launch history must not impose secure delivery on that launch.
9. **Assessment-only access:** The secure session may access only its assessment's prologue, delivery, permitted student review and required dependencies, plus authentication and exit operations.
10. **Server-side boundary:** Enforce the assessment boundary across page routes, legacy aliases, APIs, LiveViews and channels. Typed/pasted URLs and altered request identifiers must not bypass it.
11. **Assessment-only UI:** Remove course and unrelated navigation from the secure UI while retaining assessment controls, internal question/screen navigation, accessibility and exit.
12. **Both page types:** Support basic pages, including traditional and one-at-a-time modes, and adaptive pages for secure delivery and student REVIEW mode. LTI activities and superactivities embedded in assessments are out of scope; Moodle LTI admission and grade passback remain in scope.
13. **Ordinary student review:** Permit read-only review of submitted attempts in ordinary sessions under existing ownership, review and feedback rules, regardless of other secure sessions. Review must not enable answer changes or another attempt.
14. **Reload and resume:** Reload/reconnect must preserve valid session scope and saved work. A later secure launch must resume an unfinished attempt without consuming another attempt or resetting its timer.
15. **Independent attempt lifetime:** Abandoned and untimed attempts remain unfinished for later secure resume, subject to existing timing/auto-submit rules. They must never restrict ordinary course access.
16. **Exit without completion:** Permit logout/exit before or after submission, revoking only the current token and leaving unfinished work saved. No browser-close notification, heartbeat or cleanup task may be required to keep other sessions usable.
17. **Existing assessment rules:** Preserve enrollment, availability, passwords, prerequisites, accommodations, attempt limits, timing, grading and AGS passback behavior.
18. **Capability disabled:** Do not create new secure admissions when instance support is false or silently remove existing resource protection/token scope. Ordinary course access and permitted review remain independent.
19. **Launch-validation scope:** Retain existing LTI validation and SEB assertion freshness checks. Additional replay protection, diagnostic-bypass exclusion and a separate resource-binding registry are out of scope.
20. **Acceptance coverage:** Verify basic/adaptive delivery and review, server-side boundary enforcement, and ordinary-session isolation with live, abandoned, expired and dangling secure sessions in the same and different sections.
21. **Extensible secure entry:** Separate provider-specific entry verification from the shared secure-session model, confinement, assessment UI and lifecycle. Implement Moodle/SEB direct LTI entry initially; allow future Respondus LockDown Browser entry, including non-LTI flows, to establish the same scoped session without redesigning enforcement or weakening session isolation. Respondus integration itself is not part of this implementation.

## Required behavior

A page with `graded: true` and `secure_delivery: true` requires verified secure admission for that page. The initial supported entry mechanism is a validated direct LTI resource launch with SEB verified by Moodle's signed assertion. The resulting authentication session can access only that assessment's prologue, delivery, student review and necessary dependencies. Instance support is controlled at runtime by `SUPPORTS_SECURE_DELIVERY`; only supporting instances display the **Secure Delivery** Assessment Settings column.

**Confinement belongs exclusively to that authentication session. It never belongs to the student account, enrollment, section or assessment attempt.** This replaces the previous account-wide design and its lifetime/exit requirements.

Ordinary launches and existing ordinary sessions on other computers continue to work in both the same course section and other sections. They do not depend on whether the secure browser is open, closed, disconnected, abandoned, expired, or still represented by a database token. No close notification or cleanup task is needed to make ordinary access work.

Both **basic and adaptive pages** must support secure delivery and student **REVIEW mode**. Ordinary authenticated read-only review of submitted attempts is allowed under existing review and feedback rules, even while a separate secure session exists. An ordinary session cannot start or resume a protected assessment; that is the resource's intended access rule, not a lockout of the student's course access.

### The no-lockout invariant

For a fixed ordinary session or valid ordinary launch and unchanged normal course permissions, adding, removing, expiring or abandoning any other secure session must not change its access decision.

Enforce this by construction:

- Resolve secure scope only from the **current authenticated token**. Never search for a secure session by user ID, section, enrollment, attempt, email or latest launch history.
- Creating a secure token neither modifies nor revokes other authentication tokens. Do not disconnect other sessions' LiveViews or channels.
- An ordinary launch creates an ordinary token regardless of any existing secure tokens, including an incoming secure cookie in the same browser. Never copy secure scope from previous cookies or saved LTI params.
- Do not consult secure-session state during ordinary course launch authorization. Normal LTI/authentication/enrollment checks still apply.
- An unfinished attempt carries saved work and normal attempt rules, but no course-access restriction.

This is the required 100% isolation guarantee: **secure-session state cannot lock out another ordinary session or launch**. It is not a promise that unrelated authentication, enrollment, assessment availability or infrastructure failures cannot occur. Verification below specifically tests that confinement cannot create the dangling-session failure.

The deliberate tradeoff is that the same learner may use another ordinary browser/computer to access course material during an assessment. This is accepted in favor of avoiding account lockout. SEB and institutional controls remain responsible for restrictions beyond the admitted Torus session.

## Small implementation model

Use the existing `users_tokens` authentication records. Add two nullable fields to `Oli.Accounts.UserToken`:

| Field | Ordinary token | Secure token |
| --- | --- | --- |
| `secure_section_id` | null | Verified secure entry's section ID |
| `secure_resource_id` | null | Exact page's stable resource ID in that section |

Both fields must be null or both set; require `context == "session"` when set. Add foreign keys with deletion behavior that cannot silently turn a secure token into an ordinary one: restrict deletion, or explicitly revoke that exact token before deleting its target. Do not use `ON DELETE SET NULL` to release scope. Reference the stable resource, not its mutable revision slug. Validate page membership in the section before token creation.

Token scope is immutable: ordinary stays ordinary, secure stays scoped to its original page until the token is deleted or expires. A new launch creates a new token. No `secure_assessment_sessions` table, per-user uniqueness, learner lock, lease, heartbeat, generation counter, attempt binding record, support-release procedure or account-level status is needed.

Read the current token's scope with the existing session authentication lookup and expose a server-derived assign:

```elixir
nil
# Valid ordinary authenticated session.

%{section_id: section_id, resource_id: resource_id}
# Secure scope from this authenticated token only.
```

Here `nil` means a **valid ordinary token**, not a lookup failure. Invalid/expired tokens fail authentication; malformed scope fails only that token's request. Never recover by querying for another token belonging to the user. Do not put raw authentication tokens in app parameters, logs or socket payloads.

`lib/oli_web/user_auth.ex` already generates a database-backed token in `create_session/2`, renews the cookie session, and revokes the current token on logout. Extend creation with an explicit server-only secure scope option, defaulting to ordinary. Atomically insert the token with its scope before issuing the cookie; do not issue an unrestricted token and attach scope later. Preserve ordinary callers' behavior. Add a session lookup helper that returns the authenticated user and current token metadata without changing unrelated callers that only need a user.

Generate migrations with `mix ecto.gen.migration`: one for the resource setting and one for scope fields on `users_tokens`. Both use explicit `up/0` and `down/0`, following repository rules. Rolling back scope fields while secure tokens remain would remove their restriction: revoke only scoped tokens before dropping the columns, and coordinate rollback with application deployment. Ordinary tokens must survive.

## Assessment setting

Use **`secure_delivery`** throughout for the boolean resource field, settings keys, migration column, UI events and tests. Add it to `section_resources` with `default: false, null: false`, plus the schema field and changeset cast entry in `lib/oli/delivery/sections/section_resource.ex`.

Add the field/typespec to `lib/oli/delivery/settings/combined.ex`. In `Settings.combine/3`, copy it directly from the section resource, like `allow_hints`. Do not add it to Revision, StudentException or student-exception UI. Enabling is valid only for graded pages, checked against the authoritative section resource in the settings update path.

Add a **Secure Delivery** Yes/No column to Assessment Settings, visible only when the instance supports secure delivery. Tooltip: “Students must launch this assessment through the secure LMS activity. Navigation in that secure session is limited to this assessment. Applies to all students.”

### Runtime instance capability

Read `SUPPORTS_SECURE_DELIVERY` in `config/runtime.exs` into the boolean application setting `:oli, :supports_secure_delivery`, using the existing runtime boolean parsing helper:

```elixir
config :oli, :supports_secure_delivery,
  get_env_as_boolean.("SUPPORTS_SECURE_DELIVERY", "false")
```

The supported environment values are `true` and `false`; unset defaults to false. Following the existing helper, whitespace/case are normalized and other values resolve to false. This is deployment runtime configuration, read at application startup without recompilation, not an instructor-editable setting or compile-time module attribute. Apply it consistently across nodes of an instance; changing the environment requires application restart.

| Instance configuration | Assessment Settings behavior |
| --- | --- |
| `SUPPORTS_SECURE_DELIVERY=true` | Include the **Secure Delivery** column and permit authorized instructors to edit the boolean for graded assessments. |
| `SUPPORTS_SECURE_DELIVERY=false` or unset | Omit the column entirely, including header and controls. Users cannot enable the setting. |

Enforce capability in the settings update context as well as column rendering: reject attempts to set `secure_delivery: true` on unsupported instances, including forged LiveView events, APIs and bulk application. Omit this key from bulk-copy controls/payloads there so normal edits to other settings continue to work. Rendering uses the server's runtime configuration, never a client-supplied capability. Keep the database field and migrations available on all instances.

For pre-existing true values (for example, an instance later configured without support), preserve the stored policy rather than silently making the assessment ordinary. Do not create new secure admissions while support is false; explain that secure delivery is unavailable for that protected assessment. Existing scoped tokens retain their restriction, and read-only review follows the existing policy. Ordinary course launches, unrelated resources and independent ordinary sessions remain unaffected. Course-copy paths must not let users introduce a true value into an unsupported instance; reject that incompatible settings copy with an explanation rather than silently dropping the protection. These edge cases do not change the session-isolation invariant.

### Implementation touchpoints

Concrete edit points:

- `config/runtime.exs`: parse `SUPPORTS_SECURE_DELIVERY` and expose the runtime boolean application setting.
- `lib/oli/delivery/settings/assessment_settings.ex`: supported keys, runtime capability check for enabling, validation, persistence and existing settings-change audit.
- `lib/oli_web/live/sections/assessment_settings/settings_table_model.ex`: conditionally include the column and boolean control, following `allow_hints`.
- `lib/oli_web/live/sections/assessment_settings/settings_table.ex`: boolean decoding, row refresh, sorting if supported, and explicit bulk-copy values.
- `lib/oli_web/live/sections/assessment_settings/tooltips.ex`: explanation. Keep existing exception tables unchanged.

`SectionResource.to_map/1` includes Combined keys, so verify the setting survives section copies and publication updates. New resources default false; existing section overrides survive projection refresh. Copies carry assessment settings but never authentication tokens. No separately configured secure resource-binding registry is needed.

Enabling the flag requires secure admission on subsequent delivery reads/writes to **that assessment**, including an already open ordinary lesson. It does not block course navigation or unrelated assessments. Disabling the flag permits ordinary delivery under normal rules; an existing secure token remains scoped to its original page. Missing or removed resources fail their own access check and cannot trigger an account restriction. Start with authoritative database policy reads at the resource boundary rather than relying exclusively on `SectionResourceDepot` cache consistency.

## Extensible secure entry

Keep a small boundary between **verifying entry** and **issuing/enforcing a secure session**. The initial Moodle/SEB adapter validates LTI claims and the SEB assertion and resolves the learner, section and page. It passes a server-produced verified admission result to shared session creation. A future Respondus adapter can authenticate and verify a different entry mechanism, including one without LTI, and supply the same canonical learner/section/resource identity.

Shared admission checks instance support, the graded page's `secure_delivery` policy, section membership and normal learner authorization, then creates the scoped authentication token. Only an explicitly supported entry verifier may supply verified admission; a client-supplied provider name, browser header or `secure=true` parameter cannot do so. Each adapter owns verification of its evidence and binding that evidence to the authenticated learner and selected assessment.

Keep LTI claims, Moodle identifiers, SEB assertion fields and provider-specific error/return handling inside the entry adapter. Token scope, route/API/channel authorization, basic/adaptive delivery, student review, resume and logout must depend on generic secure scope rather than Moodle, SEB or the presence of an LTI launch. Provider-specific audit metadata may be recorded separately if needed; it must not become an enforcement prerequisite in the shared session model. In particular, `secure_delivery` and `SUPPORTS_SECURE_DELIVERY` represent generic secure-delivery policy and capability, not an SEB-only setting.

Implement this as a small documented function/module boundary, not a plugin registry or a speculative Respondus implementation. Initially only the Moodle/SEB verifier can issue admission. Future non-LTI entry will need its own authenticated verification contract, but must reuse the same token scope and no-cross-session-lockout rules. Existing LTI grade passback stays in its integration path; generic confinement does not require LTI grade-service metadata.

## Initial Moodle/SEB LTI admission and ordinary launches

Current code to reuse:

- `lib/oli_web/controllers/lti_controller.ex`: normal state/JWT validation, user/enrollment handling and session creation.
- `lib/oli_web/lti_redirect.ex`: section resolution and direct page routing. Its `torus_resource_id` custom parameter currently contains a **revision slug**, resolved by `SectionResourceDepot.get_page_by_revision_slug/2`.
- `lib/oli/lti/secure_launch.ex`: assertion shape and freshness validation.

Extract one structured target resolver shared by admission and redirect. Use verified issuer/client/deployment/context to select the section, then signed resource selection to identify the exact page within it. Store its canonical section/resource IDs on the new token.

| Current validated launch | New token and destination |
| --- | --- |
| Ordinary course launch, no direct protected page | Ordinary token and normal course destination. Ignore all other secure tokens. |
| Direct launch to an ordinary page | Ordinary token and existing page destination. |
| Direct resource-link launch to a graded protected page, with valid Moodle SEB assertion | Scoped token and that page's entry point. |
| Direct launch to a protected page without valid secure evidence | Reject that assessment entry with secure-relaunch instructions. Do not revoke other tokens or record an account restriction. |
| Launch claiming secure delivery but missing/invalid/mismatched page selection | Launch error; no secure token or fallback admission. Other ordinary sessions/launches are unaffected. |

For the initial Moodle/SEB adapter, run assertion checks after target resolution and before issuing a scoped token. A secure candidate requires `SUPPORTS_SECURE_DELIVERY=true`, must be a direct LTI resource-link launch, target a graded page with `secure_delivery: true` in the resolved section, and contain the valid signed Moodle SEB assertion. `{:ok, :not_required}` from the current spike gate is not secure evidence. These LTI/SEB evidence requirements belong to this adapter, not the generic session model. Admission does not waive enrollment, timing, passwords, prerequisites or attempt limits.

**Remove deployment-wide SEB enforcement from the ordinary launch path for this feature.** The current controller calls the spike gate before resolving the page; its `TORUS_SEB_REQUIRED_LAUNCHES` scopes can require SEB for an entire deployment. Leaving that behavior intact would contradict ordinary-launch isolation in the same deployment. Refactor to resource-policy-driven enforcement; legacy selector configuration must not impose SEB on ordinary course/page launches. Update the spike configuration documentation and tests accordingly. Do not merely ask operators to avoid broad scopes.

Keep standard LTI state/nonce/JWT validation and existing assertion freshness checks. Additional replay protection and diagnostic-bypass exclusion remain out of scope. Moodle supplies SEB verification; Torus does not independently or continuously attest the browser.

Every successful ordinary LTI launch or other ordinary login explicitly creates an ordinary session. Permit login/launch/logout transport before applying an incoming secure token's navigation restriction. Otherwise a stale cookie could block replacement even though the new launch is ordinary. A valid secure launch on another computer is independent too; it does not revoke the first computer's token. Existing attempt concurrency rules handle simultaneous work—this feature adds no per-user launch conflict rule.

Never infer secure scope from `LtiParams.get_latest_user_lti_params/1` or an active attempt. Saved launch params may inform ordinary routing but cannot confer secure admission or force a fresh ordinary course launch back to a prior secure page. The current ordinary launch's destination must win over another session's saved launch history.

Ordinary concurrent launches must remain permitted even if they update shared LTI metadata. Verify AGS line-item correctness with interleaved secure/ordinary launches; if shared latest-launch data affects grade routing, fix the resource-specific grade lookup rather than blocking the ordinary launch. Do not redesign grading as a confinement state machine.

## Two authorization checks

Implement a small shared policy module, for example `Oli.Delivery.SecureAssessments`, used by HTTP, LiveView and activity endpoints:

```elixir
authorize_session_scope(current_scope, operation, resolved_target)
# Ordinary scope: continue normal authorization.
# Secure scope: allow only this section/page and permitted operations.

authorize_resource_policy(current_scope, actor, operation, resolved_target)
# Protected assessment delivery: require matching secure scope.
# Ordinary later review: enforce ownership and existing read-only review policy.
```

These functions never receive or fetch “all sessions for this learner.” The caller authenticates the current token and resolves target ownership first. Document the APIs and add typespecs when implementing them.

The first check confines the SEB session. The second protects the assessment against direct URLs/APIs from ordinary sessions. An ordinary session may browse the course containing a protected assessment but cannot take that assessment without securely launching it.

| Request | Ordinary session | Secure session scoped to page A |
| --- | --- | --- |
| Course home or ordinary page, same or different section | Existing normal authorization | Deny/return to A, except authentication/exit transport |
| Delivery/start/resume/save/submit for protected A | Require secure launch | Allow under normal ownership/attempt rules |
| Delivery for protected B | Require secure launch for B | Deny; this token is scoped to A |
| Permitted submitted-attempt review of A | Allow read-only, regardless of other secure sessions | Allow read-only |
| Permitted submitted-attempt review of B | Allow read-only | Deny in this token's confined UI |
| Valid ordinary course LTI launch | Normal ordinary launch | Normal ordinary launch creating a new ordinary token |
| Logout/exit | Existing behavior | Revoke only this token, at any attempt state |

### HTTP, LiveView and API placement

Add a session-scope plug after authentication: it immediately continues for an ordinary token, without cross-session queries. For a secure token, use explicit route/controller-action classifications to allow only assessment routes, dependencies and authentication/exit transport. Unknown routes are denied only for the secure token. APIs return stable 403 errors; HTML may return to the scoped assessment. Authentication errors remain authentication errors.

Resource-aware checks run before sensitive context creation or mutation. In `lib/oli_web/router.ex`, account for `RedirectByAttemptState` preceding `:delivery_protected` today; reorder/add the guard so redirect and visit side effects cannot precede authorization. Add LiveView `on_mount` checks before `InitPage` and context loading, plus checks on navigation, protected events and data-producing async/component callbacks. HTTP checks alone do not protect reconnects or live navigation.

Use the current token's identity on connected mounts; never initialize scope from the user's latest session. Existing ordinary views on another computer remain ordinary. There is no account-wide activation message or forced refresh. Logout may use the existing **token-specific** `users_sessions` disconnect topic; never broadcast confinement to a user-wide topic.

The following boundaries remain necessary with the simpler session model:

| Surface / code | Required handling |
| --- | --- |
| Prologue, lesson, adaptive lesson, legacy page/fullscreen/pagination aliases and attempt start | Resolve section/page before content or attempt creation; apply both checks consistently. |
| Review routes, `ReviewLive`, legacy/adaptive review | Resolve owned submitted attempt before sensitive content; apply `ReviewPolicy` and feedback settings. Ordinary review creates no secure session and requires no other session to end. |
| `Api.AttemptController` | Resolve activity/part GUIDs through their resource attempt/access to learner, section and page. URL section alone is insufficient: some actions use part GUIDs independently of activity GUIDs. Check parent-child agreement. |
| Bulk GUIDs, nested part inputs and evaluations | Resolve all targets in bounded set-based queries, authorize every member first, and reject unauthorized mixtures without partial writes. |
| `Api.PageLifecycleController` and `LessonLive` finalization | Verify URL/body/attempt identities agree before finalization. Preserve existing finalization and AGS behavior. |
| Attempt state, activity models, media/uploads | Authorize dependencies against the page/actual owned attempt. Scope upload/download capabilities. Dynamic/adaptive attempt activities cannot be inferred solely from current `related_activities`. |
| Global/section state, blobs, discussion/AI/search, nested external tools | Secure sessions receive only required assessment dependencies. Reuse attempt-scoped services or add a narrow adapter; a broad section/global endpoint is not an exemption. Ordinary sessions retain normal authorization. |
| Static JS/CSS, essential assets, service-authenticated callbacks and background jobs | Keep required assets available and retain existing service authorization. Do not require browser admission for trusted grade/background operations. |

Keep attempt start and writes behind authentication/CSRF and ownership protections, including legacy routes. Do not add unrelated route migrations or account-level serialization to this feature. If revocation races with an already authorized request, existing transaction semantics apply; it cannot affect another token's authorization.

### Channels

`lib/oli_web/channels/user_socket.ex` currently accepts a signed `user.sub` token and has no session-specific socket ID; `lib/oli_web/plugs/set_token.ex` produces it. For secure channels, issue a distinct signed socket capability tied to the exact authentication-token record. Verify that record is valid and load its scope on connection/join and protected operations. Do not expose the raw authentication token. Give secure sockets a token-specific disconnect identity.

Never mint the old unscoped channel credential from a secure session. Retain ordinary channel behavior and legacy credentials as ordinary credentials only; they cannot authorize protected assessment operations. Assessment-scoped outgoing state must not use global subscriptions that push unrelated course data. Every protected channel/dependency operation needs the same resource policy, including on ordinary connections. No user-wide disconnect, generation number or session takeover is required. Already open ordinary channels remain usable.

## Basic and adaptive UI, including REVIEW mode

Derive `secure_delivery?` and scope from authenticated token metadata and pass them through controller/LiveView assigns and adaptive boot parameters. Use one secure layout branch/shared component. Hiding controls is not authorization.

Keep assessment title/instructions, timer, save/connectivity status, internal question/screen navigation, submit, review, accessibility controls and exit. Remove course navigation: linked logos, Back to course, outline, previous/next pages, breadcrumbs, search, unrelated notes/discussion, profile and footer links. Remove corresponding URLs/data from app parameters, including `InitPage` previous/next URLs. Authored links and embedded dependencies must stay within permitted assessment use; SEB handles external browser restrictions.

Edit `lib/oli_web/components/layouts/student_delivery_lesson.html.heex`, `lib/oli_web/live_session_plugs/init_page.ex`, `PrologueLive`, `LessonLive`, `ReviewLive`, `PageDeliveryController` and their legacy/adaptive templates. Replace course-directed error/completion links only for secure sessions. Surveys, paywall and prerequisites remain enforced; unmet prerequisites can show an assessment-only explanation and exit rather than redirecting secure delivery into a course workflow.

| Page type | Secure delivery | Student REVIEW in secure session | Student REVIEW in ordinary session |
| --- | --- | --- | --- |
| Basic, including traditional and one-at-a-time | Prologue, start/resume, answers/save, submit | Submitted attempt, existing review/feedback rules, assessment-only navigation | Same review rules, read-only; independent of any secure session |
| Adaptive | Prologue, start/resume, internal screen progression, saved state, submit | Actual adaptive REVIEW mode with saved state and internal review navigation | Actual adaptive REVIEW mode, read-only; independent of any secure session |

Review must not create/resume a writable attempt, change answers/state, trigger scoring or grant access to hidden feedback. Check the operation server-side; a review flag or GET method is not proof of permission. Retry/start in ordinary review requires secure launch. Adaptive review must not fall back to delivery or a basic-only renderer. Implement dependency reads needed by both renderers, excluding LTI activities and superactivities.

## Session lifetime without lockout

The **attempt** and the **authentication token** have separate lifetimes. Attempts retain saved work and existing deadlines. Tokens determine what their own requests may access.

| Event | Result |
| --- | --- |
| Secure launch | Create a scoped token; enter/resume the selected assessment using existing attempt logic. No other token changes. |
| Reload/reconnect | Use the current valid token's scope; resume saved work without resetting the attempt. |
| Submit/auto-submit | Complete normally; keep that token scoped for completion/review. Other sessions were never blocked. |
| Exit/logout, before or after submission | Always permitted. Revoke only the current token and disconnect its sockets. Leave an unfinished attempt unfinished. |
| Close browser, crash, lose network, shut down computer | No server-side action is required for isolation. Any remaining token row can affect only requests carrying it, never ordinary launches elsewhere. |
| Token expires or is revoked | Requests carrying that token must authenticate again. No ordinary token is revoked and no account lock remains. |
| Ordinary launch on another computer, same or other section | Succeeds under normal LTI/course rules whether the secure token is live, dangling, expired or gone. |
| Ordinary launch in the same browser with an old secure cookie | Issue a fresh ordinary token; never inherit scope or reject because an assessment is unfinished. |
| Second secure launch | Create its own scoped token and resume under existing attempt rules. Do not revoke another computer's admission or reset an attempt timer. |
| Abandoned/untimed attempt resumed later | Securely relaunch to resume the same unfinished attempt. No support release/cleanup prerequisite. Timed auto-submit rules apply independently. |
| Ordinary later review | Existing read-only review/feedback rules; no dependency on secure token closure or cleanup. |

Closing a browser does **not** reliably notify Torus or delete a database token. This design explicitly removes the earlier requirement to detect closure perfectly: a dangling token is harmless to other sessions. Do not implement unload/beacon callbacks, heartbeats, cleanup schedules or session-cookie deletion as the mechanism protecting ordinary access. Browser-restored cookies may restore the same restricted session; they still cannot restrict an independent ordinary launch. No claim of guaranteed browser-close revocation is made.

Use existing authentication expiry rather than inventing an exam lease. Do not enable remember-me for a secure launch; clear that browser's remember-me cookie when creating the scoped session to avoid silently falling back to a previous ordinary credential after it ends. This cookie operation must not revoke ordinary credentials on other devices. A fresh ordinary launch is always permitted.

An optional “Exit assessment” action uses existing logout or a small CSRF-protected POST wrapper. It is idempotent, requires no attempt-state check, and never silently submits. Return to a validated LMS destination or minimal signed-out page. No SEB quit secrets are stored or exposed. Explicit logout revokes the token; closing the browser stops using it and has no account-access consequences.

## Verification and delivery plan

1. Add the `secure_delivery` resource flag, runtime `SUPPORTS_SECURE_DELIVERY` capability, conditional **Secure Delivery** column, propagation and audit support. Generate reversible migrations; test defaults, boolean/non-graded validation, bulk copy, section copy and publication refresh. No student exceptions.
2. Add immutable scope to existing tokens, shared secure admission and the initial Moodle/SEB LTI entry adapter. Preserve ordinary authentication callers. Remove the spike's deployment-wide ordinary-launch gate. Test ordinary launch isolation before UI restrictions.
3. Add the two authorization checks to routes, LiveViews, APIs and channels; implement basic/adaptive secure layouts and student REVIEW modes. Use actual attempt ownership for dependencies and writes.
4. Add optional current-token exit and verify abandonment recovery. Run basic/adaptive Moodle/SEB flows and confirm grade passback, including concurrent ordinary launches.

Extend `test/oli_web/controllers/lti_controller_test.exs`, `test/oli_web/lti_redirect_test.exs`, `test/oli/lti/secure_launch_test.exs` and `test/oli/delivery/sections/assessment_settings_test.exs`. Add focused token-authentication, route/API, LiveView and channel tests. Follow the repository scenario workflow when implementing scenario integration coverage.

### Mandatory no-lockout regression matrix

Use the **same user** with independent cookie jars/tokens S (secure) and N (ordinary). Exercise N in both the same section and a different section, with the same LTI registration/deployment as S wherever applicable.

| State of S | Assertions for N |
| --- | --- |
| Live, taking an assessment | Existing ordinary HTTP, LiveView and channel access continues; new ordinary course launch succeeds. |
| Submitted but never exited | Same assertions; permitted ordinary review works. |
| Browser closed without logout; token retained indefinitely in test setup | Same assertions; do not send a close notification or run cleanup. |
| Network lost / application restarted / another server node | Same assertions with S's token still present. |
| Expired, logged out, revoked or target resource unavailable | Same assertions; only S's requests can fail because of S's state. |
| Many secure tokens, including unfinished untimed attempts | Same assertions; no per-user unique constraint or secure-session lookup. |

Also require:

- Compare N's ordinary authorization outcomes with S absent and present. They must be identical. Verify secure launch/exit never mutates or deletes N's token.
- Configure the spike's former deployment-wide scope and verify ordinary course launches still succeed without SEB after refactoring.
- Launch ordinarily with a stale secure cookie in the same browser and verify the new token is ordinary, including when the old assessment is unfinished. A rejected secure launch must not affect independent N.
- Keep N's LiveView/channel connected during secure admission, logout and expiry; verify no cross-session disconnect or restriction event.
- Review submitted basic/adaptive attempts through N while S still exists. Verify no closure prerequisite and no writable review path.
- Leave S orphaned, then securely relaunch to resume saved work without consuming another attempt or resetting time.

### Boundary and compatibility tests

- Test shared session creation and enforcement using a server-produced verified admission without LTI/Moodle/SEB fields. Separately test the real Moodle/SEB verifier's evidence checks and rejection of unverified entry. This verifies the extension boundary without adding a production alternate entry route or implementing Respondus.
- Verify runtime capability defaults false, parses true/false, shows the **Secure Delivery** column only when true, and requires no recompilation. Unsupported instances reject enabling through forged events/API/bulk/copy paths while ordinary settings edits still work.
- Verify disabling instance support does not clear existing resource policies or token scopes, rejects new secure admissions only for the affected assessment, and does not block ordinary course launches or permitted review.
- Ordinary course access remains allowed, but protected delivery/prologue/start/resume and answer APIs require matching secure admission.
- S cannot access unrelated routes, page B, another section's copy of A, unauthorized attempts or unrelated dependencies by changing URLs, bodies or socket messages.
- Authorize every GUID in bulk/nested requests and reject unauthorized mixtures without partial mutation; verify learner ownership and parent-child consistency.
- Exercise basic/adaptive delivery plus secure/ordinary student REVIEW modes, including scheduled/disallowed feedback, saved adaptive state and internal navigation.
- Logout before submission is permitted, leaves work unfinished and revokes only S. Neither submission nor logout is required for N to work.
- Verify flag changes, expired tokens, reconnect, legacy routes, mixed author/student cookies and alternate logins cannot create secure admission implicitly.
- Interleave ordinary launches with secure save/finalize, grade retries and review. Preserve correct attempt and AGS line-item behavior without denying ordinary launches.
- Verify scope migration rollback revokes only secure tokens before dropping fields; ordinary sessions remain valid.

The implementation is complete only when the resource boundary and isolation matrix pass. Removing account-wide enforcement reduces session-lifetime risk; it does not remove the need to authorize protected assessment routes and APIs.

## Decision Log

### 2026-09-23 — Native assessment activity scope

- Change: LTI activities and superactivities embedded in assessments are excluded. Earlier provider-adapter inventory entries are historical, not remaining implementation or release requirements.
- Reason: Explicit user scope clarification; retain both basic/adaptive pages, read-only review guards and existing feedback filtering.
- Evidence: `docs/exec-plans/current/secure-assessment/phase-5-execution.md` and AC-024 in `docs/exec-plans/current/secure-assessment/requirements.yml`.
- Impact: Phase 5 covers native assessment rendering/state/models/media/uploads. Moodle LTI admission and LMS grade passback are unchanged; excluded activity routes gain no secure-session exemption.
