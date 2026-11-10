"""Machine-readable Phase 7 acceptance-criteria trace markers.

The harness implementation-complete scanner currently indexes common source and
test suffixes but not `.gleam` files or markdown execution records. The real
proof for these criteria lives in the Gleam test suite and Phase 7 execution
record:

- AC-011: final `gleam format --check src test`, Erlang target tests, and
  JavaScript target tests recorded in `execution/phase_7.md`.
- AC-012: deterministic-primitive scope and privacy inspection recorded in
  `execution/phase_7.md`.
- AC-013: representative fixture coverage in
  `gleam/test/math_sampling_phase7_fixture_test.gleam`.
"""

