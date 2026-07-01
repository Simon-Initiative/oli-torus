# Activity Bank Selection and Embedded Question Remove/Restore - Informal Notes

## Source

- Jira: `MER-5620`
- Type: Story
- Summary: Activity Bank Selection & Embedded Question Remove/Restore
- Status at intake: QA
- Assignee at intake: gaston@wyeworks.com
- Epic lane slug from Jira comment: `ui_core`

## User Story

As an instructor, I want the ability to remove entire Activity Bank selections and embedded questions from a page (scored and practice), so that I can better align assessments and practice opportunities with the goals and scope of my course section.

This capability should also be available at the template level.

## Current Scope Adjustment

The original ticket includes remove/restore behavior for both embedded questions and entire Activity Bank selections. Embedded question remove/restore has already been implemented by the merged `MER-5622-manage-questions-in-activity-bank-selection` work in PR `https://github.com/Simon-Initiative/oli-torus/pull/6659/changes`.

That merged work added the LiveView/React wiring, preview-card UI actions, local reply handling, and backend routing needed for embedded activity remove/restore in Instructor View.

MER-5620 should not reimplement embedded activity remove/restore. It should treat that work as existing infrastructure and focus remaining implementation on:

- Activity Bank Selection preview display updates
- whole-selection remove/restore behavior
- routing bank-selection preview actions into the core instructor customization implementation
- warning messaging that changes only apply to new attempts

The embedded question acceptance criteria remain documented below because they are part of the original Jira scope, but implementation planning should mark them as already satisfied by the merged MER-5622/PR 6659 work unless a regression or integration gap is found.

## Acceptance Criteria

### Positive Acceptance Criteria

Note: removing bank selections & questions should not affect student progress. A student should not be required to complete something that has been removed to achieve 100%.

#### Activity Bank Selection UI

Given a user is in Instructor View
And there is an Activity Bank Selection on the page
Then the Activity Bank Selection follows the updated Instructor View UI.

The Activity Bank Selection displays:

- Activity Bank Selection heading
- Number of available questions
- "Selects: # question(s)"
- "Points per question: #"
- Selection criteria determined in authoring
- Examples:
- Tags
- Learning Objectives
- Other authored selection logic
- Sample question from this selection:
- display one sample question from the available questions

#### Remove Activity Bank Selection

Given an Activity Bank Selection is displayed
Then a "Remove" button is displayed following Figma UI patterns and hover states.

When the user selects "Remove"
Then the entire Activity Bank Selection is removed from the page.

After removal:

- A success confirmation appears above the selection
- The selection enters a removed state
- The removed state includes:
- Red border
- Gray background
- "Removed" pill/badge
- Note: users can still interact with sample question in removed state
- "Questions available" updates to 0
- The "Remove" button changes to a "Restore" button

#### Restore Activity Bank Selection

Given an Activity Bank Selection is in a removed state
Then a "Restore" button is displayed.

When the user selects "Restore"
Then the entire Activity Bank Selection is restored.

After restoration:

- A success confirmation appears above the selection
- "Questions available" returns to the original value
- The selection returns to its default visual state

#### Embedded Question Removal

Given there is an embedded question on the page
Then a "Remove" button is displayed in the top-right corner of the question container.

When the user selects "Remove"
Then the question is removed from the page.

After removal:

- A success confirmation appears above the question
- The question enters a removed state
- The removed state includes:
- Red border
- Gray background
- "Removed" pill/badge
- The "Remove" button changes to a "Restore" button

#### Restore Embedded Question

Given an embedded question is in a removed state
Then a "Restore" button is displayed.

When the user selects "Restore"
Then the question is restored to the page.

After restoration:

- A success confirmation appears above the question
- The question returns to its default visual state

#### Page Attempts Present

Given that students have already attempted the assessment or practice page
Display a warning banner at the top of the page.

Scored pages:

> Students have already started this assessment. Removing or restoring questions and activity bank selections will only impact future attempts.

Practice pages:

> Students have already visited this page. Removing or restoring questions and activity bank selections will only impact future attempts.

If the user tries to restore or remove activity bank selections or embedded questions
Display a warning modal.

If the user selects "keep/remove question," then follow the user's action.

The removal/restoration should appear in future page view/attempts.

#### Saving Behavior

Given a user removes or restores content
Then updates to the page are automatically saved.

Given a save operation is in progress
Then a "Saving..." indicator is displayed at the top of the page.

Given a save operation completes successfully
Then a "Changes have been saved" message is displayed at the top of the page.

#### Scope of Changes

Given a user removes or restores content
Then the changes apply only to the page currently being edited.

These capabilities apply to:

- Course sections
- Templates

### Negative Acceptance Criteria

- Removing questions & bank selections should not affect student progress
- Do not remove questions or Activity Bank selections globally across the course
- Do not modify authored source content when instructors remove content locally
- Do not affect other pages containing the same question or Activity Bank selection
- Do not allow "Questions available" counts to become inaccurate after removal or restoration
- Do not remove the sample question preview when the Activity Bank Selection is in a removed state unless explicitly defined later
- Do not allow removed content to permanently disappear without a restore path
- Do not restore content into an incorrect position on the page
- Do not display both "Remove" and "Restore" actions simultaneously
- Do not use outdated button styles or interaction states outside approved Figma patterns
- Do not remove hover, focus, or disabled states from interactive controls
- Do not visually present removed content as active or available

## Design Notes

Interaction design:

- Activity Bank Selection: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-8959&t=T9wp5xcQh1vNqdxN-1
- Embedded Question
- Success Messages: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=379-7382&t=T9wp5xcQh1vNqdxN-1
- Attempts started: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=286-8247&t=T9wp5xcQh1vNqdxN-1
- Warning Modals: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=379-8630&t=T9wp5xcQh1vNqdxN-1

## Related Implementation Contract

This feature should build on the shared preview customization contract documented in `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md`.

That contract is relevant because MER-5620 needs to route Activity Bank Selection remove/restore actions from preview UI into the delivery-owned instructor customization implementation without making React preview components own database mutations. The embedded activity path described by the same contract already exists and should be reused as a reference point rather than rebuilt.

Important contract points for this ticket:

- React preview components emit a customization intent instead of performing the mutation directly.
- The browser event carries an action and a typed `customizationTarget`.
- The `InstructorPreviewCustomization` hook forwards valid events into LiveView with `pushEvent(...)`.
- The owning LiveView pattern matches on `target.kind` and dispatches to `Oli.Delivery.InstructorCustomizations`.
- The LiveView returns `{:reply, reply, socket}` so the initiating preview card can update local state without a remount.
- The LiveView can update screen-owned state such as flashes, warning messages, counters, and aggregates through normal assigns at the same time.
- The reply should include only the card-local state needed by the preview component, such as `actions`, `visualState`, and `statusPill`.

MER-5620 should reuse or extend the existing target kinds from the contract:

- `bank_selection` for an entire Activity Bank Selection rendered at page level.
- `embedded_activity` only as existing reference behavior from the merged MER-5622/PR 6659 implementation.

The same contract also mentions `bank_candidate`, but candidate-level management belongs to the bank selection manager flow and later related tickets unless MER-5620 explicitly expands into that surface.

The contract currently describes `PreviewAction.kind` as `remove | restore`, while the Jira comment uses "enable / disable" language. For this ticket, detailed design should reconcile the vocabulary without changing the behavior: enabling/restoring and disabling/removing both map to toggling instructor customization state in the core implementation. The UI copy and Figma patterns should decide whether the user-facing label is "Remove/Restore" or "Enable/Disable" for each surface.

## Related Tickets And Dependencies

This ticket depends on the instructor customization core implementation and preview component infrastructure already planned or delivered in the epic:

- `MER-5639`: core non-UI customization implementation, persistence, validation, authorization, and scenario coverage.
- `MER-5618`: Preview components rendered during instructor preview and the preview-side event contract for activity-level customization actions.
- `MER-5622`: Manage Questions in Activity Bank Selection. MER-5620 should align with its shared wiring contract but should not absorb candidate-management scope unless explicitly required.

The implementation should preserve the separation defined by the wiring contract:

- preview components own local UI state and emit customization intents
- LiveViews own screen-specific orchestration, warnings, flashes, and dispatch
- `Oli.Delivery.InstructorCustomizations` owns authorization, target validation, persistence, and domain rules

## Accessibility Guidelines

Remove and Restore buttons must:

- Be keyboard accessible
- Have visible focus states
- Include accessible labels for screen readers

Success confirmations must:

- Be announced to assistive technologies where appropriate
- Remain readable and distinguishable from surrounding content

Interactive sample question content must remain operable via keyboard navigation.

## Technical Notes

The Jira ticket includes a Technical Notes heading with no additional content.

## Testing Notes

The Jira ticket includes a Testing Notes heading with no additional content.
