# Gleam Review Checklist

> Use this during PR review to catch correctness, maintainability, target-interop, and test gaps in Gleam code. Leave specific, actionable comments with file:line references and suggested fixes. Prefer idiomatic, typed, small-domain APIs over clever abstractions.

---

## 1) Scope And Public Boundaries

- [ ] Changed Gleam code is reviewed only within the diff and directly touched dependencies.
- [ ] Public modules expose a small, stable API; internal lexer/parser/evaluator details stay behind the public boundary such as `torus_math`.
- [ ] Module names are singular and domain-oriented.
- [ ] Public functions and types are named by domain behavior, not implementation mechanics.
- [ ] New dependencies are necessary, pinned in `gleam.toml`/`manifest.toml`, and suitable for both intended targets.

## 2) Type Modeling And Correctness

- [ ] Use custom types and records to model the domain so invalid states are unrepresentable where practical.
- [ ] Replace ambiguous booleans, string enums, magic ints, or sentinel values with descriptive custom type variants when they affect business logic.
- [ ] Prefer exhaustive `case` pattern matching over check-then-assert flows.
- [ ] Do not add catch-all branches that silently accept future variants when every variant should be handled intentionally.
- [ ] Keep type aliases and records descriptive enough to document business rules.
- [ ] Use opaque types when callers should not construct or pattern match on values directly.

## 3) Errors And Fallibility

- [ ] Fallible functions return `Result(success, error)` with descriptive domain error variants.
- [ ] Avoid panics in library/shared code; panics are reserved for top-level unrecoverable application failures.
- [ ] Error variants carry enough structured context for callers and tests without exposing sensitive raw inputs.
- [ ] Use `result.map`, `result.try`, pipelines, and focused helpers to keep success/error paths readable.
- [ ] Decode or parse untrusted boundary data into typed values before using it.

## 4) Idiomatic Gleam

- [ ] All module functions have explicit argument and return type annotations.
- [ ] Imports of functions and constants from other modules stay qualified; only types and constructors are unqualified when it improves readability.
- [ ] Prefer core Gleam libraries such as `gleam/list`, `gleam/result`, `gleam/option`, `gleam/dict`, and project-approved packages instead of hand-rolled equivalents.
- [ ] Keep APIs concrete and approachable; avoid abstract pattern names, category-theory terminology, or generic helper layers unless they remove real duplication.
- [ ] Use full names rather than unclear abbreviations.
- [ ] Keep module boundaries cohesive around domain APIs rather than splitting by design pattern.
- [ ] Prefer pure functions and data transformations for parser/evaluator logic.

## 5) Documentation And Comments

- [ ] Public APIs, exported types, and non-obvious invariants have concise documentation comments.
- [ ] Comments explain domain intent, invariants, target interop, or tricky algorithms rather than restating syntax.
- [ ] Parser/evaluator code documents precedence, associativity, normalization, precision, or compatibility rules when those rules are not obvious from types.
- [ ] Security-sensitive comments do not imply raw student answers, secrets, or sensitive inputs may be logged or returned.

## 6) BEAM / JavaScript Interop

- [ ] Code intended for both targets avoids target-specific APIs unless isolated behind a clear compatibility boundary.
- [ ] Generated JavaScript is consumed through thin TypeScript wrappers; domain logic is not duplicated in TypeScript.
- [ ] Elixir integration calls the public generated module and loads generated package ebin paths consistently.
- [ ] FFI or externals are minimal, typed, and validate dynamic values before converting them into trusted domain types.
- [ ] Public API names avoid BEAM module collisions and remain stable for Elixir and browser callers.

## 7) Testing And Verification

- [ ] Changed pure behavior has direct Gleam tests under `gleam/test`.
- [ ] Shared BEAM/browser behavior is tested with both `gleam test --target erlang` and `gleam test --target javascript`.
- [ ] Tests cover valid cases, invalid inputs, edge cases, and representative regressions.
- [ ] Parser/evaluator tests include precedence, associativity, normalization, diagnostic, and malformed-input cases as applicable.
- [ ] JSON or external-boundary code has round-trip and rejection tests for invalid combinations.
- [ ] Formatting is checked with `gleam format --check src test`.

## 8) Performance And Resource Use

- [ ] Hot parser/evaluator paths avoid accidental repeated full-list scans, unnecessary string rebuilding, or large intermediate structures.
- [ ] Recursive functions have clear termination and bounded stack expectations for realistic inputs.
- [ ] Repeated lookups use suitable data structures from the standard library.
- [ ] No debug printing or expensive diagnostics run on normal hot paths.

## Reviewer Red Flags

- "This fallible function panics or returns an ambiguous sentinel; return `Result` with a descriptive error variant instead."
- "This bool/string flag allows impossible combinations; model the states as a custom type."
- "This catch-all branch hides future variants; match all variants explicitly or document why unknown variants are intentionally equivalent."
- "This logic is duplicated in TypeScript/Elixir; keep the behavior in Gleam and expose it through a thin boundary."
- "This shared module was only tested on one target; run both Erlang and JavaScript Gleam tests."
