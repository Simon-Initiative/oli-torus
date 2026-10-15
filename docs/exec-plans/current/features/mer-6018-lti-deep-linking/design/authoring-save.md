# Authoring Deep Linking Save - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/prd.md`
- FDD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/fdd.md`
- Plan: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/plan.md` (Phase 3)

## 1. Slice Summary
- Make prototype authoring reliable using existing editor persistence, locks, revisions and feedback.
- Scope is the project page editor, signed response validation, selection-only persistence and ordinary single/bulk selection preservation.
- General multi-tab editing, persistent authoring request generations, server cancellation acknowledgements and generic resource-editor changes are outside this slice. No new migration or tool-dependent automation.

## 2. Requirements Coverage
- FR-001 / AC-001, AC-002, AC-003: independent role/type matrix, Regular reuse, current custom hints and accepted author/integration/lock checks.
- FR-002 / AC-004, AC-005, AC-006, AC-007: supported-host gating, portable metadata fallback, existing save feedback, autosave preparation, local close/error and active-editor message association.
- FR-003 / AC-008, AC-009: validate tool JWT and signed Torus account/project/activity/deployment association with current access/capability and captured-state checks.
- FR-004 / AC-010, AC-011, AC-012: use existing editor transaction for selection merge, fresh selection revision, stale/replay refusal, ordinary selection preservation and publication isolation.
- AC-025, AC-029: exact portable metadata and tests without an external service. Cross-service AC-030 remains deferred.

## 3. Responsibilities & Boundaries
- `AuthoringLaunch` resolves author/tool access and verifies signed handoffs. It holds no persisted request registry.
- The page editor flushes its existing page and target-activity persistence strategies before obtaining configuration details.
- `ActivityEditor.edit/5` owns permission, durable lock, transaction, revision cloning, mapping updates and post-commit broadcast. Add a signed-result update shape to this boundary rather than another editing subsystem.
- The activity component owns its modal and active request ID. Close/error clears that local request; the callback itself never persists, so a late frame message cannot save without the editor submitting its token.

## 4. Interfaces & Signatures
- `start_request(author, project, activity, lock_id)` checks current ownership/capability and returns launch correlation. Sign author/project/activity/deployment, UUID, publication/revision, lock resource and a server-generated fingerprint of editable activity fields.
- Carry the original signed request through the existing signed `lti_message_hint`; login-hint context stays within 255 characters. The tool echoes the opaque hint and signed `data`.
- `validate_request` and `validate_return` check association/current state; tool signature/audience/message validation remains in the controller.
- `result_token` signs a validated selection without writing. `validate_result` is used inside editing. Submit the token directly to the save endpoint; there is no separate retrieval round trip.
- `save_result` delegates to `ActivityEditor.edit/5` with only `%{"deep_link_result" => token}`. Reject mixed model/token updates. The editor revalidates under its normal lock/transaction, merges selection into current content and always creates a fresh selection revision. Ordinary edit requests preserve current `deepLink`.
- The POST save response carries authoritative model/title/objectives/tags. The page editor synchronizes its existing activity context before closing the selector.
- Host events are `ltiAuthoringPrepare`, `ltiAuthoringSave` and local `ltiAuthoringClose`. No authoring cancel endpoint.

## 5. Data Flow & Edge Cases
1. Flush pending/in-flight page and activity edits; a failed save refuses configuration. The existing deferred persistence barrier serializes a running save before flushing queued edits and propagates errors.
2. Capture the current activity state after preparation and open one selector in the active editor. Supported-host capability prevents offering configuration where persistence is unavailable.
3. Verify the tool response and sign a result; write nothing at callback time.
4. Submit the signed result through the normal editing transaction. Compare current revision and deterministic server fingerprint before merge; fingerprints detect in-place draft changes without forcing fresh ordinary revisions.
5. Commit selection/revision/mapping together. A fresh selection revision prevents replay. Rollback retains previous content and permits retry after a real database failure.
6. Use the existing `PersistenceStatus` for `Saving...` and `All changes saved`. On failure, retain the current model, show the established error banner/modal detail and suppress a saved confirmation. An uncertain network outcome tells the author to reload.
7. Close/error discards the mounted editor request. Do not start a second save after local close; wait for an already-running save to finish before closing. Unmount stops host state updates; no cancellation/disposal framework is added.

Ordinary single/bulk saves retain stored selection and existing revision policy. Generic resource editing/import/copy remains unchanged. Two tabs keep the platform's existing author-owned lock behavior; captured-state validation detects intervening activity changes but does not impose a global newest-request-wins policy.

## 6. Test Plan
- Scenario/domain/API: role/type matrix, signed callback rejection, saved-model fields, ordinary single/bulk preservation with unchanged revision policy, same-revision changed-state refusal, replay, permission/capability/lost-lock refusal and publication isolation.
- Real database constraint: complete revision/mapping rollback and retry.
- Deferred persistence: immediate flush, in-flight/queued serialization, failure propagation and recovery.
- Mounted page editor: preparation order/failure, existing Saving/saved indicator, authoritative model sync and failed-save feedback without a false saved state.
- Activity component: supported host, roles, metadata fallback, local cancellation, old/duplicate message filtering and focus return. Reuse frame/modal coverage.
- No external tool/browser automation; owner manual review remains available.

## 7. Risks & Open Questions
- No global guarantee about which of two unchanged-state requests from different tabs wins; that additional policy was removed at owner request.
- If a save commits but its response is lost, reload to obtain the authoritative selection. Local close is not an undo operation or server cancellation protocol.
- A tool must echo the standard opaque hint/data. Actual browser navigation and interoperability remain deferred.
- No blocking open questions for this reduced scope. Phase 3 was committed as `3bc97a98be` after owner approval; later implementation commits require separate approval.

## 8. Definition of Done
- [x] Requirements mapped to the reduced scope.
- [x] Existing primitives own persistence and feedback.
- [x] Test plan covers successful save and meaningful failures.
- [x] Final validation and correction reviews pass.
