# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `5 — Wizard left-panel copy and footer restyle (step 1 only)`

## Scope from plan.md
- Update the `steps` list titles/descriptions in `new_course.ex` to the new copy (node `44:842`).
- Add footer/left-panel styling changes in `stepper.ex`, gated on the existing `if @id == "course_creation_stepper"` conditional (node `44:838`); resolve the Cancel-button border decision (extend `.secondary` vs. add a variant) per FDD Open Questions before finalizing that detail.

## Design fidelity note

Re-fetched `get_design_context` on nodes `44:842` (left-panel copy) and `44:838` (footer) to confirm exact source text and colors before implementing, rather than relying solely on the earlier `ui_workflow` brief's summary:
- Step 1 and Step 2 titles/descriptions in `new_course.ex` already matched the Figma source exactly (no change needed — likely already correct from an earlier pass). Step 3's description differed by one clause ("Everyone needs to tell us..." vs. Figma's "Tell us..."); corrected to match Figma exactly, including its typographic right-single-quote apostrophe ("course's"), matching this file's existing style elsewhere.
- Footer node `44:838` confirmed: Cancel — `border-Border-border-bold` (#8AB8E5), `text-Specially-Tokens-Text-text-button-secondary` (#006CD9/#FFFFFF); Next Step — local Figma fallback `#0073E5` for `fill/buttons/fill-primary`, conflicting with the repo's synced token value `#0080FF` for the same variable name (already documented as a known drift in `informal.md`/the `ui_workflow` brief).

## Implementation Blocks
- [x] Core behavior changes:
  - `new_course.ex`: corrected the wizard step-3 description string.
  - `stepper.ex`: added `attr :variant, :atom, default: :default, values: [:default, :course_creation]` to `OliWeb.Common.Stepper`, replacing the pre-existing `@id == "course_creation_stepper"` string-comparison conditional (and the two new ones this phase would otherwise have added) with `@variant == :course_creation` — see Review Loop, this was a review-driven refactor, not part of the original plan. `new_course.ex`'s `<.live_component>` call now passes `variant={:course_creation}` explicitly; the student-onboarding wizard (`wizard.ex`) passes nothing and gets the `:default` variant, unchanged.
  - Cancel button (course_creation variant only): added `!border !border-Border-border-bold !text-Specially-Tokens-Text-text-button-secondary`.
  - Next Step button (course_creation variant, and only when not disabled — see Bugs found below): added `!bg-Fill-Buttons-fill-primary-bold` (revised from the originally-planned `!bg-Fill-Buttons-fill-primary` — see Review Loop fix #1).
- [x] Data or interface changes — `Stepper`'s public interface gained one new optional attr (`variant`), backward compatible (defaults to `:default`, so the only other caller, `wizard.ex`, needed no change).
- [x] Access-control or safety checks — n/a (presentation-only; no `phx-click`/`disabled` logic touched, only `class` attributes).
- [x] Observability or operational updates — none needed for this phase.

## Test Blocks
- [x] Tests added/updated:
  - `new_course_test.exs` (new file): AC-014 (all three step titles/descriptions match the agreed copy), and two tests proving the Cancel border and (enabled) Next Step fill overrides apply on the course-creation instance — the Next Step test first selects a source via `render_click` to get the button out of its `disabled` state before checking the fill override, since the override is deliberately suppressed while disabled.
  - `student_onboarding_wizard_test.exs`: AC-015 regression — asserts the onboarding wizard's `Stepper` instance (`#student-onboarding-wizard`) is not `#course_creation_stepper`, and that neither the Cancel border override nor the Next-Step-equivalent ("Go to course") fill override leak into it.
- [x] Required verification commands run:
  - `mix compile --warnings-as-errors` — clean.
  - `mix test test/oli_web/live/new_course/ test/oli_web/live/delivery/onboarding_wizard/ test/oli_web/live/delivery/student_onboarding/ test/oli_web/live/products/ test/oli_web/live/common/ test/oli_web/live/dev/ test/oli_web/components/design_tokens/` — 161 tests, 0 failures.
  - `mix format --check-formatted` — OK.
  - `mix credo --strict` on all changed files — no new issues (all reported items pre-exist this diff, verified by line number).
- [x] Results captured — see above; all green.

## Bugs found and fixed during implementation
- **Tailwind `!important` override would have defeated the disabled-state style.** `.torus-button.primary:disabled` sets a gray background via a non-`!important` rule; naively applying `!bg-Fill-Buttons-fill-primary-bold` unconditionally would have used Tailwind's `!` modifier to force the blue fill even while the Next Step button is disabled (at wizard step 1, before a source is selected), silently losing the disabled visual cue. Fixed by gating the override on `@variant == :course_creation and !@next_step_disabled`, confirmed correct by review (see Review Loop, elixir finding #3).

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no divergence from the FDD's approved design; the `variant` attr refactor and the fill-token swap (`-primary` → `-primary-bold`) are implementation details responding to review findings, not scope changes.
- [x] Open questions added to docs when needed — see Review Loop fix #2 below (Cancel border contrast flagged to design, not code-changed).

## Review Loop
- Round 1: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/ui.md`, via 4 parallel `reviewer` subagents, scoped to the uncommitted diff (`git status --short`, since one test file was new/untracked).
  - Security: no findings. All new class-list entries are static literals gated on a hardcoded/static assign comparison; no new event handlers, no new data flow.
  - Performance: no findings. Static conditional class lists, no new queries/loops; `Stepper` is instantiated once per page at two fixed call sites, not inside any collection render.
  - Elixir: 5 findings (1 moderate, 1 minor, 2 informational, 1 nit); moderate + minor applied as a fix, nit applied, both informational items logged only.
  - UI/accessibility: 4 findings (1 high, 1 medium, 2 low); high applied as a fix, one low applied as a fix, one medium and one low logged only (see below).
- Round 1 fixes:
  1. (UI, High) `!bg-Fill-Buttons-fill-primary` (#0080FF) under the button's existing white text computes to ~3.8:1 contrast, failing WCAG AA's 4.5:1 minimum for normal-size text (14px semibold is not "large text" under WCAG's 18.66px-bold threshold) — a regression versus the pre-existing `bg-delivery-primary` fill (~5.4:1), and worse than even the Figma-local-fallback value (`#0073E5`, ~4.6:1) that the plan had already decided *not* to use. Fixed by switching to `Fill-Buttons-fill-primary-bold` (#0062F2, same token family, already defined in `assets/tailwind.tokens.js`), which computes to ~5.2:1 and passes AA. Both new tests and the onboarding-wizard regression test updated to match.
  2. (Elixir, Moderate+Minor) Sibling-id string coupling (`@id == "course_creation_stepper"`) was about to be used a 3rd time in this shared component, with the literal duplicated across two files and no compile-time link between them — a renamed `id` would silently break all three overrides with no error. Fixed by adding an explicit `attr :variant, :atom, default: :default, values: [:default, :course_creation]` to `Stepper` and converting all three existing `@id ==` checks (including the pre-existing one at the old line 52, not just this phase's two new ones) to `@variant == :course_creation`; `new_course.ex` now passes `variant={:course_creation}` explicitly, `wizard.ex` needs no change (keeps the `:default` variant).
  3. (Elixir, Nit) A new test's name claimed "on step 1" but didn't actually navigate steps (the assertion is step-independent, since the Cancel button renders identically at every step). Renamed to "(present on every step)" to accurately describe what's tested.
  4. (UI, Low) Added a symmetric `refute has_element?` for the Next-Step-equivalent fill override in the onboarding-wizard regression test (previously only the Cancel border was asserted not to leak), since both overrides share the same `@variant` gate today but could diverge later.
- Round 1 findings logged, not code-changed:
  5. (UI, Medium, not fixed) `Border-border-bold` (#8AB8E5) against the Cancel button's white background computes to ~2.1:1, under WCAG 1.4.11's 3:1 non-text-contrast threshold in light mode (dark mode, ~5.3:1, is fine). Unlike the Phase 3 Template-badge contrast fix, this color is an explicitly Figma-confirmed value (node `44:838`), not an interim/unconfirmed choice — overriding it would mean substituting a different, non-Figma-specified color on my own judgment rather than the additive "add a border to an unconfirmed fill" fix used in Phase 3. Logged as an open question to flag to design (see `informal.md`'s existing Open decisions section, which already tracks this same token by name) rather than silently deviating from a confirmed design value. The button stays identifiable via fill/shape/label without the border, so this is not a functional blocker.
  6. (Elixir, Informational, not fixed) Reviewer suggested the Stepper footer buttons could eventually compose `lib/oli_web/components/design_tokens/primitives/button.ex`'s `interaction_classes/1`/`variant_classes/3` instead of raw `torus-button` classes with per-caller overrides. Logged as a reasonable follow-up refactor, out of scope for this step-1-only phase (would require touching the Previous-step button and both `Stepper` callers' full button markup, well beyond this ticket's declared boundary).
  7. (Elixir, Informational, not fixed, pre-existing) `assets/css/button.css:19-21` is missing a comma after `button.torus-button.secondary:disabled`, so `.secondary:disabled` never receives its intended disabled styling today — not introduced by this diff (the Next Step button affected by this phase uses `.primary`, unaffected by the bug) and out of this phase's scope; logged for a future, separately-scoped CSS fix.
  8. (UI, Low, not fixed) Reviewer flagged that "Previous step" (unchanged) and "Cancel" (restyled) now visually diverge within the same footer on steps 2-3. This is expected: Figma node `44:838` (the footer this phase implements) shows only Cancel + Next Step, consistent with this ticket's explicit "step 1 of 3 only" scope boundary (`informal.md`) — Previous step only renders on steps 2-3, which this ticket does not touch.
- All fixes re-verified: full regression suite green (161/161), `mix credo --strict` shows no new issues, `mix format --check-formatted` OK.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists run, all high/moderate findings resolved, remaining findings logged with justification
- [x] Validation passes (`validate_work_item.py --check all`)
