# Native Gleam Math Parser - Product Requirements Document

## 1. Overview
This work item defines the first production-oriented proof of concept for a Torus-owned ASCII math expression parser implemented in Gleam. The parser will provide a shared syntax layer that can run on both the BEAM/server side and JavaScript/browser side, returning a stable semantic AST and structured parse errors from the same source implementation.

The primary product value is consistency: authors, students, previews, and grading workflows should eventually rely on one math syntax contract rather than separate client and server behavior. This PRD focuses on the parser foundation, not the evaluator or grading semantics.

## 2. Background & Problem Statement
Torus needs a math expression capability for future math evaluation workflows such as client-side answer validation, server-side grading, expression normalization, variable validation, unit handling, and targeted feedback. Those downstream capabilities depend on a parser that is deterministic, portable, and owned by Torus.

The current proof-of-concept thesis is that a pure Gleam parser can parse the supported calculator-style ASCII math subset into stable Torus-owned types, and that the same golden test suite can pass on both Erlang/BEAM and JavaScript targets. Proving this early reduces the risk of browser/server drift before evaluation and feedback behavior are added.

## 3. Goals & Non-Goals
### Goals
- Establish a pure Gleam math parser foundation that builds and runs for both server and browser targets.
- Produce a stable Torus-owned AST that preserves source metadata needed by later validation, feedback, rendering, telemetry, and exact-form work.
- Return structured parse errors with source spans suitable for later user-facing diagnostics.
- Demonstrate deterministic cross-target behavior through a shared golden test corpus.
- Keep parser, validation, formatting, normalization, evaluation, and unit handling as separate layers.

### Non-Goals
- Algebraic equivalence, numeric tolerance checking, random sampling, variable domain sampling, targeted feedback matching, significant figures, decimal precision grading, LaTeX parsing, and MathJax/KaTeX rendering are not part of this parser milestone.
- Unit parsing, unit conversion, and unit validation are deferred until the pure expression parser contract is stable.
- Production authoring UI, student-facing answer validation UI, and grading workflow integration are not part of this PRD.
- JSON serialization is not part of the core parser contract unless a later browser integration slice requires a thin adapter.

## 4. Users & Use Cases
- Students: eventually receive consistent validation and feedback for math input regardless of whether syntax checking happens in the browser or on the server.
- Authors: eventually configure math activities with confidence that preview, validation, and grading use the same syntax interpretation.
- Learning engineers and assessment designers: need a stable AST foundation for normalization, equivalence, and feedback rules.
- Torus engineers: need a single portable parser implementation with deterministic tests before layering evaluation and UI behavior on top.

## 5. UX / UI Requirements
- No production UX changes are required for this parser PRD.
- Developer-facing demos may show input, parsed AST/debug output, and structured errors to prove server/browser parity.
- Future user-facing UI must map structured parser errors to accessible, localized, and context-appropriate messages without exposing implementation internals.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: the same input must produce equivalent parse success, AST shape, metadata, or parse error on both supported Gleam targets.
- Portability: the core parser must avoid target-specific externals so browser and server behavior cannot drift by runtime.
- Maintainability: parser, validation, formatting, and future evaluation concerns must remain separate modules or layers.
- Diagnosability: parse failures must retain enough source-position context to support later highlighting and clear messages.
- Privacy: parser diagnostics, telemetry, and debug tooling must not require storing raw student input in production logs.
- Extensibility: the AST and token metadata must leave room for later units, validation, normalization, evaluation, exact-form rules, and feedback.

## 9. Data, Interfaces & Dependencies
- Primary implementation location is the top-level `gleam/` project.
- Torus application code should depend on a small public Gleam math API and Torus-owned AST/error types, not lexer or Pratt-parser internals.
- Server integration should continue through an Elixir boundary module under `lib/oli/` once the public parser contract is available.
- Browser integration should consume compiled Gleam JavaScript modules from `gleam/build/dev/javascript` through the existing asset pipeline.
- The parser data model must preserve spans, raw numeric literal form, numeric notation metadata, and multiplication style where applicable.
- Validation configuration for allowed symbols and functions is a separate interface from syntactic parsing.

## 10. Repository & Platform Considerations
- Torus is a Phoenix application with TypeScript assets and focused browser integrations; parser logic belongs in the shared Gleam project rather than duplicated in Elixir and TypeScript.
- Backend domain boundaries remain under `lib/oli/`; LiveViews, controllers, and browser hooks should call domain or public parser boundaries rather than parser internals.
- Webpack remains the browser bundling path for compiled Gleam JavaScript.
- Required verification should include targeted Gleam tests for both Erlang and JavaScript targets, plus any affected Elixir or TypeScript checks for integration slices.
- Code review should include security and performance review by default, plus Elixir and TypeScript review when integration files are changed.
- No Jira issue was provided with this request; any execution ticket should link back to this work item if created.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Parser POC success is measured by cross-target test pass rate, golden corpus coverage, and stability of AST/debug output across parser changes.
- The parser core should not emit production telemetry directly in this milestone.
- Future product integration should consider aggregate parse-success and parse-error-category telemetry without recording raw student expressions.

## 13. Risks & Mitigations
- Identifier ambiguity: reserve exact constants and supported function-call syntax, use deterministic single-letter-variable parsing for other alphabetic runs, and leave author-specific symbol restrictions to validation.
- Implicit multiplication ambiguity: define deterministic parser behavior and defer ambiguity warnings or author linting to a later validation layer.
- Unit ambiguity: defer unit parsing until expression parsing is stable, while preserving token metadata needed for a future value/unit boundary.
- Runtime differences: keep parsing pure, preserve raw literals, avoid evaluator semantics in the parser milestone, and require both Erlang and JavaScript test runs.
- Error-message churn: return structured errors from the parser and keep user-facing message formatting outside the core parser.

## 14. Open Questions & Assumptions
### Open Questions
- Should browser integration require JSON serialization of ASTs in the first follow-up slice, or is stable debug output sufficient until UI work begins?
- Should the MVP reject likely missing-parentheses function input during parsing, validation, or both for best author/student feedback?
- Which downstream math activity or evaluation workflow will be the first production consumer of the parser contract?

### Assumptions
- Single-letter-variable mode is acceptable for the first parser milestone.
- The mathematical constant for Euler's number is reserved in the parser for the first milestone rather than treated as an author-configurable variable.
- Unit syntax is important but intentionally deferred until the expression AST and cross-target test corpus are stable.
- The first milestone may include developer-only demos, but it does not expose new learner-facing behavior.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add golden parser tests for accepted syntax categories, rejected syntax categories, precedence behavior, structured errors, and stable debug output.
  - Run affected `mix test` targets for any Elixir boundary changes.
  - Run affected `yarn` checks for any browser integration changes.
- Manual validation:
  - Use a developer-only demo or console workflow to compare representative server and browser parse results.
  - Inspect representative structured errors for useful spans and future UI-message mapping.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
- [ ] Parser source builds for Erlang and JavaScript targets
- [ ] Shared golden tests pass on both targets
- [ ] Parser behavior remains separated from evaluation and production UI concerns
