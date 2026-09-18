# Course Builder Source Selection UI Updates - Product Requirements Document

## 1. Overview

This work item updates the "Select source materials" step (step 1 of 3) of the section-creation wizard so an instructor or admin can discover an ordinary curriculum source ("Template") and browse and select their own course sections ("My Course Sections") in one place, with denser cards, type tags, a new explanatory banner, accessible filter tooltips, and a hover state on My Course Sections cards. Selecting a My Course Sections card already works end to end — the underlying query and copy-creation flow shipped with `MER-5831` (merged 2026-09-18) — and proceeds into that flow's existing, unstyled step-2 "Choose what to copy" UI; this ticket adds only step 1's presentation layer and does not change step 2's functionality. The follow-up ticket `MER-5832` is expected to redesign that step-2 presentation next. Jira: [`MER-5828`](https://eliterate.atlassian.net/browse/MER-5828).

## 2. Background & Problem Statement

Today the wizard's source list shows projects and products ("Templates") together with no filtering, a low-density card layout, and no way for an instructor to see their own previously created sections as a future source. The wider course-replication epic originally also planned a "Blueprint" linked-child relationship feature; that entire workstream (`MER-5825`, `MER-5826`, `MER-5827`, `MER-5829`, `MER-5830`, `MER-5833`) is `Closed Won't Do` epic-wide (confirmed on `MER-5841`, decision by Darren, 2026-09-08), so this UI work is scoped only to Templates and My Course Sections, with no linked/child relationship concept anywhere.

The authorization contract for which sections an instructor may see under "My Course Sections" was delivered by `MER-5841` (merged to `master` 2026-09-17, [PR #6854](https://github.com/Simon-Initiative/oli-torus/pull/6854)). `MER-5831` (merged to `master` 2026-09-18, [PR #6855](https://github.com/Simon-Initiative/oli-torus/pull/6855)) then built the copy-creation engine on top of it and already wired it into the wizard: `select_source.ex` already fetches My Course Sections rows via `Oli.Delivery.SectionCreation.permitted_sections/2`, and selecting one already proceeds into a working, unstyled "Choose what to copy" step. This ticket's job is exclusively the step-1 presentation layer on top of that already-functional flow — it is not what makes selection work, and it must not disable or gate a flow that already works.

## 3. Goals & Non-Goals

### Goals
- Let an instructor/admin filter the source list by All Sources, Templates, or My Course Sections without losing their chosen sort order.
- Show only sections the current instructor (or, for admins, any active enrollable section) is eligible to see under My Course Sections, enforced server-side.
- Increase card density/scannability and add a type tag ("Template", "My Section", or none).
- Add the new-feature explanatory banner and the two filter-button tooltips with the agreed copy.
- Add the designed "select to copy" hover treatment on My Course Sections cards, on top of the selection behavior that already works via `MER-5831`.
- Update the wizard's left-panel step copy and footer styling for step 1 only, without visually affecting the unrelated student-onboarding wizard that shares the same `OliWeb.Common.Stepper` component.
- Leave the tab/card/tag surface functionally as-is where it already works (selection, eligibility, copy creation) and ready for `MER-5832` to redesign only the step-2 presentation, without needing to touch this ticket's step-1 components again.

### Non-Goals
- Any Blueprint parent/child relationship, synchronization, enable/disable, or linked-section visibility — cancelled epic-wide, not part of this or any other lane.
- Redesigning the step-2 "Choose what to copy" UI/modal for My Course Sections — `MER-5832`. It already works today (unstyled) via `MER-5831`; this ticket does not touch it.
- Any Course Copy backend semantics (allowlist, transaction, learner-data exclusion) — already implemented by `MER-5831` / `course_copy/`; not re-touched here.
- Changes to step 2 (`name_course`) or step 3 (`course_details`) of the wizard.

## 4. Users & Use Cases

- Instructor (Direct delivery or LMS instructor with a configure role): filters the source list to find a Template to build a new section from today, or browses their own past sections in My Course Sections in preparation for copying one once `MER-5832` ships.
- Admin author: same filtering/browsing, scoped to any active enrollable section rather than only sections they personally teach.
- Independent learner/instructor without a course-authoring account: unaffected by this change beyond the redesigned card layout; still sees the existing "Link Authoring Account" prompt where applicable.

## 5. UX / UI Requirements

- Three filter tabs — All Sources, Templates, My Course Sections — each keyboard-operable with an accessible name and a selected state; switching tabs never resets the user's chosen sort order (default remains Most Recent).
- A new explanatory banner renders between the filter/search bar and the pagination + "Showing X-Y of Z" row, with the agreed copy (see `informal.md`, Open decisions — resolved).
- Hover tooltips on the Templates and My Course Sections filter buttons, each with a keyboard/focus-triggered equivalent, reusing the existing `GlobalTooltip` phx-hook.
- Redesigned source cards: denser layout, a "Template" tag for existing project/product sources, a "My Section" tag for My Course Sections rows, and no tag for a source that is neither.
- My Course Sections cards show a darkened-overlay hover state with the label "SELECT TO COPY COURSE SECTION" — the card is already selectable/clickable via the existing `MER-5831` flow, so this hover accurately previews what clicking already does; this ticket must not add, remove, or gate that click behavior.
- Left-panel step 1/2/3 titles and descriptions are updated to the new copy; footer (Cancel/Next Step) button styling is refreshed — both scoped to the section-creation wizard instance only.
- All of the above must support keyboard-only operation, visible focus states, and assistive-technology announcements for dynamic result-list updates.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Accessibility: every new/changed control (filter tabs, tooltips, cards, hover state) must be keyboard-operable with visible focus and an accessible name; hover-only affordances need a focus/keyboard equivalent; dynamic list updates must be announced to assistive technology.
- Authorization: My Course Sections eligibility must be enforced server-side by reusing `MER-5841`'s contract; client-side filtering alone is not acceptable as an authorization boundary.
- Regression safety: existing Template-based source selection, search, sort, and course creation must keep working unchanged; the shared `OliWeb.Common.Stepper` component must not visually change for the unrelated student-onboarding wizard.
- Internationalization: no new requirement beyond existing repository conventions; new copy (banner, tooltips, tags) should follow the same string-handling approach already used in `select_source.ex`/`card_listing.ex`.

## 9. Data, Interfaces & Dependencies

- Consumes `MER-5841`'s authorization contract (`Oli.Delivery.SectionCreation.authorize_actor/2`) and `MER-5831`'s already-merged query/row-normalization work (`SectionCreation.permitted_sections/2`, `TableModel.is_product?/1`/`is_course?/1`/`source_title/1`/`source_description/1`/`source_identifier/1`) — both are hard dependencies now that `MER-5831` is merged; no new eligibility query or row-typing scheme should be written.
- Primary files: `lib/oli_web/live/new_course/select_source.ex`, `lib/oli_web/live/common/card_listing.ex`, `lib/oli_web/live/new_course/table_model.ex`, `lib/oli_web/live/new_course/new_course.ex`, `lib/oli_web/live/common/stepper/stepper.ex`. `lib/oli_web/live/new_course/name_course.ex` (step 2's copy-options UI) is read-only context, not a file this ticket edits.
- Design source: Figma file "Course replication feature" (`ZAfwBt1ek94xAyriR6wy8S`); full node list and the `ui_workflow` design brief are recorded in `informal.md` and `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md`.
- Handoff: `MER-5832` consumes the tab/card/tag surface built here — which is already functionally complete — and redesigns the step-2 "Choose what to copy" presentation; it does not need to enable anything this ticket left disabled, because nothing is disabled.

## 10. Repository & Platform Considerations

- Implementation surface is Phoenix LiveView/HEEx, not React (`OliWeb.Common.CardListing`, `OliWeb.Delivery.NewCourse.{SelectSource,TableModel}`, `OliWeb.Common.Listing`).
- Reuse the repository's Figma-synced semantic token layer (`assets/tailwind.tokens.js`, via `tailwind.plugins.js`'s `tokenColorPlugin`) for all new colors (card surface/border, tag colors, tooltip surface/border/text) instead of hardcoding hex values; see the token-mapping table in the `ui_workflow` brief.
- Reuse the existing `GlobalTooltip` phx-hook for both filter-button tooltips instead of building a new tooltip mechanism.
- `OliWeb.Common.Stepper` is shared with `lib/oli_web/live/delivery/student_onboarding/wizard.ex`; any left-panel/footer styling change must be scoped to the `course_creation_stepper` id, following the existing `if @id == "course_creation_stepper"` conditional already present in that component.
- Code review should include `.review/ui.md` (UX/accessibility/visual behavior) and `.review/security.md`/`.review/performance.md` per repository default policy; `.review/elixir.md` applies given the LiveView changes.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item. This is an additive, low-risk UI change to an existing wizard step reusing an already-shipped authorization contract (`MER-5841`); it ships through the normal deployment pipeline like the rest of the epic's lanes.

## 12. Telemetry & Success Metrics

- Emit or extend an existing telemetry/AppSignal signal when the My Course Sections filter tab is selected and when a My Course Sections card is activated, to give the `MER-5832` team visibility into real usage of the already-functional flow ahead of its step-2 redesign (aggregate counts only, no section titles or user-identifying content).
- Success signal for this ticket: no regression in existing Template-based or My-Course-Sections-based section-creation completion rate, and the My Course Sections tab renders without error for eligible instructors/admins in production telemetry.

## 13. Risks & Mitigations

- Risk: `OliWeb.Common.Stepper` styling changes leak into the unrelated student-onboarding wizard. Mitigation: scope every left-panel/footer style change to the `course_creation_stepper` id and add a regression test asserting the onboarding wizard's rendered output is unchanged.
- Risk: instructors reach the existing, unstyled step-2 "Choose what to copy" UI via the newly-prominent, polished My Course Sections tab, producing a visually inconsistent hand-off between a polished step 1 and a rough step 2. Mitigation: accepted as a brief, release-scoped window rather than something to fix here — Torus ships by release rather than immediately on merge, and `MER-5832` (which redesigns step 2) follows this ticket immediately.
- Risk: this ticket's refactor of `select_source.ex`/`table_model.ex` (to add tabs/tags) accidentally changes or forks the "who can see this section" behavior already implemented by `MER-5841`/`MER-5831`. Mitigation: touch only presentation logic; add a regression test proving a section `MER-5841`'s contract would deny still never appears in the My Course Sections response after this ticket's changes.
- Risk: color/token drift between the Figma frame's local fallback values and the repository's synced `tailwind.tokens.js` (already found once, on the footer "Next Step" button fill). Mitigation: always resolve by token name, not by the frame's literal hex fallback, and flag any drift found back to design rather than picking a value unilaterally.

## 14. Open Questions & Assumptions

### Open Questions
- **Pending Slack question to Jess (design), asked 2026-09-18:** the Figma reference card for a Template row (node `44:805`) shows a green "Free" pill, not the word "Template" this PRD's UX requirements call for. Interim decision: implement literal "Template" text using that same pill styling; if design confirms "Free"/cost-based is correct instead, this needs a follow-up change, and it's still open what a paid template's card should show.
- Whether the My Section hover treatment (dark overlay + "SELECT TO COPY COURSE SECTION") should extend to Free/Template cards, or stays exclusive to My Section cards — no other card type shows this hover state in the designs reviewed so far; needs designer confirmation.
- Exact card metadata and sort options beyond what is already in the current implementation.
- Footer "Next Step" button fill color: Figma's local fallback is `#0073E5`; the repository's synced token `Fill-Buttons-fill-primary` is `#0080FF`. Use the token; flag the drift to design.
- Footer "Cancel" button border: the design shows a `Border-border-bold` (`#8AB8E5`) border that no existing `torus-button` variant matches exactly — needs a decision (extend `.secondary`, or add a variant).

### Assumptions
- The entire Blueprint Courses workstream is definitively out of scope epic-wide, per the `MER-5841` comment thread (Eli Knebel, Francisco Castro, decision by Darren, 2026-09-08).
- `MER-5841`'s authorization contract and `MER-5831`'s query/row-normalization work, both already merged, fully satisfy this ticket's data needs; no additional backend work is required.
- Selecting a My Course Sections card is intentionally left functional (not gated) in this ticket, per Gastón's decision on 2026-09-18: the resulting unstyled step-2 experience is an acceptable, brief, release-scoped state ahead of `MER-5832`.
- The hover-state ambiguity on non-My-Section card types is safe to leave unresolved for this PR — building only the confirmed My Section hover state — since inventing an unconfirmed additional state would violate the design-fidelity guardrails already established for this ticket.

## 15. QA Plan

- Automated validation:
  - `Phoenix.LiveViewTest` coverage for `select_source.ex`/`card_listing.ex`/`table_model.ex` covering filter tabs, sort preservation, tag rendering, My Course Sections eligibility scoping (regression), and confirming card selection/activation proceeds into the existing copy-creation flow unchanged for every source type.
  - A regression LiveView test for the student-onboarding wizard confirming `OliWeb.Common.Stepper`'s shared styling is unchanged.
  - Accessibility assertions (roles, `aria-selected`, focus order) within the same LiveView test suite where feasible.
- Manual validation:
  - Visual/layout comparison against the Figma design (via the `ui_workflow` `implement`/`qa` modes) for card density, banner, tooltips, and the My Section hover state, in both light and dark mode.
  - Manual keyboard-only walkthrough of filter tabs, tooltips, and cards.
  - Manual confirmation that the student-onboarding wizard is visually unaffected.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
