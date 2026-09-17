# Course Builder Source Selection UI Updates - Functional Design Document

## 1. Executive Summary

Add a tri-state source filter (All Sources / Templates / My Course Sections) and a redesigned card surface to the section-creation wizard's step 1 ("Select source materials"), implemented entirely inside the existing `OliWeb.Delivery.NewCourse.SelectSource` LiveComponent and its collaborators (`CardListing`, `TableModel`). My Course Sections rows are fetched by reusing `MER-5841`'s already-merged authorization query and rendered as list-only, non-selectable cards; no new backend authorization logic, no Blueprint concept, and no changes outside step 1 of the wizard. This is a pure presentation/query-composition change over an existing, already-authorization-safe data source — no new domain model, migration, or transaction boundary is introduced.

## 2. Requirements & Assumptions

- Functional requirements: FR-001 through FR-008 in `requirements.yml` — filter tabs with sort preservation, server-scoped My Course Sections eligibility, card redesign with type tags, the new-feature banner, filter-button tooltips, a visual-only My Course Sections hover state, left-panel/footer restyle scoped to the course-creation wizard, and keyboard/announcement accessibility.
- Non-functional requirements: server-side authorization for My Course Sections (no client-side-only filtering), no regression to existing Template-based creation, no visual bleed into the shared `OliWeb.Common.Stepper` component's other consumer (`student_onboarding/wizard.ex`).
- Assumptions (carried from `prd.md`):
  - `MER-5841`'s authorization/query contract (merged to `master`) is sufficient for My Course Sections eligibility; this ticket calls into it and does not duplicate or extend the authorization rule itself.
  - The Blueprint Courses workstream is out of scope epic-wide; no relationship/synchronization concept exists anywhere in this design.
  - Building only the confirmed My Section hover state (not inventing a matching state for Free/Template cards) is the correct scope for this PR; extending it is an explicit open question, not something to guess at.

## 3. Repository Context Summary

- What we know:
  - `OliWeb.Delivery.NewCourse.SelectSource` (`lib/oli_web/live/new_course/select_source.ex`) is a `live_component` that owns `@params` (offset/limit/sort/query/selection), calls `retrieve_all_sources/3` once per mount, and re-derives `@table_model`/`@total_count` through `filter/3` → `sort/3` → `paginate/2` on every param change. It renders `OliWeb.Common.FilterBox` (search input + sort `<select>` + an `:extra_opts` slot, no tab/segmented-control concept today), then `OliWeb.Common.Listing` (pagination + `OliWeb.Common.CardListing` when `cards_view?`).
  - `OliWeb.Delivery.NewCourse.TableModel` (`table_model.ex`) already distinguishes "Template" (a product/blueprint, `type: :blueprint`) from "Project" via the structural check `Map.has_key?(item, :type)`; there is no third source shape yet.
  - `OliWeb.Common.CardListing` (`card_listing.ex`) renders one card per row with a cover image, title, description, and a payment badge only — no type tag exists today.
  - `OliWeb.Common.Stepper` (`lib/oli_web/live/common/stepper/stepper.ex`) renders the wizard's left panel (already `bg-blue-700`, i.e. `#1D4481` exactly) and the Cancel/Next Step footer, and is reused verbatim by `lib/oli_web/live/delivery/student_onboarding/wizard.ex`. It has one existing `@id`-scoped conditional (lines 50-55) that this design extends rather than replacing.
  - `MER-5841` (merged, PR #6854) already exposes a source-resolution rule for "an active enrollable section on which the actor holds an instructor/content-developer role, or any active enrollable section for an admin" and states explicitly that "the course-builder source list is built from the same rule as the gate" — i.e. this ticket is expected to call that rule, not re-derive eligibility.
  - The repository has a Figma-synced semantic color-token layer (`assets/tailwind.tokens.js` + `tailwind.plugins.js`) and a generic tooltip mechanism (`GlobalTooltip` phx-hook, `assets/src/hooks/global_tooltip.ts`) that already produce the exact visual treatment this design needs, with no new client-side JS.
  - There is a precedent tab-bar interaction pattern in the codebase (`OliWeb.ManualGrading.Tabs`: `phx-click`/`phx-value-tab` + an "active" class), though that module is feature-local and not parameterized for reuse.
- Unknowns to confirm:
  - The exact `Oli.Delivery`/`Oli.Publishing`/authorization module and function name `MER-5841` exposes for "sections the actor may create from" (its PR touches `lib/oli/delivery/sections/section_specification.ex`, `lib/oli/delivery.ex`, and `lib/oli_web/live/new_course/select_source.ex` itself) — must be confirmed by reading that merged code before implementation, not assumed here.
  - Whether `MER-5841`'s rule is exposed as a single call usable directly from `SelectSource.retrieve_all_sources/3`, or needs a small new query function in `Oli.Publishing`/`Oli.Delivery.Sections` that simply calls into it — this is an implementation detail, not a design fork, and does not change any interface in Section 5 below.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `SelectSource` (LiveComponent) gains one new piece of state, `@params.source_filter :: :all | :templates | :my_sections` (default `:all`), and one new query result, `@my_sections` (fetched alongside the existing `@sources` in `update/2`, not on every filter change). `retrieve_all_sources/3` is extended to also fetch My Course Sections rows via the `MER-5841` contract; `filter/3` gains a first pass that narrows `table_model.rows` to the active `source_filter` before the existing text-query pass runs (FR-001).
- A new, small, feature-local function component (e.g. `source_filter_tabs/1`, colocated in `select_source.ex`) renders the three tabs above `FilterBox.render`, following the existing `phx-click`/`phx-value-*` interaction pattern already used by `OliWeb.ManualGrading.Tabs`, but styled to the new design (not reusing that Bootstrap-styled module, since it is not parameterized and only has two feature-local tabs).
- `TableModel` gains a typed row-kind derivation (`{:project, ...} | {:publication, ...} | {:product, ...} | {:previous_section, ...}`, per `MER-5831`'s design comment) so both the type tag and, later, `MER-5832`'s selection action can dispatch on one consistent shape instead of the current structural `Map.has_key?(item, :type)` check (FR-003).
- `CardListing` renders the new type tag (via a new shared `design_tokens/primitives/badge.ex` component) and the My Course Sections hover overlay; it stays a pure rendering component and receives row-kind and hover-eligibility as already-computed data, not by re-deriving them.
- `Stepper` gains no new markup shape, only a conditional style branch keyed on the existing `@id == "course_creation_stepper"` check, matching its current pattern (FR-007).

### 4.2 State & Data Flow

1. `SelectSource.update/2` (mount path) fetches `@sources` (existing Template rows) and `@my_sections` (new: `MER-5841`'s eligible-sections query for the current actor) once, tags each row with its source kind, and merges them into one `@all_rows` list used for filtering/sorting/pagination — mirroring the existing single-fetch-then-filter-in-memory model already used for `@sources`.
2. A tab click sets `@params.source_filter` and re-derives `table_model` via the existing `get_table_model_and_count/3` pipeline, now filtering by `source_filter` first, then by the text query, exactly as `filter/3` already composes with the existing query filter.
3. Search, sort, and pagination are unchanged in mechanism; they now simply operate over whichever subset `source_filter` narrows `@all_rows` to (FR-001, AC-002, AC-003).
4. Card click (`phx-click="source_selection"`) is unchanged for Template rows; for My Course Sections rows the click handler recognizes the `{:previous_section, ...}` kind and returns `{:noreply, socket}` without side effects (FR-006, AC-013).

### 4.3 Lifecycle & Ownership

- `SelectSource` remains the sole owner of `@params`/`@sources`/`@my_sections`/`@table_model`; no new process, GenServer, or Oban job is introduced.
- The My Course Sections eligibility query executes once per LiveView mount (same lifecycle as the existing `retrieve_all_sources/3` call), not on every render or filter change — consistent with the existing performance posture of this LiveComponent.
- `MER-5841` continues to own the authorization rule itself; this design only calls it and must not fork a second copy of that logic into `SelectSource` or `TableModel`.

### 4.4 Alternatives Considered

- **Tab bar: reuse `OliWeb.ManualGrading.Tabs` vs. a new feature-local component vs. a new shared `design_tokens/` primitive.** Chosen: a new feature-local component. `ManualGrading.Tabs` is hardcoded to its own two labels and not parameterized; forcing reuse would mean rewriting it into a generic primitive for a single additional consumer, which is speculative generalization the "Simplicity First" philosophy rules out absent a second concrete reuse case. A `design_tokens/` extraction remains available later if a third tab-bar consumer appears.
- **My Course Sections eligibility: call `MER-5841`'s existing rule vs. write a new query.** Chosen: call the existing rule. Writing a second query risks exactly the authorization drift `MER-5841`'s own PR description calls out as a defect class it closed; there is no requirement here that the existing rule cannot satisfy.
- **Row typing: adopt the `{:project,...}|{:publication,...}|{:product,...}|{:previous_section,...}` shape now vs. defer it to `MER-5832`.** Chosen: adopt it now, as the PRD's open question already flags but does not force a decision on scope depth. Doing the typing work here (touching only `TableModel`, which already computes `is_product?/1`) is strictly additive and lets `MER-5832` add its action without re-touching this ticket's files, at negligible extra cost.
- **Card type tag: a new shared badge/pill primitive vs. inline markup in `CardListing`.** Chosen: a new shared primitive under `design_tokens/primitives/`, per the repository's own guardrails calling out badges/pills as a named good-reuse candidate, and because this ticket alone already needs two variants ("Template", "My Section") plus a no-tag case.

## 5. Interfaces

- `SelectSource.retrieve_all_sources/3` (existing, extended): now also returns My Course Sections rows tagged with their source kind, sourced from `MER-5841`'s authorization rule; signature and call sites unchanged.
- `SelectSource.filter/3` (existing, extended): gains a `source_filter`-based narrowing pass before the existing text-query pass; parameter shape (`params.applied_query`, now also `params.source_filter`) is additive, not breaking.
- New: `source_filter_tabs/1` function component in `select_source.ex`, `phx-click="filter_source"` / `phx-value-filter="all"|"templates"|"my_sections"` handled by a new `handle_event("filter_source", ...)` clause, following the existing `handle_event` style already in this module (`update_view_type`, `sort`, etc.).
- `TableModel.row_kind/1` (new, additive): returns `{:project, item} | {:publication, item} | {:product, item} | {:previous_section, item}`; `is_product?/1`, `render_type_column/3`, and the new tag renderer are re-expressed in terms of it rather than duplicating the structural check.
- New: `OliWeb.DesignTokens.Primitives.Badge` (`lib/oli_web/components/design_tokens/primitives/badge.ex`), `attr :variant, :atom, values: [:my_section, :free, nil], default: nil`; renders nothing when `variant` is `nil`.
- `CardListing.render/1` (existing, extended): receives the same `@model`/`@selected`/`@ctx` it does today; the new tag and hover overlay are derived from each row's kind inside the existing per-row rendering, not via new required attrs, so no external caller of `CardListing` needs to change.
- `Stepper.render/1` (existing, unchanged signature): the new footer/left-panel styling is expressed purely as additional conditional Tailwind classes gated on the existing `@id` attr; no new attrs are added, so `student_onboarding/wizard.ex`'s call site is untouched (FR-007, AC-015).

## 6. Data Model & Storage

N/A — no new Ecto schema, migration, or persisted field is introduced. My Course Sections rows are read through `MER-5841`'s existing query surface over the existing `sections` schema; this ticket adds no column, table, or index.

## 7. Consistency & Transactions

N/A — this is a read-only, presentation-layer change. No write path, transaction, or multi-step mutation is introduced; the existing single-fetch-then-filter-in-memory model for the source list is preserved.

## 8. Caching Strategy

N/A — no new cache is introduced. The My Course Sections query executes once per LiveView mount, matching the existing `retrieve_all_sources/3` fetch cadence; no additional caching layer is warranted at this scale (a single instructor's eligible-section list).

## 9. Performance & Scalability Posture

N/A — no new performance budget is required. The added query is bounded by "sections the current instructor teaches" (typically small), reuses `MER-5841`'s already-reviewed authorization query rather than adding a new one, and the existing in-memory filter/sort/paginate pipeline over `@sources` already handles a comparable or larger existing data volume (all visible projects/products for an institution).

## 10. Failure Modes & Resilience

- If the My Course Sections query fails or the actor has zero eligible sections, the tab must render an explicit, non-error empty state (reusing `Listing`'s existing `empty_state_text` attr), not a raised exception or a silently-empty "All Sources" tab.
- A card whose row kind cannot be determined (neither Template nor My Course Sections) must render with no tag (as designed) rather than raising in `TableModel.row_kind/1`; treat an unrecognized shape as a `{:project, item}` fallback consistent with today's default branch in `is_product?/1`/`render_type_column/3`.
- Activating a My Course Sections card must fail safe to a no-op (FR-006, AC-013), not to an error page or an unintended navigation, if the click handler is reached before `MER-5832` wires the real action.

## 11. Observability

- Extend or add a lightweight telemetry event when the My Course Sections tab is selected (aggregate counts only; no section titles, ids, or user-identifying payload), per the PRD's Telemetry & Success Metrics section, using the existing AppSignal/telemetry conventions described in `docs/OPERATIONS.md` rather than a new pipeline.
- No new structured logging is required beyond what LiveView/Phoenix already emits for this LiveComponent's existing event handlers.

## 12. Security & Privacy

- My Course Sections membership must be enforced by `MER-5841`'s server-side rule; the UI must not compute or filter eligibility client-side, and must not expose a section's existence in the payload to an actor `MER-5841` would deny (FR-002, AC-004, AC-005, AC-006).
- No learner-identifying or learner-generated data is displayed or fetched by this ticket — cards show only section title/description/date, sourced the same way existing Template cards already are.
- No new authorization boundary is introduced or bypassed; this design strictly composes with the boundary `MER-5841` already shipped.

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
  - Hovering a My Course Sections card shows the overlay/label (manual visual check, AC-012); activating that card performs no navigation/creation while the existing Template selection flow is unaffected (AC-013, automated).
  - Left-panel step copy matches the updated text for all three steps (AC-014).
  - A new regression test in `test/oli_web/live/delivery/student_onboarding/wizard_test.exs` (or equivalent) asserts the student-onboarding wizard's rendered footer/left-panel styling is unchanged after this change (AC-015, FR-007).
  - Keyboard-only operability (tab order, visible focus) for every new/changed control (AC-016), and an assistive-technology announcement on filter/search-driven result-list updates (AC-017).
- Manual/visual QA: run the `ui_workflow` `implement`→`qa` cycle against the Figma brief already captured in `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md` for card density, banner, tooltips, and the My Section hover state, in both light and dark mode.
- Regression: existing Template-based source selection, search, sort, and course-creation completion must keep passing unchanged (`select_source_test.exs`, `new_course_test.exs` if present).

## 14. Backwards Compatibility

N/A beyond the explicit regression requirement already covered above (Section 13, AC-015): every public function signature touched (`retrieve_all_sources/3`, `filter/3`, `CardListing.render/1`, `Stepper.render/1`) is extended additively, and no existing call site outside this work item needs to change.

## 15. Risks & Mitigations

- Risk: the My Course Sections query duplicates or drifts from `MER-5841`'s authorization rule instead of calling it. Mitigation: implementation must call into `MER-5841`'s exposed rule directly; AC-006 exists specifically to catch drift via test.
- Risk: `Stepper` styling changes leak into `student_onboarding/wizard.ex`. Mitigation: every new style is gated on the existing `@id == "course_creation_stepper"` conditional; AC-015 is a dedicated regression test for the other consumer.
- Risk: the My Section hover overlay is read as a real, working "select to copy" action before `MER-5832` ships. Mitigation: implement the hover exactly as designed (it is not visually incorrect) but verify via AC-013 that activation is a true no-op; treat any "not yet clickable" messaging as a `MER-5832`-time product decision, not something invented here.
- Risk: a Figma-token color drift (already found once, on the footer "Next Step" button fill: design fallback `#0073E5` vs. the repository's synced token `#0080FF`) is silently "fixed" by hardcoding a hex value instead of using the token. Mitigation: always resolve colors by token name from `assets/tailwind.tokens.js`; flag drift to design rather than picking a value.

## 16. Open Questions & Follow-ups

- Whether the My Section hover treatment extends to Free/Template cards, or stays exclusive to My Section cards (needs designer confirmation; not blocking this design, since only the confirmed state is being built).
- Footer "Cancel" button border treatment: no existing `torus-button` variant has both the right border color (`Border-border-bold`) and the existing no-border `.secondary` background; needs a decision between extending `.secondary` or adding a variant before implementation finalizes that one visual detail.
- Whether `MER-5841`'s eligibility rule is exposed as a single directly-callable function or needs a one-line wrapper in `Oli.Publishing`/`Oli.Delivery.Sections` — to be confirmed by reading the merged `MER-5841` code at implementation time; does not change any interface documented in Section 5.
- Follow-up for `MER-5832`: this design leaves the `{:previous_section, ...}` row kind and the no-op click handler ready to be replaced with the real selection/copy action; `MER-5832` should not need to change `TableModel`'s row-kind shape or `CardListing`'s rendering contract.

## 17. References

- PRD: `docs/exec-plans/current/epics/course_replication/course_builder_sources/prd.md`
- Requirements traceability: `docs/exec-plans/current/epics/course_replication/course_builder_sources/requirements.yml`
- Source context and design references: `docs/exec-plans/current/epics/course_replication/course_builder_sources/informal.md`
- `ui_workflow` design brief (Figma → token/component mapping): `~/.codex/memories/oli-torus-ng/ui-work/MER-5828/brief.md`
- `MER-5841` (merged, PR #6854): authorization/query contract this design calls into.
- `MER-5831` (open, PR #6855): source-kind typing direction (`{:project,...}|{:publication,...}|{:product,...}|{:previous_section,...}`) followed in Section 4.1/5.
- Key existing files: `lib/oli_web/live/new_course/select_source.ex`, `lib/oli_web/live/new_course/table_model.ex`, `lib/oli_web/live/common/card_listing.ex`, `lib/oli_web/live/common/filter_box.ex`, `lib/oli_web/live/common/stepper/stepper.ex`, `lib/oli_web/live/manual_grading/tabs.ex` (precedent pattern), `assets/tailwind.tokens.js`, `assets/src/hooks/global_tooltip.ts`.
