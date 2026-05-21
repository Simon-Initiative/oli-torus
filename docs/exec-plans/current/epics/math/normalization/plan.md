# Math AST Normalization - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/normalization/prd.md`
- FDD: `docs/exec-plans/current/epics/math/normalization/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/normalization/requirements.yml`

## Scope
Deliver the Level 1 structural normalization layer for parsed Torus Math expressions in shared Gleam code. The plan covers normalized types, structural normalization, normalized formatting, SHA-256 hashing through `gleam_crypto`, public `torus_math` API exposure, and direct Gleam tests on Erlang and JavaScript targets.

Guardrails:
- Do not implement expansion, factoring, cancellation, rational reduction, trigonometric identities, assumption-dependent rewrites, or heuristic simplification.
- Do not duplicate normalization logic in Elixir or TypeScript wrappers.
- Do not change existing parser debug strings or equality APIs.
- Do not add persistent storage, production telemetry, learner-facing UI, or feature flags.
- Add meaningful Gleam documentation comments throughout, especially for every public function, exported type, and non-obvious internal helper that encodes normalization invariants, target-stability assumptions, or domain-preservation rules.

## Clarifications & Default Assumptions
- Public API shape defaults to `structural_normalize`, `normalized_to_debug_string`, and `normalized_hash`; no `normalize_with_options` API is planned for MVP.
- `normalized_hash` uses SHA-256 from `gleam_crypto`, encoded as lowercase hex over the normalized debug string.
- Unit-specific normalized result types are included now, but semantic unit normalization remains unsupported and should emit `UnitSemanticNormalizationUnsupported`.
- Numeric folding starts conservatively. If a literal or folded result cannot be represented consistently on Erlang and JavaScript, preserve raw/source information instead of forcing exact folding.
- Documentation is part of implementation quality, not a final polish pass. Each phase includes a comment/doc review gate.

## Phase 1: Dependencies And Normalized Type Contracts
- Goal: Establish the shared normalized data model and dependency foundation before behavior is implemented.
- Tasks:
  - [ ] Add `gleam_crypto` to `gleam/gleam.toml` and `gleam/manifest.toml` using `cd gleam && gleam add gleam_crypto`.
  - [ ] Create `gleam/src/math/normalization/types.gleam`.
  - [ ] Define `Normalized`, `NormalParsed`, `NormalExpr`, `NormalUnitExpr`, `ExactNumber`, and `NormalizationWarning` per the FDD.
  - [ ] Include unit-specific placeholder result types and `UnitSemanticNormalizationUnsupported`.
  - [ ] Keep `NNegate` and `NDivide` as first-class normalized variants so domain-sensitive structures are not erased.
  - [ ] Add Gleam documentation comments for every exported type and constructor group explaining the invariant each type protects, especially source preservation, domain preservation, and future unit support.
  - [ ] Add brief comments for any helper type aliases or constructors whose purpose is not obvious from the name.
- Testing Tasks:
  - [ ] Compile the type contracts without behavior tests yet.
  - [ ] Confirm formatting includes new files.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
- Definition of Done:
  - `gleam_crypto` is declared and locked.
  - Normalized types compile on the Erlang target.
  - Exported types have clear Gleam documentation comments.
  - No existing parser or equality API behavior changes.
- Gate:
  - Gate A passes when the type model compiles and comments explain all exported normalized contracts.
- Dependencies:
  - Existing parser AST in `gleam/src/math/ast.gleam`.
- Parallelizable Work:
  - Test corpus planning for later phases can proceed in parallel after the type names are stable.

## Phase 2: Structural Normalization Core
- Goal: Implement Level 1 structural normalization over `ast.Expression` without unsafe simplification.
- Tasks:
  - [ ] Create `gleam/src/math/normalization/normalize.gleam`.
  - [ ] Implement recursive conversion from parser `Expr` to `NormalExpr`.
  - [ ] Normalize unary plus by returning the normalized child while preserving original source through `Normalized.original`.
  - [ ] Flatten nested additive and multiplicative structures only where the existing operator semantics remain domain-preserving.
  - [ ] Sort commutative additive and multiplicative operands by explicit node rank plus stable normalized sort key.
  - [ ] Move numeric constants/cofactors to stable positions without collecting like terms.
  - [ ] Implement conservative literal-only numeric folding for safe additions/products.
  - [ ] Preserve `NDivide`, `NNegate`, powers, calls, factorial, abs, and other domain-sensitive forms without rewriting them to simpler unguarded equivalents.
  - [ ] Normalize `ast.Quantity` into `NormalQuantity(value, unit)` with structural unit placeholders and `UnitSemanticNormalizationUnsupported`.
  - [ ] Add Gleam documentation comments at function level for public normalization entry points and for internal helpers that flatten, fold, sort, or intentionally skip domain-sensitive rewrites.
  - [ ] Comment the exact boundary between structural normalization and simplification near the main normalization entry point.
- Testing Tasks:
  - [ ] Add `gleam/test/math_normalization_test.gleam` with initial structural behavior tests for AC-001 and AC-002.
  - [ ] Add non-equivalence/domain-preservation tests for `2(x + 3)` versus `2x + 6`, `x/x`, `(x^2 - 1)/(x - 1)`, `0 * (1 / (x - x))`, `sqrt(x^2)`, and trig identity examples for AC-005.
  - [ ] Add quantity placeholder tests proving unit-specific result types exist but semantic unit normalization is not performed.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
- Definition of Done:
  - Core structural normalization handles the FDD examples.
  - Unsafe simplification examples remain structurally distinct.
  - Function-level comments describe why flattening, sorting, folding, and skipped rewrites are safe or intentionally limited.
- Gate:
  - Gate B passes when Erlang-target tests cover AC-001, AC-002, and AC-005.
- Dependencies:
  - Phase 1 type contracts.
- Parallelizable Work:
  - Normalized debug formatter work can begin once `NormalExpr` constructors are stable.

## Phase 3: Normalized Debug Formatting And Stable Sort Keys
- Goal: Produce deterministic normalized debug strings and stable sort keys independent of runtime inspect output.
- Tasks:
  - [ ] Create `gleam/src/math/normalization/format.gleam`.
  - [ ] Implement `normalized_to_debug_string`.
  - [ ] Implement stable node ranks: numbers, constants, variables, powers, products, sums, calls, abs, factorial, negate, divide, and unit placeholders.
  - [ ] Implement sort-key formatting used by normalization sorting.
  - [ ] Ensure normalized formatting is separate from existing parser debug formatting in `gleam/src/math/format.gleam`.
  - [ ] Add Gleam documentation comments for public formatter functions and internal sort-key helpers, explicitly documenting target-stability requirements and why inspect output is forbidden.
  - [ ] Review all helper names for clarity and avoid abbreviations that make normalized strings harder to audit.
- Testing Tasks:
  - [ ] Add tests asserting structurally equivalent expressions produce the same normalized debug string for AC-001.
  - [ ] Add tests asserting Level 1 non-equivalent examples produce different normalized debug strings for AC-002 and AC-005.
  - [ ] Add repeated-run determinism tests for normalized debug strings for AC-004.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Normalized debug output is stable and covered on both targets.
  - Existing parser debug output remains unchanged.
  - Formatter and sort-key functions have comments explaining their stability contract.
- Gate:
  - Gate C passes when normalized debug output satisfies AC-001, AC-002, AC-004, and AC-005 on Erlang and JavaScript.
- Dependencies:
  - Phase 2 normalization core.
- Parallelizable Work:
  - Hash implementation can start once normalized debug string output is stable.

## Phase 4: SHA-256 Hashing And Public `torus_math` API
- Goal: Expose the normalization API through the public Gleam boundary and implement stable SHA-256 hashes.
- Tasks:
  - [ ] Create `gleam/src/math/normalization/hash.gleam`.
  - [ ] Implement SHA-256 hashing with `gleam/crypto.hash(crypto.Sha256, data)`.
  - [ ] Implement lowercase hex encoding for hash byte output.
  - [ ] Ensure `Md5` and `Sha1` are not used.
  - [ ] Update `gleam/src/torus_math.gleam` to expose `structural_normalize`, `normalized_to_debug_string`, and `normalized_hash`.
  - [ ] Add function-level Gleam comments to each new `torus_math` public API explaining caller responsibilities, structural-only scope, and cross-target determinism.
  - [ ] Add comments in `hash.gleam` explaining why the hash is over the normalized debug string and why the output is lowercase hex.
- Testing Tasks:
  - [ ] Add public API tests that call normalization only through `torus_math` for AC-006.
  - [ ] Add hash determinism tests for AC-004, including stable lowercase hex shape.
  - [ ] Add a test proving hash values match for expressions with equivalent structural normalization and differ for Level 1 non-equivalent examples.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Public APIs compile and are covered by public-boundary tests.
  - Hashes are produced centrally in Gleam and work on both targets.
  - New public functions and hash helpers have explanatory documentation comments.
- Gate:
  - Gate D passes when AC-003, AC-004, and AC-006 are covered through public API tests on both targets.
- Dependencies:
  - Phase 3 stable normalized debug strings.
- Parallelizable Work:
  - Metadata preservation tests can be expanded while hash implementation proceeds, as long as normalized type shape does not change.

## Phase 5: Metadata Preservation And Numeric Folding Boundaries
- Goal: Prove normalization preserves source form and handles exact-number folding conservatively.
- Tasks:
  - [ ] Implement or refine exact-number conversion helpers for integers, decimals, scientific notation, rationals, approximate floats, and large raw values.
  - [ ] Define the first safe integer/rational folding bound in code comments and tests.
  - [ ] Ensure raw numeric literals, notation, decimal places, fraction/division source shape, spans, and multiplication style remain inspectable through `Normalized.original` and normalized source fields.
  - [ ] Add or refine warnings for large exact numbers kept as source strings.
  - [ ] Add Gleam function-level comments for numeric conversion and folding helpers that explain cross-target integer constraints and why raw form is retained.
  - [ ] Review comments for any security-sensitive wording so they do not imply raw student answers should be logged.
- Testing Tasks:
  - [ ] Add metadata preservation tests for `0.80` versus `0.8`, `8/10` versus `4/5`, `1.2e-3` versus `0.0012`, and `2x` versus `2*x` for AC-003.
  - [ ] Add tests for folding within safe bounds and preserving large/out-of-bound numeric forms.
  - [ ] Re-run complete normalization suite on both targets.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - AC-003 is covered with source-form preservation tests.
  - Numeric folding boundaries are explicit in code comments and tests.
  - Cross-target test suite passes.
- Gate:
  - Gate E passes when metadata and numeric-boundary coverage is complete on both targets.
- Dependencies:
  - Phases 2 through 4.
- Parallelizable Work:
  - Final review preparation can proceed in parallel after metadata tests are stable.

## Phase 6: Final Verification, Documentation Review, And Handoff
- Goal: Confirm all requirements are covered, comments are complete, and the work item is ready for implementation review.
- Tasks:
  - [ ] Review all new Gleam modules for public type and public function documentation comments.
  - [ ] Review non-obvious internal helpers for comments that explain invariants, domain-preservation decisions, sort-key stability, hash stability, unit placeholder behavior, and numeric folding boundaries.
  - [ ] Confirm no comments merely restate syntax or encourage logging raw submitted answers.
  - [ ] Confirm no Elixir or TypeScript wrapper duplicates normalization logic.
  - [ ] Confirm no feature flag, storage migration, production telemetry, or learner-facing UI was added.
  - [ ] Run code review against `.review/gleam.md`, `.review/security.md`, and `.review/performance.md`; include `.review/elixir.md` or `.review/typescript.md` only if wrappers were changed.
  - [ ] Update execution notes in this work item if implementation discovers constraints that change the plan.
- Testing Tasks:
  - [ ] Run final Gleam format and both target test suites.
  - [ ] Run targeted broader checks only if Elixir or TypeScript wrappers changed.
  - [ ] Validate plan traceability after implementation references are added in later execution records.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - FR-001 through FR-006 and AC-001 through AC-007 have direct proof in tests or execution notes.
  - Documentation comments are present at exported Gleam types, public functions, and important internal helpers.
  - Final review finds no scope creep into simplification.
- Gate:
  - Gate F passes when final verification commands pass and the comment/documentation review is complete.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Review checklist preparation can happen while final test runs execute.

## Parallelization Notes
- Phase 1 type contracts block most implementation work.
- Test corpus drafting can happen in parallel with Phase 1 once constructor names are stable.
- Debug formatting can proceed in parallel with late Phase 2 once `NormalExpr` shape stabilizes.
- Hashing can proceed after the normalized debug string contract is stable.
- Metadata preservation and numeric-boundary tests can be expanded while public API tests are added, provided normalized type shape is settled.
- Comment review should happen continuously in each phase; Phase 6 is a final audit, not the first time comments are added.

## Phase Gate Summary
- Gate A: Normalized type model compiles, `gleam_crypto` is installed, and exported types have explanatory comments.
- Gate B: Structural normalization core passes Erlang tests for safe equivalence, literal folding, and unsafe non-simplification.
- Gate C: Normalized debug strings and sort keys are deterministic on Erlang and JavaScript.
- Gate D: SHA-256 hashes and public `torus_math` APIs pass both target suites.
- Gate E: Metadata preservation and numeric folding boundary tests pass on both targets.
- Gate F: Final format/tests/review pass, all required Gleam comments are present, and no scope creep is present.
