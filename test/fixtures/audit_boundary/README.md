# Audited account compiler fixtures

Run from the repository root after compiling the selected environment:

```sh
MIX_ENV=dev elixir scripts/check_audit_boundary.exs
MIX_ENV=test elixir scripts/check_audit_boundary.exs
```

The runner copies the real Mix project configuration and app build into a temporary directory, reuses installed dependencies, isolates generated Gleam artifacts, and appends a fixture source directory. It forces the baseline compilation, verifies allowed calls, then checks one forbidden fixture at a time and recompiles successfully after removing it. It does not start Torus, run the test alias, or access the database.

The private production modules are initially shells. Calls to their generated `__info__/1` functions prove module visibility without adding production probe APIs. `CompilerProbe` is a fixture-only internal module with a normal function so that an imported call can also be checked. It belongs to the actual audited boundary; the fixture does not redefine any boundary configuration. No probe functions execute.

Mix task fixtures classify directly into `Oli` and verify facade access plus rejected calls to both private modules. The test-only case uses the real compiled `LiveComponentTests` boundary. These checks cover compiled static calls, including aliases, imports, and captures. They do not claim to intercept dynamic `apply/3`, raw SQL, runtime-loaded `.exs` files, or protocol implementations that Boundary leaves unclassified.
