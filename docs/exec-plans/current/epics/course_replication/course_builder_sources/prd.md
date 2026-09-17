# Course Builder Source Selection UI Updates - Product Requirements Document

## 1. Overview

This work item updates the "Select source materials" step (step 1 of 3) of the section-creation wizard so an instructor or admin can discover an ordinary curriculum source ("Template") and browse their own course sections ("My Course Sections") in one place, with denser cards, a new explanatory banner, and accessible filter tooltips. My Course Sections is list-only in this ticket: selecting a My Course Sections card is an intentional no-op, since the copy action ships in the follow-up ticket `MER-5832`. Jira: [`MER-5828`](https://eliterate.atlassian.net/browse/MER-5828).

## 2. Background & Problem Statement

Today the wizard's source list shows projects and products ("Templates") together with no filtering, a low-density card layout, and no way for an instructor to see their own previously created sections as a future source. The wider course-replication epic originally also planned a "Blueprint" linked-child relationship feature; that entire workstream (`MER-5825`, `MER-5826`, `MER-5827`, `MER-5829`, `MER-5830`, `MER-5833`) is `Closed Won't Do` epic-wide (confirmed on `MER-5841`, decision by Darren, 2026-09-08), so this UI work is scoped only to Templates and My Course Sections, with no linked/child relationship concept anywhere.

The authorization contract for which sections an instructor may see under "My Course Sections" was just delivered by `MER-5841` (merged to `master` 2026-09-17, [PR #6854](https://github.com/Simon-Initiative/oli-torus/pull/6854)); the actual copy-creation engine is `MER-5831` (open, [PR #6855](https://github.com/Simon-Initiative/oli-torus/pull/6855)). This ticket only needs the former.

## 3. Goals & Non-Goals

### Goals
- Let an instructor/admin filter the source list by All Sources, Templates, or My Course Sections without losing their chosen sort order.
- Show only sections the current instructor (or, for admins, any active enrollable section) is eligible to see under My Course Sections, enforced server-side.
- Increase card density/scannability and add a type tag ("Template", "My Section", or none).
- Add the new-feature explanatory banner and the two filter-button tooltips with the agreed copy.
- Add a purely visual "select to copy" hover treatment on My Course Sections cards without enabling any selection/copy behavior yet.
- Update the wizard's left-panel step copy and footer styling for step 1 only, without visually affecting the unrelated student-onboarding wizard that shares the same `OliWeb.Common.Stepper` component.
- Leave the tab/query/card/tag surface in a state `MER-5832` can extend with a real selection action without restructuring it.

### Non-Goals
- Any Blueprint parent/child relationship, synchronization, enable/disable, or linked-section visibility — cancelled epic-wide, not part of this or any other lane.
- Implementing the actual "select to copy" action or copy-options modal for My Course Sections — `MER-5832`.
- Any Course Copy backend semantics (allowlist, transaction, learner-data exclusion) — `MER-5831` / `course_copy/`.
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
- My Course Sections cards show a darkened-overlay hover state with the label "SELECT TO COPY COURSE SECTION" — visual only; the card must not become selectable/clickable for copy purposes in this ticket.
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

- Consumes `MER-5841`'s authorization/query contract for "an active enrollable section on which the actor holds an instructor or content-developer role, or any active enrollable section for an admin" — no new eligibility query should be written.
- Does not call any `MER-5831` (Course Copy) interface; that dependency is soft and only relevant for keeping row/source-kind typing compatible with the follow-up ticket.
- Primary files: `lib/oli_web/live/new_course/select_source.ex`, `lib/oli_web/live/common/card_listing.ex`, `lib/oli_web/live/new_course/table_model.ex`, `lib/oli_web/live/new_course/new_course.ex`, `lib/oli_web/live/common/stepper/stepper.ex`.
- Design source: Figma file "Course replication feature" (`ZAfwBt1ek94xAyriR6wy8S`); full node list and the `ui_workflow` design brief are recorded in `informal.md` and `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md`.
- Handoff: `MER-5832` consumes the tab/query/card/tag surface built here and replaces the My Course Sections no-op action with the real copy-initiation modal.

## 10. Repository & Platform Considerations

- Implementation surface is Phoenix LiveView/HEEx, not React (`OliWeb.Common.CardListing`, `OliWeb.Delivery.NewCourse.{SelectSource,TableModel}`, `OliWeb.Common.Listing`).
- Reuse the repository's Figma-synced semantic token layer (`assets/tailwind.tokens.js`, via `tailwind.plugins.js`'s `tokenColorPlugin`) for all new colors (card surface/border, tag colors, tooltip surface/border/text) instead of hardcoding hex values; see the token-mapping table in the `ui_workflow` brief.
- Reuse the existing `GlobalTooltip` phx-hook for both filter-button tooltips instead of building a new tooltip mechanism.
- `OliWeb.Common.Stepper` is shared with `lib/oli_web/live/delivery/student_onboarding/wizard.ex`; any left-panel/footer styling change must be scoped to the `course_creation_stepper` id, following the existing `if @id == "course_creation_stepper"` conditional already present in that component.
- Code review should include `.review/ui.md` (UX/accessibility/visual behavior) and `.review/security.md`/`.review/performance.md` per repository default policy; `.review/elixir.md` applies given the LiveView changes.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item. This is an additive, low-risk UI change to an existing wizard step reusing an already-shipped authorization contract (`MER-5841`); it ships through the normal deployment pipeline like the rest of the epic's lanes.

## 12. Telemetry & Success Metrics

- Emit or extend an existing telemetry/AppSignal signal when the My Course Sections filter tab is selected, to give the `MER-5832` team visibility into interest/usage ahead of the real copy action shipping (aggregate counts only, no section titles or user-identifying content).
- Success signal for this ticket: no regression in existing Template-based section-creation completion rate, and the My Course Sections tab renders without error for eligible instructors/admins in production telemetry.

## 13. Risks & Mitigations

- Risk: `OliWeb.Common.Stepper` styling changes leak into the unrelated student-onboarding wizard. Mitigation: scope every left-panel/footer style change to the `course_creation_stepper` id and add a regression test asserting the onboarding wizard's rendered output is unchanged.
- Risk: the "My Section" hover overlay reads as a real, clickable "select to copy" action to instructors before `MER-5832` ships. Mitigation: keep the hover exactly as designed (it is not visually wrong), but explicitly verify via test that activating the card performs no navigation/creation; escalate the "should this say 'coming soon'" question to product rather than inventing new copy.
- Risk: introducing a second, divergent "who can see this section" check instead of reusing `MER-5841`'s contract, creating an authorization drift. Mitigation: the query implementation must call into `MER-5841`'s existing resolution rule; add a test proving a section denied by that contract never appears in the My Course Sections response.
- Risk: color/token drift between the Figma frame's local fallback values and the repository's synced `tailwind.tokens.js` (already found once, on the footer "Next Step" button fill). Mitigation: always resolve by token name, not by the frame's literal hex fallback, and flag any drift found back to design rather than picking a value unilaterally.

## 14. Open Questions & Assumptions

### Open Questions
- Whether the My Section hover treatment (dark overlay + "SELECT TO COPY COURSE SECTION") should extend to Free/Template cards, or stays exclusive to My Section cards — no other card type shows this hover state in the designs reviewed so far; needs designer confirmation.
- Exact card metadata and sort options beyond what is already in the current implementation.
- Whether the row/source-kind typing refactor suggested by `MER-5831`'s design comment is completed fully in this ticket or left partially prepared for `MER-5832`.
- Footer "Next Step" button fill color: Figma's local fallback is `#0073E5`; the repository's synced token `Fill-Buttons-fill-primary` is `#0080FF`. Use the token; flag the drift to design.
- Footer "Cancel" button border: the design shows a `Border-border-bold` (`#8AB8E5`) border that no existing `torus-button` variant matches exactly — needs a decision (extend `.secondary`, or add a variant).

### Assumptions
- The entire Blueprint Courses workstream is definitively out of scope epic-wide, per the `MER-5841` comment thread (Eli Knebel, Francisco Castro, decision by Darren, 2026-09-08).
- `MER-5841`'s authorization contract, already merged, is sufficient for the My Course Sections eligibility query needed here; no additional backend work beyond calling into it is required for this ticket.
- The hover-state ambiguity on non-My-Section card types is safe to leave unresolved for this PR — building only the confirmed My Section hover state — since inventing an unconfirmed additional state would violate the design-fidelity guardrails already established for this ticket.

## 15. QA Plan

- Automated validation:
  - `Phoenix.LiveViewTest` coverage for `select_source.ex`/`card_listing.ex`/`table_model.ex` covering filter tabs, sort preservation, tag rendering, My Course Sections eligibility scoping, and the no-op card action.
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
