# Math Expression Syntax Help - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/help/prd.md`
- FDD: `docs/exec-plans/current/epics/math/help/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/help/requirements.yml`

## Scope
Deliver parser-backed syntax validation, compact help, static syntax documentation, and parser-derived MathJax previews for algebraic Math Expression inputs in Single Response and Multi-Input authoring and delivery.

Guardrails:
- No parser grammar, evaluator, scoring, feedback-selection, activity JSON, attempt-state, publication, or database changes beyond the preview formatter and static help route.
- No raw ASCII input should be rendered directly by MathJax.
- No raw learner submissions, expected answers, sampled assignments, parser internals, or generated LaTeX should be logged or emitted in production telemetry.
- Number-only, text, paragraph, dropdown, and legacy exact-LaTeX inputs stay on existing controls.
- Source code comments are important in this work: add concise comments at non-obvious boundaries, especially where raw ASCII rendering is rejected, where lightweight Gleam browser imports avoid Node crypto, where inline Multi-Input disables preview for layout reasons, and where raw expression privacy is protected. Do not add comments that merely restate obvious assignments or component props.

## Clarifications & Default Assumptions
- Use `/help/math-syntax` as the route unless product redirects the implementation before coding starts.
- Treat inline Multi-Input help as compact and layout-aware; use focus-visible or nearby compact presentation when always-visible placement would break the blank layout.
- Implement enough AST-to-LaTeX formatting for the documented algebraic examples in this work item. For quantity/unit preview, either complete parser-derived formatting or explicitly suppress preview until it is supported.
- Keep existing `MathExpressionTextInput` as a compatibility wrapper if that reduces implementation risk.
- No new production telemetry is planned; existing request/app telemetry remains sufficient.
- The likely review set is security, performance, requirements, UI, TypeScript, Gleam when formatter APIs change, and Elixir when the static route is added.

## Phase 1: Shared Math Preview Boundary
- Goal: Add the parser-derived formatting capability that makes previews safe and consistent with Torus math semantics.
- Tasks:
  - [ ] Add a deterministic Gleam AST-to-LaTeX formatter behind the shared math boundary for supported expression syntax: arithmetic, implicit multiplication, parentheses, powers, division/fractions, functions, constants, absolute value, factorial, scientific notation, and variables.
  - [ ] Decide and implement the quantity/unit preview behavior: either add quantity/unit LaTeX formatting or return an explicit unsupported-preview result for quantity inputs.
  - [ ] Expose the formatter through the smallest practical public API, preserving `torus_math` as the public boundary and avoiding browser imports that pull Node-only crypto.
  - [ ] Extend `assets/src/gleam/torusExpression.ts` with a validation-and-preview adapter returning `empty`, `valid`, `invalid`, or `unknown`, with `latex` only on valid parser-derived results.
  - [ ] Add focused source comments in the adapter and formatter explaining why preview output must come from parser output and why raw user ASCII is not sent directly to MathJax.
- Testing Tasks:
  - [ ] Add Gleam tests for formatter output for representative valid expressions and quantity/unit behavior selected above.
  - [ ] Add TypeScript adapter tests for valid, invalid, empty, and unsupported-preview results.
  - [ ] Confirm parser/evaluator/scoring behavior remains unchanged by running existing math-focused tests.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`; `cd assets && yarn test <targeted torusExpression tests>`
- Definition of Done:
  - Parser-derived LaTeX exists for supported preview cases.
  - Invalid, empty, and unsupported cases suppress preview without rendering raw ASCII.
  - Coverage supports `AC-005`, `AC-006`, `AC-007`, `AC-022`, `AC-023`, `AC-031`, and `AC-032`.
- Gate:
  - Shared Gleam and adapter tests pass on both supported Gleam targets and in the frontend test runner.
- Dependencies:
  - Existing Gleam parser and unit quantity parser.
- Parallelizable Work:
  - Static documentation drafting in Phase 4 can begin using the PRD examples while this phase is in progress.

## Phase 2: Reusable Math Expression Input Component
- Goal: Create the shared React component behavior for validation, help, accessibility, and optional preview.
- Tasks:
  - [ ] Create `assets/src/components/activities/common/math_expression/MathExpressionInput.tsx` with layout modes `authoring`, `delivery_single`, and `inline_multi_input`.
  - [ ] Implement validation state handling with debounce during editing and immediate validation on blur or save/submit-facing events.
  - [ ] Implement neutral empty state, valid state, invalid state, and controlled unknown/failure state.
  - [ ] Implement `MathExpressionHelpPopover` with compact examples, accessible label, hover/focus/click/Enter/Space activation, Escape/outside/focus-leave close behavior, and a new-tab `Learn more` link.
  - [ ] Implement optional `MathExpressionPreview` using `MathJaxLatexFormula` only when parser-derived LaTeX is available and `previewMode="below_input"`.
  - [ ] Keep inline mode stable: no preview allocation, no layout-shifting validation block, compact help placement.
  - [ ] Add source comments for non-obvious interaction boundaries, especially debounced validation versus immediate blur validation, popover focus behavior, and the no-preview inline mode.
- Testing Tasks:
  - [ ] Add component tests for valid examples, invalid examples, empty neutral state, accessible invalid state, debounce/immediate validation, and failure fallback.
  - [ ] Add component tests for help icon rendering, accessible label, hover/focus/click/keyboard activation, close behavior, and `Learn more` link target.
  - [ ] Add component tests for preview shown, preview hidden, stale preview suppressed, and inline mode no-preview behavior.
  - Command(s): `cd assets && yarn test <targeted MathExpressionInput tests>`; `cd assets && yarn lint`
- Definition of Done:
  - Shared component covers validation, help, preview, accessibility, and inline constraints without activity-specific state coupling.
  - Coverage supports `AC-005`, `AC-006`, `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-011`, `AC-012`, `AC-013`, `AC-014`, `AC-019`, `AC-020`, `AC-021`, `AC-022`, `AC-023`, `AC-029`, `AC-033`, and `AC-034`.
- Gate:
  - Component tests prove all layout modes and interaction paths before activity integrations begin.
- Dependencies:
  - Phase 1 adapter contract.
- Parallelizable Work:
  - Static Phoenix route implementation can proceed in parallel after the `Learn more` target is confirmed.

## Phase 3: Activity Authoring Integration
- Goal: Use the shared component for author-facing algebraic Math Expression answer editors.
- Tasks:
  - [ ] Replace or wrap relevant `InputEntry` math-expression text controls with `MathExpressionInput` using `layout="authoring"` and `previewMode="below_input"`.
  - [ ] Ensure Single Response correct-answer and targeted-feedback editors get validation, help, and preview.
  - [ ] Ensure Multi-Input `AnswerKeyTab` inherits the same behavior for correct answers and targeted feedback through `InputEntry`.
  - [ ] Confirm any candidate/test expression fields currently present in authoring are routed through the shared component or explicitly logged as follow-up if not present.
  - [ ] Keep required author-field blocking behavior aligned with existing save/publish validation paths and do not change learner grading semantics.
  - [ ] Add source comments only where integration decisions are non-obvious, such as why authoring preview is transient and not serialized into match config or activity content.
- Testing Tasks:
  - [ ] Add or update Single Response authoring tests for correct answer and targeted feedback editors.
  - [ ] Add or update Multi-Input authoring tests for selected blank answer-key and targeted feedback editors.
  - [ ] Verify excluded input types continue using their existing controls.
  - Command(s): `cd assets && yarn test <targeted short_answer authoring tests>`; `cd assets && yarn test <targeted multi_input authoring tests>`
- Definition of Done:
  - Authoring behavior is shared and visible in the expected response editor paths.
  - No new persisted validation or preview data is introduced.
  - Coverage supports `AC-001`, `AC-002`, `AC-004`, `AC-024`, `AC-025`, `AC-026`, `AC-027`, `AC-031`, `AC-032`, and `AC-033`.
- Gate:
  - Authoring tests pass and inspection confirms activity JSON shape is unchanged.
- Dependencies:
  - Phase 2 shared component.
- Parallelizable Work:
  - Student delivery integration can proceed after the shared component gate if different files are owned by a separate implementer.

## Phase 4: Student Delivery Integration
- Goal: Use the shared component in student Single Response and Multi-Input delivery without disrupting submission or layout behavior.
- Tasks:
  - [ ] Update `ShortAnswerDelivery.tsx` to render `MathExpressionInput` for text-validating `math_expression` inputs with `layout="delivery_single"` and `previewMode="below_input"`.
  - [ ] Update `assets/src/data/content/writers/html.tsx` to render `MathExpressionInput` for inline `input_ref` algebraic Math Expression blanks with `layout="inline_multi_input"` and `previewMode="none"`.
  - [ ] Preserve existing delivery `onChange`, deferred save, blur flush, per-part submit, reset, and disabled behavior.
  - [ ] Keep student-facing invalid messages plain and avoid parser offsets or implementation terms.
  - [ ] Add source comments at the writer integration point explaining why inline Multi-Input disables preview and avoids layout shifts.
- Testing Tasks:
  - [ ] Add or update Short Answer delivery tests for validation, help, preview, and continued typing of incomplete expressions.
  - [ ] Add or update Multi-Input delivery tests proving validation and help are present while rendered previews are absent.
  - [ ] Add regression assertions for submit/save/reset behavior where practical.
  - Command(s): `cd assets && yarn test <targeted short_answer delivery tests>`; `cd assets && yarn test <targeted multi_input delivery tests>`; `cd assets && yarn test <targeted data/content writer tests>`
- Definition of Done:
  - Student Single Response shows validation, help, and parser-derived preview.
  - Student Multi-Input inline blanks show validation and help without preview or layout-breaking messages.
  - Coverage supports `AC-001`, `AC-003`, `AC-020`, `AC-021`, `AC-028`, `AC-029`, `AC-030`, `AC-031`, `AC-032`, and `AC-033`.
- Gate:
  - Delivery tests pass and manual inspection confirms inline blanks do not shift or crowd surrounding text.
- Dependencies:
  - Phase 2 shared component and Phase 1 adapter.
- Parallelizable Work:
  - Static help page tests can run independently once Phase 5 is implemented.

## Phase 5: Static Syntax Help Page
- Goal: Add the stable documentation page linked from the help popover.
- Tasks:
  - [ ] Add `get "/help/math-syntax", StaticPageController, :math_syntax` in the existing open-access browser route scope.
  - [ ] Add `math_syntax/2` to `OliWeb.StaticPageController`.
  - [ ] Add `lib/oli_web/templates/static_page/math_syntax.html.heex` with student-readable sections for arithmetic, implicit multiplication, parentheses, powers, fractions, functions, constants, absolute value, factorial, scientific notation, variables, units, and common mistakes.
  - [ ] Use headings, short prose, tables or lists, code formatting, and accepted/rejected examples.
  - [ ] Keep implementation terms out of student-facing copy.
  - [ ] Add source comments sparingly only if route/template placement is non-obvious; the page copy itself should carry user-facing explanation.
- Testing Tasks:
  - [ ] Add ExUnit route/controller tests for page load and representative content.
  - [ ] Confirm component tests from Phase 2 target the static help URL in the `Learn more` link.
  - Command(s): `mix test test/oli_web/controllers/static_page_controller_test.exs`; `mix format lib/oli_web/router.ex lib/oli_web/controllers/static_page_controller.ex test/oli_web/controllers/static_page_controller_test.exs`
- Definition of Done:
  - Static page loads publicly at `/help/math-syntax`.
  - Page content is scannable, student-readable, and aligned with supported syntax.
  - Coverage supports `AC-014`, `AC-015`, `AC-016`, `AC-017`, `AC-018`, `AC-034`, and `AC-035`.
- Gate:
  - Route test passes and manual content review confirms no parser-internal language appears in the page.
- Dependencies:
  - None for page creation; Phase 2 for final link verification.
- Parallelizable Work:
  - Can run in parallel with Phases 2-4 after the route default is accepted.

## Phase 6: Cross-Cutting Verification And Release Readiness
- Goal: Prove the feature is complete across shared math, frontend activity surfaces, static docs, accessibility, privacy, and review readiness.
- Tasks:
  - [ ] Run focused test suites from previous phases and then broader impacted suites as warranted.
  - [ ] Inspect changed files for raw expression logging, raw parser diagnostic exposure, generated LaTeX logging, and accidental persisted preview or validation state.
  - [ ] Manually verify keyboard-only flow: input, help icon, popover, `Learn more`, Escape close, validation messages, and preview suppression.
  - [ ] Manually verify representative valid expressions: `2x + 6`, `2(x + 3)`, `sqrt(2)/2`, `x^2`, `1.2e-3`, `abs(x - 2)`, `sin(x)`, `pi`, and `9.8 m/s^2`.
  - [ ] Manually verify representative invalid expressions: `2^^3`, `1,000`, `sin x`, `sqrt()`, `9.8m/s^2`, and `(x + 1`.
  - [ ] Confirm source comments are present at important non-obvious boundaries and absent from obvious code paths.
  - [ ] Prepare review notes for security, performance, requirements, UI, TypeScript, Gleam, and Elixir reviewers based on touched files.
- Testing Tasks:
  - [ ] Run all targeted Jest, ExUnit, and Gleam commands from earlier phases.
  - [ ] Run formatting/linting for touched languages.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`; `cd assets && yarn test <targeted tests>`; `cd assets && yarn lint`; `mix test test/oli_web/controllers/static_page_controller_test.exs`; `mix format <touched elixir files>`
- Definition of Done:
  - All acceptance criteria have implementation evidence: `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-011`, `AC-012`, `AC-013`, `AC-014`, `AC-015`, `AC-016`, `AC-017`, `AC-018`, `AC-019`, `AC-020`, `AC-021`, `AC-022`, `AC-023`, `AC-024`, `AC-025`, `AC-026`, `AC-027`, `AC-028`, `AC-029`, `AC-030`, `AC-031`, `AC-032`, `AC-033`, `AC-034`, and `AC-035`.
  - No unintended persistence, scoring, logging, parser grammar, or feedback behavior changes are present.
- Gate:
  - Targeted automated tests and manual accessibility/privacy checks are complete before review handoff.
- Dependencies:
  - Phases 1-5 complete.
- Parallelizable Work:
  - Manual content review and privacy inspection can happen in parallel with final automated test runs.

## Parallelization Notes
- Phase 1 is the main dependency for preview-capable component work.
- Phase 5 can proceed early because the route and copy are mostly independent of shared component implementation.
- Phase 3 and Phase 4 can be split between authoring and delivery owners after Phase 2 is stable.
- Test writing can begin alongside each phase, but final assertions should wait for the relevant component or route contracts to settle.
- Source-code comment review should happen continuously with each phase, not only at the end, because the most important comments sit at architectural boundaries.

## Phase Gate Summary
- Gate A: Shared formatter and browser adapter produce parser-derived preview output without raw ASCII MathJax rendering.
- Gate B: Shared React component proves validation, help, preview, accessibility, and inline no-preview behavior in isolation.
- Gate C: Authoring integrations pass and activity content serialization remains unchanged.
- Gate D: Delivery integrations pass and inline Multi-Input blanks remain stable.
- Gate E: Static syntax page route and content tests pass.
- Gate F: Final focused tests, formatting/linting, privacy inspection, source-comment review, and manual accessibility checks are complete.
