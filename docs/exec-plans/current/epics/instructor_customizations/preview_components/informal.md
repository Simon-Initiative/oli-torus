# Activity Preview Components Informal Technical Design

## Intent

Instructor customization changes the instructor-facing page view from a mostly read-only activity inspection surface into a customization workspace. The current implementation reuses each activity's authoring web component in `mode="instructor_preview"` with `editmode="false"`. That has worked while the instructor view was a light variant of authoring, but it is becoming the wrong abstraction as the view now needs distinct layout, controls, summaries, remove/restore state, bank selection management, and reusable instructor-facing question UI.

Introduce a third top-level activity mode: `preview`.

Each activity can then provide:

- `authoring`: author editing and model mutation
- `delivery`: student interaction and attempt lifecycle
- `preview`: instructor-facing inspection and customization

The working name should be `preview`, not `instructor`, because the rendering surface is not inherently tied to instructor role checks and may later be reused by author preview, review tooling, or other read-only/customization contexts. The first consumer is the basic page instructor preview route.

## Current Behavior

For basic pages, `/sections/:section_slug/preview/page/:revision_slug` is handled by `PageDeliveryController.page_preview/2`. Non-advanced pages call `render_page_preview/3`, build an `Oli.Rendering.Context` with `mode: :instructor_preview`, render page content through `Oli.Rendering.Page.Html`, and inject the result into `page_delivery/instructor_page_preview.html.heex`.

The activity renderer branch is in `lib/oli/rendering/activity/html.ex`. For `:instructor_preview`, it selects `ActivitySummary.authoring_element`; all other modes select `delivery_element`. It emits the authoring web component with:

- `editmode="false"`
- `mode="instructor_preview"`
- `authoringcontext` containing `previewMode: "instructor"`
- `student_responses`
- `section_slug`
- `activity_id`
- `projectSlug` currently set to the section slug

The page layout loads `@scripts`, and `render_page_preview/3` currently sets those scripts to every activity's `authoring_script`.

Client-side, `assets/src/components/activities/AuthoringElement.ts` parses `editmode`, `mode`, `authoringcontext`, and `student_responses`, then passes them through `AuthoringElementProvider`. Individual activity authoring implementations and shared authoring widgets branch on `mode === "instructor_preview"` to disable/hide editing affordances and sometimes show student-response views. For now, student response visualizations remain tied only to the Authoring component path and should not be part of the new Preview component interface.

This means instructor preview is not a first-class activity mode. It is authoring with an extra mode flag.

## Problem

The instructor customization epic needs a visually distinct, workflow-specific rendering for each question. The preview needs to support controls and information that do not belong in authoring or delivery:

- enable/disable embedded questions through an upper-right question control
- remove/restore activity bank selections
- candidate management for activity bank selections
- available points and learning objective summaries
- instructor-facing question chrome and state
- compact answer key, hints, feedback, choices, and response summaries
- visual consistency across many activity types

Keeping this inside authoring components will spread `if instructor preview` conditionals through authoring components, shared authoring controls, and per-activity tabs. That increases coupling and makes it harder to reason about authoring behavior, preview behavior, and future reuse.

## Proposed Shape

Add `preview` as a required mode for the activity set covered by instructor customization. This is one cohesive ticket of work: add the preview infrastructure and implement the Preview web components for all supported basic-page activities in the same delivery, rather than introducing authoring fallback behavior or staging a later activity-by-activity migration.

An activity manifest would become:

```json
{
  "id": "oli_multiple_choice",
  "delivery": {
    "element": "oli-multiple-choice-delivery",
    "entry": "./delivery-entry.ts"
  },
  "authoring": {
    "element": "oli-multiple-choice-authoring",
    "entry": "./authoring-entry.ts"
  },
  "preview": {
    "element": "oli-multiple-choice-preview",
    "entry": "./preview-entry.ts"
  }
}
```

## Primary Instructor Customization UI

The key instructor customization affordance in preview mode is an `Enable / Disable` button rendered in the upper-right corner of each question preview.

This button is the only direct question-level customization action. Instructors use it to toggle whether the question is active for the section/page. The surrounding preview UI should make the current state obvious, but it should not expose authoring-style editing controls.

Expected behavior:

- Active question: show a `Disable` button in the upper-right corner.
- Disabled question: show an `Enable` button in the upper-right corner.
- The disabled state should be visually apparent across the preview card without hiding the question content completely.
- The button should dispatch a preview customization event with enough identifiers for the server-side customization API to insert or delete the matching exclusion row.
- The button should be controlled by capability flags such as `canCustomize`; users without permission can see the state but cannot toggle it.

For embedded activity references, this maps to toggling an `embedded_activity` exclusion. For activity bank selections or bank candidates, the same visual pattern can be reused, but the event payload must identify whether the target is a whole selection or a candidate within a selection.

All other preview component work, including shared renderers for stem, choices, hints, feedback, answer key, points, and response summaries, supports this instructor preview surface. Those shared components should not become additional customization mechanisms unless a later requirement explicitly adds one.

## Pre-Design UI Component Inventory

Before producing a detailed technical design or implementation approach, an engineer should inventory the UI componentry required by the Preview designs.

That inventory should be specific enough for an AI-assisted implementation pass to determine which components already exist and which must be built. The output should include a concrete "UI componentry - Reuse or Build New" plan.

For each needed piece of Preview UI, classify it as one of:

- Reuse existing component as-is.
- Reuse existing component with a small wrapper or styling adapter.
- Extract/refactor existing behavior into shared preview-safe componentry.
- Build a new preview-specific component.

The inventory should include at least:

- upper-right `Enable / Disable` button
- activity preview card/chrome
- question stem renderer
- choices renderer
- answer key display
- hints display
- feedback display
- points and learning objective summary
- disabled-state visual treatment
- activity bank selection and candidate preview controls, if those are in the slice

The result should identify candidate existing files or component families in `assets/src/components/...`, explain why each is safe or unsafe to reuse in Preview mode, and call out any authoring-only dependencies that should be avoided. This work should happen before detailed design so the Preview component architecture is driven by actual reusable building blocks rather than assumptions.

## Elixir Changes

### Manifest Parsing

Update `Oli.Activities.Manifest` to include a `:preview` field. `parse/1` should require `"preview"` for local/core activity manifests that participate in instructor customization. A missing preview block for those activities should be treated as an invalid implementation, not as a signal to render authoring instead.

Update `Oli.Activities.ModeSpecification` only if better error reporting is useful. The existing `parse/1` shape works for required `delivery`, `authoring`, and `preview`.

### Activity Registration Schema

Add columns to `activity_registrations`:

- `preview_element`
- `preview_script`

Add unique indexes for non-null preview values:

- `preview_element`
- `preview_script`

Update `Oli.Activities.ActivityRegistration`:

- add fields
- cast fields
- require fields for the core activity registrations that will render in instructor customization

Update `Oli.Activities.register_activity/2` to persist:

- `preview_script: "#{subdirectory}#{manifest.id}_preview.js"`
- `preview_element: manifest.preview.element`

Bundle registration through `register_from_bundle/2` should work through the same manifest path, but preview bundle support requires package producers to include the preview script when the activity is expected to support instructor customization.

LTI external tool registrations need an explicit product decision. Either they are out of scope for the initial instructor customization activity set, or they receive a real preview component in the same ticket. They should not silently reuse authoring as preview.

### Registration Read APIs

Add preview metadata to registration projections:

- `Oli.Activities.activities_for_project/2`
- `Oli.Activities.activities_for_section/0`
- `Oli.Activities.ActivityMapEntry`

Add a helper for preview scripts:

```elixir
def get_activity_preview_scripts() do
  list_activity_registrations()
  |> Enum.map(fn r -> r.preview_script end)
end
```

### Activity Summary

Extend `Oli.Rendering.Activity.ActivitySummary` with:

- `preview_element`
- `preview_script` if useful for script accounting or diagnostics

Any code that creates activity summaries from registrations needs to populate `preview_element`. Important places include:

- `PageDeliveryController.render_page_preview/3`
- `Oli.Delivery.Page.ActivityContext.create_context_map/6` or related summary builders if preview rendering moves into attempt-backed contexts later
- manual grading preview helpers only if they should use preview components
- tests and factories that construct `ActivitySummary`

The safest initial scope is the static basic instructor preview route. Delivery and review rendering should continue using existing delivery behavior.

### Rendering

Change `Oli.Rendering.Activity.Html` so `:instructor_preview` selects:

```elixir
preview_element
```

The rendered attribute set should change from authoring-specific names to preview-specific names:

- use `previewcontext`
- use `mode="preview"` or omit mode entirely if `PreviewElement` does not need it
- do not rely on `authoringcontext`
- do not render authoring-specific edit attributes as part of the preview contract

The preview context should carry the data preview components need without forcing them to know about authoring:

- `sectionSlug`
- `pageResourceId`
- `pageRevisionSlug`
- `activityResourceId`
- `activityHtmlId`
- `graded`
- `points`
- `learningObjectives`
- `customizationState` for active/excluded/restorable
- `customizationTarget` for the upper-right `Enable / Disable` button, including target kind and required ids
- `selectionId` for bank-selected activities when available
- `bibParams`

Do not put instructor authorization decisions in the web component. Elixir/LiveView/controller code should decide whether controls are allowed and pass capability flags, such as:

- `canCustomize`

### Page Preview Controller

Update `PageDeliveryController.render_page_preview/3`:

- populate `preview_element` in each `ActivitySummary`
- load preview scripts, not authoring scripts
- pass page-level customization state into rendering context once that core lane exists

Today the controller assigns:

```elixir
scripts: Enum.map(all_activities, fn a -> a.authoring_script end)
```

This should become something like:

```elixir
scripts: Enum.map(all_activities, fn a -> a.preview_script end)
```

or call the helper above.

The activity map currently sets `script: type.authoring_script` for preview. Update that to `type.preview_script` or stop relying on `summary.script` for this path if only the page-level script list matters.

### Tests

Expected backend test updates:

- registrar test proves manifests with preview populate `preview_script` and `preview_element`
- registrar test proves supported local/core activity manifests require preview metadata
- activity registration changeset test validates preview fields for supported activities
- activity renderer test proves `:instructor_preview` uses the preview element
- page preview controller/view test proves preview scripts are loaded when present

## Client Changes

### Webpack Entries

`assets/webpack.config.js` currently creates exactly two entry points per activity manifest:

- `<id>_authoring`
- `<id>_delivery`

Change entry generation to include `<id>_preview` when `manifest.preview` exists. The collision-count validation must change from a fixed `2 * foundActivities.length` to a sum of generated entries.

Part components should not automatically get preview entries in the first pass. The requested feature is for top-level activity rendering. If preview components later need activity-internal part previews, that should be designed separately.

### Types

Update `assets/src/components/activities/types.ts`:

- `Manifest` gets `preview: ModeSpecification` for supported activity manifests
- introduce `PreviewMode` or `PreviewContext` types
- avoid extending `AuthoringElementProps` if preview has a distinct contract

### PreviewElement Base

Add a new base web component beside `AuthoringElement` and `DeliveryElement`, for example:

- `assets/src/components/activities/PreviewElement.ts`
- `assets/src/components/activities/PreviewElementProvider.tsx`

The base should parse:

- `model`
- `previewcontext`
- `activity_id`
- `section_slug`
- `bib_params`

It should expose a small event bridge for instructor customization actions:

- `setActivityEnabled(enabled: boolean)`

The event should be intentionally narrow because the only direct instructor customization action is the upper-right `Enable / Disable` control. The command should be explicit rather than toggle-based: the component should request a known target state by calling or dispatching `setActivityEnabled(true)` or `setActivityEnabled(false)`. The surrounding preview context should provide the section/page/activity/selection identifiers needed by the server. This avoids ambiguity if the UI state is stale or if a request is retried.

The preview component should not expose generic model editing APIs like `onEdit`, `onPostUndoable`, or media requests unless a concrete preview use case needs them. This is the main boundary that keeps preview from becoming authoring mode under another name.

If the first slice is rendered by a controller/static page, event handling can be simple DOM events consumed by a Phoenix hook or LiveView bridge. If the new instructor view is LiveView-heavy, prefer having the component dispatch named custom events and let the containing LiveView own persistence and authorization.

### Preview Component Implementations

Each supported activity gets a Preview implementation in this ticket:

- `<Activity>Preview.tsx`
- `preview-entry.ts`
- `manifest.json` preview block

The preview entry defines the preview custom element:

```ts
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.preview.element, MultipleChoicePreview);
```

The React component should compose shared preview UI primitives rather than branching through authoring tabs.

### Shared Preview UI

Create a shared preview component library under a dedicated directory, for example:

- `assets/src/components/activities/common/preview/ActivityPreviewCard.tsx`
- `EnableDisableButton.tsx`
- `QuestionStem.tsx`
- `Choices.tsx`
- `AnswerKey.tsx`
- `Hints.tsx`
- `Feedback.tsx`
- `LearningObjectives.tsx`
- `PointsSummary.tsx`
- `CustomizationToolbar.tsx`

`ActivityPreviewCard` should own the consistent question frame and place `EnableDisableButton` in the upper-right corner. Activity-specific preview implementations should normally provide content slots or props for stem, answer key, hints, and feedback, while the card handles the shared enable/disable state presentation.

These components should render read-only model data and expose only the explicit enable/disable callback. They should not import authoring controls such as authoring buttons, tabbed authoring sections, or model mutation actions.

Supported activity set to implement together:

- multiple choice
- check all that apply
- short answer
- multi input
- response multi
- ordering
- image hotspot
- file upload
- likert
- directed discussion where applicable
- embedded / LTI external tool preview placeholders

Adaptive advanced pages remain out of scope for this design.

## Delivery Strategy

This should be delivered as one ticket of work that lands the preview infrastructure and all required activity Preview components together.

The ticket should include:

- Add manifest/schema/build support for preview.
- Add preview element base/provider.
- Implement shared preview UI.
- Implement Preview components for the full supported activity set.
- Server renders `preview_element`.
- Server loads `preview_script`.
- Remove or stop using `mode === "instructor_preview"` branches in authoring components that were only supporting the old instructor preview route.

There should be no authoring fallback path for the supported activity set. If an activity is in scope for instructor customization, it must have a Preview component before the ticket is complete.

## Naming Decision

Use `preview` for manifest keys, database fields, scripts, and client classes. Use instructor-specific language in context/capabilities where the current caller is instructor preview.

Examples:

- `preview_element`
- `preview_script`
- `PreviewElement`
- `PreviewElementProvider`
- `previewcontext`
- `canCustomize`
- `customizationState`

Avoid `instructor_element` and `instructor_script` because those names imply role-specific rendering and will be harder to reuse for author preview or review tooling.

## Risks And Open Questions

- Existing tests and factories assume only authoring/delivery fields. The schema migration is straightforward but touches many fixtures.
- Bundled third-party activity registration currently assumes two scripts by convention. Decide whether third-party bundles are out of scope for instructor customization or must provide preview metadata before participating.
- The static preview page currently has no React app-level event bridge. Customization controls need either Phoenix hooks or a LiveView wrapper to handle preview component events.
- The preview context contract should be kept stable before many activity preview components are implemented.
- Some current instructor preview UI shows student response visualizations inside authoring components. Those visualizations remain on the Authoring component path for now; Preview components should not receive `student_responses`.
- Activity bank selection UI is not a normal activity web component. The page renderer will likely need a parallel page-level preview component for `selection` elements, separate from activity preview elements.
- The upper-right `Enable / Disable` control must remain the single question-level customization affordance for this feature. Avoid introducing secondary per-activity controls that look like editing or separate customization actions.
- Advanced adaptive pages intentionally remain separate. Do not add preview components to `AdaptiveDelivery` until there is a separate advanced-page design.

## Suggested Implementation Sequence

1. Add nullable preview fields to activity registration and manifest parsing.
2. Update local registrar and webpack to support preview entries.
3. Add `PreviewElement` and `PreviewElementProvider`.
4. Change basic instructor preview rendering to use `preview_element` and `preview_script`.
5. Add backend tests for manifest registration and HTML rendering.
6. Implement shared preview UI components.
7. Implement Preview components for the full supported activity set in the same ticket.
8. Wire customization event dispatch from preview components to the instructor customization UI persistence path.
9. Remove or stop using `instructor_preview` conditionals from authoring components that only supported the old route.

## Verification

The ticket should be verifiable end to end across the supported activity set:

- a manifest with preview creates a preview bundle and registration metadata
- supported activity manifests include preview metadata
- instructor preview renders preview custom elements for all supported activities
- preview components receive model and preview context attributes
- customization events include section, page, activity, and selection identifiers needed by the core customization APIs
- delivery, review, and authoring routes continue to use existing delivery/authoring components
