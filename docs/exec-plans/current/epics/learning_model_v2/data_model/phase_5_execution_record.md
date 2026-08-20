# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/data_model`
Phase: `5`

## Scope from plan.md

- Preserve exact Project and Product learning-model selections through modern and legacy archives.
- Preserve optional typed LO and activity parameter envelopes through export/import.
- Reject invalid explicit archive configuration with bounded file/resource context and transactional rollback.
- Retain set-based export query behavior.

## Implementation Blocks

- [x] Core behavior changes
  - Project and Product JSON now export their persisted semantic model strings.
  - LO and activity resource JSON conditionally export canonical `learningModelParameters` envelopes.
  - Project and Product ingest use `ModelVersion.decode_archive/2` with the specified Project and Product fallbacks.
  - Objective and activity bulk ingest decode and validate typed envelopes before `Repo.insert_all/3`.
- [x] Data or interface changes
  - Added trusted archive-specific Project and Blueprint creation boundaries so divergent imported values are preserved without exposing model selection to ordinary changesets or UI paths.
  - Generic objective `parameters` remains independent from `learning_model_parameters`.
  - The ingest parser records each resource's authoritative archive filename separately from its JSON `id`, allowing downstream validation errors to name the actual source file.
- [x] Access-control or safety checks
  - External strings are decoded through fixed matching; no atoms are created from archive input.
  - Explicit invalid selection or parameter data rolls back the complete ingest transaction with bounded archive file/resource context.
  - Missing/null selections use only the documented fallbacks; missing parameter properties persist as `nil`.
- [x] Observability or operational updates when needed
  - Existing ingest error reporting is reused; errors identify the relevant field and bounded authoritative archive filename without dumping complete resource payloads.
  - The v2 ingest LiveView converts controlled transactional rollback state into a render-safe message instead of attempting to render the internal State struct.

## Test Blocks

- [x] Tests added or updated
  - Direct Project, Product, LO, and activity JSON assertions.
  - Full divergent-selection and typed-parameter round trip, including two activity parts and explicit `0.0`.
  - Missing/null legacy fallback coverage and Product inheritance from an explicit Project value.
  - Invalid selection type/value and invalid parameter version/type/number/part rollback coverage.
  - Both LO/activity resource-type mismatch directions and misleading internal IDs versus authoritative archive filenames.
  - Product export query-count comparison with one versus two Products.
- [x] Required verification commands run
  - `mix test test/oli/interop/export_test.exs test/oli/interop/ingest_test.exs test/oli/interop/ingest/scalable_ingest_test.exs test/oli_web/live/ingest/ingestv2_test.exs`
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `git diff --check`
- [x] Results captured
  - Final focused Phase 5 suite: 27 tests, 0 failures.
  - Formatting, warning-free compilation, and whitespace checks passed.
  - A broader `test/oli/interop` run was attempted but application startup encountered a pre-existing local test-database inconsistency: migration `20240513230512` is marked up while table `pending_uploads` is absent. The required focused suite starts and passes against the same environment.

## Acceptance-Criteria Proof Map

- `AC-008` through `AC-012`: `lib/oli/interop/export.ex`, Project/Product processors, trusted archive creation boundaries, and interop export/ingest tests.
- `AC-014` through `AC-016`, `AC-018`, `AC-020`, and `AC-024`: conditional resource export, shared pre-insert decode/validation, and typed parameter round-trip/rollback tests.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - The plan now names the archive-specific trusted creation boundaries used to retain the Phase 2 mass-assignment protections.
- [x] Open questions added to docs when needed
  - No new open question was introduced.

## Review Loop

- Round 1 findings:
  - Elixir review found that controlled Processor rollback State reached the v2 ingest LiveView unchanged and could fail HTML rendering.
  - Elixir review found that Product validation used the JSON-controlled internal ID rather than the authoritative archive filename.
  - Requirements review requested mutation-resistant Product-null inheritance proof, additional unsupported/mismatched envelope ingest cases, and accurate command/proof records.
  - Security and performance reviews were clean.
- Round 1 fixes:
  - Normalized v2 ingest failures to a bounded render-safe string and added regression coverage.
  - Added an authoritative source-file projection during parsing and used it for Product and Revision-parameter diagnostics.
  - Added explicit `:lkt_aoa` Project plus null Product inheritance, both mismatch directions, unsupported model/parameter versions, rollback, and source-file context coverage.
- Round 2 findings:
  - Elixir, security, and performance reviews were clean.
  - Requirements review requested direct authoritative-filename proof for a parameter-envelope failure and two proof-map additions.
- Round 2 fixes:
  - Added a parameter failure whose internal resource ID deliberately differs from its archive filename.
  - Added the Activity mapper to `AC-015` proof and Phase 5 explicit-zero proof to `AC-018`.
- Final review: all applicable review guides report no remaining actionable findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
