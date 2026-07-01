# Math Expression Syntax Help - Product Requirements Document

## 1. Overview
Add lightweight syntax education, immediate parse feedback, and rendered previews for Torus Math Expression inputs. The feature should make calculator-style algebraic syntax discoverable and trustworthy for authors and students without introducing a calculator, formula builder, visual equation editor, new grading semantics, or a second parser.

The user-facing pattern is a smart text field: users type supported ASCII math, receive immediate validation feedback, can open compact syntax help, can navigate to a full syntax reference page, and, where layout permits, see a MathJax-rendered preview based on the Torus parser's interpretation.

## 2. Background & Problem Statement
Torus Math Expression work has established a shared parser and evaluator for constrained calculator-style algebraic syntax. That enables validation and evaluation, but users still need clear discovery for powers, functions, constants, absolute values, scientific notation, variables, fractions, and units.

Students need help entering answers confidently in delivery. Authors need the same syntax guidance and need confidence that durable expected answers and targeted feedback expressions parse as intended before content is saved or published. Multi-Input inline blanks add a layout constraint: validation and help are still needed, but always-visible rendered previews would disrupt the surrounding prose.

## 3. Goals & Non-Goals
### Goals
- Provide immediate client-side parse feedback for all algebraic Math Expression text inputs in authoring and delivery.
- Add a compact floating help affordance to every algebraic Math Expression input, including constrained Multi-Input layouts where feasible.
- Link the help affordance to a stable static syntax documentation page.
- Show MathJax-rendered previews for author-facing algebraic expression inputs and student single-response Math Expression inputs.
- Keep student Multi-Input inline blanks compact by omitting rendered previews there.
- Ensure validation and help are usable by keyboard users and assistive technologies.
- Generate previews from the Torus parser's AST-to-LaTeX path rather than from independent MathJax parsing of raw ASCII.

### Non-Goals
- Do not build a math calculator, keypad, formula builder, or visual equation editor.
- Do not change parser grammar, normalization, evaluator behavior, unit semantics, equivalence, scoring, feedback selection, or grading policy.
- Do not introduce syntax accepted only by the preview renderer.
- Do not use MathJax or KaTeX as an independent parser for raw user input.
- Do not show always-visible rendered previews for student Multi-Input inline blanks.
- Do not extend this feature to number-only, text, paragraph, dropdown, or legacy exact-LaTeX math inputs unless separately scoped.
- Do not add production analytics or telemetry beyond existing operational observability.

## 4. Users & Use Cases
- Authors: enter expected answers, targeted feedback answers, and authoring preview expressions while receiving immediate syntax feedback and a rendered preview of how Torus interpreted the expression.
- Students: submit single-response Math Expression answers with validation, compact help, and a rendered preview when the expression is valid.
- Students using Multi-Input activities: type Math Expression answers inside inline blanks with validation and help but without disruptive rendered previews.
- Learning engineers and QA: verify that syntax documentation, validation states, and previews match the shared parser and do not drift across authoring and delivery surfaces.

## 5. UX / UI Requirements
- Math Expression inputs should remain text-first and lightweight; the help affordance should support typing, not replace it.
- Valid non-empty expressions should receive a positive visual state, invalid non-empty expressions should receive an error visual state, and empty untouched fields should remain neutral.
- Validation must not rely on color alone; error text, status text, icons, and ARIA state should be used where appropriate for the layout.
- The help affordance should appear visually attached to the input, preferably as a small circular icon above the upper-right input border, without obscuring typed text.
- Help popovers must open by hover, focus, click, Enter, or Space, and close by Escape, outside click, or focus leaving the popover region.
- The help popover should be concise, include examples such as `2x + 6`, `sqrt(2)/2`, `x^2`, `sin(x)`, `pi`, and `9.8 m/s^2`, and include a `Learn more` link that opens the syntax page in a new tab.
- The static syntax page should be scannable, student-readable, and organized by syntax category with accepted and rejected examples.
- Rendered previews should appear near the input when the expression is valid and preview mode is enabled; invalid or empty inputs must not show stale or confusing previews.
- Student Multi-Input inline blanks must avoid layout shifts while still exposing validation and help access.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: validation state, help controls, popovers, and the static help page must be usable with keyboard navigation and assistive technologies.
- Reliability: parser failures, incomplete expressions, unsupported variables, and invalid units must return controlled validation states rather than crashing UI components.
- Consistency: authoring and delivery should share the same parser validation path and reusable Math Expression input behavior where practical.
- Privacy: production logs and telemetry must not record raw learner expressions or raw expected answers by default.
- Performance: client-side validation should be debounced enough to avoid visible typing lag while still feeling immediate; preview rendering should only run from valid parser output.
- Maintainability: syntax documentation must be kept close enough to math feature ownership that grammar changes can update documentation in the same review path.

## 9. Data, Interfaces & Dependencies
- Depends on the shared Torus Math Expression parser exposed to browser code through the existing Gleam JavaScript integration or thin TypeScript adapters.
- Depends on an AST-to-LaTeX formatter or equivalent shared math formatting boundary so MathJax receives parser-derived LaTeX instead of raw ASCII input.
- Depends on existing React activity authoring and delivery surfaces for Single Response and Multi-Input Math Expression fields.
- Adds or extends a reusable Math Expression input component with configuration for value, change handling, validation mode, help visibility, preview mode, allowed variables, unit support, labels, layout mode, and accessibility attributes.
- Adds a stable static route, recommended as `/help/math-syntax`, that is linkable from authoring and delivery contexts.
- Uses MathJax only as the renderer for parser-derived preview output.

## 10. Repository & Platform Considerations
- Frontend behavior belongs in the focused React activity authoring and delivery surfaces under `assets/src/`, mounted through the existing Phoenix application model.
- Shared math validation and formatting should remain behind the small public Gleam math boundary rather than duplicating parser logic in TypeScript.
- Backend/Phoenix work is expected for the static syntax help route and any server-rendered page shell.
- The publication model matters: authoring validation should help prevent invalid durable content before save or publish, while delivery behavior must remain stable for already published content.
- Testing should use Jest or component tests for client behavior, Gleam tests if formatting/parser boundaries change, ExUnit or controller tests for the static route, and scenario coverage only if a realistic authoring-to-delivery workflow is added.
- Code review should include `.review/security.md`, `.review/performance.md`, `.review/requirements.md`, `.review/ui.md`, and `.review/typescript.md`; include `.review/gleam.md` if shared math formatting or parser APIs change, and `.review/elixir.md` if the static route or backend integration changes.
- No Jira issue key was provided; this work item directory is the planning source of truth until a ticket is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: authors and students can discover supported syntax from every algebraic Math Expression input without leaving the workflow.
- Quality signal: automated tests prove valid, invalid, and empty input states; popover interaction; documentation links; and preview visibility rules across authoring, single-response delivery, and Multi-Input delivery.
- Consistency signal: previews are generated only from Torus parser output and never from independent raw ASCII MathJax parsing.
- Accessibility signal: keyboard and screen-reader checks pass for validation state, help popovers, and the static documentation page.
- No new production analytics are required. If future telemetry is added, it should record aggregate-safe categories such as validation state counts or help-page visits, not raw expressions.

## 13. Risks & Mitigations
- Help affordances clutter inline Multi-Input blanks: allow compact or focus-only presentation in constrained layouts while preserving validation and access to help.
- Preview syntax drifts from parser syntax: generate preview from Torus parser AST converted to LaTeX and avoid raw ASCII rendering paths.
- Validation becomes inaccessible if represented only by red and green outlines: add ARIA state, accessible descriptions, and visible text or non-color indicators where layout allows.
- Static docs become outdated as grammar evolves: require documentation review when parser grammar, supported functions, constants, units, or syntax rules change.
- Authoring and delivery implementations drift: centralize validation, help, and preview behavior in a reusable component with explicit layout and preview modes.
- Validation or preview introduces typing lag: debounce validation and only render previews for valid parser output.

## 14. Open Questions & Assumptions
### Open Questions
- Should the static syntax route be exactly `/help/math-syntax`, or should it live under an existing documentation/help route namespace?
- Should compact Multi-Input inline help appear only on focus, or should every inline blank show the icon at all times when space permits?
- Does the shared math layer already expose all AST-to-LaTeX formatting needed for units, functions, constants, and absolute values, or does this work need to add that formatter?

### Assumptions
- "Algebraic Math Expression input" includes Math Expression subtypes that accept algebraic syntax, with or without units, in Single Response and Multi-Input activities.
- Number-only inputs and legacy exact-LaTeX math inputs are outside this feature unless a later product decision brings them into the same help pattern.
- General parser error text is acceptable for an initial implementation when richer parser diagnostics are not yet available, as long as the component can surface richer messages later.
- Authoring fields may block save or publish when required expressions are invalid, but this feature does not change grading semantics for learner submissions.

## 15. QA Plan
- Automated validation:
  - Add Jest or component tests for valid, invalid, and empty states; author versus student layout modes; help icon rendering; hover/focus/click activation; Escape dismissal; `Learn more` target; and preview visibility.
  - Add delivery tests showing student single-response Math Expression inputs validate and preview while Multi-Input inline blanks validate without rendered previews.
  - Add authoring tests showing answer-key, targeted feedback, and candidate/test expression fields validate and preview.
  - Add route/controller or LiveView tests for the static syntax documentation page.
  - Add Gleam target tests if AST-to-LaTeX formatting or parser-facing public APIs are changed.
- Manual validation:
  - Verify keyboard-only flow through inputs, help icon, popover, Learn more link, and Escape dismissal.
  - Verify screen-reader accessible names, `aria-invalid`, and error descriptions.
  - Check the static syntax page heading structure, examples, and wording for student readability.
  - Validate representative expressions: `2x + 6`, `2(x + 3)`, `sqrt(2)/2`, `x^2`, `1.2e-3`, `abs(x - 2)`, `sin(x)`, `pi`, and `9.8 m/s^2`.
  - Validate representative invalid inputs: `2^^3`, `1,000`, `sin x`, `sqrt()`, `9.8m/s^2`, and `(x + 1`.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
