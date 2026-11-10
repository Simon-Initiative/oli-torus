# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `6 — Accessibility hardening, telemetry, and full regression` (final phase)

## Scope from plan.md
- Audit every control introduced or changed in Phases 2-5 for keyboard operability and visible focus.
- Add an assistive-technology announcement for filter/search-driven result-list updates.
- Add or extend a lightweight telemetry event for My Course Sections tab selection (aggregate counts only).
- Run the `ui_workflow` `implement`→`qa` cycle for visual/layout fidelity in light and dark mode.

## Execution context

This phase was implemented and committed autonomously (no user available to consult mid-implementation, per the user's explicit standing instruction to implement and commit all remaining phases until done or out of tokens). One consequence: task 4 (the `ui_workflow` browser-based visual QA cycle) requires a human-prepared Browser MCP session per that skill's own Browser Readiness Contract, which wasn't available. See "QA status" below.

## Keyboard/focus audit findings

- **Real bug found and fixed**: `lib/oli_web/live/common/card_listing.ex`'s selectable source card was a bare `<a phx-click={@selected} ...>` with **no `href` attribute**. Per HTML semantics, an `<a>` without `href` is not included in the browser's default tab order and has no implicit ARIA role — it was never actually reachable by keyboard, despite carrying an `aria-label`. This markup was introduced in Phase 3's card redesign (and, in an earlier unstyled form, predates this ticket). Fixed by converting it to `<button type="button">`, which is natively focusable and natively activates on both Enter and Space with no custom JS. Added `border-0 bg-transparent p-0 text-left` to strip the browser's default button chrome (Tailwind Preflight already zeroes most of it; these are a defensive, explicit belt-and-suspenders addition) so the visual appearance is unchanged. A side effect: `group-focus-visible:opacity-100` on the My Section hover overlay (added in Phase 3) was **dead code** until now — it could never trigger on a non-focusable element — and is now functional for the first time.
- Filter tabs (Phase 2), tooltip-triggering buttons (Phase 4), and the banner (Phase 4, non-interactive) were all re-audited and confirmed already keyboard-operable with visible focus (`focus-visible:outline` classes; `GlobalTooltip`'s `focus`/`blur`/`Escape` wiring, confirmed by reading `assets/src/hooks/global_tooltip.ts` directly in this phase's review).
- **Accepted, not fixed**: the filter tabs (`role="tablist"`/`role="tab"`) are keyboard-reachable via plain sequential Tab order, not the full WAI-ARIA APG "Tabs" pattern (single tab-stop + arrow-key roving `tabindex`). This satisfies WCAG 2.1 SC 2.1.1 (operable via keyboard) but not the "ideal" tab-widget interaction model. Implementing roving-tabindex would require new keyboard-event wiring with no existing precedent in this codebase's LiveView components — judged disproportionate for this ticket; logged in `fdd.md`'s Open Questions as a follow-up.

## Assistive-technology announcement (AC-017)

- Searched the codebase for the "existing live-region/announcement pattern already used elsewhere in `Listing`" the plan pointed to — no such pattern exists in `Listing` (`lib/oli_web/live/common/listing.ex`). The actual established idiom is `<p class="sr-only" role="status" aria-live="polite">{message}</p>`, found in `lib/oli_web/components/delivery/list_navigator.ex`. Used that idiom instead (the plan's specific file pointer was inaccurate; the underlying requirement and pattern-reuse intent were still correct).
- Added `result_count_announcement/1` to `select_source.ex`, rendered once, bound to `@total_count` and the active `source_filter`, producing e.g. "Showing 3 results for All Sources" / "Showing 1 result for Templates". Since it's always-rendered with `aria-live="polite"`, any text change (from filtering, searching, sorting, or paging) is announced automatically — no manual per-handler firing needed.
- Confirmed this is *not* a repeat of Phase 4's `role="status"`-on-static-content mistake: this region's content is genuinely dynamic (recomputed from `@total_count`/`@params[:source_filter]` on every relevant render), unlike Phase 4's banner, which stayed `role="status"`-free after that earlier fix.

## Telemetry (PRD Section 12)

- PRD Section 12 specifies **two** telemetry points, not just "tab selection" as plan.md's task literally said: (1) when the My Course Sections filter tab is selected, and (2) when a My Course Sections card is activated. Implemented both:
  - `[:oli, :course_builder, :my_course_sections_filter_selected]` — in `select_source.ex`'s `filter_source` handler, gated on `source_filter == :my_sections`.
  - `[:oli, :course_builder, :my_course_sections_card_activated]` — in `new_course.ex`'s `source_selection` handler, gated on the pre-existing `section_source?/1` predicate (`"section:" <> _id` match) — reused rather than duplicated.
- Both emit `%{count: 1}` measurements with **empty `%{}` metadata** — no section ids/titles, no user ids — per the PRD's explicit "aggregate counts only" constraint.
- Confirmed via `$harness-review` (elixir dimension) that synchronous `:telemetry.execute/3` inside a LiveView `handle_event` is the established, safe convention in this codebase (matches `learning_objectives.ex`, `intelligent_dashboard_tab.ex`, `lti_controller.ex`, etc.) — no `Task.start` wrapper needed.

## Implementation Blocks
- [x] Core behavior changes: `<a>` → `<button type="button">` in `card_listing.ex`; new `result_count_announcement/1` + helpers in `select_source.ex`; two new `:telemetry.execute/3` calls (`select_source.ex`, `new_course.ex`).
- [x] Data or interface changes — none to public component attrs; `Stepper`'s `variant` attr (Phase 5) and `TableModel`'s predicates (Phase 1) are unchanged.
- [x] Access-control or safety checks — n/a; telemetry gating conditions are pure pattern matches on already-validated/authorized data, not a new authorization surface (confirmed by `$harness-review`, security dimension).
- [x] Observability or operational updates — the two new telemetry events described above are this phase's primary observability deliverable.

## Test Blocks
- [x] Tests added/updated:
  - Four test files' CSS selectors updated from `a[phx-value-id=...]`/`.card-deck a:first-child` to the `button` equivalents (`select_source_test.exs`, `name_course_test.exs`, `course_details_test.exs`, `new_course_test.exs`), since the underlying tag changed.
  - `select_source_test.exs`, `describe "assistive-technology result-count announcement"`: filter-tab-driven announcement changes (AC-017), plus a search-driven announcement test added after `$harness-review` (UI dimension) flagged the first version's test as covering only the "filter" half of "filter/search-driven," not the "search" half.
  - `select_source_test.exs`, `describe "telemetry"`: `my_course_sections_filter_selected` fires only for the My Course Sections tab, not Templates.
  - `new_course_test.exs`, `describe "telemetry"`: `my_course_sections_card_activated` fires only for a My Course Sections (`"section:<id>"`) source, not a Template/product source.
  - All telemetry tests use `:telemetry.attach/4` with a unique handler id + `on_exit` detach, following the existing precedent at `test/oli_web/components/delivery/learning_objectives/learning_objectives_component_test.exs`.
- [x] Required verification commands run:
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/live/new_course/ test/oli_web/live/delivery/onboarding_wizard/ test/oli_web/live/delivery/student_onboarding/ test/oli_web/live/products/ test/oli_web/live/common/ test/oli_web/live/dev/ test/oli_web/components/design_tokens/` — 165 tests, 0 failures.
  - `mix test test/oli_web/live/products/image_preview_test.exs` (separate check for `CardListing`'s `preview_mode` consumer, unaffected by the `<a>`→`<button>` change since it uses the `<article>` branch) — 5 tests, 0 failures.
  - `mix format --check-formatted` — OK.
  - `mix credo --strict` on all changed files — no new issues (all reported items pre-exist this diff, verified by line number).
- [x] Results captured — see above; all green.

## Bugs found and fixed during implementation
- **The `<a>`-without-`href` keyboard bug** — see "Keyboard/focus audit findings" above; this was the phase's most significant finding.
- **My own test-writing error, caught before committing**: the first version of the search-driven announcement test assumed a raw `insert(:publication)` plus two `insert(:section, base_project: project)` calls (default `type: :blueprint`) would produce exactly 2 sources for "All Sources." A manual debug check showed the actual count is 3 — the bare publication itself also surfaces as its own Project source, independent of its child sections. Fixed by using the actual observed count (3, not an assumed 2) rather than a guessed value.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged:
  - `plan.md`'s Phase 6 task description pointed to "the existing live-region/announcement pattern already used elsewhere in `Listing`, per FDD Section 11" — neither claim held up: no such pattern exists in `Listing`, and the FDD's actual Section 11 is "Observability," not accessibility. The real pattern was found in `list_navigator.ex`. Corrected in `plan.md`.
  - `plan.md`'s telemetry task described only "My Course Sections tab selection," but PRD Section 12 (the task's own cited source) specifies a second event for card activation too. Both are implemented; `plan.md` updated to reflect this.
- [x] Open questions added to docs when needed — see `fdd.md` Section 16: the roving-tabindex tab-widget gap (accepted as-is) and the inline telemetry event-name literals (accepted as-is, both from this phase's `$harness-review`).

## Review Loop
- Round 1: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/ui.md`, via 4 parallel `reviewer` subagents, scoped to the uncommitted diff (`git diff`).
  - Security: no blocking findings. One informational note (telemetry counters are gated by client-supplied `phx-value-*` params, already-untrusted pre-existing input with no authorization role attached to the telemetry sink) — no remediation needed.
  - Performance: no findings. Static tag swap, two O(1)-gated telemetry calls, one always-rendered (not per-row) live region.
  - Elixir: 2 findings (1 medium, 1 low/optional); medium applied as a fix, low logged only.
  - UI/accessibility: 2 findings (1 medium, 1 low); medium applied as a fix, low logged only (the roving-tabindex item, see above).
- Round 1 fixes:
  1. (UI, Medium) The AC-017 test's title claimed to cover "filter/search-driven" updates but its body only exercised filter-tab clicks, leaving the "search" half of the requirement unprotected by a regression test (the underlying code path was already correct by inspection — both filter and search flow through the same `update_source_list/2` → `result_count_announcement` path). Fixed by adding a dedicated search-driven test.
  2. (Elixir, Medium) `source_filter_label/1` (used by the new announcement) and the three `label="..."` literals in `source_filter_tabs/1` (from Phase 2) were two independent sources of truth for the same three strings ("All Sources"/"Templates"/"My Course Sections"), risking drift if one were edited without the other. Fixed by having `source_filter_tabs/1` call `source_filter_label/1` for each tab's `label` attr, making it the single source of truth.
  3. (UI, Low, not fixed) Roving-tabindex/arrow-key tab-widget pattern — accepted as-is, see above.
  4. (Elixir, Low, not fixed) Inline telemetry event-name list literals instead of module attributes — accepted as-is; only two call sites exist and no in-repo `:telemetry.attach/4` consumer yet.
- All fixes re-verified: full regression suite green (165/165 + 5/5 for the `image_preview` cross-check), `mix credo --strict` shows no new issues, `mix format --check-formatted` OK.

## QA status: `needs-human-review`

Per plan.md's own Definition of Done ("`ui_workflow` visual/layout QA reports no material open finding, **or findings are explicitly logged as `needs-human-review`**"), this phase's task 4 (the `ui_workflow` `implement`→`qa` browser-based visual/layout fidelity cycle) was **not run**: it requires a human-prepared Browser MCP session per that skill's own Browser Readiness Contract, and no such session was available while this phase was executed autonomously. Everything achievable without a live browser was done instead:
- All color/token/spacing decisions across every phase were cross-checked against Figma directly (`get_design_context`/`get_variable_defs`) at implementation time, not just against the earlier `ui_workflow` brief summary.
- Full automated regression (165 + 5 tests) is green.
- A code-level accessibility audit (this phase's primary task) was completed and is documented above.

**What remains for a human reviewer**: an actual in-browser pass — at minimum, opening `/sections/new` in both light and dark mode and confirming visual fidelity against the Figma nodes referenced throughout `informal.md`'s "Design references" section, plus a manual keyboard tab-through of the whole step-1 flow (tabs → tooltips → cards → wizard footer) as a final sanity check beyond what LiveViewTest's `has_element?`/`render_click` assertions can prove.

## Done Definition
- [x] Phase tasks complete (task 4 explicitly logged `needs-human-review`, per the phase's own allowed outcome)
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists run, all medium+ findings resolved, low findings logged with justification
- [x] Validation passes (`validate_work_item.py --check all`)

## Epic status

All 6 phases of `plan.md` are now complete. Per `informal.md`'s "Follow-up: doc reconciliation" section, the next step is running `harness-update_docs` against this work item directory to reconcile `prd.md`/`fdd.md`/`plan.md` with the final as-built state, before this ticket's PR closes.
