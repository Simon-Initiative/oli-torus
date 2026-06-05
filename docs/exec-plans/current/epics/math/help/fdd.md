# Math Expression Syntax Help - Functional Design Document

## 1. Executive Summary
Build a shared Math Expression input experience that sits above the existing Torus math parser and activity surfaces. The design adds parser-backed validation state, accessible syntax help, and optional MathJax preview without changing activity persistence, parser grammar, response matching, scoring, feedback selection, or learner attempt semantics.

The implementation should introduce one reusable React component family for covered algebraic Math Expression text fields, reuse the existing `assets/src/gleam/torusExpression.ts` browser adapter for validation, extend shared Gleam formatting with a parser-derived LaTeX formatter for previews, and add a public static Phoenix help page at `/help/math-syntax`.

## 2. Requirements & Assumptions
- Functional requirements:
  - Covered inputs are algebraic Math Expression text inputs in Single Response and Multi-Input authoring and delivery (`FR-001`).
  - Validation must use the client-side Torus parser and expose valid, invalid, and neutral states accessibly (`FR-002`).
  - Each covered input needs an accessible help affordance and popover with a syntax docs link (`FR-003`).
  - The static syntax page must be stable, readable, and complete enough for students and authors (`FR-004`).
  - Preview rendering must be parser-derived and enabled only where the PRD permits it (`FR-005`).
  - Authoring integration must cover answer-key, targeted feedback, and candidate/test expression editors where present (`FR-006`).
  - Delivery integration must preserve inline Multi-Input layout while improving Single Response help and preview (`FR-007`).
  - Math semantics and raw expression privacy remain unchanged (`FR-008`).
  - The work needs focused frontend, route, accessibility, and parser-derived rendering coverage (`FR-009`).
- Non-functional requirements:
  - Keep validation responsive with debounced parsing and no typing-blocking behavior.
  - Keep the shared math layer as the source of truth for parse and preview interpretation.
  - Avoid raw learner or author expression logging by default.
  - Preserve keyboard access, focus visibility, screen-reader descriptions, and dark-mode compatibility.
- Assumptions:
  - "Algebraic Math Expression input" means `math_expression` subtypes that currently route to text syntax validation: algebraic expressions, fractions, expression with units, and number with units where quantity parsing is required.
  - Number-only `math_expression` inputs may continue to use numeric controls and are not pulled into this UI unless later scoped.
  - Legacy `math` / exact-LaTeX inputs remain separate and continue to use `MathInput`.
  - General parser diagnostics are acceptable for the first release, but the component contract must allow richer messages later.

## 3. Repository Context Summary
- What we know:
  - Single Response delivery is implemented in `assets/src/components/activities/short_answer/ShortAnswerDelivery.tsx`.
  - Single Response authoring routes answer-key and targeted feedback response editors through `assets/src/components/activities/short_answer/sections/InputEntry.tsx`.
  - Multi-Input authoring routes correct answers and targeted feedback through `assets/src/components/activities/multi_input/sections/AnswerKeyTab.tsx`, which already delegates non-dropdown responses to `InputEntry`.
  - Multi-Input inline delivery renders `input_ref` elements through `assets/src/data/content/writers/html.tsx` using `WriterContext.inputRefContext`.
  - Delivery already has `assets/src/components/activities/common/delivery/inputs/MathExpressionTextInput.tsx`, but it is delivery-shaped, marks empty inputs invalid, and has no help or preview layer.
  - `assets/src/gleam/torusExpression.ts` already provides browser-side parser-backed syntax validation while intentionally importing lightweight generated Gleam modules instead of the full `torus_math` JS bundle.
  - `gleam/src/torus_math.gleam` is the public shared math boundary; existing internals include parser, parse-error formatting, unit quantity parsing, and diagnostics, but no obvious AST-to-LaTeX formatter was found.
  - Existing MathJax rendering primitives live in `assets/src/components/common/MathJaxFormula.tsx`.
  - Static open-access routes are currently served from `OliWeb.StaticPageController` and templates under `lib/oli_web/templates/static_page/`.
- Unknowns to confirm:
  - Whether the browser adapter should import a new lightweight generated `math/latex.mjs` module directly, as it does for parser modules today, or whether the full `torus_math` JS bundle can be made safe to import without Node crypto.
  - Whether design wants the inline Multi-Input help icon always visible, focus-visible only, or represented by a compact shared affordance when blanks are very narrow.
  - Whether static help content should use the public app layout exactly as other `StaticPageController` pages do or a narrower documentation-specific page shell.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Create a shared activity component group under `assets/src/components/activities/common/math_expression/`:

- `MathExpressionInput`: owns input rendering, validation state, help icon placement, accessible descriptions, and optional preview slot.
- `useMathExpressionValidation`: debounces parser calls, returns `empty`, `valid`, `invalid`, or `unknown`, and keeps the latest safe diagnostic string.
- `MathExpressionHelpPopover`: accessible popover with short examples and a `Learn more` link to `/help/math-syntax`.
- `MathExpressionPreview`: renders parser-derived LaTeX through `MathJaxLatexFormula` when preview mode is enabled and validation is valid.

Keep the existing `MathExpressionTextInput` as a compatibility wrapper during migration or replace its uses with `MathExpressionInput` in one slice. The new component should accept explicit layout and preview modes:

```ts
type MathExpressionLayout = 'authoring' | 'delivery_single' | 'inline_multi_input';
type MathExpressionPreviewMode = 'none' | 'below_input';

type MathExpressionInputProps = {
  value: string;
  validationKind: 'expression' | 'quantity';
  layout: MathExpressionLayout;
  previewMode: MathExpressionPreviewMode;
  disabled?: boolean;
  placeholder?: string;
  size?: MultiInputSize;
  ariaLabel: string;
  describedBy?: string;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp?: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
};
```

Integrate it in these surfaces:

- `ShortAnswerDelivery.tsx`: for `math_expression` inputs that resolve to text validation, use `layout="delivery_single"` and `previewMode="below_input"`.
- `InputEntry.tsx`: for math expression answer values in correct-answer and targeted feedback response editors, use `layout="authoring"` and `previewMode="below_input"`.
- `multi_input/sections/AnswerKeyTab.tsx`: no direct new component if `InputEntry` covers both correct responses and targeted feedback, but tests should prove the Multi-Input route.
- `data/content/writers/html.tsx`: for `input_ref` elements with text-validating `math_expression` subtypes, use `layout="inline_multi_input"` and `previewMode="none"`.
- `response_multi` surfaces that still delegate to the same writer or `InputEntry` should inherit behavior without a parallel implementation.

### 4.2 State & Data Flow
The browser data flow is intentionally local:

```text
user input
  -> MathExpressionInput local value prop
  -> useMathExpressionValidation
  -> assets/src/gleam/torusExpression.ts
  -> generated Gleam parser or quantity parser
  -> validation state and safe diagnostic
  -> optional parser-derived LaTeX formatter
  -> MathJaxLatexFormula preview
```

Validation state should not be persisted into activity JSON or attempt state. Existing authoring and delivery `onChange`, deferred save, submit, reset, and per-part submission flows continue to own persistence.

Preview data must be derived from a successful Torus parse. The TS adapter should expose a function such as:

```ts
type MathExpressionPreviewResult =
  | { status: 'valid'; debug: string; latex: string }
  | { status: 'invalid'; debug: string }
  | { status: 'empty' }
  | { status: 'unknown'; debug: string };
```

Quantity inputs should validate through `parse_quantity_or_expression`. If quantity-to-LaTeX formatting is not available in the first implementation slice, expression-with-units preview should either render only after a quantity formatter is added or suppress preview with a neutral "Preview unavailable" state; it must not feed raw ASCII directly to MathJax.

### 4.3 Lifecycle & Ownership
- The shared Math Expression component owns transient validation, popover, and preview state.
- Activity components own student and author value changes exactly as they do today.
- Gleam owns syntax parsing, quantity parsing, and AST-to-LaTeX formatting.
- Phoenix owns the static syntax page route and template.
- Documentation content should be updated with parser grammar changes as part of math feature ownership.

### 4.4 Alternatives Considered
- Extend only `MathExpressionTextInput`: simplest diff, but too delivery-specific and would spread authoring and preview behavior into a component with the wrong boundary.
- Add separate authoring and delivery components: avoids a larger shared prop contract, but risks behavior drift between authoring and delivery.
- Use MathJax AsciiMath or raw ASCII rendering for previews: lower implementation effort, but rejected because it creates a second syntax interpretation path.
- Implement the syntax page as a bundled React route: unnecessary because the page is static, public, and better served by Phoenix templates.

## 5. Interfaces
- React component interface:
  - `MathExpressionInput` is the only component activity surfaces should render directly for covered text-based Math Expression fields.
  - `previewMode="below_input"` is used for authoring and student Single Response.
  - `previewMode="none"` is used for student Multi-Input inline blanks.
  - `layout` controls spacing, fixed dimensions, help placement, validation text behavior, and inline layout constraints.
- TypeScript math adapter:
  - Extend `assets/src/gleam/torusExpression.ts` with a parser-backed validation-and-preview function.
  - Continue avoiding imports that pull Node-only crypto into browser bundles unless the underlying bundle issue is resolved.
- Gleam formatter:
  - Add a deterministic AST-to-LaTeX formatter, likely under `gleam/src/math/latex.gleam`, plus a public wrapper in `torus_math.gleam`.
  - The formatter should cover the documented syntax categories: arithmetic, implicit multiplication, parentheses, powers, division/fractions, functions, constants, absolute value, factorial, scientific notation, variables, and units when quantity preview is enabled.
- Static route:
  - Add `get "/help/math-syntax", StaticPageController, :math_syntax` in the existing open-access browser scope.
  - Add `math_syntax/2` to `OliWeb.StaticPageController`.
  - Add `lib/oli_web/templates/static_page/math_syntax.html.heex`.
- Link contract:
  - Help popover link target is `/help/math-syntax`, opens in a new tab, and uses `rel="noreferrer"` or equivalent.

## 6. Data Model & Storage
- No database migrations.
- No activity model changes.
- No attempt-state changes.
- No publication model changes.
- No new persisted authoring metadata for validation, help popovers, or previews.
- Static help content is repository source content in a Phoenix template, not user-authored content.

## 7. Consistency & Transactions
- Existing authoring save, delivery save, reset, submit, and per-part submit flows remain the only transaction boundaries.
- Client-side validation is advisory before those boundaries unless an existing required authoring save or publish path already blocks invalid configuration.
- The component must never write validation result or preview output into activity content.
- Delivery sections continue to render from published activity content; this work changes the rendering component behavior, not published content shape.

## 8. Caching Strategy
- No application cache changes.
- Static help page caching follows existing Phoenix/static-page behavior.
- Browser bundle caching follows the normal asset pipeline.
- Validation results may be memoized within the component for the current value and validation kind, but no cross-input or persistent cache is needed.

## 9. Performance & Scalability Posture
- Debounce validation by roughly 150-250 ms during editing and run immediately on blur or save/submit boundaries.
- Avoid parsing empty untouched values except to set the neutral state.
- Generate preview only after a successful parse and only when `previewMode` is not `none`.
- Keep MathJax typesetting scoped to the preview element and reuse the existing serialized `typesetPromise` behavior in `MathJaxFormula`.
- Inline Multi-Input blanks must not allocate preview components or trigger MathJax work.
- The feature is client-local and does not add backend hot-path database queries.

## 10. Failure Modes & Resilience
- Parser returns invalid: show invalid state and accessible diagnostic, suppress preview, and preserve the typed value.
- Parser returns unknown or adapter throws: show neutral or invalid fallback with generic text, suppress preview, and avoid console logging raw input.
- MathJax is unavailable: keep the input usable, show either unrendered preview text or a neutral preview-unavailable state, and rely on existing MathJax warning behavior without adding raw expression logs.
- Popover positioning is constrained: keep the help control reachable and allow inline layouts to use focus-visible or compact presentation.
- Static help page route fails: the popover still provides quick syntax examples; route tests should catch missing route/template regressions.
- Quantity preview formatter is incomplete: do not render raw ASCII through MathJax; either complete the formatter or explicitly suppress preview for that subtype until supported.

## 11. Observability
- No new production telemetry is required.
- Do not log raw learner submissions, raw expected answers, parser internals, sampled assignments, or generated LaTeX.
- Existing Phoenix request telemetry and AppSignal coverage are sufficient for the static route.
- Frontend errors should flow through existing error boundaries where available; component tests should cover controlled failure states rather than relying on logs.
- If telemetry is added later, it should use aggregate-safe categories such as validation state, layout mode, and docs-link activation count.

## 12. Security & Privacy
- The static syntax page is public and contains only fixed documentation content.
- The help link must use safe new-tab attributes when opening a new browser tab.
- Preview LaTeX must come from the Torus parser/formatter, not from unsanitized HTML injection.
- Do not use `dangerouslySetInnerHTML` for expression preview.
- Keep raw expressions out of production logs and telemetry.
- Preserve existing role and content access boundaries; this feature does not grant access to authoring or delivery content.
- Validation messages shown to students should avoid raw parser offsets and internal implementation terms.

## 13. Testing Strategy
- Gleam tests:
  - Add tests for AST-to-LaTeX formatting if the formatter is new or expanded, including representative valid expressions and quantity/unit cases.
  - Run both `cd gleam && gleam test --target erlang` and `cd gleam && gleam test --target javascript` when formatter or public math APIs change.
- TypeScript/Jest tests:
  - Test `MathExpressionInput` states for valid examples (`AC-005`), invalid examples (`AC-006`), neutral empty behavior (`AC-007`), debounced/immediate validation (`AC-009`), and accessible invalid state (`AC-008`).
  - Test help icon rendering, accessible label, hover/focus/click/keyboard activation, close behavior, and docs link (`AC-010`, `AC-011`, `AC-012`, `AC-013`, `AC-014`).
  - Test preview presence, absence, stale-preview suppression, and parser-derived rendering contract (`AC-019`, `AC-020`, `AC-021`, `AC-022`, `AC-023`).
  - Test layout modes for authoring, student Single Response, and student Multi-Input (`AC-001`, `AC-002`, `AC-003`, `AC-028`, `AC-029`, `AC-033`).
  - Test authoring paths through `InputEntry` for correct answers, targeted feedback, candidate/test fields where present, and invalid required fields (`AC-024`, `AC-025`, `AC-026`, `AC-027`).
- Phoenix/ExUnit tests:
  - Add `StaticPageController` route coverage for `/help/math-syntax` and expected page content (`AC-015`, `AC-035`).
- Inspection/manual QA:
  - Confirm excluded input types are unchanged (`AC-004`).
  - Review static page content coverage, structure, and student-facing wording (`AC-016`, `AC-017`, `AC-018`).
  - Confirm student-facing validation avoids raw parser offsets (`AC-030`).
  - Confirm parser/evaluator/scoring behavior and existing tests remain unchanged (`AC-031`).
  - Inspect logging and telemetry for raw expression leakage (`AC-032`).
  - Run keyboard and screen-reader-focused checks for popover and static page structure (`AC-034`).

## 14. Backwards Compatibility
- Existing activity JSON remains valid because no persisted schema changes are introduced.
- Existing published activities pick up UI improvements at render time without migration.
- Legacy `numeric`, `math`, text, paragraph, dropdown, and exact-LaTeX inputs retain their current controls.
- Existing scoring, response matching, targeted feedback selection, and submission lifecycle behavior are untouched.
- The old `MathExpressionTextInput` can remain as a wrapper while call sites migrate to avoid a large single-step rename.

## 15. Risks & Mitigations
- Parser-derived preview formatter scope grows too large: implement the formatter only for syntax already supported by the parser and required by the static docs; suppress preview for unsupported quantity cases rather than rendering raw ASCII.
- Browser bundle pulls in Node-only crypto through `torus_math`: keep the browser adapter on lightweight generated modules or split hash-dependent exports before importing the full public module.
- Inline Multi-Input layout becomes noisy: use `layout="inline_multi_input"` with no preview and compact/focus-aware help placement.
- Authoring and delivery drift: make all covered surfaces consume the same `MathExpressionInput` component and adapter.
- Accessibility is reduced to visual styling: require ARIA state, described-by wiring, focusable popover controls, Escape close behavior, and tests.
- Static docs fall behind grammar changes: require parser-affecting PRs to update `/help/math-syntax` content when syntax changes.

## 16. Open Questions & Follow-ups
- Confirm whether `/help/math-syntax` is the final route or whether product wants the page under another help/docs namespace.
- Decide final inline Multi-Input help presentation for very small blanks: always visible, focus-visible, or shared compact affordance.
- Confirm whether quantity/unit AST-to-LaTeX formatting should be implemented in the first slice or whether quantity previews should be explicitly deferred until the formatter is complete.
- Consider a follow-up review item for math grammar PRs requiring syntax page updates.

## 17. References
- `docs/exec-plans/current/epics/math/help/prd.md`
- `docs/exec-plans/current/epics/math/help/requirements.yml`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
- `docs/ISSUE_TRACKING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `guides/activities/overview.md`
- `guides/activities/structures.md`
- `assets/src/components/activities/common/delivery/inputs/MathExpressionTextInput.tsx`
- `assets/src/components/activities/short_answer/ShortAnswerDelivery.tsx`
- `assets/src/components/activities/short_answer/sections/InputEntry.tsx`
- `assets/src/components/activities/multi_input/sections/AnswerKeyTab.tsx`
- `assets/src/data/content/writers/html.tsx`
- `assets/src/gleam/torusExpression.ts`
- `gleam/src/torus_math.gleam`
- `lib/oli_web/router.ex`
- `lib/oli_web/controllers/static_page_controller.ex`
