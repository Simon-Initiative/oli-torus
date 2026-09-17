# Course Builder Source Selection - Informal Feature Context

Last updated: 2026-09-17

> **Scope correction (2026-09-17):** the entire Blueprint Courses workstream — `MER-5825`, `MER-5826`, `MER-5827`, `MER-5829`, `MER-5830`, `MER-5833` — is `Closed Won't Do` epic-wide (confirmed on `MER-5841` by Eli Knebel and Francisco Castro, decision by Darren, 2026-09-08). There is no linked/child Blueprint relationship anywhere in current scope, in this lane or any other. Everything below reflects that. The epic-level `../informal.md` and `../plan.md` still describe the cancelled workstream and need their own refresh pass (e.g. via `harness-update_docs`) — do not treat them as current for this lane.

This feature updates the shared course-builder source-selection experience so instructors can discover ordinary curriculum sources ("Templates" — the existing project/product sources) and browse their own course sections ("My Course Sections") ahead of copying them. This ticket (`MER-5828`) ships the shared UI and the My Course Sections tab/listing; the actual "select to copy" action and copy modal are deliberately deferred to a follow-up PR (`MER-5832`), so My Course Sections cards are intentionally non-functional ("dummy") for selection in this PR.

The codebase is Phoenix LiveView/HEEx (`OliWeb.Common.CardListing`, `OliWeb.Delivery.NewCourse.{SelectSource,TableModel}`, `OliWeb.Common.Listing`), not React — prior mentions of "React components" in this doc were inaccurate and have been corrected below.

## Design references

Figma file: [Course replication feature](https://www.figma.com/design/ZAfwBt1ek94xAyriR6wy8S/Course-replication-feature). All node-ids below are confirmed by Gastón (2026-09-17); the two node-ids previously listed here from the Jira description text alone (`44-721`, `40-2883`) turn out to be correct and are kept, now with confirmed content.

**Scope boundary confirmed with these designs:** all of it is the section-creation wizard's **step 1 of 3** ("Select source materials") only. Steps 2 and 3 (`name_course`, `course_details`) are not touched.

Full-screen references:

1. Node `44-721` — full step 1 view, light mode.
2. Node `44-1146` — new-feature explanatory banner, rendered between the filter/search bar and the pagination + "Showing X-Y of Z" row. New element; in code this slot is between `FilterBox.render`/`Filter.render` and `Listing.render` inside `select_source.ex`.
3. Node `40-2883` — same as (1), dark mode.
4. Node `74-4025` — hover tooltip on the "Templates" filter button.
5. Node `74-4023` — hover tooltip on the "My Course Sections" filter button.

Component-level detail (subsets of 1/3, called out because they carry the changes with the most implementation risk):

6. Left-panel background `#1D4481` — **already satisfied, no new token needed.** `assets/tailwind.theme.js` defines a custom `blue.700 = '#1D4481'` in the Tailwind theme, and `lib/oli_web/live/common/stepper/stepper.ex:40` already renders the left panel as `bg-blue-700 dark:bg-black`. Keep using `bg-blue-700`; do not introduce a raw hex value.
7. Node `44-842` — left-panel step titles/descriptions (the 3-step content). This is data owned by `new_course.ex`'s `steps` list (title/description strings passed into `OliWeb.Common.Stepper`), not shared markup — low risk to replace.
8. Node `44-789` — reference card for source type "My Section".
9. Node `44-805` — reference card for source type "Free". If a source is neither "My Section" nor "Free"/"Template", it appears to carry no label at all.
10. Node `44-1459` — "My Section" card hover state: same card with a darkened overlay and the label "SELECT TO COPY COURSE SECTION". **Open question from Gastón:** whether other card types (Free/Template) get an equivalent hover treatment — needs designer confirmation. Also note the tension with this ticket's dummy scope below.
11. Node `44-838` — wizard footer (Cancel / Next Step buttons), same layout as today with new styling only.

**Shared-component risk on (7) and (11):** `OliWeb.Common.Stepper` (`lib/oli_web/live/common/stepper/stepper.ex`) is not exclusive to course creation — `lib/oli_web/live/delivery/student_onboarding/wizard.ex` renders the same component for an unrelated student-onboarding flow. The footer button markup and the step-item chrome live in the shared component, so any new styling there must be scoped to the `course_creation_stepper` instance (the component already has one such conditional, keyed on `@id`, at stepper.ex:50-55) rather than restyling the shared component globally, or the student-onboarding wizard picks up unintended visual changes.

## Source tickets

- `MER-5828` Course Builder UI Updates — this ticket, branch `MER-5828-course-builder-ui-updates`, status In Progress.
- `MER-5841` Replication contracts and safety foundation — **merged to master 2026-09-17** ([PR #6854](https://github.com/Simon-Initiative/oli-torus/pull/6854)). Defines the server-side authorization/query contract this feature must reuse for "My Course Sections" eligibility: an active enrollable section on which the actor holds an instructor/content-developer role, or any active enrollable section for admins. This branch has been **rebased onto master and already includes it.**
- `MER-5831` Course Copy: Rules — open PR ([PR #6855](https://github.com/Simon-Initiative/oli-torus/pull/6855)), not yet merged. Not required to merge for this ticket (copy submission stays out of scope here), but Darren Siegel's design comment (2026-08-06) documents modeling "previous sections" as a distinct, typed source kind in `select_source.ex`/`table_model.ex` — follow that direction here so `MER-5832` can plug in the real action without reshaping these components again.
- `MER-5832` Course Builder: Selecting a section to copy — deferred to the follow-up PR; consumes the tab/filter/query/tag built here and replaces the placeholder action with the real copy modal.
- Epic context: `../informal.md` (stale, see scope correction above).
- Parent lane plan: `../plan.md` (same staleness caveat).

## Product outcome

The course builder lets an instructor quickly find an appropriate source: an existing Template (project or product) to build from immediately, exactly as today, or one of their own course sections to copy later. Selecting a My Course Section in this PR surfaces the section (searchable, sortable, tagged) but does not yet trigger any creation — that ships in `MER-5832`.

## Functional scope

- Improve course-card density, layout, spacing, and metadata scanability in the existing card/list components (`CardListing`, `TableModel`, `Listing`).
- Add source filters/tabs: **All Sources**, **Templates** (the existing Project/Product sources — today rendered via `TableModel.render_type_column/3` as "Project"/"Template"), and **My Course Sections** (new).
- "My Course Sections" lists active enrollable sections where the current instructor holds an instructor/content-developer role (admins: any active enrollable section) — reuse `MER-5841`'s resolution rule server-side; do not write a second, divergent eligibility query.
- Preserve Most Recent as the default sort and preserve a user-selected sort while filters change.
- Keep search and sorting scoped to the selected source semantics.
- Add consistent source/type tags: "Template" (existing) and a new "My Section" tag.
- My Course Sections cards are present, searchable, sortable, and taggable, but their selection affordance is an intentional no-op/disabled state in this ticket (e.g. hidden or disabled "Select" action with copy explaining it is coming soon). `MER-5832` swaps this placeholder for the real "select to copy" action and modal.
- No Blueprint linked-child creation action, no linked/child explanatory messaging, and no Blueprint source/owner surfacing on Manage — removed from scope; the feature is cancelled, not deferred.
- Add a new-feature explanatory banner between the filter/search bar and the pagination row (design reference 2).
- Add hover tooltips on the "Templates" and "My Course Sections" filter buttons, with a keyboard/focus equivalent (design references 4-5).
- Restyle the source cards per type: "My Section" and "Free" get distinct treatments; a source that is neither gets no label at all (design references 8-9).
- "My Section" cards get a hover state — darkened overlay plus "SELECT TO COPY COURSE SECTION" label (design reference 10) — implemented as a **purely visual hover affordance**; it must not make the card clickable/selectable in this ticket, since selection stays a no-op until `MER-5832`. Whether other card types share this hover treatment is an open decision (see below).
- Update the wizard's left-panel step titles/descriptions (design reference 7) and footer button styling (design reference 11) for **step 1 of the section-creation wizard only** — steps 2 and 3 are unchanged, and none of this may leak into the unrelated student-onboarding wizard that shares `OliWeb.Common.Stepper` (see Design references, item 6/11 risk note).

## Technical guidance

Reuse `MER-5841`'s contract for "My Course Sections" eligibility; do not filter client-side and do not duplicate the eligibility check.

Follow the source-kind modeling direction from `MER-5831`'s design comment: give each row a typed source kind (e.g. `{:project, ...} | {:publication, ...} | {:product, ...} | {:previous_section, ...}`) instead of the current structural `Map.has_key?(item, :type)` check, so `MER-5832` can add the real `:previous_section` selection/copy action without re-deriving row typing.

Do not implement any Blueprint relationship, synchronization, or linked-child messaging or actions — none of that exists in scope anywhere in the epic anymore.

All filters, sort controls, tabs, cards, and the (currently disabled) My Course Sections action need keyboard operation, accessible names, selected states, and focus behavior. Hover text must have a keyboard/focus equivalent. Dynamic result updates should be announced where appropriate. Keep the disabled action visually and semantically honest — communicate via copy/state that it ships in a follow-up rather than presenting it as broken.

Use the existing `bg-blue-700` Tailwind color for the wizard left panel; it already renders `#1D4481` exactly (`assets/tailwind.theme.js`), so no new color token is needed for that value. Any other color/token gaps surfaced while implementing the new banner, tooltips, or card states should be checked against `lib/oli_web/components/design_tokens/` first, per the repo's `implement_ui`/`ui_workflow` token-reuse guardrails, before introducing anything new.

`OliWeb.Common.Stepper` (`lib/oli_web/live/common/stepper/stepper.ex`) is shared with `lib/oli_web/live/delivery/student_onboarding/wizard.ex`. Any left-panel/footer styling change (design references 7, 11) must be scoped to the `course_creation_stepper` id, following the existing `if @id == "course_creation_stepper"` conditional pattern already in that component, not applied unconditionally.

## Out of scope

- Blueprint parent/child relationship, synchronization, enable/disable, and linked-section visibility — **cancelled epic-wide** (`MER-5825`/`5826`/`5827`/`5829`/`5830`/`5833`, all `Closed Won't Do`). Not built here or elsewhere.
- The actual copy submission/modal for My Course Sections — `MER-5832`, follow-up PR.
- Course Copy backend semantics (allowlist, transaction, learner-data exclusion) — `MER-5831` / `../course_copy/`.

## Dependencies and handoff

- Hard dependency on `../replication_contracts/` (`MER-5841`) — merged to master 2026-09-17; **this branch is rebased and includes it.**
- Soft dependency on `../course_copy/` (`MER-5831`, PR #6855, open) — not required to merge this ticket, but mirror its source-kind modeling so `MER-5832` integrates without restructuring this ticket's components.
- No dependency on `../blueprint_lifecycle/` or `../blueprint_visibility/` — both lanes are cancelled.
- Hands off to `MER-5832`: the My Course Sections tab, query, cards, and tag should be ready to receive a real selection action and copy modal without further restructuring.

## Verification expectations

- Query/filter tests for My Course Sections membership (mirroring `MER-5841`'s contract), authorization, search, and sort preservation.
- UI tests for the All Sources / Templates / My Course Sections filters, tags, and the disabled/no-op state of My Course Sections cards.
- Accessibility tests for keyboard-only operation, focus, selected state, hover equivalents, and dynamic result announcements.
- Regression tests for ordinary Template-based course creation (unchanged select/copy flow).
- No Blueprint-vs-Copy end-to-end distinction test — Blueprint is out of scope, not a parallel path to distinguish from.

## Open decisions

- Exact hover/disabled-state copy for My Course Sections cards before `MER-5832` lands.
- Exact card metadata and sort options.
- Whether the row/source-kind typing refactor (per `MER-5831`'s design comment) is completed fully in this ticket or left partially prepared for `MER-5832`.
- Whether the darkened-overlay + "SELECT TO COPY COURSE SECTION" hover treatment (design reference 10) extends to Free/Template cards, or is exclusive to "My Section" cards — needs designer confirmation.
- Exact wording for the new-feature explanatory banner (design reference 2) and the two filter tooltips (design references 4-5).

## Follow-up: doc reconciliation

As one of the last steps of this ticket (after implementation, before closing the PR), run **`harness-update_docs`** against this work item directory (`docs/exec-plans/current/epics/course_replication/course_builder_sources/`) to reconcile `prd.md`/`fdd.md`/`plan.md` (produced by the `harness-analyze`/`harness-architect`/`harness-plan` steps) with what was actually implemented — in particular the deliberately non-functional My Course Sections selection state and any source-kind typing decisions made along the way. It only rewrites this work item's own PRD/FDD/plan and re-validates them; it does not touch `informal.md` files.

It does **not** cover the epic-level drift found in this pass: `../informal.md` and `../plan.md` (and, transitively, `../blueprint_lifecycle/informal.md` and `../blueprint_visibility/informal.md`) still describe the cancelled Blueprint workstream as active scope. That reconciliation is bigger than this ticket (it spans lanes not owned here) and should be tracked as separate follow-up work once all in-flight lanes are known, rather than folded into this PR.
