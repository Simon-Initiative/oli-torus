# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `3 — Card redesign, type tags, and the My Section hover state`

## Scope from plan.md
- Add `lib/oli_web/components/design_tokens/primitives/badge.ex` — the new identification tag (`:my_section`/`:template`/`nil`), separate from the existing cost badge.
- Restyle the existing cost badge (`TableModel.render_payment_column/3`, unchanged logic) to a pill and scope it to `is_product?/1` rows only.
- Update `CardListing` to render both labels together, increase density per the Figma reference (nodes `44:789`, `44:805`, `44:824`), and add the My Section hover overlay (node `44:1459`).
- Leave `CardListing`'s existing `phx-click={@selected}`/`phx-value-id` selection markup untouched.

## Design fidelity note

Before implementing, pulled `get_design_context` for the remaining reference card (node `44:824`, the untagged card) to confirm it has neither an identification tag nor a cost badge — this, together with `44:789` (My Section, no cost badge) and `44:805` (Template, cost badge only), grounds the "cost badge scoped to Template rows only" decision already logged in `informal.md`/`prd.md`/`fdd.md`/`plan.md`.

## Implementation Blocks
- [x] Core behavior changes:
  - New `OliWeb.Components.DesignTokens.Primitives.Badge` (`badge.ex`) — identification-tag-only primitive, with `catalog/0`/`preview/1` per the repo's `design_tokens/primitives` convention (matching `button.ex`'s shape).
  - `CardListing` (`card_listing.ex`) redesigned: fixed-but-responsive card sizing (`w-full max-w-[310px] h-[296px]`), token-driven surface/border/shadow, cover-image gradient overlay, identification tag + restyled/scoped cost badge rendered together, 2-line-clamped title/description, and the My Section hover overlay (`group-hover`/`group-focus-visible`, `pointer-events-none`).
  - `assets/styles/common/card-link.scss` — added a `.card-title-clamp` rule alongside the existing `.card-text` 2-line clamp (this repo's Tailwind version predates core `line-clamp-*` utilities, so title truncation reuses the same SCSS pattern already established for the description).
  - Card click behavior (`phx-click={@selected}`, `phx-value-id`) is byte-for-byte unchanged.
- [x] Data or interface changes — none to `TableModel`, `SelectSource`, or the selection flow; `CardListing`'s public `render/1` attrs are unchanged.
- [x] Access-control or safety checks — n/a (presentation-only).
- [x] Observability or operational updates — none needed for this phase.

## Test Blocks
- [x] Tests added:
  - `select_source_test.exs`, `describe "card identification tag and cost badge"` (AC-007, AC-008): Template card shows "Template" tag + "Free" cost badge; My Course Sections card shows "My Section" tag and no cost badge; an untagged (plain publication) source shows neither.
  - `select_source_test.exs`, `describe "My Course Sections card hover state"` (AC-012): the hover-overlay markup ("Select to Copy Course Section") is present for a My Course Sections card and absent for a Template card.
  - AC-013 (activation still proceeds into the existing flow, unchanged) is re-validated by the pre-existing tests this phase left untouched (`"offers existing enrollable courses as copy sources"`, `"successfully goes to the next step"`), not duplicated.
  - New `design_tokens_live_test.exs` — regression coverage for the `badge.ex` primitive's dev-catalog integration (see Bugs found below): confirms Badge is autodiscovered, its variants render, its copy-paste snippet correctly reads `<Badge.badge ...>` (not `<Button.button ...>`), and it does not show a meaningless "Disabled" section.
- [x] Required verification commands run:
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/live/new_course/ test/oli_web/live/products/ test/oli_web/live/delivery/student_onboarding/ test/oli_web/live/common/ test/oli_web/live/dev/ test/oli_web/components/design_tokens/` — 135 tests, 0 failures.
  - `mix format --check-formatted` — OK.
  - `mix credo --strict` on all changed files — no new issues (all reported items pre-exist this diff, verified by line number).
- [x] Results captured — see above; all green.

## Bugs found and fixed during implementation
- **`.card-deck` selector removal broke 15 tests in unrelated files.** Dropping the old Bootstrap `.card-deck` wrapper div broke `name_course_test.exs` and `course_details_test.exs` (both use `.card-deck a:first-child` as a generic "pick any card to advance the wizard" helper), plus several `select_source_test.exs` assertions. Fixed by keeping `card-deck` as an additional class name on the new flex-wrap container — it carries no CSS rules of its own, so this is a zero-risk compatibility shim, not a design compromise.
- **`aria-selected={@active}` boolean-HTML-attribute quirk (Phase 2, referenced here since the same class of bug was checked for in this phase's new `aria-label` work) does not recur** — this phase's new `aria-label={card_aria_label(item)}` binds a string, not a boolean, so no analogous issue.
- **Tautological test fixture title.** The Elixir review caught that inserting a Template-type test row titled `"Chem Template"` made `assert card_html =~ "Template"` trivially true regardless of whether the identification tag actually rendered (the title itself contains "Template"). Fixed by renaming the fixture to `"Chem 101"` in both new test blocks.
- **New `Badge` primitive didn't actually integrate correctly with the `/dev/design_tokens` catalog**, despite matching the `catalog/0`/`preview/1` autodiscovery contract structurally. The catalog page's rendering was hard-coded to `Button`: it showed a meaningless "Disabled" preview column for Badge (which has no disabled concept) and generated an actively incorrect copy-paste snippet (`<Button.button variant={:my_section}>` instead of `<Badge.badge variant={:my_section} />`). Also, the containing tab was literally labeled "Buttons" even though the catalog claims to autodiscover *any* primitive. Fixed in `design_tokens_live.ex`: added a `primitive_code/2` dispatcher (Button keeps its bespoke slot-aware formatter via `button_code/1`; everything else gets a correct generic attribute-dump snippet), gated the "Disabled" section behind a new `primitive_supports_disabled?/1` (currently true only for Button), and relabeled the tab "Primitives". Added `design_tokens_live_test.exs` to regression-test this, since none existed before. This fix lives outside this phase's originally-scoped files, but is a direct, minimal-blast-radius consequence of adding `badge.ex` the way `docs/design_tokens.md`'s "wire new primitives into `/dev/design_tokens`" convention requires — not scope creep into unrelated functionality.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no divergence from the FDD's approved design; the `card-deck` compatibility shim and the `design_tokens_live.ex` generalization are implementation details, not design changes.
- [x] Open questions added to docs when needed — none new. The pre-existing open questions (Template tag color unconfirmed, hover-treatment extension to other card types, footer button color/border) are unaffected by this phase; the Template tag's contrast gap flagged by `$harness-review` was fixed in code (added a `Border-border-high` border) rather than left as a further open question, since it was a concrete, fixable WCAG 1.4.11 non-text-contrast defect in my own interim color choice, not a new design ambiguity.

## Review Loop
- Round 1: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/ui.md` (new accessible UI introduced), via 4 parallel `reviewer` subagents.
  - Security: no findings. Confirmed the click/selection handler is byte-for-byte unchanged; new `Badge.variant` is a closed, whitelisted atom set; no new injection surface.
  - Performance: no findings. All new/changed predicate calls (`tag_variant/1`, `is_product?/1`) are pure, pattern-matching, zero-I/O, called once per already-fetched row exactly as the pre-existing cost-badge call was.
  - Elixir: 4 findings, all applied as fixes (see Bugs found above and Round 1 fixes below).
  - UI/accessibility: 3 findings, all applied as fixes (see Round 1 fixes below).
- Round 1 fixes:
  1. (UI, High) The whole-card `<a>`'s accessible name silently included the always-present (opacity-only-hidden) hover-overlay text on My Section cards, with no equivalent description on other card types. Fixed by adding an explicit `card_aria_label/1` (`"Select {title}"`, or `"Select {title} to copy this course section"` for My Section rows) as the link's `aria-label`, which takes precedence over name-from-content and gives every card type a consistent, accurate accessible name.
  2. (UI, Medium) The interim "Template" tag fill (`Fill-Chip-Gray`) measured ~1.5:1 contrast against the card surface, under the WCAG 1.4.11 non-text 3:1 guideline. Fixed by adding a `Border-border-high` border to that variant so the pill's boundary is reliably perceivable regardless of the still-unconfirmed fill color; documented in `badge.ex`'s moduledoc that the border color is likewise not design-confirmed.
  3. (UI, Low) Fixed `w-[310px]` card width had no narrow-viewport allowance. Changed to `w-full max-w-[310px]` so cards can shrink below the Figma-specified width in constrained containers instead of forcing overflow.
  4. (Elixir) Tautological test title — see Bugs found above.
  5. (Elixir) `badge.ex` dev-catalog integration gap — see Bugs found above.
  6. (Elixir, minor) Loosened `catalog/0` typespec — added the same `catalog_entry`/`catalog_section`/`catalog_example` types `button.ex` already establishes as the sibling-primitive convention.
  7. (Elixir, not fixed, logged only) Pre-existing `TableModel.is_product?/1` naming convention violation (predicate starting with `is_`) — flagged as "not introduced by this PR" by the reviewer; left unchanged, since renaming a widely-used pre-existing public function is out of this phase's scope and would be its own follow-up.
- All fixes re-verified: full regression suite green (135/135), `mix credo --strict` shows no new issues, `mix format --check-formatted` OK.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists run, all actionable findings resolved
- [x] Validation passes (`validate_work_item.py --check all`)
