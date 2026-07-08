# Bank Selection Filters - Lightweight Implementation Brief

Source ticket: `MER-5624`

This document captures the lightweight UI implementation brief and phased execution plan agreed in chat on 2026-06-29. It is intentionally smaller than a full PRD/FDD/plan pack and is meant to support a `harness-work` style implementation with phase-by-phase review and commits.

## Current Decision

Use a lightweight process, not the full feature planning lane.

- Implementation should extend the existing bank-selection manager LiveView.
- Work should proceed in explicit phases.
- Each phase should be reviewed before continuing.
- Each implementation phase should land as its own commit.
- Do not implement the whole ticket in one pass.

## Important Dependency Note

`MER-5623` is currently in review / pull request and should not be assumed to be implemented on this branch.

Implication:

- Treat bulk-action preservation requirements as compatibility constraints.
- Do not build on unpublished `MER-5623` branch behavior unless it has been merged into the current branch.
- If checkbox-only state from `MER-5622` exists, preserve it where practical.
- If full bulk actions are absent, document the preservation boundary in the phase summary instead of inventing `MER-5623` behavior.

## Design Sources

- Full filter component, including Show All/Available/Removed toggles plus search, learning-objective filter, and question-type filter:
  `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7440&t=SNzWnAHAxamIxKZQ-4`
- Search bar plus learning-objective and question-type filter component detail:
  `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=305-11129&t=SNzWnAHAxamIxKZQ-4`
- Learning Objectives dropdown example:
  `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=385-6445&t=SNzWnAHAxamIxKZQ-4`
- In-page manager context:
  `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7391`

## Implementation Surface

Surface: `liveview/heex`

Rationale:

- `OliWeb.Delivery.Instructor.BankSelectionManagerLive` already owns candidate state, paging, selected preview, remove/restore events, and warning flows.
- Filtering should remain server-driven so it can apply to the full candidate set, not only currently loaded rows.
- React preview components should not own filter state or filtering behavior.

## Design System Alignment

Shared vs local decision: `keep feature-local`

- The composed toolbar is domain-specific to activity bank selection candidate management.
- Use existing token classes and `OliWeb.Icons`.
- Do not force a new shared filter component unless implementation reveals a clean, already-existing reusable primitive.
- Do not create or modify design tokens in this ticket.

Potential reuse:

- Search input visual pattern can borrow from instructor insights / student support tile conventions.
- Toggle buttons can follow the local filter button pattern from instructor dashboard tiles.
- Dropdown button styling can use existing tokenized Tailwind classes and `Icons.chevron_down`.
- Clear All should use `Icons.trash`.

## Token Mapping

- Toolbar surface: `bg-Surface-surface-primary`
- Primary toggle background: `bg-Background-bg-primary`
- Search/dropdown input fill: `bg-Specially-Tokens-Fill-fill-input`
- Active toggle text/border: `text-Text-text-button`, `border-Text-text-button`
- Inactive text: `text-Text-text-high`
- Inactive borders: `border-Border-border-default` or `border-Specially-Tokens-Border-border-input`
- Hover/focus: use existing button/input focus rings, usually `focus-visible:outline-Fill-Buttons-fill-primary`
- Filter typography: `font-open-sans text-[16px] font-semibold leading-6`
- Clear All typography: `text-sm font-normal`
- Dropdown option typography: `text-sm font-normal leading-6`
- Figma shadow: `0px 2px 10px rgba(0,50,99,0.1)` may be represented with an existing local arbitrary shadow if no tokenized equivalent exists.

## Interaction Decisions

- Keep the current manager count copy: `Showing X of Y questions`.
- Primary visibility filter is single-select.
- Default primary visibility filter is Show All.
- Search should update dynamically with debounce and require no manual submit.
- Search should filter server-side across the full candidate set.
- Learning Objective and Question Type filters should be multi-select.
- Filter option sets should be generated from the current activity bank selection candidate set, including available and removed questions.
- Changing filters should reset pagination to the first filtered page.
- If the selected candidate is filtered out, select the first visible filtered row.
- If no rows match, show an explanatory empty state and no candidate preview.
- Clear All resets primary visibility to Show All and clears search, learning objectives, and question types.
- Remove/restore, preview selection, candidate checkbox interactions, and future bulk actions should not unintentionally reset active filters.

## Open Design-State Handling

Figma does not show every state. Use pragmatic defaults and adjust in later review if needed.

- Selected secondary filters can be indicated with selected count or active styling.
- Long LO labels should truncate or wrap only inside the dropdown, without widening the toolbar unexpectedly.
- Empty LO/type option lists should render a small explanatory disabled row or keep the dropdown disabled.
- Dropdown focus/hover states should use existing tokenized focus and hover behavior.

## File Targets

Likely primary files:

- `lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex`
- tests under `test/oli_web/live/delivery/instructor/`

Possible domain/context files if server-side filtering belongs below the LiveView:

- `lib/oli/delivery/instructor_customizations.ex`
- related tests under `test/oli/delivery/instructor_customizations/`

Avoid touching:

- React preview components unless a filter-related visual bridge bug is discovered.
- Shared `design_tokens/` primitives unless reuse becomes clearly justified and explicitly approved.
- Broader epic docs unless implementation changes those documented assumptions.

## Phased Execution Plan

### Phase 0: Preparation And Branch Reality Check

Goal: establish exact current branch state before implementation.

Tasks:

- Confirm `MER-5623` is not present on this branch.
- Inspect existing manager LiveView tests.
- Identify the current candidate row view model fields available for title, content, objective data, question type, and enabled/removed state.
- Decide whether candidate filtering can be added to the existing `list_bank_selection_candidates/4` path or needs a small companion query/view model helper.

Commit:

- Optional planning-only commit for `informal.md` and this brief, if desired.

### Phase 1: Filter Contract And Server-Side Listing

Goal: add the filtering data contract without final UI polish.

Tasks:

- Add a filter state shape to `BankSelectionManagerLive`.
- Thread filters through candidate load, refresh, and pagination.
- Reset offset when filters change.
- Keep the current `Showing X of Y questions` behavior, updated for filtered totals.
- Preserve selected candidate when still visible; otherwise select the first visible filtered candidate.
- Add focused tests for filter state transitions and pagination reset.

Commit:

- Commit phase 1 after tests pass.

### Phase 2: Primary Visibility Filters

Goal: implement Show All, Show Available, and Show Removed.

Tasks:

- Add the primary single-select filter UI above the candidate table.
- Default to Show All.
- Show Available excludes removed rows.
- Show Removed excludes available rows.
- Add empty state messaging for no matching questions.
- Add LiveView tests for all three states and mutual exclusivity.

Commit:

- Commit phase 2 after tests pass.

### Phase 3: Search

Goal: add dynamic text search.

Tasks:

- Add the search input matching the Figma toolbar.
- Search should debounce and update without manual submit.
- Search title and question content where practical from the available data/query layer.
- Preserve search through preview selection, remove/restore, and checkbox interactions.
- Add tests for title/content matching and no manual submit requirement.

Commit:

- Commit phase 3 after tests pass.

### Phase 4: Learning Objective And Question Type Filters

Goal: add the two multi-select dropdown filters.

Tasks:

- Generate LO options from questions in the current activity bank selection candidate set.
- Generate question type options from questions in the current activity bank selection candidate set.
- Include both available and removed questions when generating options.
- Implement multi-select dropdowns with selected state and clear behavior.
- Combine filter families with AND semantics. Multiple selected Learning Objectives or Question Types should match any selected option within that family.
- Add tests for option generation, multi-select behavior, and combined filtering.

Commit:

- Commit phase 4 after tests pass.

### Phase 5: Clear All, Preservation, Polish, And Review

Goal: close the ticket behavior and prepare for PR review.

Tasks:

- Implement Clear All Filters.
- Confirm filters are not reset by remove actions, restore actions, preview interactions, checkbox interactions, or future-compatible bulk-action hooks.
- Verify empty, long-label, selected-filter, and dropdown-open states.
- Run targeted formatting and tests.
- Run review lenses relevant to the change: security, performance, Elixir/LiveView, and UI.

Commit:

- Commit phase 5 after final verification passes.

## Test Strategy

Use LiveView tests as the primary layer because this is server-driven UI state.

Likely coverage:

- Initial render defaults to Show All.
- Primary filters are mutually exclusive.
- Visibility filters include/exclude removed rows correctly.
- Search updates results dynamically.
- LO/type options are generated only from current selection candidates.
- LO/type filters are multi-select.
- Combined filter families narrow with AND semantics; multi-select values within LO and type filters match any selected option.
- Clear All resets all filters.
- Empty result state renders explanatory copy.
- Existing remove/restore and selected-preview flows preserve active filters.
- Pagination resets on filter changes and continues to load filtered results.

Add domain/context tests only if filtering logic moves into `Oli.Delivery.InstructorCustomizations`.

Expected commands:

- targeted LiveView test module under `test/oli_web/live/delivery/instructor/`
- targeted context tests if context code changes
- `mix format` on touched Elixir files

## Risks

- Full-set filtering may require new or adjusted queries so the UI does not load all candidates into LiveView memory.
- Searching question content may be limited by what the current candidate query exposes; if content matching is expensive, prefer a targeted query-level implementation.
- `MER-5623` branch behavior may change table selection or bulk-action state. Keep this ticket compatible with current branch behavior and document any follow-up once `MER-5623` merges.
- Dropdown and filter toolbar states are partially unspecified in Figma. Use sensible token-aligned states and expect visual iteration.
