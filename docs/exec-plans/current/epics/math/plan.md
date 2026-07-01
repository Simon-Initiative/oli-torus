# Math Feature Roadmap

## Purpose

This is the high-level roadmap for the broader Torus Math feature after the completed native Gleam parser milestone. It is intentionally not a phase-by-phase implementation plan. Each entry is a major feature layer with a description, rough included scope, and the reason it belongs in this sequence.

The core product direction from the surrounding docs is:

- Treat math as an evaluation capability inside existing Torus activities, not as a new activity type.
- Improve existing Number inputs for scalar numeric answers.
- Add Math Expression as the new expression-capable input mode for algebra, variables, form constraints, and units.
- Keep legacy Math available as exact-LaTeX comparison for existing content and intentional legacy use.
- Build the capability one semantic layer at a time so parser, normalization, evaluation, feedback, activity runtime, and authoring UI do not collapse into one risky release.

## Current Foundation: Parser Complete

The parser milestone under `docs/exec-plans/current/epics/math/parser` is complete and should be treated as the foundation for the remaining roadmap.

It provides:

- A pure Gleam parser exposed through `torus_math`.
- Shared Erlang and JavaScript target support.
- Stable AST values for the MVP ASCII expression syntax.
- Structured parse errors with spans.
- Numeric literal metadata, source spans, whitespace metadata, and explicit/implicit multiplication metadata.
- Validation for allowed variables and functions.
- Stable debug formatting for demos and golden tests.
- Thin Elixir and browser wrappers plus a developer-only Math Prototype LiveView.

It intentionally does not provide:

- Normalization.
- Numeric grading.
- Algebraic equivalence.
- Unit parsing or conversion.
- Exact-form grading.
- Feedback rule matching.
- Activity evaluation integration.
- Production authoring or student UI changes.

## Sequencing Principles

- Build semantic layers before building author-facing controls for them.
- Keep parser, normalization, evaluation, unit handling, feedback, and UI as separable modules.
- Reuse the same Gleam core for server and browser behavior whenever practical.
- Make every layer deterministic before it becomes part of grading.
- Prefer focused, testable equality contracts before wiring into Short Answer or Multi-Input.
- Do not log raw learner expressions by default; future telemetry should use aggregate categories or hashes where possible.
- Preserve backward compatibility for existing Number, Text, Dropdown, and legacy Math content.

## Feature Sequence

### 1. Equality Contract And Configuration Model

Define the stable shape that compares an expected answer with a student answer under a JSON-encodable equality configuration.

This contract should not decide which feedback to return. Torus already determines the matched response and feedback inside the activity evaluation flow. The math equality API should only answer whether a candidate equals the expected answer according to the response's configured math rules.

This feature is intentionally thin at runtime but important at the type-design level. The center of the feature is a rich Gleam algebraic data type for `equalityConfig`. That type should model the valid author choices as sum and product types, including the parameters each choice requires, so invalid combinations are hard to construct in code and easy to reject at JSON boundaries.

The config type should be designed as the future source of truth for authoring UI choices. The UI will eventually let authors choose how equality should be measured for a response; this Gleam type should already express those valid choices clearly enough that the UI can map to it without inventing parallel semantics.

Includes:

- Public equality input contract: student answer, expected answer, equality config, and optional deterministic context.
- Public equality output contract: equal/not-equal plus structured diagnostic details for debugging, preview, and later UI messaging.
- A first-class Gleam `equalityConfig` algebraic data type, with sum/product types that represent valid equality modes and their required parameters.
- JSON-encodable representation of that Gleam config so it can be stored on a configured Response object.
- Numeric equality modes, including current scalar operators such as equal, not equal, greater than, greater than or equal, less than, less than or equal, between, and not between.
- Numeric tolerance parameters, including no tolerance, absolute tolerance, relative tolerance, and combined absolute/relative strategies.
- Algebraic expression modes, including exact expression/form comparison and algebraic equivalence through later normalization and sampling.
- Expression validation parameters, including allowed variables, variable domains, allowed functions, and deterministic seed/sample settings.
- Form constraint parameters, including integer-only, fraction/rational, simplified fraction, and decimal precision requirements.
- Unit-aware equality parameters, including units ignored, units required, accepted units, strict unit requirements, and conversion policy.
- Type-level separation between valid modes; for example, range bounds should belong to range comparisons, sample counts should belong to algebraic equivalence, and unit conversion settings should belong to unit-aware comparisons.
- Elixir and TypeScript adapters that preserve the same JSON shape without requiring callers to know Gleam internals.
- Result taxonomy for parse errors, validation errors, domain violations, non-equivalence, unit failures, and form failures.
- Golden contract fixtures that can be reused across later equality features.

Design emphasis:

- Spend the effort here on getting the algebraic data type correct, not on implementing all equality behavior.
- Prefer explicit variants over loosely typed option bags.
- Make illegal states unrepresentable in Gleam where practical, and explicitly invalid at the JSON decode boundary where not.
- Keep the API small: the primary behavior can be a parse/decode/validate contract for config plus a placeholder or narrow equality entry point that later features fill in.
- Document each config variant with the authoring intent it represents, because those variants become the vocabulary for the authoring UI.

Future Torus integration target:

- `equalityConfig` should be designed so it can hang off each configured Response object as a new attribute.
- `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex` can eventually invoke the math equality API from the existing activity evaluation flow.
- `lib/oli/delivery/evaluation/evaluator.ex` can eventually use the API inside the current reduce loops that compare submitted responses against configured responses.
- The existing evaluator code will still know which Response/Feedback matched and which feedback to return; the math contract only replaces the equality predicate for math-aware responses.

Why this comes first:

- Without a stable JSON equality contract, later layers will leak implementation details into Response JSON, activity evaluation, and authoring UI schemas.

### 2. Numeric Scalar Evaluation For Number Inputs

Upgrade and unify the existing standard/basic page Number input evaluator before full Math Expression grading. This must preserve the numeric comparison behavior Torus already supports in the standard response-rule evaluation path while adding the new tolerance and precision semantics. It delivers immediate value and establishes comparison/tolerance semantics reused by expression sampling.

Adaptive page evaluation is explicitly not part of this feature. Existing adaptive numeric handling in `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` should continue to execute as-is on the adaptive branch unless a later, separate work item changes it.

Includes:

- Parity with current standard response-rule numeric operators from `assets/src/data/activities/model/rules.ts` and `lib/oli/delivery/evaluation/rule.ex`:
  - Equal to: `eq`, currently encoded as `input = {value}`.
  - Not equal to: `neq`, currently encoded as the inverse of equality.
  - Greater than: `gt`, currently encoded as `input > {value}`.
  - Greater than or equal to: `gte`, currently encoded as greater-than OR equality.
  - Less than: `lt`, currently encoded as `input < {value}`.
  - Less than or equal to: `lte`, currently encoded as less-than OR equality.
  - Between: `btw`, currently encoded as a range equality rule such as `input = {[lower,upper]}` or `input = {(lower,upper)}`.
  - Not between: `nbtw`, currently encoded as the inverse of the range rule.
- Parity with current range behavior:
  - Inclusive ranges with `[` and `]`.
  - Exclusive ranges with `(` and `)`.
  - Bounds accepted in either order on the Elixir side for non-variable authored values.
  - Existing precision suffixes such as `#3` on scalar and range numeric rules.
- A JSON-encodable numeric equality config shape that can represent all current numeric comparison semantics for newly authored or migrated configurations.
- Absolute tolerance.
- Relative tolerance with stable near-zero handling.
- Numeric representation equivalence for integer, decimal, and scientific notation when form rules allow it.
- Decimal precision rules independent of numeric tolerance: exactly, at least, and at most N decimal places.
- Compatibility strategy for the current `#precision` behavior, which is currently interpreted as significant figures in `Rule.check_precision/2`.
- Clear separation between legacy significant-figures behavior and the new decimal-place precision controls, so migrating Number input behavior does not silently change existing authored content.
- Focused tests for every existing operator, inclusive/exclusive ranges, inverted comparisons, precision suffixes, edge cases near zero, very large values, scientific notation, and precision conflicts.

Why this comes before algebra:

- Algebraic sampling eventually compares numeric results at sampled points, so the tolerance model should be proven first.
- Number inputs can improve independently without changing activity type or author mental model.
- A unified math equality engine cannot replace the current standard evaluator reduce-loop predicate until it can faithfully represent existing Number response comparisons.
- Legacy rule-string compatibility is handled later at the Torus activity evaluation integration boundary, not inside this numeric semantics layer.

### 3. Normalization And Canonical Expression Forms

Add a deterministic normalization layer over parsed ASTs without making correctness decisions yet.

Includes:

- AST-to-normal-form transformation.
- Constant folding.
- Canonical ordering for commutative addition and multiplication.
- Safe flattening of associative operators.
- Basic rational/fraction representation where needed for later exact-form checks.
- Stable normalized debug strings and normalized hashes.
- Preservation of source metadata needed for feedback and form checks.
- Tests proving normalization is deterministic across Erlang and JavaScript targets.

Why this comes before equivalence:

- Algebraic expression equivalence needs a common internal representation before sampling or comparison rules can be trusted.

### 4. Deterministic Expression Evaluation And Sampling Infrastructure

Implement pure numeric evaluation of parsed or normalized expressions at concrete variable assignments.

Includes:

- Evaluation of numbers, constants, variables, arithmetic operators, powers, supported functions, absolute value, and factorial where valid.
- Structured runtime math errors such as division by zero, invalid root, invalid logarithm, undefined tangent, and invalid factorial.
- Variable assignment model.
- Seeded sampling point generation.
- Variable domain config: ranges, exclusions, integer-only sampling, and default domains.
- Sampling retry behavior when generated points hit invalid domains.
- Deterministic behavior for repeated runs with the same seed and config.
- Performance checks on representative expression corpora.

Why this comes before equivalence:

- Equivalence is a policy over repeated deterministic evaluations. The evaluator and sampler must be independently correct first.

### 5. Algebraic Expression Equivalence

Use normalization plus deterministic sampling to decide whether a student expression is mathematically equivalent to the expected expression within configured domains and tolerances.

Includes:

- Equivalent expression mode for Math Expression inputs.
- Comparison of expected and candidate expressions over N sampled points.
- Reuse of numeric tolerance semantics from Number evaluation.
- Domain guard handling for expressions that are undefined at some points.
- Allowed-variable validation as part of the evaluation path.
- Configurable sample count as an advanced setting.
- Golden corpus for common identities and near-miss failures.
- Clear distinction between syntax failure, validation failure, domain failure, and non-equivalence.

Why this comes after normalization and sampling:

- It depends on normalized ASTs, numeric evaluation, variable domains, seeded sampling, and tolerance semantics.

### 6. Exact Form And Representation Constraints

Layer form requirements on top of semantic correctness. A response can be mathematically correct but still fail an author-required representation rule.

Includes:

- Integer-only form.
- Fraction/rational-only form.
- Simplified fraction form.
- Decimal form with precision rules.
- Representation checks using raw numeric literals and AST source metadata.
- Form-specific feedback categories such as unsimplified fraction or wrong form.
- Tests that prove form checks do not replace numeric or algebraic correctness checks.

Why this comes after equivalence:

- Form constraints should refine an already-understood correctness result. They should not be the first evaluator layer that decides whether two expressions mean the same thing.

### 7. Unit Syntax, Dimension Model, And Unit-Aware Evaluation

Add quantity support only after expression value evaluation is stable. Units should be parsed and validated without destabilizing expression parsing.

Includes:

- Quantity parse result: expression value plus unit expression.
- Unit grammar for atoms, multiplication, division, and integer powers.
- Initial unit catalog for common SI and derived units needed by target disciplines.
- Unit normalization to canonical dimensions.
- Unit conversion when allowed.
- Required, ignored, accepted-list, and strict-unit modes.
- Targeted unit outcomes: missing unit, wrong-but-convertible unit, incompatible unit, and unit not accepted.
- Tests for values such as `9.8 m/s^2`, `980 cm/s^2`, and `10 N`.

Why this comes after expression evaluation:

- Unit support depends on a trusted numeric value evaluator and introduces value/unit boundary ambiguity that should not be mixed into earlier parser or equivalence work.

### 8. Feedback Rules, Partial Credit, And Author Linting

Add math-aware feedback and scoring policy after evaluator outcomes are structured and reliable.

Includes:

- Predefined feedback rule library for syntax error, unexpected variable, domain violation, wrong form, unsimplified fraction, missing unit, wrong convertible unit, and incompatible unit.
- Rule evaluation modes: first-match and accumulate.
- Partial credit score handling within bounded score ranges.
- Author-defined rule hooks or predicates only after predefined rules are stable.
- Linting for unreachable rules, catch-all ordering problems, conflicting form settings, tolerance contradictions, empty unit lists, invalid score ranges, and risky domains.
- Preview-facing messages with suggested fixes.
- Publish-blocking error lints and visible warning lints.

Why this comes after units and forms:

- Feedback rules should be driven by real evaluator result categories, not by speculative string matching.

### 9. Preview, Diagnostics, And Browser Adapters

Expose the evaluator safely to author preview and browser-side validation before production grading integration.

Includes:

- Browser-facing serialization for parsed, normalized, or evaluated results where needed.
- Human-readable diagnostics that map structured errors into author/student language.
- Developer and author preview of candidate answers against expected answers.
- Live syntax and validation preview using the shared parser.
- Rendered math preview path through MathJax or KaTeX if needed for Math Expression input confidence.
- "How do I enter math?" examples for supported ASCII syntax.
- Privacy review for preview and diagnostics so raw expressions are not sent to unrelated telemetry.

Why this comes before activity runtime integration:

- Authors and developers need a trustworthy preview surface before the evaluator starts affecting learner scores.

### 10. Integration Into Torus Activity Evaluation

Wire the evaluator into Torus grading paths after the evaluator, feedback, linting, and preview semantics are established.

Includes:

- Number input evaluation updates for existing activities.
- A permanent compatibility component for existing activity models that still store numeric comparisons as legacy response rule strings.
- Evaluation-time in-memory translation from legacy numeric rule strings into the new JSON `equalityConfig` shape before invoking the unified math equality engine.
- Preservation of existing persisted activity content: old activities should not need migration before they can be evaluated by the new engine.
- Support for legacy standard response rules from `lib/oli/delivery/evaluation/rule.ex` and `assets/src/data/activities/model/rules.ts`, including scalar comparisons, inverted comparisons, ranges, inclusive/exclusive bounds, and `#precision` suffixes.
- Math Expression evaluation in Short Answer.
- Math Expression evaluation per blank in Multi-Input.
- Independent per-input evaluation config for Multi-Input.
- Existing scoring aggregation support, including sum-of-parts and all-or-nothing where applicable.
- Backward compatibility for legacy Math exact-LaTeX behavior.
- Attempt result details suitable for feedback display and analytics.
- Security, performance, and privacy review for production grading paths.
- Scenario or integration tests for authoring, delivery, attempt evaluation, and feedback outcomes.

Why this is near the end:

- This is the point where evaluator behavior affects learner scoring, so all lower-level semantics need to be stable first.

### 11. Update Activity Authoring UIs

Expose the completed evaluator capability through existing activity authoring workflows.

Includes:

- Number Answer Key panel updates for tolerance, numeric representation, and decimal precision.
- New Math Expression input type in Short Answer.
- New Math Expression input type per blank in Multi-Input.
- Shared Math Expression configuration panel for correct answer, evaluation method, variables, domains, answer form, tolerance, units, feedback rules, and preview.
- Author-facing validation and lint display.
- Clear distinction between Number, Math Expression, and legacy Math.
- Compact labels such as "Expression" where inline Multi-Input surfaces have limited space.
- Accessible controls, keyboard-friendly workflows, and clear help/examples.
- Documentation and migration guidance that avoids silently changing existing content behavior.

Why this is last:

- Authoring UI should configure already-working evaluator semantics. Building the UI last avoids designing controls for behavior that is not yet implemented or stable.

## Deferred Expansion Candidates

These are important capabilities from the source docs, but they should be planned after the first production Math Expression path is proven end to end.

- Significant figures policies distinct from decimal places.
- Advanced exact forms such as factored, expanded, simplified radical, or style/complexity constraints.
- Cross-input constraints and shared variables across multiple blanks.
- Richer custom unit systems and discipline-specific unit catalogs.
- Function equality beyond algebraic expression equivalence.
- Composite numeric types such as vectors and matrices.
- Enhanced partial credit with weighted rule groups.
- Per-learner hints based on repeated error patterns.
- Pluggable evaluator test architecture for future test types.
- Step checking and line-by-line work evaluation.
- Calculus-specific derivative and integral recognition.
- Graph and geometry input evaluation.
- Programmatic variant generation with symbolic parameters.
- Optional CAS integration if native normalization and sampling are insufficient for future requirements.

## Dependency Summary

```text
Completed parser
  -> equality contract/config
  -> numeric scalar evaluation
  -> normalization
  -> deterministic expression evaluation and sampling
  -> algebraic expression equivalence
  -> exact form constraints
  -> unit-aware evaluation
  -> feedback rules and author linting
  -> preview and diagnostics
  -> Torus activity evaluation integration
  -> activity authoring UI updates
```
