# MER-6039 verification

Verified on 2026-10-19 for [MER-6039](https://eliterate.atlassian.net/browse/MER-6039).
The baseline was commit `a660c3661f`; the fixed release used the same checkout with
the changes to `config/config.exs` and `lib/oli/predefined.ex`.

## Full application cold starts

Across three paired runs, median peak resident set size (RSS) decreased from
3.40 GiB to 0.73 GiB, a 78.6% reduction. All six runs reached HTTP/database health
readiness and exited successfully after graceful shutdown.

| Pair | Before peak RSS (MiB) | After peak RSS (MiB) | Before ready (seconds) | After ready (seconds) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 3547.16 | 745.08 | 7.235 | 3.784 |
| 2 | 3262.17 | 726.91 | 8.700 | 1.359 |
| 3 | 3485.80 | 747.52 | 7.220 | 3.453 |

### Environment and method

- Native macOS 27.0.1 on arm64, Elixir 1.19.2, Erlang/OTP 28.1.1,
  Torus 0.35.0, and PostgreSQL 18.6.
- Both releases used `MIX_ENV=prod`, the same dependencies and assets, and the
  repository's release settings. They were built into separate temporary
  directories before and after the source changes:

  ```sh
  MIX_ENV=prod mix release --overwrite --path "$comparison_dir/before"
  MIX_ENV=prod mix release --overwrite --path "$comparison_dir/after"
  ```

- Both used the same newly created, migrated local database, with no seeded course
  or learner data. Runtime settings enabled the normal application server on
  localhost port 46039, disabled TLS redirection and Erlang distribution, selected
  `Cluster.Strategy.Epmd`, disabled ClickHouse OLAP and AppSignal, and selected
  file-based xAPI upload. Required credentials and bucket names were disposable
  local values. Scheduler and application-pool settings retained their defaults.
- Runs alternated before/after three times, with one application process running
  at a time. Each process started through `bin/oli start` with `PHX_SERVER=true`
  from a directory outside either release.
- `/usr/bin/time -l` measured the launched process's maximum RSS in bytes. A local
  poll checked `/healthz` every 100 ms, then allowed ten more seconds of runtime
  before sending SIGTERM. The reported peak covers startup, this observation
  window, and graceful shutdown; it is not aggregate host or container memory.
- Each run used a fresh BEAM process. Filesystem caches were not flushed. The host
  was shared, so readiness times are supporting observations, not a latency
  benchmark. The temporary database, releases, and measurement scripts were removed
  after verification.

These are full application starts, separate from the ticket's earlier Linux/amd64
configuration-parsing experiment (3.24 GiB versus 103 MiB, without starting Torus).
The measurements establish the improvement in this local environment; they do not
set Linux deployment memory limits or establish production workload capacity.

## Release contents and lookup behavior

- Generated `sys.config` decreased from 8,056,559 to 79,151 bytes. The fixed file
  does not contain `world_universities_and_domains_json`.
- Both releases packaged the same 9,683-entry JSON directory, with SHA-256
  `508da54e6c54a0eeda856b1ca9dcf024505c18fe66d3135b50ca4de793b369f8`.
- An isolated `bin/oli eval` in the fixed release confirmed the configuration key
  was absent and lookup returned all 9,683 entries, including the expected name,
  country code, and institution URL, from outside the release directory.
- Temporarily moving only the disposable release's data file confirmed lookup
  returned `[]` when the file was unavailable. The file was restored afterward.

## Regression checks

- Before the fix, the targeted run had 37 tests and two expected failures:
  configuration still contained the payload, and lookup failed without that key.
- After the fix, `mix test test/oli/predefined_test.exs
  test/oli_web/controllers/lti_controller_test.exs` passed all 37 tests. Coverage
  includes entry count and ordering, Unicode names, the first of multiple URLs,
  and the university data embedded in the LTI registration form.
- `mix format` passed for the four changed Elixir files; `git diff --check` passed.
- Required Elixir, security, and performance reviews found no actionable issues.
