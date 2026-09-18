# Course Builder Source Selection UI Updates - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/prd.md`
- FDD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/fdd.md`
- Design brief: `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md` (via `ui_workflow`)

## Scope

Update step 1 of 3 ("Select source materials") of the section-creation wizard: add All Sources / Templates / My Course Sections filter tabs with sort-order preservation, redesign source cards with type tags and the "My Section" hover state, add the new-feature banner and filter tooltips, and restyle the wizard's left-panel copy and footer for step 1 only — without touching steps 2/3, without any Blueprint concept, and without leaking styling changes into the shared `OliWeb.Common.Stepper`'s other consumer (`student_onboarding/wizard.ex`). No new schema, migration, or backend authorization logic: `MER-5841` (authorization) and `MER-5831` (the My Course Sections query, row normalization, and the copy-creation flow) are both already merged and already wired up; this plan only builds the presentation layer on top of them and explicitly does not gate the selection behavior they already provide.

## Clarifications & Default Assumptions

- `MER-5831` merged to `master` on 2026-09-18 (PR #6855, merge commit `7908b1002e`) and this branch is rebased onto it. Its merge already wired `SectionCreation.permitted_sections/2` into `select_source.ex`, already normalized all source kinds in `table_model.ex` (`is_product?/1`, `is_course?/1`, `source_title/1`, `source_description/1`, `source_identifier/1`), and already made every card — including My Course Sections rows — selectable, proceeding into a working (unstyled) step-2 "Choose what to copy" flow. This superseded the plan's original premise that My Course Sections selection would be a no-op in this ticket.
- Per Gastón's decision on 2026-09-18: this plan does not add any gating, confirmation, or disabled state to My Course Sections card selection. It builds the visual/discovery layer only. The resulting brief, unstyled-step-2 window is accepted because Torus ships by release rather than on merge, and `MER-5832` (which redesigns step 2) follows this ticket immediately.
- The My Section hover treatment (dark overlay + "SELECT TO COPY COURSE SECTION") is built only for My Section cards in this plan; extending it to Template cards is out of scope pending designer confirmation (PRD Open Questions) and is not blocked by any phase below.
- **Template tag text, pending Jess (design):** the Figma reference card for a Template row (node `44:805`) shows a green "Free" pill, not the word "Template" the PRD/Jira AC calls for. Interim decision (2026-09-18, Gastón): implement literal "Template" text using that same green pill styling, and confirm with design via Slack; Phase 3 below reflects this interim choice.
- No new row-kind abstraction is introduced. `MER-5831` already normalized row typing via `is_product?/1`/`is_course?/1`; every phase below builds directly on that existing interface rather than the `{:project,...}|{:publication,...}|{:product,...}|{:previous_section,...}` shape originally floated pre-merge.
- No feature flag is used (PRD Section 11); this ships as a normal additive change.

## Phase 1: Confirm the existing My Course Sections integration and add the tag-rendering helper

- Goal: establish a regression baseline for the already-shipped (`MER-5831`) My Course Sections query, authorization, and row normalization, and add the one small new piece of logic later phases need: a tag derivation built directly on the existing `is_product?/1`/`is_course?/1` predicates. No new query, no new row-typing abstraction, and no visible UI change yet.
- Tasks:
  - [x] Read `lib/oli/delivery/section_creation.ex` and confirm `permitted_sections/2`/`permitted_sections_query/2` (used already by `select_source.ex`'s `retrieve_all_sources/2`) implement exactly the eligibility rule this ticket needs — no code change expected here, this is a confirmation task.
  - [x] Add a small tag-derivation helper in `table_model.ex` (e.g. `tag_variant/1`) that returns `:template` when `is_product?/1`, `:my_section` when `is_course?/1`, and `nil` otherwise — built directly on the existing predicates, not a new row-kind shape.
  - [x] Confirm the unrecognized-row fallback (neither product nor course) renders no tag rather than raising (FDD Section 10) — already true of `render_type_column/3`'s default branch; add a test if none exists.
- Testing Tasks:
  - [x] Regression test: an instructor sees only active enrollable sections where they hold an instructor/content-developer role under My Course Sections, confirming this ticket's changes have not altered that existing behavior (AC-004) — already covered by `select_source_test.exs`'s `"Instructor course copy sources"` describe block; reran it green rather than duplicating it.
  - [x] Regression test: an admin actor sees any active enrollable section under My Course Sections, unchanged (AC-005) — already covered by `section_creation_test.exs`'s `"T21 resolves any active enrollable section for an admin"`; reran it green.
  - [x] Regression test: a section the existing authorization rule would deny for the current actor is absent from the returned rows, unchanged (AC-006) — already covered by `section_creation_test.exs`'s institution-boundary and student-enrollment tests; reran them green.
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs test/oli/delivery/section_creation_test.exs`
- Definition of Done:
  - The existing My Course Sections eligibility/selection behavior is confirmed unchanged and regression-tested, and the new tag-derivation helper exists and is unit-tested; no rendered markup has changed yet.
- Gate:
  - All Phase 1 tests pass; the existing `select_source_test.exs`/`section_creation_test.exs` suites are green unmodified in behavior (only new regression assertions added).
- Dependencies:
  - None — first phase. (No dependency on `MER-5841`/`MER-5831` landing, since both are already merged and rebased onto this branch.)
- Parallelizable Work:
  - None; Phase 3's tag rendering depends on the helper added here.

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
  - Phase 1 (sequencing only, for the Phase 1 regression baseline; the underlying My Course Sections rows and `is_product?/1`/`is_course?/1` predicates this phase filters over already exist independent of Phase 1's new tag helper).
- Parallelizable Work:
  - Safe to build in parallel with Phase 4 (banner/tooltips) and Phase 5 (Stepper), since neither touches `filter/3` or the tab markup.

## Phase 3: Card redesign, type tags, and the My Section hover state

- Goal: denser cards with a type tag per row kind and the designed My Section hover overlay, leaving the existing, already-working selection click completely untouched.
- Tasks:
  - [ ] Add `lib/oli_web/components/design_tokens/primitives/badge.ex` with `attr :variant, :atom, values: [:my_section, :template, nil], default: nil`, rendering nothing when `variant` is `nil`, using the token mapping from the `ui_workflow` brief (`Fill-Accent-fill-accent-purple`/`Text-text-accent-purple` for My Section; `Fill-Chip-Green`/`Text-text-accent-green` reused for Template as an interim styling choice — the Figma reference card for that row kind shows a green "Free" pill instead of the word "Template", pending confirmation with Jess).
  - [ ] Update `CardListing` to render the badge (via Phase 1's tag-derivation helper) per row and increase card density/metadata per the Figma reference (nodes `44:789`, `44:805`, `44:824`).
  - [ ] Add the My Section hover overlay (dark overlay + "SELECT TO COPY COURSE SECTION", node `44:1459`) as a visual addition only.
  - [ ] Do **not** modify `CardListing`'s existing `phx-click={@selected}`/`phx-value-id` selection markup — it already correctly routes every row kind, including My Course Sections, into the existing `MER-5831` copy-creation flow. Verify by code review that this task list did not touch it.
- Testing Tasks:
  - [ ] LiveView test: Template card shows "Template" tag, My Course Sections card shows "My Section" tag, a card that is neither shows no tag (AC-007).
  - [ ] LiveView/manual test: the redesigned grid shows more cards per viewport and renders title/description/date/tag without truncation regressions (AC-008).
  - [ ] Manual visual check: hovering a My Course Sections card shows the darkened overlay and label per the Figma reference (AC-012).
  - [ ] LiveView regression test: activating a My Course Sections card still proceeds into the existing step-2 copy-options flow exactly as it did before this ticket (no new gating), and activating a Template card still creates a section as before (AC-013).
  - Command(s): `mix test test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/common/card_listing_test.exs`
- Definition of Done:
  - Cards visually match the confirmed Figma states for Template (interim text, pending Jess)/My Section/no-tag, and My Course Sections selection still works exactly as it did before this ticket (verified by regression test, not by inspection).
- Gate:
  - Phase 3 tests pass; existing Template-card and My-Course-Sections-card selection/creation regression tests pass unmodified.
- Dependencies:
  - Phase 1 (tag-derivation helper).
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

- Phase 1 lands first to establish the regression baseline and the tag-derivation helper Phase 3 needs; it is intentionally light now that `MER-5831` already ships the underlying query/data.
- Phases 2, 3, 4, and 5 touch disjoint files (`select_source.ex` tab/filter logic; `card_listing.ex` + new badge primitive; `select_source.ex` banner/tooltip markup; `new_course.ex` + `stepper.ex`) and can be implemented and reviewed in parallel once Phase 1 lands.
- Phase 6 is the integration/closeout phase and must run last.

## Phase Gate Summary

- Gate A (after Phase 1): the already-shipped My Course Sections authorization/selection behavior is regression-tested and confirmed unchanged; the new tag-derivation helper exists and is unit-tested; no visible UI change yet.
- Gate B (after Phases 2-5, any order): filter tabs, card redesign/hover, banner/tooltips, and wizard copy/footer restyle each pass their own phase's tests independently, with no cross-phase regression.
- Gate C (after Phase 6): full accessibility/telemetry/regression pass is green, `ui_workflow` visual QA is closed or explicitly escalated to human review, and the ticket is ready for `harness-update_docs` (per `informal.md`'s existing "Follow-up: doc reconciliation" note) before PR close.
