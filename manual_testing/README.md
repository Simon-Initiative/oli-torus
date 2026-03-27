# Manual Testing Experiment

This directory holds repository-managed assets for the automated testing experiment.

## Layout
- `schemas/`: canonical schema contracts for test cases, suites, and run reports
- `cases/`: authored YAML test-case definitions
- `suites/`: YAML suite definitions that point at one or more test cases
- `skills/`: browser-execution skills and reference material for the runtime agent
- `tools/`: Python support utilities the advanced runtime may call
- `results/`: local run artifacts written during execution and upload staging
- `tests/`: schema-contract and fixture tests

## Runtime Inputs

The advanced runtime is the primary executor for this work. Human-to-agent
messaging is outside the scope of these repository tools. The in-scope contract
starts after the runtime or agent skill has already resolved structured inputs.

At minimum, the runtime should provide these inputs before execution:

- target suite identifier or case identifier
- target environment label and optional base URL
- optional release, branch, or tag identifier
- optional run label for unique result grouping
- credentials source reference
- repository documentation context paths to load

Secrets such as usernames, passwords, cookies, and tokens must not be stored in
the authored YAML assets or committed run reports.

## Credentials Source References

Execution requests may refer to credentials indirectly through fields such as
`credentials_source_ref`, for example:

- `staging-shared-qa`
- `dev-authoring-smoke`

These references are identifiers only. They are not credential payloads.

## Tooling Entry Points

The support tooling in `tools/manualtest.py` is intended for agent-skill use with
explicit structured arguments, for example:

- `prepare-run --suite smoke --environment-label staging --run-label 20260326t153000z --credentials-source-ref staging-shared-qa`
- `prepare-run --case authoring_smoke --environment-label dev --base-url https://dev.example.org --run-label 20260326t153000z --credentials-source-ref dev-authoring-smoke`
- `normalize-run --manifest /tmp/manifest.json --result /tmp/runtime_result.json --results-root manual_testing/results`
