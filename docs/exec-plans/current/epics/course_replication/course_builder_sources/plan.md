# Course Builder Source Selection UI Updates - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/prd.md`
- FDD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/fdd.md`
- Design brief: `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md` (via `ui_workflow`)

## Scope

Update step 1 of 3 ("Select source materials") of the section-creation wizard: add All Sources / Templates / My Course Sections filter tabs with sort-order preservation, scope My Course Sections to the current instructor's eligible sections via `MER-5841`'s already-merged authorization contract, redesign source cards with type tags and a visual-only "My Section" hover state, add the new-feature banner and filter tooltips, and restyle the wizard's left-panel copy and footer for step 1 only — without touching steps 2/3, without any Blueprint concept, and without leaking styling changes into the shared `OliWeb.Common.Stepper`'s other consumer (`student_onboarding/wizard.ex`). No new schema, migration, or backend authorization logic.

## Clarifications & Default Assumptions

- `MER-5841`'s authorization/query contract is sufficient for My Course Sections eligibility; Phase 1 confirms the exact callable function by reading the merged code rather than guessing, per FDD Section 3's "Unknowns to confirm."
- The My Section hover treatment (dark overlay + "SELECT TO COPY COURSE SECTION") is built only for My Section cards in this plan; extending it to Free/Template cards is out of scope pending designer confirmation (PRD Open Questions) and is not blocked by any phase below.
- Row-kind typing (`{:project,...}|{:publication,...}|{:product,...}|{:previous_section,...}`) is done now, in Phase 1, so later phases and `MER-5832` build on one consistent shape rather than the current structural `Map.has_key?(item, :type)` check.
- No feature flag is used (PRD Section 11); this ships as a normal additive change.

## Phase 1: My Course Sections query and row-kind typing

- Goal: make My Course Sections rows available to the rest of the LiveComponent, correctly authorized and typed, with no visible UI change yet.
- Tasks:
  - [ ] Confirm and call `MER-5841`'s exposed authorization/query function for "sections the actor may create from" (read the merged code in `lib/oli/delivery.ex`, `lib/oli/delivery/sections/section_specification.ex`, `lib/oli_web/live/new_course/select_source.ex` first; add a one-line wrapper only if no directly callable function exists).
  - [ ] Extend `SelectSource.retrieve_all_sources/3` to also fetch and tag My Course Sections rows alongside the existing Template rows, fetched once per mount.
  - [ ] Add `TableModel.row_kind/1` returning `{:project, item} | {:publication, item} | {:product, item} | {:previous_section, item}`; re-express `is_product?/1` and `render_type_column/3` in terms of it without changing their existing behavior for Template/Project rows.
  - [ ] Ensure an unrecognized row shape falls back to `{:project, item}` rather than raising (FDD Section 10).
- Testing Tasks:
  - [ ] Unit/LiveView test: an instructor sees only active enrollable sections where they hold an instructor/content-developer role under My Course Sections (AC-004).
  - [ ] Unit/LiveView test: an admin actor sees any active enrollable section under My Course Sections (AC-005).
  - [ ] Unit/LiveView test: a section `MER-5841`'s rule would deny for the current actor is absent from the returned rows, not merely hidden client-side (AC-006).
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs`
- Definition of Done:
  - My Course Sections rows are fetched, correctly authorized, and typed; existing Template/Project rendering and tests are unaffected.
- Gate:
  - All Phase 1 tests pass; no change yet to any rendered markup (verified by running the existing `select_source_test.exs` suite unmodified assertions still green).
- Dependencies:
  - None — first phase.
- Parallelizable Work:
  - None; every later phase depends on row-kind typing existing.

## Phase 2: Filter tabs (All Sources / Templates / My Course Sections)

- Goal: let the user switch between the three source sets without losing their chosen sort order, and without leaking rows across tabs.
- Tasks:
  - [ ] Add `@params.source_filter :: :all | :templates | :my_sections` (default `:all`) to `SelectSource`.
  - [ ] Add a feature-local `source_filter_tabs/1` function component rendered above `FilterBox.render`, using `phx-click="filter_source"` / `phx-value-filter` and a new `handle_event("filter_source", ...)` clause, following the existing `handle_event` style in this module.
  - [ ] Extend `filter/3` with a `source_filter`-narrowing pass that runs before the existing text-query pass.
  - [ ] Give each tab an accessible name and a selected/`aria-selected` state; add a keyboard/focus-visible style consistent with the rest of the module.
- Testing Tasks:
  - [ ] LiveView test: all three tabs render with accessible names and correct selected state (AC-001).
  - [ ] LiveView test: changing tabs does not change the currently selected sort order; default sort stays Most Recent until explicitly changed (AC-002).
  - [ ] LiveView test: a search performed under one tab never returns rows belonging to a different tab (AC-003).
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs`
- Definition of Done:
  - Tabs are visible, keyboard-operable, and correctly scope search/sort/pagination without disturbing the user's sort choice.
- Gate:
  - Phase 2 tests pass; existing Template-only regression assertions in `select_source_test.exs` still pass unmodified.
- Dependencies:
  - Phase 1 (needs My Course Sections rows and row kind to exist to filter over).
- Parallelizable Work:
  - Safe to build in parallel with Phase 4 (banner/tooltips) and Phase 5 (Stepper), since neither touches `filter/3` or the tab markup.

## Phase 3: Card redesign, type tags, and the My Section hover state

- Goal: denser cards with a type tag per row kind and the designed My Section hover overlay, with selection staying a no-op for My Course Sections rows.
- Tasks:
  - [ ] Add `lib/oli_web/components/design_tokens/primitives/badge.ex` with `attr :variant, :atom, values: [:my_section, :free, nil], default: nil`, rendering nothing when `variant` is `nil`, using the token mapping from the `ui_workflow` brief (`Fill-Accent-fill-accent-purple`/`Text-text-accent-purple` for My Section, `Fill-Chip-Green`/`Text-text-accent-green` for Free).
  - [ ] Update `CardListing` to render the badge per row kind and increase card density/metadata per the Figma reference (nodes `44:789`, `44:805`, `44:824`).
  - [ ] Add the My Section hover overlay (dark overlay + "SELECT TO COPY COURSE SECTION", node `44:1459`) as a purely visual state.
  - [ ] Update the card click handler so a `{:previous_section, ...}` row's activation is a true no-op (`{:noreply, socket}`), while the existing Template/Project `source_selection` flow is unchanged.
- Testing Tasks:
  - [ ] LiveView test: Template card shows "Template" tag, My Course Sections card shows "My Section" tag, a card that is neither shows no tag (AC-007).
  - [ ] LiveView/manual test: the redesigned grid shows more cards per viewport and renders title/description/date/tag without truncation regressions (AC-008).
  - [ ] Manual visual check: hovering a My Course Sections card shows the darkened overlay and label per the Figma reference (AC-012).
  - [ ] LiveView test: activating a My Course Sections card produces no navigation/creation, while activating a Template card still creates a section as before (AC-013).
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/common/card_listing_test.exs`
- Definition of Done:
  - Cards visually match the confirmed Figma states for Template/Free/My Section/no-tag, and My Course Sections selection is verifiably inert.
- Gate:
  - Phase 3 tests pass; existing Template-card selection/creation regression tests pass unmodified.
- Dependencies:
  - Phase 1 (row kind).
- Parallelizable Work:
  - Safe to build in parallel with Phase 2, 4, and 5 once Phase 1 lands, since it touches `CardListing`/the new badge primitive rather than the tab or filter logic.

## Phase 4: New-feature banner and filter tooltips

- Goal: add the explanatory banner and the two filter-button tooltips with the agreed copy and a keyboard-accessible equivalent.
- Tasks:
  - [ ] Render the new-feature banner between `FilterBox.render`/`Filter.render` and `Listing.render` in `select_source.ex`, using the agreed copy (see `informal.md`, Open decisions).
  - [ ] Wire `phx-hook="GlobalTooltip" data-tooltip="..." data-tooltip-style="body"` onto the Templates and My Course Sections filter buttons, reusing the existing hook rather than building a new tooltip.
- Testing Tasks:
  - [ ] LiveView test: the banner renders in the correct position with the agreed copy (AC-009).
  - [ ] LiveView/manual test: both filter buttons show their agreed tooltip copy on hover (AC-010).
  - [ ] Manual keyboard test: both tooltips are reachable via keyboard focus alone (AC-011).
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs`
- Definition of Done:
  - Banner and both tooltips render with the agreed copy and are keyboard-accessible.
- Gate:
  - Phase 4 tests pass.
- Dependencies:
  - None beyond Phase 1 landing (for stable file state); does not depend on Phase 2 or 3's markup.
- Parallelizable Work:
  - Safe to build in parallel with Phase 2, 3, and 5.

## Phase 5: Wizard left-panel copy and footer restyle (step 1 only)

- Goal: update the left-panel step 1/2/3 copy and the footer button styling for the section-creation wizard only, without affecting the student-onboarding wizard.
- Tasks:
  - [ ] Update the `steps` list titles/descriptions in `new_course.ex` to the new copy (node `44:842`).
  - [ ] Add footer/left-panel styling changes in `stepper.ex`, gated on the existing `if @id == "course_creation_stepper"` conditional (node `44:838`); resolve the Cancel-button border decision (extend `.secondary` vs. add a variant) per FDD Open Questions before finalizing that detail.
- Testing Tasks:
  - [ ] LiveView test: the left-panel copy for all three steps matches the updated text (AC-014).
  - [ ] New regression test asserting the student-onboarding wizard's rendered footer/left-panel styling is unchanged after this change (AC-015).
  - Command(s): `mix test test/oli_web/live/new_course/new_course_test.exs test/oli_web/live/delivery/student_onboarding/wizard_test.exs`
- Definition of Done:
  - Section-creation wizard shows the new copy/styling; student-onboarding wizard is pixel-identical to before this ticket.
- Gate:
  - Phase 5 tests pass, including the new onboarding-wizard regression test.
- Dependencies:
  - None; fully independent of Phases 1-4.
- Parallelizable Work:
  - Safe to build in parallel with every other phase; touches only `new_course.ex` and `stepper.ex`.

## Phase 6: Accessibility hardening, telemetry, and full regression

- Goal: close out cross-cutting accessibility and observability requirements and confirm no regression across the whole Select Source Materials step.
- Tasks:
  - [ ] Audit every control introduced or changed in Phases 2-5 for keyboard operability and visible focus (tabs, tooltips, cards, banner).
  - [ ] Add an assistive-technology announcement (existing live-region/announcement pattern already used elsewhere in `Listing`, per FDD Section 11) for filter/search-driven result-list updates.
  - [ ] Add or extend a lightweight telemetry event for My Course Sections tab selection (aggregate counts only, no section titles/ids), per PRD Section 12 and `docs/OPERATIONS.md` conventions.
  - [ ] Run the `ui_workflow` `implement`→`qa` cycle against `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md` for visual/layout fidelity in both light and dark mode.
- Testing Tasks:
  - [ ] LiveView/manual test: every new/changed control is keyboard-operable with a visible focus indicator (AC-016).
  - [ ] LiveView/manual test: a filter/search-driven result-list update is announced to assistive technology (AC-017).
  - [ ] Full regression pass across the whole Select Source Materials step (all phases' tests together).
  - Command(s): `mix test test/oli_web/live/new_course/ test/oli_web/live/delivery/student_onboarding/` then `mix format --check-formatted`
- Definition of Done:
  - All 17 acceptance criteria pass; no regression in existing Template-based course creation; `ui_workflow` visual/layout QA reports no material open finding (or findings are explicitly logged as `needs-human-review`).
- Gate:
  - Full `mix test` run for the affected directories is green; `ui_workflow` QA status is `needs-human-review` or `done`, not `iterating` with open structural findings.
- Dependencies:
  - Phases 1-5.
- Parallelizable Work:
  - None; this phase closes out and depends on everything before it.

## Parallelization Notes

- Phase 1 must land first; it is the only hard serial dependency (row typing + My Course Sections data availability).
- Phases 2, 3, 4, and 5 touch disjoint files (`select_source.ex` tab/filter logic; `card_listing.ex` + new badge primitive; `select_source.ex` banner/tooltip markup; `new_course.ex` + `stepper.ex`) and can be implemented and reviewed in parallel once Phase 1 lands.
- Phase 6 is the integration/closeout phase and must run last.

## Phase Gate Summary

- Gate A (after Phase 1): My Course Sections rows are correctly authorized and typed; no visible UI change yet; existing tests green.
- Gate B (after Phases 2-5, any order): filter tabs, card redesign/hover, banner/tooltips, and wizard copy/footer restyle each pass their own phase's tests independently, with no cross-phase regression.
- Gate C (after Phase 6): full accessibility/telemetry/regression pass is green, `ui_workflow` visual QA is closed or explicitly escalated to human review, and the ticket is ready for `harness-update_docs` (per `informal.md`'s existing "Follow-up: doc reconciliation" note) before PR close.
