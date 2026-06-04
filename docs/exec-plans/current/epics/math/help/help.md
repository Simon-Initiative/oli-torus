# Math Expression Syntax Help - Informal PRD / Technical Specification

## 1. Purpose

This feature provides lightweight, consistent syntax education and feedback for every algebraic Math Expression text input in Torus. The goal is to help authors and students understand the supported calculator-style math syntax without introducing a heavy math editor or calculator UI.

The feature focuses on four user-facing capabilities:

1. Immediate client-side parse feedback using red / green input outlines.
2. A small floating help icon attached to every algebraic expression input.
3. A static, well-organized syntax documentation page with examples.
4. MathJax-rendered previews for author inputs and student single-response inputs, but not for student Multi-Input inline blanks.

This is a UX and documentation layer over the already-implemented math parser. It should not introduce new math semantics, new grading behavior, or a second parser.

## 2. Background

Torus Math Expression evaluation now supports a constrained ASCII / calculator-style syntax for algebraic expressions. The client-side parser can already validate student input immediately and indicate whether the expression is syntactically valid.

However, users still need discoverability:

- Students need to know how to type powers, square roots, functions, constants, absolute values, scientific notation, and units.
- Authors need the same syntax education, plus confidence that the expected answer they typed is being interpreted correctly.
- Inline Multi-Input fields create layout constraints that make always-visible previews impractical.

This feature standardizes the UX pattern for Math Expression fields so that syntax support is visible, accessible, and consistent across authoring and delivery.

## 3. Goals

- Add immediate client-side parse feedback to **all algebraic expression text inputs**, including authoring fields.
- Preserve the existing immediate red / green feedback behavior already present for student inputs.
- Add a small floating help icon to every algebraic expression input.
- Show a concise hover / focus popup from the help icon.
- Provide a “Learn more” link in that popup that opens a static syntax documentation page in a new browser tab.
- Create a static documentation page that clearly explains the supported syntax with many examples.
- Show a MathJax-rendered preview for:
  - Student single-response Math Expression inputs.
  - All author-facing algebraic expression inputs.
- Do **not** show a MathJax-rendered preview for student Multi-Input inline blanks.
- Ensure validation and help are accessible by keyboard and screen readers.
- Avoid building a math calculator, keypad, or visual equation editor in this feature.

## 4. Non-Goals

- Do not add a full math calculator or formula builder.
- Do not add a visual equation editor.
- Do not change parser grammar, evaluator behavior, normalization, equivalence, unit semantics, or grading policy.
- Do not introduce a second syntax accepted only by the preview renderer.
- Do not rely on MathJax or KaTeX to parse the raw ASCII expression independently of the Torus parser.
- Do not show always-visible rendered previews for student Multi-Input inline blanks.
- Do not build a complex authoring UI for units or expression construction.
- Do not add production analytics or telemetry in this feature unless separately scoped.

## 5. User Experience Summary

Every algebraic expression input should feel like a smart text field:

- The user types calculator-style math.
- The field immediately indicates whether the expression parses.
- The help icon gives quick syntax hints.
- The user can open full syntax documentation in a new tab.
- Where layout permits, the user sees a rendered math preview that reflects how Torus interpreted the expression.

The intended experience is:

> “I can type normal calculator-style math, I immediately know if it is valid, I can quickly see examples if I forget the syntax, and in authoring or single-response contexts I can see a rendered preview of what Torus thinks I typed.”

## 6. Scope: Which Inputs Are Covered

This feature applies to all text inputs that accept the new Math Expression / algebraic-expression syntax.

Covered examples:

- Student Short Answer Math Expression input.
- Student single-response Math Expression input in any equivalent activity surface.
- Author expected-answer fields for Math Expression responses.
- Author candidate-answer / preview fields for Math Expression evaluation.
- Author expression fields inside configuration panels, including expected expression, test candidate expression, exact-form examples, or equivalency test inputs where applicable.  Include Targeted Feedback response editors also.
- Multi-Input author fields that configure a selected blank’s Math Expression answer.
- Student Multi-Input inline Math Expression blanks, with validation and help, but without rendered preview.

Not covered:

- Legacy exact-LaTeX Math input, unless product explicitly decides to reuse the help affordance with different docs.
- Number-only inputs.
- Text, paragraph, dropdown, or other non-math input types.
- Internal developer-only fields unless they are already using the same Math Expression input component.

## 7. Requirement 1: Immediate Red / Green Client-Side Parse Feedback

### 7.1 Behavior

Every algebraic expression input must run the client-side parser as the user types or after short debounce.

The input should show:

- Green outline when the current non-empty expression parses successfully.
- Red outline when the current non-empty expression fails to parse.
- Neutral/default outline when the input is empty, unless the field is required and has been touched/submitted.

This currently exists for student input and must be extended to author inputs.

### 7.2 Validation Timing

Recommended behavior:

- Validate on input change with a short debounce, such as 150–250 ms.
- Validate immediately on blur.
- Validate immediately on submit/save/publish.
- Do not block typing while the expression is temporarily incomplete.

Examples of temporarily incomplete expressions:

```text
2(
sqrt(
x^
```

These may be red once validation runs, but the UI should not prevent the user from continuing to type.

### 7.3 Validation Messages

A red outline alone is not enough. When invalid, the UI should show concise text near the input where layout allows.

Example messages:

```text
This expression is not valid yet.
```

```text
Expected a closing parenthesis.
```

```text
Use function parentheses: write sin(x), not sin x.
```

```text
Unknown variable z. Allowed variables: x, y.
```

```text
Units must be separated from the value by a space, such as 9.8 m/s^2.
```

The first version may use general parse-error text if the parser does not yet expose specific messages everywhere. However, the component should be structured so richer parser messages can be surfaced later.

### 7.4 Accessibility

Validation must not rely on red / green color alone.

The input should support:

- `aria-invalid="true"` when invalid.
- An accessible error message referenced with `aria-describedby`.
- Visible text when invalid in contexts where there is space.
- Non-color indicators where practical, such as icons or short status text.

For compact inline Multi-Input blanks, visible validation text may be deferred to a shared message area or a focused tooltip, but screen-reader-accessible feedback should still exist.

## 8. Requirement 2: Floating Help Icon

### 8.1 Placement

Every algebraic expression input should include a small circular help icon.

Placement:

- The icon should sit floating just above the upper-right border of the input control.
- It should visually feel attached to the input, but not obscure the typed text.
- It should be consistent across authoring and delivery.
- In cramped inline Multi-Input layouts, the icon may appear on focus or be represented by a nearby compact affordance if always-visible placement is too disruptive.

Suggested visual treatment:

```text
small circular button
? icon or help icon
subtle border
white or neutral background
accessible focus ring
```

### 8.2 Interaction

The help icon must be reachable by mouse and keyboard.

The popup should open when:

- The icon is hovered.
- The icon receives keyboard focus via Tab.
- The icon is clicked or activated with Enter/Space.

The popup should close when:

- Hover/focus leaves the icon and popup region.
- Escape is pressed.
- The user clicks elsewhere.
- Focus moves away, unless focus moves into an interactive element inside the popup.

### 8.3 Popup Content

The popup should be short and not attempt to replace the full documentation page.

Suggested title:

```text
Math / Formula
```

Suggested body:

```text
Use calculator-style math like 2x + 6, 2(x + 3), sqrt(2)/2, x^2, sin(x), pi, or 9.8 m/s^2.
```

Suggested link:

```text
Learn more
```

The “Learn more” link must open the static syntax documentation page in a new tab.

### 8.4 Popup Accessibility

The help icon should have an accessible label such as:

```text
Show supported math syntax
```

The popup should use an accessible tooltip/popover pattern appropriate to the existing component library.

Because the popup contains an interactive “Learn more” link, it should not be implemented as a purely non-focusable tooltip if that would make the link inaccessible. A lightweight popover is preferable.

The popup should be readable by screen readers and keyboard users.

## 9. Requirement 3: Static Supported Syntax Page

### 9.1 Purpose

Create a static system page that fully explains the supported Math Expression syntax.

The page should serve both authors and students. It should be written in clear, plain language and organized by syntax category.

The help icon popup links to this page using “Learn more,” opening in a new tab.

### 9.2 Location

Exact route can be decided by implementation, but examples include:

```text
/help/math-syntax
/math/syntax
/docs/math-expression-syntax
```

Recommended route:

```text
/help/math-syntax
```

The page should be stable enough to link from both authoring and delivery contexts.

### 9.3 Page Structure

Recommended structure:

1. Page title
2. Short intro
3. Quick examples
4. Basic arithmetic
5. Multiplication and implicit multiplication
6. Parentheses
7. Powers and exponents
8. Fractions and division
9. Functions
10. Constants
11. Absolute value
12. Factorial
13. Scientific notation
14. Variables
15. Units
16. Common mistakes
17. Author notes, if applicable

### 9.4 Suggested Static Page Content

#### Title

```text
Supported Math Expression Syntax
```

#### Intro

```text
Math Expression answers use calculator-style typing. You can enter numbers, variables, arithmetic, powers, parentheses, common functions, constants, and supported units.
```

#### Quick examples

| What you want | Type this |
|---|---|
| Two times x plus six | `2x + 6` |
| Two times the quantity x plus three | `2(x + 3)` |
| Square root of two divided by two | `sqrt(2)/2` |
| x squared | `x^2` |
| Scientific notation | `1.2e-3` |
| Absolute value of x minus two | `abs(x - 2)` or `|x - 2|` |
| Sine of x | `sin(x)` |
| Pi | `pi` |
| Acceleration with units | `9.8 m/s^2` |

#### Basic arithmetic

Supported operators:

```text
+   addition
-   subtraction
*   multiplication
/   division
^   power
```

Examples:

```text
3 + 4
10 - 2
6 * 7
12 / 4
2^3
```

#### Multiplication

You may use `*` or implicit multiplication.

Examples:

```text
2*x
2x
2(x + 3)
(x + 1)(x - 1)
xy
```

Note:

```text
2x means 2 times x.
```

#### Parentheses

Use parentheses to group expressions.

Examples:

```text
2(x + 3)
(x + 1)/(x - 1)
(x + y)^2
```

#### Powers

Use `^` for powers.

Examples:

```text
x^2
x^(1/2)
(2x + 1)^3
```

Do not use Unicode superscripts such as `x²` unless the parser explicitly supports them.

#### Fractions and division

Use `/` for division and fractions.

Examples:

```text
1/2
sqrt(2)/2
(x + 1)/(x - 1)
```

Use parentheses when needed to make the numerator or denominator clear.

#### Functions

Supported functions:

```text
sqrt(x)
sin(x)
cos(x)
tan(x)
ln(x)
log(x)
log10(x)
log2(x)
abs(x)
exp(x)
```

Examples:

```text
sqrt(2)
sin(x)
ln(x + 1)
log10(100)
abs(x - 2)
exp(x)
```

Functions require parentheses.

Correct:

```text
sin(x)
```

Incorrect:

```text
sin x
```

#### Constants

Supported constants:

```text
pi
e
```

Examples:

```text
2pi
pi/2
e^x
```

#### Absolute value

Use `abs(...)` or vertical bars if supported.

Examples:

```text
abs(x - 2)
|x - 2|
```

If vertical bars create ambiguity, use `abs(...)`.

#### Factorial

Use `!` for factorial when supported by the item.

Examples:

```text
5!
n!
```

Factorial is generally valid only for non-negative integers.

#### Scientific notation

Use `e` notation.

Examples:

```text
1.2e-3
6e7
3.0e8
```

Do not use thousands separators.

Correct:

```text
1000
```

Incorrect:

```text
1,000
```

#### Variables

Allowed variables depend on the question. Common variables include:

```text
x
y
t
a
n
```

If a question allows only `x`, then an answer using `z` may be invalid even if the syntax is otherwise correct.

Examples:

```text
2x + 6
x^2 + y^2
v*t
```

#### Units

Some questions may require units. Type a space between the value and the unit.

Examples:

```text
9.8 m/s^2
980 cm/s^2
10 N
36 km/hr
1.0 mol/L
```

Use `/` for division in units and `^` for unit powers.

Correct:

```text
9.8 m/s^2
```

Incorrect:

```text
9.8m/s^2
```

If units are required, an answer without units may be marked incomplete or incorrect.

#### Common mistakes

| Instead of | Use |
|---|---|
| `sin x` | `sin(x)` |
| `√x` | `sqrt(x)` |
| `x²` | `x^2` |
| `1,000` | `1000` |
| `9.8m/s^2` | `9.8 m/s^2` |
| `2^^3` | `2^3` |

### 9.5 Formatting Requirements

The page should be readable and scannable:

- Use headings for each syntax category.
- Use short paragraphs.
- Use tables for examples.
- Use code formatting for typed syntax.
- Avoid implementation terms such as AST, parser, normalization, sampling, and equivalence.
- Include both accepted and rejected examples.
- Keep the language suitable for students.

## 10. Requirement 4: MathJax Rendered Preview

### 10.1 Preview Scope

Rendered preview is required for:

- Student single-response Math Expression inputs.
- All author-facing algebraic expression inputs.

Rendered preview is explicitly **not** required for:

- Student Multi-Input inline Math Expression blanks.

### 10.2 Preview Behavior

When the expression parses successfully, show a rendered math preview.

Suggested label:

```text
Preview
```

Example:

```text
Input: 2(x + 3)
Preview: rendered math equivalent of 2(x + 3)
```

When the expression is invalid:

- Hide the rendered preview, or show a neutral placeholder such as “Preview unavailable until the expression is valid.”
- Show the validation error instead.

When the input is empty:

- Hide the preview, or show no preview state.

### 10.3 Preview Source of Truth

The preview must be generated from the Torus parser’s interpretation, not from an independent MathJax AsciiMath parser.

Recommended pipeline:

```text
user ASCII input
  -> client-side Torus parser
  -> AST
  -> AST-to-LaTeX formatter
  -> MathJax render
```

This ensures the preview reflects what Torus actually parsed and will evaluate.

Do **not** send raw ASCII directly to MathJax as a separate interpretation path. That risks accepting or rendering syntax differently from the Torus parser.

### 10.4 Authoring Preview

Every author input for an algebraic expression should show a rendered preview below or near the field.

This includes expected-answer fields and any author-facing expression test fields.

The preview helps authors confirm:

- Parentheses were interpreted as intended.
- Powers and fractions are visually clear.
- Functions were recognized.
- Units appear as expected, if rendered.

### 10.5 Student Single-Response Preview

For student single-response Math Expression inputs, show the preview below the input when valid.

This gives the student confidence that Torus interpreted the typed answer correctly.

### 10.6 Student Multi-Input Exception

Do not show the rendered preview for student Multi-Input inline blanks.

Reason:

- Multi-Input blanks are inline within paragraph text.
- Always-visible previews would disrupt reading flow and layout.
- Multiple previews could make the item visually chaotic.
- Validation plus help is sufficient for the initial release.

Future enhancement:

- A focused preview below the question block may be considered later, but it is out of scope for this feature.

## 11. Component Design Guidance

Create or extend a reusable Math Expression input component rather than duplicating logic across authoring and delivery.

Conceptual props / configuration:

```text
value
onChange
validationMode
showHelpIcon: true
showRenderedPreview: true | false
allowedVariables
unitsEnabled
placeholder
ariaLabel
inputSize / layout mode
```

Recommended preview modes:

```text
none
below_input
```

Recommended layout modes:

```text
standalone
authoring
inline_multi_input
```

Behavior by layout mode:

| Mode | Validation | Help icon | Rendered preview |
|---|---|---|---|
| Authoring | Yes | Yes | Yes |
| Student single-response | Yes | Yes | Yes |
| Student Multi-Input inline | Yes | Yes, if layout permits | No |

## 12. Authoring-Specific Notes

Author inputs should receive the same red / green validation treatment as student inputs.

This is important because author syntax errors should be caught before save, preview, or publish.

Author fields should show validation messages more readily than student fields because authors are configuring durable content. Invalid expressions should eventually block save/publish when the expression is required.

The help popup and syntax docs should be available from every author expression field, not only from the main answer-key panel.

## 13. Student-Specific Notes

Student inputs should be helpful but not overly distracting.

For single-response questions:

- Show validation.
- Show help icon.
- Show preview when valid.

For Multi-Input questions:

- Show validation.
- Show help icon where feasible.
- Do not show rendered preview.
- Avoid layout shifts while students type.

Student-facing validation should avoid overly technical language.

Preferred:

```text
This expression is not valid.
```

Better when parser supports it:

```text
Use parentheses with functions, such as sin(x).
```

Avoid:

```text
Unexpected token at parser offset 3.
```

## 14. Acceptance Criteria

### Validation

- Every algebraic expression input runs the client-side parser during editing.
- Author algebraic expression inputs show immediate red / green parse feedback.
- Student single-response algebraic expression inputs continue to show immediate parse feedback.
- Student Multi-Input algebraic expression blanks show immediate parse feedback without layout-breaking messages.
- Empty untouched fields use a neutral state.
- Invalid fields expose accessible error state and are not identified by color alone.

### Help Icon

- Every algebraic expression input has a small circular help icon associated with it.
- The icon is positioned floating just above the upper-right border of the input control where layout permits.
- The icon is keyboard focusable.
- Hovering over the icon opens the help popup.
- Tabbing to the icon opens the help popup.
- Activating the icon by click, Enter, or Space opens the help popup.
- The popup title is `Math / Formula` or an approved equivalent.
- The popup includes concise examples of supported syntax.
- The popup includes a `Learn more` link.
- The `Learn more` link opens the static syntax page in a new tab.

### Static Syntax Page

- A static help page exists at a stable route such as `/help/math-syntax`.
- The page explains supported Math Expression syntax.
- The page includes examples for arithmetic, implicit multiplication, parentheses, powers, fractions, functions, constants, absolute value, factorial, scientific notation, variables, and units.
- The page includes common mistakes and corrected syntax.
- The page uses code formatting for typed examples.
- The page avoids internal implementation terms.

### Rendered Preview

- Author algebraic expression fields show a MathJax-rendered preview when the expression is valid.
- Student single-response Math Expression inputs show a MathJax-rendered preview when the expression is valid.
- Student Multi-Input inline Math Expression blanks do not show rendered previews.
- Preview is based on the Torus parser’s AST converted to LaTeX.
- Invalid expressions do not render stale previews.
- Empty inputs do not show confusing preview content.

### Accessibility

- Help icons have accessible labels.
- Help popups are reachable and usable by keyboard.
- Invalid inputs use `aria-invalid` or equivalent accessible state.
- Validation messages are available to assistive technologies.
- Color is not the only indicator of validity.
- The static syntax page is navigable by headings and readable as text.

## 15. Testing Strategy

### Unit / Component Tests

- Valid expression produces green/valid state.
- Invalid expression produces red/invalid state.
- Empty untouched expression produces neutral state.
- Author input uses the same validation behavior as student input.
- Help icon renders for algebraic expression inputs.
- Help popup appears on hover.
- Help popup appears on keyboard focus.
- Learn more link has correct target and opens in a new tab.
- Rendered preview appears when valid and configured to show.
- Rendered preview does not appear when preview mode is disabled.
- Rendered preview does not appear for student Multi-Input inline mode.

### Integration Tests

- Student single-response Math Expression question shows validation, help icon, and preview.
- Student Multi-Input Math Expression blanks show validation and help affordance, but no preview.
- Author answer-key Math Expression field shows validation, help icon, and preview.
- Author preview/test candidate field shows validation, help icon, and preview.
- Static syntax page loads from the Learn more link.

### Accessibility Tests

- Help icon is reachable by Tab.
- Popup opens on focus.
- Popup can be dismissed with Escape.
- Learn more link is reachable by keyboard.
- Invalid input state is exposed to assistive technologies.
- Static documentation page has a logical heading structure.

### Manual QA Examples

Use these expressions to validate UI states:

Valid:

```text
2x + 6
2(x + 3)
sqrt(2)/2
x^2
1.2e-3
abs(x - 2)
sin(x)
pi
9.8 m/s^2
```

Invalid:

```text
2^^3
1,000
sin x
sqrt()
9.8m/s^2
(x + 1
```

## 16. Risks And Mitigations

### Risk: The help icon clutters inline Multi-Input layout

Mitigation:

- Allow inline mode to show the icon only on focus or use a compact shared help affordance if necessary.
- Preserve the requirement that validation exists even if the icon presentation varies slightly in constrained layouts.

### Risk: MathJax preview interprets syntax differently from Torus

Mitigation:

- Generate preview from the Torus parser AST converted to LaTeX.
- Do not feed raw ASCII directly to MathJax as the source of truth.

### Risk: Validation color is inaccessible

Mitigation:

- Add text status and ARIA state.
- Do not rely on red / green alone.

### Risk: Static docs become outdated as syntax evolves

Mitigation:

- Keep the docs route and content near the math feature code/docs.
- Update docs as part of any grammar-changing PR.
- Add a code review checklist item for syntax docs when parser support changes.

### Risk: Authoring and student components drift

Mitigation:

- Use a shared Math Expression input component with configuration flags for preview and layout.
- Keep parser validation behavior centralized.

## 17. Implementation Notes

- Prefer a shared reusable component for Math Expression inputs.
- Authoring and delivery should use the same parser validation path.
- If preview rendering requires AST-to-LaTeX support, that formatter should live in the shared math layer or a clearly defined client adapter.
- The static syntax page can be server-rendered, static HTML/HEEx, or documentation-driven, depending on existing Torus conventions.
- The popup should be implemented as a true popover when it includes the interactive Learn more link.
- Do not use the static documentation page as the only form of help; the quick popup is required.
- Avoid layout shifts when validation state changes, especially in student delivery.

## 18. Definition of Done

- All algebraic expression inputs have immediate client-side parse feedback.
- Author algebraic expression inputs now have the same immediate validation behavior as student inputs.
- Every algebraic expression input has the floating help icon or approved compact equivalent for constrained inline mode.
- Help popup appears on hover and keyboard focus.
- Popup includes title, quick examples, and Learn more link.
- Static syntax documentation page exists and is linked from the popup.
- MathJax-rendered preview appears for student single-response Math Expression inputs.
- MathJax-rendered preview appears for all author algebraic expression inputs.
- MathJax-rendered preview is not shown for student Multi-Input inline blanks.
- Preview is based on Torus parser output, not independent raw ASCII interpretation.
- Accessibility checks pass for validation, help icon, popup, and static docs page.
- Existing math parser, normalization, sampling, equivalence, unit, exact-form, and activity tests continue to pass.
