# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/math/normalization`
Phase: `4 - SHA-256 Hashing And Public torus_math API`

## Scope from plan.md
- Expose the normalization API through the public Gleam boundary.
- Implement stable SHA-256 normalized hashes through `gleam_crypto`.
- Add public API tests for normalized debug strings, hashes, determinism, and structural equivalence boundaries.

## Implementation Blocks
- [x] Core behavior changes
  - Added `gleam/src/math/normalization/hash.gleam`.
  - Implemented SHA-256 hashing with `gleam/crypto.hash(crypto.Sha256, data)`.
  - Encoded hashes as lowercase hex with `gleam/bit_array.base16_encode` and `gleam/string.lowercase`.
  - Kept hashing over the normalized debug string so formatter and hash determinism share one text contract.
  - Did not use `Md5` or `Sha1`.
- [x] Data or interface changes
  - Updated `gleam/src/torus_math.gleam` to expose:
    - `structural_normalize`
    - `normalized_to_debug_string`
    - `normalized_hash`
  - Added function-level comments on each new public API.
- [x] Access-control or safety checks
  - No access-control changes required.
  - Hash/debug output remains developer/test/prototype output and is not wired to learner-facing UI.
- [x] Observability or operational updates when needed
  - No telemetry, storage, feature flag, or operational changes were added.

## Test Blocks
- [x] Tests added or updated
  - Added public-boundary tests that call normalization through `torus_math`.
  - Added hash determinism and lowercase SHA-256 hex shape checks.
  - Added a hash equivalence/non-equivalence test for structurally equivalent expressions and Level 1 non-equivalent expressions.
  - Added a public API metadata preservation check proving `Normalized.original` retains distinct parser source forms for implicit and explicit multiplication.
- [x] Required verification commands run
  - `cd gleam && gleam format --check src test` - passed.
  - `cd gleam && gleam test --target erlang` - passed, 84 tests.
  - `cd gleam && gleam test --target javascript` - passed, 84 tests.
- [x] Results captured
  - Erlang and JavaScript target checks both passed after adding hashing and public APIs.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD, FDD, or plan changes were required; implementation followed Phase 4 as written.
- [x] Open questions added to docs when needed
  - No new open questions were discovered.

## Review Loop
- Round 1 findings:
  - No findings from local review against `.review/gleam.md`, `.review/security.md`, and `.review/performance.md`.
- Round 1 fixes:
  - N/A
- Round 2 findings (optional):
  - N/A
- Round 2 fixes (optional):
  - N/A

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
