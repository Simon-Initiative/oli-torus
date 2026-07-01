# Math UI Integration Approach

## Purpose

This document describes how the new math evaluation capabilities should appear to authors and students in existing Torus activities. It is intentionally written from the user experience perspective, not as an implementation design.

The math requirements in `requirements.pdf` will be integrated into the existing Short Answer and Multi-Input activity workflows. Authors should not have to choose a new activity type just to use better math evaluation. They should continue building familiar question types, then choose the response style that matches what they want students to enter.

## Product Direction

Add the new capabilities in two places:

1. Extend the existing Number input type for numeric scalar answers.
2. Add a new Math Expression input type for parsed math, algebraic equivalence, variables, domains, and units.

Keep the existing Math input type available as a legacy exact-LaTeX option. Its behavior is materially different from the new evaluator: it compares raw LaTeX strings and is useful only where an author explicitly wants that legacy behavior or where older content already depends on it.

The recommended author-facing distinction is:

- Number: "The student should enter a numeric value."
- Math Expression: "The student may enter a formula, expression, variable-based answer, fraction, or value with units."
- Math: "Legacy exact math input."

If product language needs to be shorter in tight UI surfaces, use "Expression" in compact selectors and "Math Expression" in headings.

## Existing Author Workflow

Short Answer currently has one response type for the whole activity. In the Question tab, the author chooses the input type from a dropdown. In the Answer Key tab, the author configures the correct answer and feedback for that same input type.

Multi-Input currently lets authors place multiple answer blanks inside the stem. Each blank has its own input type, selected from the inline input-ref toolbar, and the Answer Key tab configures the selected blank. This is the right model for math: each blank should carry its own evaluation settings.

The new math features should preserve this structure:

- Short Answer: choose Math Expression once for the activity, then configure the answer in Answer Key.
- Multi-Input: choose Math Expression per blank, then configure that blank in Answer Key.
- Existing Text, Number, Dropdown, and Math workflows should remain recognizable.

## Short Answer Authoring

In Short Answer, the Question tab input type dropdown should include:

- Number
- Short Text
- Paragraph
- Math Expression
- Math

Math Expression should be placed near Number and Math. Number should remain the default choice for numeric-only answers. Math should remain available but should be visually or textually distinguishable as the exact/legacy math option where space allows.

When the author chooses Math Expression, the student input preview should indicate a smart expression text field. The author should understand that students type bounded calculator-style syntax such as `2(x+3)`, `sqrt(2)/2`, `1.2e-3`, or `9.8 m/s^2`, and that Torus validates and previews that expression as they type.

In the Answer Key tab, Math Expression should replace the current simple correct-answer input with a structured configuration panel:

- Correct answer
- Evaluation method
- Accepted variables
- Variable domains
- Answer form
- Tolerance
- Units
- Feedback rules
- Preview and validation

The panel should keep the first task simple: the author should be able to enter a correct answer and use sensible defaults without configuring every option.

## Multi-Input Authoring

In Multi-Input, the inline input toolbar should add Math Expression as another input type:

- Dropdown
- Text
- Number
- Math Expression
- Math

When the author changes a blank to Math Expression, the inline placeholder label in the stem should read "Expression" or "Math Expression" depending on available width. The selected blank's Question tab should continue to show size controls, because size still matters for inline layout. No separate expression settings are needed on the Question tab beyond input size and any future display controls.

The selected blank's Answer Key tab should show the same Math Expression configuration panel used by Short Answer. Each blank should be configured independently. For example, one blank can require an integer numeric result, another can require an algebraically equivalent expression in `x`, and another can require a value with units.

Multi-Input scoring should continue to feel like part scoring. Authors should not need to learn a separate math scoring workflow. The Math Expression panel defines whether the selected blank is correct; the existing Multi-Input scoring controls define how points are aggregated across blanks.

## Number Input Enhancements

FR-001 through FR-004 belong in Number. These requirements describe numeric scalar answer behavior, not full symbolic expression behavior.

The Number Answer Key panel should evolve from the current operator plus answer field into a clearer numeric evaluator configuration:

- Correct value
- Comparison
- Tolerance
- Numeric representation
- Decimal precision

Comparison should continue to include the familiar operators:

- Equal to
- Not equal to
- Greater than
- Greater than or equal to
- Less than
- Less than or equal to
- Between
- Not between

Tolerance should be visible when the comparison is equality-like or range-like:

- No tolerance
- Absolute tolerance
- Relative tolerance
- Absolute or relative tolerance

Authors should be able to enter values like `0.1`, `1e-6`, or `1%` where appropriate. Relative tolerance should be presented as a percent-oriented option, because that is how authors are likely to think about it.

Numeric representation should control whether equivalent numeric forms are accepted:

- Any numeric representation
- Integer only
- Decimal
- Scientific notation

Decimal precision should be separate from tolerance. Authors should be able to require:

- Exactly N decimal places
- At least N decimal places
- At most N decimal places

This separation is important because an answer can be numerically within tolerance and still fail the precision rule. For example, `0.80` can be required even when `0.8` has the same numeric value.

The existing "Significant Figures" control should not be treated as satisfying the new decimal-precision requirement. If it remains in the Number UI, it should be clearly separated from decimal places. If significant figures are not part of the immediate scope, avoid expanding that control while implementing FR-001 through FR-004.

## Math Expression Configuration

Math Expression covers FR-005 through FR-015.

The default Math Expression setup should be optimized for the common case:

- Correct answer: author-entered expression
- Evaluation method: Equivalent expression
- Variables: inferred from the correct answer, editable by the author
- Domains: reasonable defaults, editable when needed
- Tolerance: default expression tolerance
- Units: ignored unless enabled
- Answer form: no special form required

The author should be able to create a basic item by entering `2(x+3)` and leaving defaults alone. Students entering `2x+6` should be accepted because the intent is mathematical equivalence, not string matching.

### Correct Answer

The correct answer field should accept calculator-style math as the primary authoring syntax. It may also accept a supported LaTeX subset, but the UI should guide authors toward the same syntax students can type.

The field should provide immediate validation:

- Valid expression
- Invalid syntax
- Unknown variable
- Unsupported function
- Unit syntax problem

Validation should be phrased as author-facing correction guidance, not as evaluator internals.

### Evaluation Method

Authors should choose how the response is judged:

- Equivalent expression
- Exact numeric value
- Exact form only

Equivalent expression is the primary mode for algebraic answers. Exact numeric value is useful when an expression-capable field is desired but the answer is still ultimately numeric. Exact form only is for cases where the written representation is the learning objective.

### Variables

The Variables section should show all variables detected in the correct answer. Authors should be able to add or remove allowed variables.

For each variable, authors should be able to configure:

- Allowed range
- Exclusions
- Integer-only sampling

The UI should make variable domains feel like constraints for checking answers, not like content shown directly to students. If a domain makes evaluation unreliable, the author should see a warning in Preview and validation.

### Answer Form

Answer form controls should enforce how the student writes the answer:

- No required form
- Integer only
- Fraction
- Simplified fraction
- Decimal

When Decimal is selected, decimal-place rules should appear:

- Exactly N places
- At least N places
- At most N places

This section should be used when representation is part of the learning goal. It should not be required for routine algebraic equivalence.

### Tolerance

Math Expression should expose tolerance, but it should not dominate the default UI. Most authors should see a default tolerance with an option to customize it.

Advanced tolerance controls should include:

- Absolute tolerance
- Relative tolerance
- Number of sample points for equivalence checks

The number of sample points should be treated as an advanced setting. Authors generally care that equivalent expressions are accepted; they should not have to understand random sampling to author a routine problem.

### Units

Units should be off by default.

When enabled, authors choose:

- Ignore units
- Require units

If units are required, authors configure accepted units. The UI should support common entries such as `m/s^2`, `cm/s^2`, and `N`.

The author should be able to decide whether convertible units are accepted. For example, `980 cm/s^2` may be accepted for `9.8 m/s^2` when conversion is allowed, but rejected when a specific unit is required.

### Feedback Rules

Math Expression should use the existing targeted feedback mental model: authors can provide feedback for specific incorrect patterns. However, the new evaluator should offer math-aware rule choices instead of requiring authors to write raw matching rules.

MVP feedback rules should include:

- Missing unit
- Wrong but convertible unit
- Unit not accepted
- Domain violation
- Unsimplified fraction
- Wrong form
- Syntax error
- Unexpected variable

Authors should be able to attach feedback to these cases the same way they attach targeted feedback today. The default incorrect feedback should still catch all other incorrect answers.

## Student Experience

For Number responses, students should continue seeing a compact text-style numeric entry. The field should accept numeric representations such as scientific notation when the author allows them. Client-side validation should avoid blocking entry too aggressively while the student is typing, but it should still flag obviously invalid numeric input.

For Math Expression responses, the MVP student input should be a smart text field, not a math keyboard, palette, calculator, or visual expression editor. Students should be able to type the answer directly using the supported syntax from `requirements.pdf`.

The smart expression input should include live validation. As the student types, the field should show whether the expression is valid, invalid, uses an unsupported function, uses an unexpected variable, or has a unit issue. Validation should be helpful without being disruptive while the student is still mid-entry.

The smart expression input should include a rendered preview. When a student types `sqrt(2)/2` or `2(x+3)`, Torus should render the interpreted math below or beside the field. The goal is confidence: students can see how the system understood their answer without needing a visual editor.

The smart expression input should include a "How do I enter math?" help link. The link should open a concise popover or documentation page with supported examples such as:

- `2x + 6`
- `2(x+3)`
- `sqrt(2)/2`
- `x^2`
- `1.2e-3`
- `9.8 m/s^2`

The field may also include lightweight inline example text. For example: `Example: 2(x+3), sqrt(2)/2, or 9.8 m/s^2`.

A math palette or calculator-style UI should not be part of the MVP. It should only be considered later if student testing shows that keyboard entry is a real barrier. That kind of UI adds design, accessibility, mobile, focus-management, and insertion complexity, and it can accidentally imply that students must use the palette instead of simply typing.

Students should not be exposed to raw evaluator concepts such as AST, normalization, or sample points. Feedback should describe the actionable problem:

- "Use one of the allowed variables."
- "Include a unit."
- "Use a simplified fraction."
- "This expression is not valid."
- "Check the values where the expression is defined."

If the student enters a mathematically equivalent expression with different spacing, term order, or safe expansion, it should feel correct. For example, if the expected answer is `2(x+3)`, `2x+6` and `x*2 + 6` should be accepted when Equivalent expression is selected.

## Preview And Validation

Author preview should be central to the Math Expression workflow. Authors should be able to type sample student answers and see whether they pass, fail, or trigger targeted feedback.

The preview should show user-facing outcomes:

- Correct
- Incorrect
- Invalid expression
- Feedback rule matched
- Unit issue
- Domain issue

Validation warnings should appear before authors publish or save problematic configurations. The most important warnings are:

- Correct answer cannot be parsed.
- A required unit list is empty.
- A variable appears in the correct answer but is not allowed.
- A domain excludes all useful sample values.
- Decimal precision conflicts with the selected answer form.
- Feedback rules are unreachable because a catch-all appears first.

Warnings should suggest a fix. Errors should block publish when the item cannot be evaluated reliably.

## Backward Compatibility

Existing Number, Text, Dropdown, and Math content should continue to behave as it does today unless an author explicitly changes the input type or updates the evaluator settings.

Existing Math should not silently become Math Expression. The old exact-LaTeX comparison can produce different grading behavior, and automatic migration would risk changing scores for published content.

New content should steer authors toward:

- Number for scalar numeric answers.
- Math Expression for algebraic, symbolic, fraction/form, variable, or unit-aware answers.
- Math only when legacy exact math comparison is intentionally desired.

## Requirement Mapping

Number input:

- FR-001: absolute tolerance
- FR-002: relative tolerance
- FR-003: numeric representation equivalence
- FR-004: decimal precision independent of tolerance

Math Expression input:

- FR-005: parse expressions into an AST
- FR-006: normalize expressions before comparison
- FR-007: algebraic equivalence through sampling
- FR-008: domain guards
- FR-009: allowed variables
- FR-010: variable domains
- FR-011: deterministic evaluation
- FR-012: exact-form requirements
- FR-013: optional unit handling
- FR-014: targeted unit feedback
- FR-015: require or ignore units

## Recommended UI Rollout

First, improve Number so authors can handle common numeric grading cases without changing activity type. This gives immediate value for tolerance and decimal precision while preserving the existing numeric workflow.

Second, add Math Expression to Short Answer. This provides the simplest end-to-end authoring path for expression equivalence and lets the team refine the configuration panel in a single-input context.

Third, add Math Expression to Multi-Input using the same configuration panel per blank. This extends the same author model to multi-part questions and avoids creating a separate multi-input math workflow.

Finally, keep legacy Math visible but deemphasized in documentation and examples. New examples should teach Number and Math Expression as the primary choices.
