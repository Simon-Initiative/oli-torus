# Course Builder Source Selection UI Updates - Functional Design Document

## 1. Executive Summary

Add a tri-state source filter (All Sources / Templates / My Course Sections) and a redesigned card surface to the section-creation wizard's step 1 ("Select source materials"), implemented entirely inside the existing `OliWeb.Delivery.NewCourse.SelectSource` LiveComponent and its collaborators (`CardListing`, `TableModel`). `MER-5841` (authorization) and `MER-5831` (the copy-creation engine) are both already merged to `master`, and `MER-5831`'s merge already wired My Course Sections rows into `select_source.ex`'s source list, already normalized all three source kinds in `table_model.ex`, and already made every card — including My Course Sections rows — selectable, proceeding into a working (if unstyled) step-2 "Choose what to copy" flow. This design is therefore a presentation-only change: it adds the tab UI, the type-tag primitive, card density/hover treatment, the banner, tooltips, and the step-1 wizard chrome restyle, and does not add, remove, or gate any selection/authorization/copy behavior, all of which already exists and already works. No new domain model, migration, or transaction boundary is introduced, and no changes reach outside step 1 of the wizard.

## 2. Requirements & Assumptions

- Functional requirements: FR-001 through FR-008 in `requirements.yml` — filter tabs with sort preservation, confirming My Course Sections eligibility scoping is preserved through this ticket's refactor, card redesign with type tags, the new-feature banner, filter-button tooltips, the My Course Sections hover treatment (without disabling its already-working selection), left-panel/footer restyle scoped to the course-creation wizard, and keyboard/announcement accessibility.
- Non-functional requirements: server-side authorization for My Course Sections (no client-side-only filtering) must survive this ticket's refactor unchanged, no regression to existing Template-based or My-Course-Sections-based creation, no visual bleed into the shared `OliWeb.Common.Stepper` component's other consumer (`student_onboarding/wizard.ex`).
- Assumptions (carried from `prd.md`):
  - `MER-5841`'s authorization contract and `MER-5831`'s query/row-normalization work, both merged to `master`, are sufficient for this ticket's data needs; this ticket calls into existing functions and does not duplicate, extend, or fork them.
  - The Blueprint Courses workstream is out of scope epic-wide; no relationship/synchronization concept exists anywhere in this design.
  - Selecting a My Course Sections card is intentionally left functional (not gated) in this ticket — per the 2026-09-18 scope decision — so the resulting brief, unstyled step-2 experience ahead of `MER-5832` is accepted, not treated as a defect to fix here.
  - Building only the confirmed My Section hover state (not inventing a matching state for Template cards) is the correct scope for this PR; extending it is an explicit open question, not something to guess at.

## 3. Repository Context Summary

This section was rewritten on 2026-09-18 after `MER-5831` merged and this branch was rebased onto it; the original version (written before that merge) described a pre-`MER-5831` version of these files and is no longer accurate. Current state, confirmed by reading the merged code directly:

- What we know:
  - `OliWeb.Delivery.NewCourse.SelectSource` (`lib/oli_web/live/new_course/select_source.ex`) is a `live_component` that owns `@params` (offset/limit/sort/query/selection), calls `retrieve_all_sources/2` once per mount, and re-derives `@table_model`/`@total_count` through `filter/3` → `sort/3` → `paginate/2` on every param change. `retrieve_all_sources/2` already calls `Oli.Delivery.SectionCreation.authorize_actor(actor, section_spec)` and, on success, concatenates `SectionCreation.permitted_publications/2`, `SectionCreation.permitted_products/2`, and **`SectionCreation.permitted_sections/2`** (the My Course Sections query) into one sorted `sources` list. It renders `OliWeb.Common.FilterBox` (search input + sort `<select>` + an `:extra_opts` slot, no tab/segmented-control concept today), then `OliWeb.Common.Listing` (pagination + `OliWeb.Common.CardListing` when `cards_view?`).
  - `Oli.Delivery.SectionCreation` (`lib/oli/delivery/section_creation.ex`) is `MER-5841`'s authorization module, extended by `MER-5831`. `permitted_sections_query/2` is documented as "sections the actor may create a section from: active enrollable sections the actor teaches, or any of them for an administrator," scoped to the LTI institution when applicable — this is the exact My Course Sections eligibility rule, already wired, already correct. `permitted_sections/2` (default `institution: nil`) executes it.
  - `OliWeb.Delivery.NewCourse.TableModel` (`table_model.ex`) already normalizes all three source kinds — project/publication, product/template, and course/My-Section — behind `is_product?/1` (`type == :blueprint`), `is_course?/1` (`type == :enrollable`), `source_title/1`, `source_description/1`, and `source_identifier/1` (returning `"section:#{id}"` for a course row, matching `MER-5831`'s `section:<id>` source scheme). `render_type_column/3` already labels the three kinds "Template" / "Course" / "Project" as plain table text (not yet a visual tag).
  - `OliWeb.Common.CardListing` (`card_listing.ex`) renders one card per row with a cover image, title (`TableModel.source_title/1`), description (`TableModel.source_description/1`), and an **existing** cost badge (`TableModel.render_payment_column/3`, "Free" or a price, currently a plain Bootstrap `badge badge-success`, rendered unconditionally on every row regardless of kind); the `phx-click={@selected}`/`phx-value-id={TableModel.source_identifier/1}` selection action is **already unconditional for every row kind, including course/My-Section rows** — clicking one already dispatches `"section:<id>"` as the chosen source. No identification tag (Template/My Section) exists today; the cost badge is a separate, already-existing concept from that new identification tag (confirmed with design, see Section 16).
  - `lib/oli_web/live/new_course/new_course.ex` and `name_course.ex` (step 2) already handle a `"section:" <> id` source end to end: `section_source?/1`, `build_copy_options/2`, and a working (visually unstyled) `<fieldset :if={@copy_source?}>` "Choose what to copy" block with content/schedule/assessment-settings checkboxes, already shipped by `MER-5831`. This ticket does not touch these files.
  - `OliWeb.Common.Stepper` (`lib/oli_web/live/common/stepper/stepper.ex`) renders the wizard's left panel (already `bg-blue-700`, i.e. `#1D4481` exactly) and the Cancel/Next Step footer, and is reused verbatim by `lib/oli_web/live/delivery/student_onboarding/wizard.ex`. It has one existing `@id`-scoped conditional (lines 50-55) that this design extends rather than replacing.
  - The repository has a Figma-synced semantic color-token layer (`assets/tailwind.tokens.js` + `tailwind.plugins.js`) and a generic tooltip mechanism (`GlobalTooltip` phx-hook, `assets/src/hooks/global_tooltip.ts`) that already produce the exact visual treatment this design needs, with no new client-side JS.
  - There is a precedent tab-bar interaction pattern in the codebase (`OliWeb.ManualGrading.Tabs`: `phx-click`/`phx-value-tab` + an "active" class), though that module is feature-local and not parameterized for reuse.
- Unknowns to confirm: none remaining — the exact functions, signatures, and end-to-end selection behavior described above were confirmed by reading the merged `MER-5831` code directly on 2026-09-18, superseding this section's original, pre-merge assumptions.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `SelectSource` (LiveComponent) gains one new piece of state, `@params.source_filter :: :all | :templates | :my_sections` (default `:all`). No new query result is needed — `retrieve_all_sources/2` already fetches and merges Template and My Course Sections rows; `filter/3` gains a first pass that narrows `table_model.rows` to the active `source_filter` before the existing text-query pass runs (FR-001).
- A new, small, feature-local function component (e.g. `source_filter_tabs/1`, colocated in `select_source.ex`) renders the three tabs above `FilterBox.render`, following the existing `phx-click`/`phx-value-*` interaction pattern already used by `OliWeb.ManualGrading.Tabs`, but styled to the new design (not reusing that Bootstrap-styled module, since it is not parameterized and only has two feature-local tabs).
- `TableModel` gains a new tag-rendering helper that dispatches on its **existing** `is_product?/1`/`is_course?/1` predicates — "Template" for a product, "My Section" for a course, no tag otherwise (FR-003). No new row-kind abstraction is introduced; `MER-5831` already established this predicate-pair shape as the normalized interface, and inventing a second, parallel typed-tuple shape on top of it would be pure duplication.
- `CardListing` renders the new identification tag (via a new shared `design_tokens/primitives/badge.ex` component), restyles the **existing** cost badge (`TableModel.render_payment_column/3`) to a matching pill treatment without changing its Free/price computation, scopes that cost badge's display to `is_product?/1` rows only (it currently renders unconditionally), and adds the My Course Sections hover overlay. The identification tag and the cost badge are independent labels and can both render on the same card (confirmed with design — see Section 16). `CardListing` stays a pure rendering component and receives row data already shaped by `TableModel`'s existing helpers. Its selection markup (`phx-click={@selected}`, `phx-value-id={TableModel.source_identifier/1}`) is **unchanged** — it is correct as-is and already routes every row kind, including course/My-Section rows, into the existing `MER-5831` copy flow.
- `Stepper` gains no new markup shape, only a conditional style branch keyed on the existing `@id == "course_creation_stepper"` check, matching its current pattern (FR-007).

### 4.2 State & Data Flow

1. `SelectSource.update/2` (mount path) calls the existing `retrieve_all_sources/2`, which already authorizes the actor and already merges Template and My Course Sections rows into one sorted `sources` list — no change to this fetch.
2. A tab click sets `@params.source_filter` and re-derives `table_model` via the existing `get_table_model_and_count/3` pipeline, now filtering by `source_filter` first, then by the text query, exactly as `filter/3` already composes with the existing query filter.
3. Search, sort, and pagination are unchanged in mechanism; they now simply operate over whichever subset `source_filter` narrows `sources` to (FR-001, AC-002, AC-003).
4. Card click (`phx-click={@selected}`, dispatching `TableModel.source_identifier/1`) is **unchanged for every row kind**, Template and My Course Sections alike — it already proceeds into the existing `new_course.ex`/`name_course.ex` creation flow, including the unstyled step-2 "Choose what to copy" UI for a `section:<id>` source. This design does not add, remove, or intercept that click (FR-006, AC-013).

### 4.3 Lifecycle & Ownership

- `SelectSource` remains the sole owner of `@params`/`@sources`/`@table_model`; no new process, GenServer, or Oban job is introduced.
- The My Course Sections eligibility query already executes once per LiveView mount (same lifecycle as the rest of `retrieve_all_sources/2`), not on every render or filter change — this design does not change that cadence.
- `MER-5841`/`MER-5831` continue to own the authorization and copy-creation logic itself; this design only touches presentation code around their already-merged, already-called interfaces and must not fork a second copy of that logic into `SelectSource` or `TableModel`.

### 4.4 Alternatives Considered

- **Tab bar: reuse `OliWeb.ManualGrading.Tabs` vs. a new feature-local component vs. a new shared `design_tokens/` primitive.** Chosen: a new feature-local component. `ManualGrading.Tabs` is hardcoded to its own two labels and not parameterized; forcing reuse would mean rewriting it into a generic primitive for a single additional consumer, which is speculative generalization the "Simplicity First" philosophy rules out absent a second concrete reuse case. A `design_tokens/` extraction remains available later if a third tab-bar consumer appears.
- **My Course Sections eligibility: call the existing `SectionCreation.permitted_sections/2` vs. write a new query.** Chosen: keep calling the existing function, unchanged. Writing a second query risks exactly the authorization drift `MER-5841`'s own PR description calls out as a defect class it closed; there is no requirement here that the existing rule cannot satisfy, and it is already wired up.
- **Card selectability: disable/gate My Course Sections cards in this ticket vs. leave the already-working selection alone.** Originally planned as a "dummy"/no-op state before `MER-5831` merged; superseded once the merge revealed selection already works end to end (unstyled step 2). Chosen, per the 2026-09-18 product decision: leave it alone. Actively building gating code to disable an already-correct, already-tested flow would be net-negative engineering effort for a UX concern (an unstyled step 2) that resolves itself the moment `MER-5832` ships immediately after this ticket.
- **Row typing: adopt a new `{:project,...}|{:publication,...}|{:product,...}|{:previous_section,...}` tagged-tuple shape vs. reuse `MER-5831`'s existing `is_product?/1`/`is_course?/1` predicate pair.** Chosen: reuse the existing predicates. `MER-5831` already solved the "consistent row typing" problem this alternative was meant to address, in a simpler shape than the tagged tuple originally proposed in Darren Siegel's pre-merge design comment; introducing a second, parallel typing scheme now would be redundant, not additive.
- **Card type tag: a new shared badge/pill primitive vs. inline markup in `CardListing`.** Chosen: a new shared primitive under `design_tokens/primitives/`, per the repository's own guardrails calling out badges/pills as a named good-reuse candidate, and because this ticket alone already needs two variants ("Template", "My Section") plus a no-tag case.

## 5. Interfaces

- `SelectSource.retrieve_all_sources/2` (existing, **unchanged**): already returns Template and My Course Sections rows merged and sorted, via `SectionCreation.authorize_actor/2` + `.permitted_publications/2`/`.permitted_products/2`/`.permitted_sections/2`. This design does not modify this function.
- `SelectSource.filter/3` (existing, extended): gains a `source_filter`-based narrowing pass before the existing text-query pass; parameter shape (`params.applied_query`, now also `params.source_filter`) is additive, not breaking.
- New: `source_filter_tabs/1` function component in `select_source.ex`, `phx-click="filter_source"` / `phx-value-filter="all"|"templates"|"my_sections"` handled by a new `handle_event("filter_source", ...)` clause, following the existing `handle_event` style already in this module (`update_view_type`, `sort`, etc.).
- `TableModel.is_product?/1`, `.is_course?/1`, `.source_title/1`, `.source_description/1`, `.source_identifier/1` (existing, **unchanged**): reused directly by the new tag-rendering helper and by `CardListing`. No row-kind abstraction is added on top of them.
- New: `OliWeb.DesignTokens.Primitives.Badge` (`lib/oli_web/components/design_tokens/primitives/badge.ex`), `attr :variant, :atom, values: [:my_section, :template, nil], default: nil`; renders nothing when `variant` is `nil`. This is the new **identification** tag only (Template/My Section) — confirmed by design (2026-09-18, Jess via Slack) to be a distinct label from the existing cost badge, which is restyled separately (see next bullet) rather than folded into this component.
- `TableModel.render_payment_column/3` (existing, **unchanged computation**): its Free/price output is reused as-is; only its presentation changes — `CardListing` restyles it to a pill matching the Figma cost-badge reference (node `44:805`) and gates its rendering on `TableModel.is_product?/1`, so it no longer appears unconditionally on every card as it does today.
- `CardListing.render/1` (existing, extended): receives the same `@model`/`@selected`/`@ctx` it does today; the new identification tag, the restyled/scoped cost badge, and the hover overlay are derived from `TableModel`'s existing predicates inside the existing per-row rendering. The existing `phx-click={@selected}`/`phx-value-id={TableModel.source_identifier/1}` selection markup is **not modified** — it already correctly dispatches every row kind into the existing creation flow.
- `Stepper.render/1` (existing, unchanged signature): the new footer/left-panel styling is expressed purely as additional conditional Tailwind classes gated on the existing `@id` attr; no new attrs are added, so `student_onboarding/wizard.ex`'s call site is untouched (FR-007, AC-015).
- `new_course.ex` / `name_course.ex` (existing, **out of scope, not touched**): already handle `"section:" <> id` sources, `copy_source?/1`, and the step-2 `copy_options` fieldset. This design's only relationship to them is that `CardListing`'s unchanged click behavior continues to hand off into them correctly.

## 6. Data Model & Storage

N/A — no new Ecto schema, migration, or persisted field is introduced. My Course Sections rows are read through `MER-5841`'s existing query surface over the existing `sections` schema; this ticket adds no column, table, or index.

## 7. Consistency & Transactions

N/A — this is a read-only, presentation-layer change. No write path, transaction, or multi-step mutation is introduced; the existing single-fetch-then-filter-in-memory model for the source list is preserved.

## 8. Caching Strategy

N/A — no new cache is introduced. The My Course Sections query executes once per LiveView mount, matching the existing `retrieve_all_sources/3` fetch cadence; no additional caching layer is warranted at this scale (a single instructor's eligible-section list).

## 9. Performance & Scalability Posture

N/A — no new performance budget is required. The added query is bounded by "sections the current instructor teaches" (typically small), reuses `MER-5841`'s already-reviewed authorization query rather than adding a new one, and the existing in-memory filter/sort/paginate pipeline over `@sources` already handles a comparable or larger existing data volume (all visible projects/products for an institution).

## 10. Failure Modes & Resilience

- If the My Course Sections query fails or the actor has zero eligible sections, the tab must render an explicit, non-error empty state (reusing `Listing`'s existing `empty_state_text` attr), not a raised exception or a silently-empty "All Sources" tab. This is existing behavior (`retrieve_all_sources/2` already returns `[]` on an `authorize_actor/2` error) that this design must not regress.
- The new tag-rendering helper must render no tag for a row where neither `is_product?/1` nor `is_course?/1` returns `true` (as designed), rather than raising — matching the existing default branch already present in `render_type_column/3`.

## 11. Observability

- Extend or add a lightweight telemetry event when the My Course Sections tab is selected (aggregate counts only; no section titles, ids, or user-identifying payload), per the PRD's Telemetry & Success Metrics section, using the existing AppSignal/telemetry conventions described in `docs/OPERATIONS.md` rather than a new pipeline.
- No new structured logging is required beyond what LiveView/Phoenix already emits for this LiveComponent's existing event handlers.

## 12. Security & Privacy

- My Course Sections membership is already enforced by `SectionCreation.permitted_sections/2` (server-side); this ticket's refactor of `select_source.ex`/`table_model.ex` must preserve that boundary exactly — no client-side eligibility computation, and no section exposed in the payload to an actor the existing rule would deny (FR-002, AC-004, AC-005, AC-006).
- No learner-identifying or learner-generated data is displayed or fetched by this ticket — cards show only section title/description/date, sourced the same way existing Template cards already are.
- No new authorization boundary is introduced, bypassed, or reimplemented; this design strictly composes with the boundary `MER-5841`/`MER-5831` already shipped, and leaves the already-working selection/copy-creation flow's own security posture untouched.

## 13. Testing Strategy

- `Phoenix.LiveViewTest` coverage in `test/oli_web/live/new_course/select_source_test.exs` (extending existing coverage):
  - Filter tabs render with accessible names and `aria-selected` and preserve the active sort across tab changes (AC-001, AC-002).
  - Search/sort results returned under one tab never leak rows from another tab (AC-003).
  - My Course Sections returns only sections where the current instructor holds an eligible role, and any active enrollable section for an admin actor (AC-004, AC-005).
  - A section `MER-5841`'s rule would deny for the current actor is absent from the rendered My Course Sections rows, verified by asserting on the rendered payload rather than a client-side hide (AC-006).
  - Card tag rendering: Template → "Template" tag, My Course Sections → "My Section" tag, neither → no tag (AC-007).
  - Card grid density/metadata rendering without truncation regressions — automated LiveView assertions plus a manual pass (AC-008).
  - The new-feature banner renders between the filter/search bar and the pagination/result-count row with the agreed copy (AC-009).
  - Filter-button tooltips render the agreed copy and are reachable via keyboard focus, not only mouse hover (AC-010, AC-011).
  - Hovering a My Course Sections card shows the overlay/label (manual visual check, AC-012); activating that card still proceeds into the existing `MER-5831` copy-creation flow exactly as before this ticket, with no additional gating introduced, and the existing Template selection flow is unaffected (AC-013, automated).
  - Left-panel step copy matches the updated text for all three steps (AC-014).
  - A new regression test in `test/oli_web/live/delivery/student_onboarding/wizard_test.exs` (or equivalent) asserts the student-onboarding wizard's rendered footer/left-panel styling is unchanged after this change (AC-015, FR-007).
  - Keyboard-only operability (tab order, visible focus) for every new/changed control (AC-016), and an assistive-technology announcement on filter/search-driven result-list updates (AC-017).
- Manual/visual QA: run the `ui_workflow` `implement`→`qa` cycle against the Figma brief already captured in `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md` for card density, banner, tooltips, and the My Section hover state, in both light and dark mode.
- Regression: existing Template-based source selection, search, sort, and course-creation completion must keep passing unchanged (`select_source_test.exs`, `new_course_test.exs` if present).

## 14. Backwards Compatibility

N/A beyond the explicit regression requirement already covered above (Section 13, AC-015): the only public function signature actually touched is `filter/3` (extended additively with the `source_filter` pass); `retrieve_all_sources/2`, `CardListing.render/1`, and `Stepper.render/1` keep their existing signatures unchanged, and no existing call site outside this work item needs to change.

## 15. Risks & Mitigations

- Risk: this ticket's refactor of `select_source.ex`/`table_model.ex` (to add the tab/tag layer) accidentally forks or breaks the already-working My Course Sections eligibility call. Mitigation: touch only presentation logic around `retrieve_all_sources/2`/the existing predicates, do not rewrite them; AC-006 exists specifically to catch drift via test.
- Risk: `Stepper` styling changes leak into `student_onboarding/wizard.ex`. Mitigation: every new style is gated on the existing `@id == "course_creation_stepper"` conditional; AC-015 is a dedicated regression test for the other consumer.
- Risk: instructors reach the existing, unstyled step-2 "Choose what to copy" UI more often once step 1's My Course Sections tab is prominent and polished, producing a visually inconsistent hand-off (polished step 1 → rough step 2) until `MER-5832` ships. Mitigation: accepted per the 2026-09-18 product decision — Torus ships by release, not on merge, and `MER-5832` follows immediately; this design must not add gating to work around it.
- Risk: a Figma-token color drift (already found once, on the footer "Next Step" button fill: design fallback `#0073E5` vs. the repository's synced token `#0080FF`) is silently "fixed" by hardcoding a hex value instead of using the token. Mitigation: always resolve colors by token name from `assets/tailwind.tokens.js`; flag drift to design rather than picking a value.

## 16. Open Questions & Follow-ups

- **Resolved 2026-09-18 (Jess, design, via Slack):** the green "Free" pill on the Template reference card (node `44:805`) is the existing cost badge (`render_payment_column/3`), only restyled — not the new "Template" identification tag, which stays literal per the PRD/Jira AC. Both labels are independent and can render on the same card (e.g. a free Template shows both). This design's `Badge` component (`:template`/`:my_section`/`nil`) and the separate cost-badge restyle (Section 5) reflect this.
- Still open, inferred rather than explicitly confirmed: whether the restyled cost badge should be gated to `is_product?/1` rows only (as Section 4.1/5 currently specify), based on the Figma reference cards showing it present on the Template card and absent from the My Section and untagged cards — Jess did not explicitly confirm this scoping, only that the badge and tag are separate and can coexist. Proceeding with the `is_product?/1` gate as the reading most consistent with the mockups.
- No Figma reference exists for a paid Template's card; `render_payment_column/3`'s existing price-string branch is reused as-is rather than inventing new behavior for that case.
- Whether the My Section hover treatment extends to Template cards, or stays exclusive to My Section cards (needs designer confirmation; not blocking this design, since only the confirmed state is being built).
- **Resolved 2026-09-18, Phase 5 implementation:** Footer "Cancel" button border treatment — resolved as neither: instead of extending the shared `.secondary` class or adding a new `torus-button` CSS variant (both app-wide, well beyond this wizard's blast radius), `OliWeb.Common.Stepper` gained an explicit `variant={:course_creation}` attr that adds the border/text-color classes only to that instance's Cancel button. `$harness-review` (UI dimension) found the specified border color (`Border-border-bold`, `#8AB8E5`) measures ~2.1:1 against the button's white background, under WCAG 1.4.11's 3:1 non-text-contrast threshold in light mode — logged as a design flag, not code-changed, since the color is Figma's own explicit, confirmed value.
- **New, from Phase 5 `$harness-review` (elixir dimension):** the Stepper footer's Cancel/Previous/Next buttons are raw `torus-button`-classed markup rather than composing `lib/oli_web/components/design_tokens/primitives/button.ex`'s shared interaction/variant-class helpers. Flagged as a reasonable future refactor, explicitly out of scope for this step-1-only phase (would touch the Previous-step button and both `Stepper` callers' markup).
- Follow-up for `MER-5832`: this design leaves `TableModel`'s existing `is_product?/1`/`is_course?/1`/`source_identifier/1` interface and `CardListing`'s rendering contract untouched and already functionally complete; `MER-5832` only needs to redesign the step-2 "Choose what to copy" presentation, not enable or restructure anything this ticket built.
- **New, from Phase 6 `$harness-review` (ui dimension), accepted as-is:** the source filter tabs (`role="tablist"`/`role="tab"`/`aria-selected`/`aria-controls`, added in Phase 2) sit in plain sequential Tab order rather than following the full WAI-ARIA APG "Tabs" pattern (single tab-stop with arrow-key roving `tabindex`). This is keyboard-operable (Tab + Enter/Space reaches and activates every tab) and satisfies WCAG 2.1 SC 2.1.1, just not the "ideal" tab-widget interaction model. Implementing roving-tabindex + arrow-key navigation would require new keyboard-event wiring with no existing precedent elsewhere in this codebase's LiveView components — judged disproportionate polish for this ticket's scope. Logged as a follow-up rather than implemented.
- **New, from Phase 6 `$harness-review` (elixir dimension), accepted as-is:** the two new telemetry events (`[:oli, :course_builder, :my_course_sections_filter_selected]`/`[:oli, :course_builder, :my_course_sections_card_activated]`) inline their event-name lists rather than using module attributes, unlike some other telemetry emitters in the codebase. Not promoted to attributes since there are only two call sites and no `:telemetry.attach/4` consumer in this repo yet; worth revisiting if more emission points are added.

## 17. References

- PRD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/prd.md`
- Requirements traceability: `docs/exec-plans/current/epics/course_replication/course_builder_sources/requirements.yml`
- Source context and design references: `docs/exec-plans/current/epics/course_replication/course_builder_sources/informal.md`
- `ui_workflow` design brief (Figma → token/component mapping): `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md`
- `MER-5841` (merged 2026-09-17, PR #6854): authorization contract (`SectionCreation.authorize_actor/2`) this design calls into.
- `MER-5831` (merged 2026-09-18, PR #6855, merge commit `7908b1002e`): already-shipped My Course Sections query, row normalization (`is_product?/1`/`is_course?/1`/`source_title/1`/`source_description/1`/`source_identifier/1`), and the unstyled step-2 copy-options flow this design builds its presentation layer on top of, unchanged.
- Key existing files: `lib/oli_web/live/new_course/select_source.ex`, `lib/oli_web/live/new_course/table_model.ex`, `lib/oli_web/live/common/card_listing.ex`, `lib/oli_web/live/common/filter_box.ex`, `lib/oli_web/live/common/stepper/stepper.ex`, `lib/oli_web/live/manual_grading/tabs.ex` (precedent pattern), `assets/tailwind.tokens.js`, `assets/src/hooks/global_tooltip.ts`.
