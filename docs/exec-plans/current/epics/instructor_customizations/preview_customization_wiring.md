# Instructor Preview Customization Wiring Contract

This document captures the shared React-to-LiveView customization contract used by instructor-facing preview activities in the `MER-5613` epic.

It is intentionally implementation-oriented rather than ticket-oriented. Later stories can reuse this contract without re-explaining how preview cards communicate with LiveView or how LiveView returns per-card state updates without forcing a remount.

## Purpose

Instructor preview cards need to support section-specific customization actions such as `Remove` and `Restore`, while remaining reusable across multiple LiveViews and multiple target types:

- embedded activities rendered directly on a page preview
- activity bank selections rendered at page level
- candidate activities rendered inside an activity bank selection manager

The contract in this document separates:

- local component UI state owned by React
- business mutations owned by the containing LiveView
- optional visual treatment owned by the containing surface

## Ownership Model

### React Preview Components

React preview cards own local UI state that should survive customization actions, such as:

- expanded or collapsed sections
- active tabs
- local loading state
- local action state derived from the latest server reply

React preview cards do not decide which database mutation to execute.

### Containing LiveView

The LiveView that renders the preview surface owns:

- the meaning of each customization action in that surface
- dispatch to the correct `Oli.Delivery.InstructorCustomizations` context function
- page-level or manager-level aggregates that depend on customization state
- flash messages and any other screen-owned feedback

This keeps the preview cards reusable across multiple surfaces while allowing each LiveView to react differently to the same `Remove` or `Restore` intent.

## Event Flow

The wiring uses a bidirectional flow between React and LiveView:

1. A preview card button is clicked in React.
2. React dispatches a browser event that carries:
   - the requested action
   - the typed customization target for that preview
3. The `InstructorPreviewCustomization` hook listens for that browser event and calls `pushEvent(...)` into the owning LiveView.
4. The LiveView `handle_event/3` pattern matches on the target kind and action, then performs the appropriate domain mutation.
5. The LiveView returns:
   - a `{:reply, reply, socket}` payload for the specific preview card that initiated the action
   - normal socket assigns updates for any other LiveView-owned UI that depends on the mutation
6. The hook callback emits a reply event back to the browser.
7. The originating React card consumes that reply and updates only its local customization-related state.

The key property of this design is that the preview card does not need to remount to reflect `Remove` or `Restore`. Existing local UI state remains intact.

## Why `{:reply, reply, socket}` Is The Right Boundary

This contract deliberately avoids a `React -> controller/API -> LiveView sync` design.

The owning LiveView is already the screen authority and already holds the websocket connection needed to:

- perform the mutation
- update screen-level aggregates
- return a targeted reply to the initiating preview card

Using `{:reply, reply, socket}` keeps the flow single-owner:

- React sends intent
- LiveView performs the mutation
- LiveView replies with the new per-card state
- LiveView diffs the rest of the screen as needed

## Browser Event Contract

The event emitted by React should be treated as a customization intent, not a direct mutation command.

Current payload shape:

```json
{
  "action": "remove",
  "target": {
    "kind": "embedded_activity",
    "pageResourceId": 123,
    "activityResourceId": 456
  }
}
```

The hook forwards that payload into the LiveView event only after runtime validation.

Current hook-side validation responsibilities:

- `action` must be `remove` or `restore`
- `target.kind` must be one of the supported preview customization kinds
- `pageResourceId` must be present
- `embedded_activity` requires `activityResourceId`
- `bank_selection` requires `selectionId`
- `bank_candidate` requires both `selectionId` and `activityResourceId`

Invalid browser events are dropped client-side and never reach `pushEvent(...)`.

## Target Kinds

The shared `PreviewCustomizationTarget.kind` contract is defined in `assets/src/components/activities/types.ts`.

Supported kinds are:

- `embedded_activity`
- `bank_selection`
- `bank_candidate`

Expected meaning:

- `embedded_activity`
  - an authored activity embedded directly in the page preview
- `bank_selection`
  - an activity bank selection treated as a page-level customizable item
- `bank_candidate`
  - a specific candidate activity inside a selection manager surface

The point of `kind` is to make each containing LiveView dispatch explicitly rather than inferring behavior from button labels.

## Validation Boundaries

The wiring intentionally validates the customization request at more than one layer.

### Hook-side Validation

The browser event boundary is untyped at runtime, even though the preview card is authored in TypeScript.

The `InstructorPreviewCustomization` hook therefore validates the event payload shape before forwarding it into LiveView. This prevents malformed or incomplete browser events from becoming LiveView mutation requests.

### LiveView-side Validation

The containing LiveView must still revalidate the target against its own current state before executing a write.

For example, page preview should reject requests where:

- `pageResourceId` does not match the page currently being previewed
- `activityResourceId` does not belong to the set of activities rendered on that page

This prevents stale or mismatched browser payloads from mutating unrelated preview state and keeps any derived LiveView aggregates aligned with the current screen.

### Domain-side Validation

After the LiveView-level target checks pass, the LiveView still delegates the actual mutation to `Oli.Delivery.InstructorCustomizations`, which remains responsible for authorization and domain-level validity.

## TypeScript Contract

The shared preview typing lives in `assets/src/components/activities/types.ts`.

Relevant structures:

```ts
export type PreviewCustomizationTargetKind =
  | 'embedded_activity'
  | 'bank_selection'
  | 'bank_candidate';

export interface PreviewCustomizationTarget {
  kind: PreviewCustomizationTargetKind;
  pageResourceId: number;
  activityResourceId?: number;
  selectionId?: string;
}

export interface PreviewAction {
  kind: 'remove' | 'restore';
  label: string;
}

export type PreviewVisualState = 'default' | 'removed';

export interface PreviewStatusPill {
  kind: 'removed';
  label: string;
}
```

`PreviewContext` carries:

- `actions`
- `customizationTarget`
- `visualState`
- `statusPill`

alongside the existing preview content metadata.

## Why Visual State Is Separate From Remove/Restore State

The same business state does not always require the same visual treatment.

Examples:

- In page preview, an excluded embedded activity may need:
  - `Restore`
  - gray removed background
  - red left accent
  - `Removed` pill beside the title
- In a bank-selection management screen, an excluded candidate may need:
  - `Restore`
  - no removed card treatment because removal state is communicated elsewhere in the layout

For that reason, the contract does not infer removed styling from the presence of a `Restore` action.

Instead:

- `actions` control what the user can do
- `visualState` controls the card-level visual treatment
- `statusPill` controls optional header status chips such as `Removed`

This allows the same preview component to be reused across multiple LiveViews without hardcoding surface-specific styling rules inside React.

## LiveView Dispatch Expectations

Each LiveView that consumes preview customization events should pattern match on `target.kind` and then choose the correct side effect for that screen.

Illustrative shape:

```elixir
def handle_event("toggle_preview_activity_customization", %{"action" => action, "target" => %{"kind" => "embedded_activity"} = target}, socket) do
  ...
end

def handle_event("toggle_preview_activity_customization", %{"action" => action, "target" => %{"kind" => "bank_selection"} = target}, socket) do
  ...
end

def handle_event("toggle_preview_activity_customization", %{"action" => action, "target" => %{"kind" => "bank_candidate"} = target}, socket) do
  ...
end
```

The handler is free to perform whatever screen-appropriate side effects are needed before replying to React.

Typical side effects include:

- calling an `InstructorCustomizations` remove or restore function
- validating that the requested target belongs to the current preview surface
- recalculating page or manager aggregates
- updating flashes
- updating any LiveView-owned UI outside the preview card itself

## Reply Contract

The reply sent back to React should be limited to the state the preview card itself needs to update locally.

Typical reply shape:

```json
{
  "ok": true,
  "activityResourceId": 456,
  "actions": [{ "kind": "restore", "label": "Restore" }],
  "visualState": "removed",
  "statusPill": { "kind": "removed", "label": "Removed" }
}
```

On error, the LiveView should still reply so the initiating component can leave its submitting state:

```json
{
  "ok": false
}
```

The LiveView can still update its socket at the same time so aggregates and flashes continue to use normal LiveView diffs.

## Current Reference Implementation

The first concrete implementation of this wiring lives in the instructor page preview flow:

- React preview card:
  - `assets/src/components/activities/common/preview/ActivityPreviewCard.tsx`
- shared preview types:
  - `assets/src/components/activities/types.ts`
- hook bridge:
  - `assets/src/hooks/instructor_preview_customization.ts`
- current LiveView consumer:
  - `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`
- current preview-context builder:
  - `lib/oli_web/delivery/instructor/preview_page_context.ex`

That implementation currently dispatches only `embedded_activity` mutations, but the event and type contract are intentionally shaped so later LiveViews can add `bank_selection` and `bank_candidate` handling without redesigning the preview card.

## Guidance For Future Tickets

When a new LiveView wants to reuse preview customization:

1. Reuse the existing preview card and hook contract.
2. Provide a `customizationTarget` with the correct `kind`.
3. Provide `actions` that reflect the current server-owned customization state.
4. Provide `visualState` and `statusPill` only if that surface wants removed-card treatment.
5. Pattern match on `target.kind` in the LiveView event handler.
6. Return `{:reply, reply, socket}` so the initiating card updates in place while the rest of the screen continues to update through normal LiveView diffs.

This keeps the customization flow consistent across page preview, activity-bank selection management, and later instructor customization surfaces.
