# MER-6018 LTI Deep Linking - Functional Design Document

## 1. Executive Summary

Keep the prototype's two storage boundaries: project configuration in the existing activity revision and delivery configuration in section-owned deep-link records. Harden editor saves and callback correlation, introduce missing-only transactional publication initialization, and copy template records into destination sections. Fix and component-test Torus-owned instructor configuration frame targeting; external-tool browser verification is deferred. The design builds on existing modules and does not introduce new authoring resource types or tool-specific production logic.

Requirements are canonical in `requirements.yml`; this document defines how each acceptance criterion will be satisfied. Planning traceability is not implementation proof.

## 2. Requirements & Assumptions

- Authoring choices and capability/permission enforcement: FR-001; AC-001, AC-002, AC-003.
- Authoring UI/save orchestration: FR-002; AC-004, AC-005, AC-006, AC-007.
- Trusted return validation: FR-003; AC-008, AC-009.
- Revision persistence, freshness and publication isolation: FR-004; AC-010, AC-011, AC-012.
- Direct creation and missing-only publication application: FR-005, FR-006; AC-013, AC-014, AC-015, AC-016, AC-017, AC-018.
- Template initialization and inheritance: FR-007, FR-008; AC-019, AC-020, AC-021.
- Instructor configuration: FR-009; AC-022, AC-023, AC-024.
- Portable data/compatibility and permanent evidence: FR-010, FR-011; AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031.

Assume the project page editor owns configuration persistence; template authoring launches, ordinary section-copy controls and resource-link identity migration are outside this work item. A selection is portable only if the external tool supports the copied URL/custom configuration in a new context. No MyProse-side behavior is inferred from Torus record independence.

## 3. Repository Context Summary

- `assets/src/components/activities/lti_external_tool/LTIExternalToolAuthoring.tsx` owns the current role/type choices, modal and signed-result submission.
- `assets/src/apps/page-editor/PageEditor.tsx` uses its existing page/activity persistence strategies for prepare/save/close events. Deep Linking uses the existing `PersistenceStatus` indicator and error banner.
- `lib/oli/lti/authoring_launch.ex` verifies signed author/project/activity/deployment correlation and captured activity state, then delegates selection saves to the existing activity editor. See `design/authoring-save.md`.
- `lib/oli_web/controllers/api/lti_controller.ex` and `lib/oli_web/controllers/lti_controller.ex` own launch details, LTI transport and callback/result handoff.
- `lib/oli/authoring/editing/activity_editor.ex` retains ordinary revision policy. A signed selection save creates a fresh revision; ordinary single/bulk activity content edits preserve the stored selection.
- `lib/oli/delivery.ex` calls `PlatformExternalTools.initialize_section_deep_links/2` inside direct creation. That helper currently inserts every selected candidate and is not a missing-only updater.
- `lib/oli/delivery/sections/updates.ex` owns the active worker publication-application transaction, including final migration and cache invalidation. Inspect legacy update entry points before claiming complete coverage.
- `lib/oli/delivery/sections/blueprint.ex` creates templates and delegates duplication to `SectionCopy`; the copy engine is shared with previous-section copying.
- Prototype baseline: regular/configuration frames shared a name. Phase 2 uses instance-unique names and distinct outcomes; component regressions establish targeting/message behavior, without claiming that the collision caused the observed empty MyProse modal.
- Existing tests cover legacy LTI transport and selection CRUD. The dummy browser tool scenario currently disables Deep Linking and covers a regular launch in a new window.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Keep UI state in the authoring element and save orchestration in the page editor. Keep authorization, token verification, selection parsing and destination initialization in existing domain contexts. Controllers translate request/response contracts and do not implement publication or copy policy.

Introduce narrow, documented domain helpers for guarded authoring selection saves, missing-only publication initialization and template selection copying. Reuse revision/edit and delivery creation transactions rather than creating parallel persistence paths.

### 4.2 State & Data Flow

Authoring flushes the existing page and target-activity persistence strategies before configuration. Prevent overlapping configuration in the active page editor and disable activity edits while its modal is active. Close/error discards that editor's active request and ignores subsequent messages; callbacks return a signed handoff and never persist by themselves. No authoring request registry or cancellation endpoint is introduced. General coordination between multiple tabs is outside this slice.

Regular uses the current draft selection or the integration default. Deep Link sends the selected context role and existing configuration entry point. A validated callback returns a signed result token to the initiating frame. The page editor submits that token through its coordinated save path; the server derives the selection from the token and merges only `deepLink` into the current activity content. On success, return the authoritative saved model/revision and synchronize the editor before restoring editable controls. On persistence failure, restore the last successful selection while retaining independently saved edits; do not leave a failed selection looking saved.

Display generic selection metadata in the priority order tool title, supported descriptive metadata/URL, then a clear configured-state label. Do not parse MyProse custom keys to invent a generic activity name, and do not render tool-supplied HTML as trusted markup. Keep the Torus wrapper usable without altering the tool's internal UI.

### 4.3 Lifecycle & Ownership

The activity resource ID remains stable. Each project selection save participates in revision/publication change tracking. Section initialization copies published values into `(section_id, resource_id)` records. Applying a publication initializes only missing records; an existing row is authoritative even when the project selection changes or disappears.

Project → template uses exact selected published revisions. Template → section copies the template's current records and preserves absent/cleared selections without project fallback. Instructor configuration updates the current section's record through the existing section callback after explicit authorization checks. Copying selections never copies learner data.

### 4.4 Alternatives Considered

- Continue client-side model replacement after result retrieval: smallest prototype, but it leaves freshness and failed-save recovery dependent on browser state. Select a signed-result-aware server guard within the editor persistence boundary.
- A revision ID alone misses ordinary in-place draft edits. Compare the captured revision and a deterministic server fingerprint of its editable fields, keeping ordinary revision policy unchanged.
- Overwrite section records from new publications: simple but violates instructor ownership. Select insert-missing behavior protected by the composite uniqueness constraint.
- Reinitialize sections created from templates from project content: loses template changes and restores cleared records. Copy template-owned records instead.
- Add a global section-copy option now: expands ticket scope. Integrate inheritance with the existing template source policy only; keep general course-copy behavior explicit and covered.

## 5. Interfaces

Proposed contracts refine existing interfaces; exact function placement is confirmed in the phase-level implementation design without changing these invariants.

- Project Regular launch-details remains a GET with an allowlisted role. Deep Linking starts with a trusted-Origin POST after host flush, including its lock resource. The signed `lti_message_hint` wrapper carries the original request token through OIDC; compact login hints respect the 255-character context limit. The tool echoes the opaque message hint. Refuse legacy Deep Link GETs.
- Signed request correlation includes author, project/activity, deployment, request UUID, working publication, starting revision, server fingerprint and lock resource. Tokens retain dedicated salts and bounded lifetimes. Re-resolve accepted collaboration, capability, association and captured activity state at authorization/return/save.
- Project POST endpoints start configuration and submit a signed result token. Save returns authoritative model/title/objectives/tags. The authoring component submits the returned token directly; the unused prototype result-retrieval endpoint is removed. Closing is local and does not issue a cancellation request.
- `ActivityEditor.edit/5` accepts a sole `deep_link_result` token. Under its existing lock/transaction, validate that token against current activity state, derive a selection-only content merge and use existing clone/update/mapping/broadcast functions. Ordinary single/bulk content saves retain `deepLink` and reject non-map LTI models. Generic resource editing, copying/import and ordinary revision policy retain their baseline contracts.
- `initialize_section_deep_links(section_id, publication_id)` becomes idempotent, missing-only and transaction-compatible. Return a created count or a structured error. No external tool calls occur inside this operation.
- A template-copy helper accepts source/destination section identities and corresponding destination resources, preserving type/URL/custom/title/text and reporting insert failure. Honor any existing resource remap rather than assuming every copy retains resource IDs.
- Frame identity is local presentation data, distinct from LTI `resource_link.id`. Give every mounted instance a stable unique frame name; delivery/configuration instances and multiple activities on one page must not share targets. Validate message source/origin and associate callbacks with the expected launch/frame.
- Section configuration uses `Oli.Lti.SectionDeepLinkLaunch`: starting configuration is a POST that allows only an authorized instructor/admin and an active Deep Linking deployment, with an exact trusted-Origin check. Compact login hints carry section ID, account namespace and a request UUID; authorization rechecks them before emitting signed correlation in the LTI `data` claim. Return validation binds account/section/activity/deployment and rechecks current permission and capability. Launch details also include an actor/route-bound `request_token` for the POST cancellation endpoint. A successful return includes `request_id` so the mounted configuration frame can associate completion with its launch.
- Author and instructor Deep Linking requests include the optional standard custom claim from the current draft or exact section/activity selection. Keep string values verbatim, including empty strings and serialized JSON; omit non-string legacy values without coercion or persistence changes. Omit the claim when no compliant values exist. A section without a stored selection has no project/publication fallback. Continue targeting the tool's configured selector endpoint and preserve signed `data`; tool-side UI preselection is optional and cannot be guaranteed by Torus. See [Deep Linking 2.0, section 4.4.11](https://developers.imsglobal.org/spec/lti-dl/v2p0) and [LTI 1.3, section 4.3](https://www.imsglobal.org/spec/lti/v1p3).

## 6. Data Model & Storage

Retain optional `content.deepLink` with `type: ltiResourceLink`, optional URL/custom/title/text and the existing section deep-link schema. Reuse the database uniqueness constraint for `(section_id, resource_id)`. Validate candidates before inserts and preserve valid tool-defined custom values exactly.

Keep `priv/repo/migrations/20261005200125_widen_lti_deep_link_selection_fields.exs`. Its forward path widens URL/title/text to PostgreSQL `text`; rollback explicitly refuses data loss when values exceed the former limit. Existing activities without a selection need no content backfill. No additional table or migration is currently proposed.

## 7. Consistency & Transactions

### Authoring freshness and replay

Use the existing activity-edit transaction and owned editing lock. Validate the signed result and captured revision/fingerprint within that transaction before cloning. Merge only the selection into current content, create a fresh revision and advance the mapping through the normal editor primitives. Broadcast only after commit.

The server fingerprint detects changed content/title/objectives/tags/learning-model parameters even when an ordinary edit retains its revision ID. It is generated only on the server and carried in signed correlation, not supplied as an unsigned client assertion. Ordinary single/bulk writes preserve the selection. After a successful selection save, the new revision rejects replay. No nonce consumption, cross-tab supersession registry or new ordinary-edit revision policy is needed.

### Destination creation/application

Join candidate LTI revisions from the explicit publication with canonical destination membership. Never scan newer working revisions or all project selections independently of the destination. Skip absent/null selections and reject invalid candidates that would otherwise initialize a missing record.

Use conflict-do-nothing insertion for existing rows; do not reuse the instructor upsert helper for publication initialization. Existing rows are skipped before evaluating replacement content, and a concurrent successful insert wins without overwrite. Validate all new candidates and perform writes within the caller's transaction so a failed insert cannot leave partial initialization.

For direct creation, retain the existing placement after resources exist. For publication application, run initialization after update/migration/post-processing has finalized destination resource membership and within the same section-locked transaction. Publish completion signals and cache invalidation only after commit. Cover major/minor and remixed-project update cases where resource inclusion differs.

For template creation, initialize within `Blueprint` creation after destination resources exist. For template-to-section duplication, copy selections after resource mapping is available within `SectionCopy`'s transaction and before success. Restrict this behavior to template source policy so previous-section copying is not silently expanded.

For instructor configuration, verify signed correlation and route association before taking a section row lock. Starting a request replaces the previous pending request for that section/activity under the same lock. Use a deterministic scoped key in the nonce table's indexed `value` column and the request UUID as its domain. Reject noncanonical resource identifiers before issuing state. Recheck current access, integration identity and tool claims within the return transaction; require that request to remain pending, consume its UUID and upsert only that section/resource's selection atomically. Remove pending state only with a successful save; failed writes roll back both selection and request consumption. Return correlation lifetime does not exceed nonce retention. No additional migration is needed. The return page stores JSON in an escaped HTML attribute and posts to its own origin; it does not embed tool metadata as executable script.

Cancellation also takes the section lock and removes only the initiating actor's signed, route-bound request. Cancellation does not require current configuration permission/capability or an unexpired return token: removing a previously issued request cannot enable a save. It reports `completed` when persistence already committed, otherwise `cancelled`. The modal intercepts Bootstrap dismissal before hiding, waits for this acknowledgement and refreshes an already committed selection; failed transport keeps an actionable Close retry. A terminal error invalidates its request, while an error before persistence can still be retried at the protocol boundary until cancellation or supersession. Cancellation cannot undo a committed return.

## 8. Caching Strategy

Use existing authoring broadcasts and delivery cache/depot invalidation. Reload tool details after a successful section selection change. No selection cache or new cache subsystem is needed. Rollback must not publish a success state or invalidate into a partially applied section.

## 9. Performance & Scalability Posture

Resolve candidates with scoped publication/destination joins and existing-selection exclusion. Validate in memory only the selected candidates and use bounded/batched database operations where practical. Avoid one revision/deployment lookup per destination activity and avoid external HTTP calls in creation/update/copy transactions. Verify SQL/query shape and index use during implementation review; no new numerical SLA is asserted.

Ordinary edits retain existing debounce/revision behavior. Only selection saves force a fresh revision. Fingerprinting uses the one resolved activity, not a project scan; no external HTTP occurs inside editing transactions.

## 10. Failure Modes & Resilience

- Preparation/flush failure: do not launch; retain the current selection and provide retry/reload guidance appropriate to actual editor state.
- Cancelled/older launch message: ignore it; do not fetch/apply a selection after active-request invalidation.
- Invalid or expired JWT/correlation/result: refuse without mutation; present actionable configuration failure.
- Lock loss or intervening edit: reject the stale selection and preserve the newer draft. Synchronize the editor before retrying.
- Selection save error: do not report success or leave the failed selection in displayed persisted state.
- Initialization/copy error: roll back the owning creation/application transaction and retain the prior section/publication state.
- External tool unavailable or incompatible: do not discard existing selections; preserve existing integration status/launch failure behavior.
- Instructor modal cancellation/error: retain its section selection, do not signal successful replacement merely because the modal closed.

## 11. Observability

Use existing bounded diagnostic/logging paths with failure categories and operation context. Do not log JWTs, request/result tokens, raw tool custom objects, serialized task text or learner payloads. No new telemetry scheme is introduced. Capture intentional test logs at their source and preserve clean successful ExUnit output.

## 12. Security & Privacy

Validate tool signature/key association, issuer/audience, lifetime, supported message/version/deployment claims and accepted content shape. Verify Torus tokens separately; a tool signature does not authenticate unchanged Torus correlation data. Preserve applicable standard anti-replay checks and enforce one successful selection application through the atomic revision guard.

Recheck author/project/activity/integration association and edit-lock ownership at save. Enforce section instructor/admin authorization and capability at configuration launch and section callback, not just via visible controls. Student launches preserve learner identity and section context; selecting Instructor in project authoring preserves the initiating author's identity/project context. Keep launch choices out of inherited selection data.

Check iframe message source and expected origin where Torus owns the return page. Treat tool metadata as untrusted display text. Use disposable fixtures/real scenario setup without production credentials; configuration inheritance must not expose or copy learner data.

## 13. Testing Strategy

- AC-001–AC-003: API/controller role/type matrix, unsupported options, integration states, author access and default/reused regular target/custom claims.
- AC-004–AC-007: focused frontend state/save/component tests with controlled responses for accessibility and visible success/failure states; exercise failed persistence and stale messages without an external tool service.
- AC-008–AC-009: signed-tool controller/domain checks for invalid keys/claims/items, tampering/expiry, cross-association, removed access and lost locks.
- AC-010–AC-012: editor domain tests and real authoring workflows for atomic selection revision changes, same-lock intervening edits, replay, stale autosaves, preserved unrelated content and publication isolation.
- AC-013–AC-018: direct creation/application scenarios for exact older/newer revisions, new/missing/unconfigured activities, destination filtering, retained overrides, repeat/concurrent insertion and complete rollback. Unit tests can assert insert/query behavior and failure propagation separately.
- AC-019–AC-021: project → template → section scenarios, current template changes, cleared/missing template selections, destination remaps/filtering, independent records and rollback without learner-data copying.
- AC-022–AC-024: frontend regressions for distinct regular/configuration frame targets, mounted modal state and return association using controlled messages; authorized/unauthorized controller checks, cancellation/failure and section-local override isolation. Actual tool navigation/selection in the modal remains deferred; component tests cannot fully verify AC-022.
- AC-025–AC-027: arbitrary custom payload/long-field round trips, migration/rollback checks, absent selection and unchanged user/context/link identity.
- AC-028–AC-031: committed real domain scenario/frontend coverage and durable author/instructor guidance. Preserve existing manual MyProse observations; AC-030's new complete walkthrough and cross-service browser evidence are deferred. Add hooks/directives only where existing real scenario capabilities cannot express a required workflow; use `build_scenario` and `extend_scenario` when implementing them.

Do not start or add a real/test tool service for the current verification scope. Extending the dummy tool, configuring its registrations and running tool-dependent browser tests are deferred. Backend scenario setup must use real directives, not domain factories/mocks; signed-protocol unit tests may use local test keys/HTTP mocks, and frontend tests may control transport and message events. Verify actual cryptographic validation in backend tests rather than mocking it away. Publication/inheritance scenarios verify persisted selections and launch parameters without visiting tool URLs.

## 14. Backwards Compatibility

Retain default Developer + Regular, existing delivery URL/custom lookup, unconfigured activity behavior, stable internal resource IDs and existing LTI resource-link identity. Preserve existing section rows during publication changes. Ordinary non-LTI activity editing keeps its existing revision policy. Unsupported authoring hosts do not gain a nonfunctional configuration action.

Template inheritance is additive to the template copy policy, not a new section-copy checkbox or automatic project fallback. Test project cloning/remapping where shared copy infrastructure is touched; broaden support only with a documented scope decision.

## 15. Risks & Mitigations

- In-place edits or alternate save paths can bypass freshness: cover all relevant LTI edit entry points, preserve non-LTI behavior and add same-lock regressions.
- Broad helper reuse can overwrite overrides: separate insert-missing publication policy from instructor upsert and template copy.
- Copy-engine changes can leak into previous-section copying: gate by source policy and retain adjacent regression tests.
- A frame collision is not yet a reproduced root cause: cover distinct targets and handler association with failing component tests, and retain the pending runtime confirmation until tool-dependent verification resumes.
- Tool payloads can be large or contain references to shared state: keep exact values, scoped queries and explicit compatibility documentation.
- The prototype is behind `master`: integrate the current base before implementing and resolve/test changed creation, editing and copy entry points.

## 16. Open Questions & Follow-ups

No product question blocks the current design. Reset/clear UI, wizard source labels, general section-copy controls, context-specific LTI identity and MyProse catalog fixes remain separate follow-ups. Confirm exact guarded-save helper placement and any scenario extension in slice design before coding. Revisit tool fixture choice only when external verification resumes; the current scope does not authorize extending that tool.

## 17. References

- `docs/exec-plans/current/features/mer-6018-lti-deep-linking/prd.md`, `requirements.yml` and `informal.md` in this work item.
- `docs/exec-plans/current/features/lti-authoring-launch/overview.md` and `docs/exec-plans/current/features/lti-authoring-launch/plan.md`.
- `docs/design-docs/publication-model.md`, `docs/design-docs/locking.md`, `docs/TESTING.md`, `docs/CODEREVIEW.md`, `docs/OPERATIONS.md` and `harness.yml`.
- [MER-6018](https://eliterate.atlassian.net/browse/MER-6018).

## Decision Log

### 2026-10-13 - Keep verification executable without an external tool
- Change: Replace current cross-service browser gates with focused frontend/controller/scenario checks; retain actual tool navigation and compatibility as deferred evidence.
- Reason: The owner requested postponing every test type that requires running a real or test tool; the available example tool lacks the Deep Linking selection/response flow.
- Evidence: `assets/automation/tests/torus/lti_external_tool/lti-external-tool.spec.ts` covers Regular only; `test/oli_web/controllers/lti_controller_test.exs` already demonstrates signed Deep Linking responses with test keys and controlled JWKS retrieval.
- Impact: Storage, authorization and production interfaces are unchanged. Backend protocol and persistence checks continue; AC-022 runtime confirmation and AC-030 compatibility proof stay pending.

### 2026-10-13 - Bind instructor returns and separate frame outcomes
- Change: Add signed section/account/activity/deployment/request correlation, current-access checks and atomic successful-request consumption; use instance-unique frame names and distinguish success, error and cancellation.
- Reason: Phase 2 tests exposed colliding targets, false success on errors/close, and configuration endpoints accepting learner or unrelated tool returns. The existing save helper also discarded persistence failures.
- Evidence: `lib/oli/lti/section_deep_link_launch.ex`, `test/scenarios/lti_external_tool/section_configuration_test.exs`, and `assets/test/components/lti/`.
- Impact: Section returns must echo the Torus `data` from the initiating request and applicable deployment/version claims. Legacy positive tests now use a bound instructor request; a pre-upgrade configuration window must be reopened. Actual external navigation remains deferred.

### 2026-10-14 - Serialize cancellation and supersession with section persistence
- Change: Store latest pending request state in the existing indexed nonce table, start configuration through a trusted-Origin POST and cancel through an actor/route-bound POST. Control Bootstrap dismissal until cancellation is acknowledged and report persistence winning the race as completion.
- Reason: Review found that an unused older request could overwrite a newer selection, Bootstrap hid the modal before cancellation, and expired/revoked capability could prevent dismissal. Further review identified resource aliases and an unindexed pending-state query.
- Evidence: `lib/oli/lti/section_deep_link_launch.ex`, `lib/oli_web/router.ex`, `test/scenarios/lti_external_tool/section_configuration_test.exs`, and `assets/test/components/lti/external_tool_configuration_test.tsx`.
- Impact: One pending generation per section/activity, indexed bounded database operations and no additional migration. Return validation remains strict; safe cancellation cannot save data. External tool/browser verification remains deferred.

### 2026-10-14 - Offer current custom parameters to compatible selectors
- Change: Share standards-compatible current selection custom values in authoring and section Deep Linking request claims.
- Reason: The owner approved Torus-side support for tools that can prepopulate selection without a MyProse-specific contract.
- Evidence: `lib/oli_web/controllers/lti_controller.ex` and `test/scenarios/lti_external_tool/section_configuration_test.exs`.
- Impact: One indexed section/resource lookup at section authorization; authoring reuses the resolved draft revision. Preserve storage, Regular claims, selector target and correlation. Non-string legacy parameters stay stored unchanged and are omitted only from the optional configuration hint.


### 2026-10-14 - Keep authoring production work proportional to the ticket
- Reason: The owner requested removing the additional coordination infrastructure and using the existing save feedback.
- Change: Reuse `ActivityEditor.edit/5`, its lock/transaction and the existing deferred persistence barrier. Retain signed handoff/current-access checks, a server-side captured-state comparison and selection-only merge. Use the page's `Saving...` / `All changes saved` indicator; no separate selection-saved toast/message.
- Impact: Remove the authoring coordinator, persisted request generations/cancel endpoint, generic-resource changes and forced fresh ordinary revisions. Closing authoring configuration is local. General multi-tab coordination and acknowledged cancellation races are not introduced in authoring; committed section behavior remains Phase 2. No new migration.
