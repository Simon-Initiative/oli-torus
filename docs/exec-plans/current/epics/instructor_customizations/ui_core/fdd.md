# Activity Bank Selection Preview Customization - Feature Design Document

## 1. Executive Summary

MER-5620 should implement the new Activity Bank Selection preview UI in the Instructor View preview experience for Course Sections, including whole-selection remove/restore, using the existing instructor customization persistence and the shared preview customization wiring contract.

The core domain layer already has bank-selection validation and write APIs in `Oli.Delivery.InstructorCustomizations`, and the browser hook already accepts `bank_selection` targets. However, the Activity Bank Selection preview does not appear to have received the new MER-5618 preview-component UI that embedded activities and several activity types now use. The design therefore includes both the Activity Bank Selection visual implementation from Figma and the LiveView wiring needed to make remove/restore work.

The remaining design work centers on inline preview ownership. UI ownership means adding a real Activity Bank Selection preview component/layout rather than only adding a button to the old rendered selection block. The owning LiveView for this ticket is the existing instructor lesson preview, `OliWeb.Delivery.Instructor.PreviewLessonLive`, which already mounts `InstructorPreviewCustomization`. MER-5620 should replace the inline `selection` renderer used inside that LiveView with a React custom element that follows the preview-component pattern and delegates whole-selection events back to the existing LiveView. Because Activity Bank Selection is a content element and not a registered activity type, it should be bundled through a generic instructor-preview components entry instead of a fake activity `manifest.json`. The separate `/selection/:selection_id` activity-listing route belongs to a different ticket and should not be migrated or reimplemented here.

Implementation should treat embedded activity remove/restore as existing infrastructure from MER-5622 / PR 6659. MER-5620 should regression-test that behavior but should not reimplement it.

## 2. Requirements & Assumptions

### Requirement Trace

- FR-001 / AC-001: Render Activity Bank Selection preview metadata: heading, available-question count, select count, points per question, authored criteria, and one sample question.
- FR-002 / AC-002 / AC-003 / AC-004: Support whole-selection remove and restore, update available count, show success confirmation, show the approved removed treatment, and keep the sample question visible and keyboard-operable.
- FR-003 / AC-005 / AC-006: Emit `bank_selection` customization intents with `pageResourceId` and `selectionId`, dispatch through the owning LiveView into `Oli.Delivery.InstructorCustomizations`, and return targeted replies for local UI state.
- FR-004 / AC-007 / AC-008 / AC-009: Show future-attempt warning text and require confirmation when existing scored attempts or practice visits are present.
- FR-005 / AC-010 / AC-011: Keep changes scoped to the current page and section/template context, preserve authored content and historical progress, and meet accessibility requirements for controls and states.
- FR-006 / AC-012: Do not reimplement embedded activity remove/restore; keep it functional after bank-selection changes.

### Assumptions

- The primary implementation target is instructors operating in Course Sections under `/sections/:section_slug`.
- Template-level UI is reached through Product/Template Customize Content page Edit links, which use the same instructor-style `PreviewLessonLive` route for the template's blueprint section. No separate template UI is required for MER-5620.
- Template-level activity exclusions should be copied from the blueprint section to future course sections created from that template, while already-created sections remain unchanged.
- Existing `Oli.Delivery.InstructorCustomizations.exclude_bank_selection/4` and `restore_bank_selection/4` are the persistence authority for whole-selection remove/restore.
- Existing student attempts and prior progress are immutable for this feature; remove/restore only affects future activity realization.

## 3. Repository Context Summary

Relevant boundaries:

- `lib/oli/delivery/instructor_customizations.ex` owns target validation, persistence, and read models for page activity exclusions. It already exposes bank-selection target validation and write APIs.
- `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex` is the current LiveView reference for embedded activity preview customization. It mounts `InstructorPreviewCustomization`, dispatches remove/restore into the domain context, and returns `{:reply, reply, socket}` payloads.
- `assets/src/hooks/instructor_preview_customization.ts` already validates and forwards `bank_selection` targets, so hook changes should be small or unnecessary unless warning confirmation requires a client-side helper.
- `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md` is the shared transport contract.
- `lib/oli_web/controllers/activity_bank_controller.ex` and `lib/oli_web/templates/activity_bank/preview.html.heex` own the separate Activity Bank candidate-listing preview route. That route is intentionally out of scope for this ticket.
- `lib/oli/rendering/content/selection.ex` is the legacy renderer for authored selection blocks. It produces the jumbotron-style Activity Bank Selection display and the `Preview activities` link when rendered inside page content. Instructor Preview should bypass it for inline selections while keeping it available for non-instructor-preview contexts and the separate candidate-listing route.
- `assets/src/apps/InstructorPreviewComponents.tsx` is the generic instructor-preview bundle entry for custom elements that are not activity manifest entries.
- `assets/src/components/activities/common/preview/ActivityPreviewCard.tsx` and related MER-5618 preview components provide reusable interaction patterns for individual activity previews, but there is no local Activity Bank Selection preview component. MER-5620 should implement that selection-level UI rather than treating the work as a button-only extension.
- `Oli.Delivery.ActivityProvider` already consults instructor customization state when realizing future activity bank selections, so the UI should not need new delivery-time storage semantics.
- Scenario directive infrastructure already has bank-selection exclusion verbs, which can support integration tests if this feature needs cross-workflow proof.

## 4. Proposed Design

### Inline Preview Ownership

Use the existing instructor lesson preview as the owning surface:

- Keep `OliWeb.Delivery.Instructor.PreviewLessonLive` as the LiveView owner.
- Do not introduce a new LiveView or route for MER-5620.
- Keep `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id` as the legacy/separate candidate-listing route owned by the existing Activity Bank controller until the separate listing ticket changes it.
- Replace the inline Instructor Preview rendering of content elements with `"type" => "selection"` by emitting an Activity Bank Selection React custom element.
- Continue using `InstructorPreviewCustomization` mounted on `PreviewLessonLive` as the browser-to-LiveView transport for remove/restore.

This keeps AC-005 and AC-006 aligned with the existing LiveView/React contract without creating a second screen surface.

### Preview Context

Build a server-owned selection preview context from the resolved section, page revision, selection node, current exclusion view, and activity bank query result. Store these payloads under a generic `Oli.Rendering.Context.instructor_preview_context` map, keyed by preview feature, so the base render context does not grow Activity-Bank-specific fields:

- `page_resource_id`
- `revision_slug`
- `selection_id`
- display heading/title
- available-question count
- authored select count
- points per question, if available from the selection/page model
- authored criteria summary
- sample activity/question content resolved server-side from the bank selection logic
- sample activity preview payload using the same `preview_element`, model, and preview context shape used by normal activity preview components
- `selection_enabled?`
- `actions`: `[%{kind: "remove", label: "Remove"}]` when enabled, `[%{kind: "restore", label: "Restore"}]` when removed
- `visualState`: `"default"` or `"removed"`
- `statusPill`: `nil` or `%{kind: "removed", label: "Removed"}`
- `customizationTarget`: `%{kind: "bank_selection", pageResourceId: page_resource_id, selectionId: selection_id}`

### Activity Bank Selection UI Component

Implement the approved Instructor View Activity Bank Selection UI from Figma as an explicit feature deliverable. This is separate from the existing individual activity preview components added by MER-5618.

Recommended shape:

- Add a selection-level React custom element dedicated to Activity Bank selections.
- Register that custom element through `instructor_preview_components.js`, not through the activity manifest scanner.
- Treat `Oli.Rendering.Content.Selection` as the legacy authored-content renderer to bypass for Instructor Preview, not as the final Figma-backed preview UI.
- Reuse shared preview primitives where they fit: header/action button styling, removed visual state, status pill, rich-text rendering, and sample question rendering.
- Do not force the selection UI into `ActivityPreviewCard` if that creates an awkward model; an Activity Bank Selection is a page-level selector with aggregate metadata and a sample question, not a normal activity card.
- Render the Figma-required metadata: available questions, select count, points per question, authored criteria, sample question, active/removed state, and success/warning affordances.
- Keep the sample question as a real preview using the existing activity preview/authoring rendering path, so keyboard behavior and rich content remain consistent with activity previews.

Elixir remains the data adapter: it resolves counts, criteria, customization state, candidate sample data, and required scripts. React owns the full HTML for the Activity Bank Selection preview and renders the sample question by mounting the existing activity `preview_element` custom element. This keeps the sample activity consistent with normal preview components without moving bank-selection query logic to the browser.

### Remove/Restore Flow

The LiveView handles:

```elixir
handle_event(
  "toggle_preview_activity_customization",
  %{
    "action" => action,
    "target" => %{
      "kind" => "bank_selection",
      "pageResourceId" => page_resource_id,
      "selectionId" => selection_id
    }
  },
  socket
)
```

The event handler should:

1. Confirm `page_resource_id` matches the currently previewed page.
2. Confirm `selection_id` belongs to the currently previewed page revision.
3. If a warning confirmation is required and the action is not confirmed yet, store a pending customization in assigns and show the warning modal without mutating domain state.
4. Dispatch to `InstructorCustomizations.exclude_bank_selection/4` for `remove` or `InstructorCustomizations.restore_bank_selection/4` for `restore`.
5. Rebuild the selection preview context from the returned or freshly read exclusion view.
6. Return a targeted reply with `ok`, `target`, `actions`, `visualState`, `statusPill`, and any selection aggregate values needed by the local UI.
7. Update LiveView assigns for flash/success message, warning modal state, available count, and removed-state presentation.

Malformed, stale, unauthorized, or invalid targets should return `%{ok: false}` and should not mutate state.

### Warning Confirmation

The LiveView owns warning state because warning eligibility depends on section/page data and because mutation authority belongs to the server.

For scored pages, the warning is shown when at least one learner has already started the assessment. For practice pages, the warning is shown when at least one learner has already visited the page. The implementation should identify or add a small query helper near the delivery/instructor preview boundary that answers this without exposing learner identities.

Required warning copy:

- AC-007 scored warning: `Students have already started this assessment. Removing or restoring questions and activity bank selections will only impact future attempts.`
- AC-008 practice warning: `Students have already visited this page. Removing or restoring questions and activity bank selections will only impact future attempts.`

When warning state is active, an attempted remove/restore should show the confirmation modal and proceed only after user confirmation, satisfying AC-009. The final confirmed mutation should use the same domain dispatcher as an unconfirmed mutation.

### Template Behavior

Template support uses the existing Product/Template Customize Content flow:

- Product/Template Customize Content page Edit links target `/sections/:blueprint_slug/preview/lesson/:revision_slug` with a product remix `return_to`, including the course-author workspace form `/workspaces/course_author/:project_slug/products/:product_slug/remix`.
- That route is the same `PreviewLessonLive` surface used for Course Section instructor preview, so the Activity Bank Selection and embedded activity remove/restore UI does not need a separate template-specific implementation.
- `PreviewReturn` must preserve the product remix return path so "Return to Customize Content" returns to the template Customize Content page rather than the blueprint section remix page.
- `Blueprint.duplicate/3` must copy `section_page_activity_exclusions` from the source blueprint/template section to the new course section. This matches existing Customize Content semantics: future course sections inherit template-level content customization, but already-created sections are not retroactively updated.

This keeps the design centered on the existing instructor preview surface while satisfying AC-010 for template scope and future-section behavior.

## 5. Interfaces

### Browser Event Payload

Activity Bank Selection remove/restore emits:

```json
{
  "action": "remove",
  "target": {
    "kind": "bank_selection",
    "pageResourceId": 123,
    "selectionId": "selection-id"
  }
}
```

`action` is `"remove"` or `"restore"`. `target.kind` is `"bank_selection"`. `pageResourceId` and `selectionId` are required.

### LiveView Reply

Successful replies should include:

```elixir
%{
  ok: true,
  target: %{
    kind: "bank_selection",
    pageResourceId: page_resource_id,
    selectionId: selection_id
  },
  actions: [%{kind: "restore", label: "Restore"}],
  visualState: "removed",
  statusPill: %{kind: "removed", label: "Removed"},
  questionsAvailable: 0
}
```

Restore replies use `actions: [%{kind: "remove", label: "Remove"}]`, `visualState: "default"`, `statusPill: nil`, and the recomputed available-question count.

Failure replies should include `ok: false` and a concise reason category for debugging/UI fallback, without leaking learner data.

### Domain Calls

- Remove: `Oli.Delivery.InstructorCustomizations.exclude_bank_selection(section_or_id, page_resource_id, selection_id, opts)`
- Restore: `Oli.Delivery.InstructorCustomizations.restore_bank_selection(section_or_id, page_resource_id, selection_id, opts)`
- Validation: `Oli.Delivery.InstructorCustomizations.validate_bank_selection_customization_target(section_or_id, page_resource_id, selection_id)`
- Read state: `get_page_exclusion_view/2` or `get_selection_exclusion_view/3`

The LiveView may call validation explicitly for clearer local error handling, but the domain write remains the final authority.

## 6. Data Model & Storage

No new database tables or migrations are expected.

Whole-selection remove/restore should use the existing instructor customization exclusion storage with:

- `section_id`
- `page_resource_id`
- `kind: :bank_selection`
- `selection_id`

The feature must not write to authored page revisions, published source content, activity bank logic, or existing student attempt records. This satisfies AC-010 and preserves the publication/resource/revision model.

If the implementation discovers missing uniqueness constraints or race-prone duplicate exclusion rows, address that in the core instructor customization layer rather than in UI code.

## 7. Consistency & Transactions

`Oli.Delivery.InstructorCustomizations` should remain the consistency boundary for exclusion writes.

Expected behavior:

- Remove is idempotent from the user perspective: removing an already removed selection should leave it removed.
- Restore is idempotent from the user perspective: restoring an already active selection should leave it active.
- Page and selection target validation happens before writes.
- The LiveView rebuilds UI state after a successful write rather than trusting the submitted action.
- Existing attempts and progress are not rewritten.

Concurrent instructor actions on the same selection should converge to the latest persisted exclusion state when the LiveView refreshes its selection preview context.

## 8. Caching Strategy

No new cache is required.

The LiveView should reuse existing Activity Bank query and exclusion-view reads. After remove/restore, it should refresh only the affected selection preview state and any page-level aggregates needed for the screen. Avoid storing derived selection-enabled state in long-lived process state without re-reading after writes.

## 9. Performance & Scalability Posture

The preview should avoid per-candidate query loops during render.

Recommended approach:

- Use the existing Activity Bank query path to obtain total available count and the paged/sample activity rows.
- Use the existing exclusion view once per page/selection render.
- For sample question rendering, reuse the first available queried activity when possible or issue a limit-1 query rather than loading all candidates.
- Keep warning detection to an existence/count query scoped by section and page resource, not a full learner-attempt listing.

This is a section/instructor preview surface, so throughput requirements are modest, but the implementation should still avoid N+1 behavior and expensive all-candidate loads.

## 10. Failure Modes & Resilience

Expected failure modes and handling:

- Invalid browser payload: dropped by `InstructorPreviewCustomization` before `pushEvent`.
- Stale page resource id: LiveView returns `ok: false`; no write.
- Selection id not present on current page: LiveView/domain validation returns `ok: false`; no write.
- Unauthorized instructor/admin context: route authorization or domain authorization rejects; no write.
- Domain persistence error: LiveView keeps the prior UI state, clears submitting state through `ok: false`, and shows recoverable feedback.
- Warning confirmation canceled: pending action is cleared; no write.
- Activity Bank query failure after mutation: persisted state remains authoritative; LiveView should show an error and allow refresh/retry.

The UI should never hide the sample question solely because a selection is removed; removed state is a customization overlay, not deletion.

## 11. Observability

No new product telemetry is required for the initial design.

Use existing logging/AppSignal paths for unexpected domain or query errors. Avoid logging learner-specific attempt details for warning eligibility. If the implementation already has a reusable instructor customization telemetry event, bank-selection remove/restore can emit the same event shape with `target_kind: :bank_selection`.

Success and failure feedback should be visible to the instructor through existing LiveView flash/success-message patterns.

## 12. Security & Privacy

Security checks:

- Preserve instructor/admin authorization for section preview routes.
- Validate section, page resource id, and selection id server-side.
- Delegate final domain validation to `Oli.Delivery.InstructorCustomizations`.
- Do not trust `pageResourceId`, `selectionId`, action labels, visual state, or count values from the browser.
- Escape authored criteria/title values in server-rendered HTML.

Privacy checks:

- Warning copy must not reveal which learners have attempted or visited the page.
- No learner attempt IDs, user IDs, or names should be sent to the browser for this feature.

## 13. Testing Strategy

Automated tests:

- LiveView test for active selection preview render with required metadata and sample question: AC-001.
- LiveView test for remove flow: action emitted/handled, domain state changed, available count becomes 0, success appears, action changes to Restore: AC-002 and AC-005.
- LiveView test for restore flow: state returns to default, original count returns, success appears, action changes to Remove: AC-003.
- LiveView/UI test for removed treatment and sample question operability: AC-004 and AC-011.
- LiveView test for targeted success/failure replies, including stale page id and missing selection id: AC-006.
- Warning tests for scored started attempts and practice page visits: AC-007 and AC-008.
- Warning modal test that mutation occurs only after confirmation: AC-009.
- Scope test showing removal affects only the current page and section/template scope, preserving authored content and existing progress: AC-010.
- Regression test that embedded activity remove/restore still functions and is not reimplemented through a new path: AC-012.

Frontend tests:

- Add or update Jest coverage only if new TypeScript is introduced. Existing hook validation already includes `bank_selection`, so frontend tests may be limited to the new preview component state/props if React rendering is used.

Scenario tests:

- Add scenario coverage if the implementation needs end-to-end proof across authoring, publishing, section delivery, instructor customization, and future attempts.
- A template Customize Content preview smoke test should verify that product remix `return_to` paths are preserved.
- A blueprint duplication test should verify that activity exclusions are copied to future sections and not retroactively applied to already-created sections.

Manual verification:

- Compare active, removed, warning, modal, hover, disabled, and focus states against the approved Figma references.
- Verify scored and practice page copy exactly matches AC-007 and AC-008.
- Verify future attempts reflect removal/restoration while existing attempts remain unchanged.

## 14. Backwards Compatibility

Preserve the user-facing Activity Bank candidate-listing preview URL. MER-5620 should not convert that controller route into a LiveView route; this ticket replaces the inline Activity Bank Selection preview rendered inside `PreviewLessonLive`.

Do not change the embedded activity preview customization contract or existing embedded event behavior from MER-5622. Do not change delivery attempt realization beyond the existing use of instructor customization exclusion state.

Template Customize Content compatibility is handled through blueprint-section page Edit links into `PreviewLessonLive`. Future course sections inherit template-level activity exclusions through blueprint duplication, not through retroactive propagation.

If the implementation proves that legacy Activity Bank Selection preview code is no longer referenced by any active authoring, delivery, template, or preview surface, remove that dead code as part of MER-5620 cleanup rather than preserving unused fallback paths.

## 15. Risks & Mitigations

- Risk: Inline Activity Bank Selection preview keeps using the legacy server-rendered jumbotron. Mitigation: bypass `Oli.Rendering.Content.Selection` only for `:instructor_preview` and emit the React custom element inside the existing `PreviewLessonLive` surface.
- Risk: Warning confirmation could fork the customization transport path. Mitigation: keep LiveView as the mutation owner; use the existing hook for intents and let LiveView own pending confirmation state.
- Risk: Template requirements may be interpreted as a separate surface. Mitigation: use the existing Product/Template Customize Content page Edit route into `PreviewLessonLive`; do not add template-specific UI unless that route behavior changes.
- Risk: Template-level exclusions may fail to affect future course sections. Mitigation: copy `section_page_activity_exclusions` during `Blueprint.duplicate/3` and test that already-created sections remain unchanged.
- Risk: Counts drift from delivery behavior. Mitigation: recompute from the same Activity Bank and exclusion-view sources used by delivery, and refresh after writes.
- Risk: Overlap with MER-5622 causes duplicated embedded behavior. Mitigation: only add `bank_selection` handling and regression-test embedded remove/restore.
- Risk: Attempt/visit warning query is ambiguous for practice pages. Mitigation: locate the existing delivery visit/access signal and encapsulate warning eligibility in a small tested helper.
- Risk: legacy preview code is removed too early even though the separate candidate-listing route still uses it. Mitigation: retain controller/template/legacy renderer until the separate listing ticket replaces that surface.

## 16. Open Questions & Follow-ups

- Confirm the exact source of "students have already visited this page" for practice pages: resource access, resource attempts, page visits, or an existing delivery summary helper.
- Confirm where points-per-question is stored for Activity Bank Selection preview and whether it is always available for both scored and practice pages.
- Revisit `ActivityBankController.preview/2` only in the separate candidate-listing ticket.

## 17. References

- `docs/exec-plans/current/epics/instructor_customizations/ui_core/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/ui_core/requirements.yml`
- `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md`
- `docs/exec-plans/current/epics/instructor_customizations/core/fdd.md`
- `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/fdd.md`
- `lib/oli/delivery/instructor_customizations.ex`
- `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`
- `lib/oli_web/controllers/activity_bank_controller.ex`
- `lib/oli_web/templates/activity_bank/preview.html.heex`
- `assets/src/hooks/instructor_preview_customization.ts`
- `lib/oli/delivery/template_preview.ex`
- `lib/oli_web/controllers/products_controller.ex`
