# Eval Engine Lambda Approach

Last updated: 2026-04-08

## Purpose

This document captures a high-level approach for migrating `authoring-eval` from a Docker-hosted Express service to AWS Lambda for Torus dynamic-question variable evaluation.

The goal is to preserve existing authoring and delivery behavior while replacing the long-running container deployment with an on-demand Lambda execution model and reducing the operational risk around untrusted JavaScript execution.

## Executive Recommendation

Move the evaluator to a dedicated AWS Lambda function, retain `vm2` for the initial migration, and do not treat `vm2` as the primary security boundary.

Recommended target shape:

- Torus invokes the evaluator Lambda directly via AWS SDK / `ExAws.Lambda.invoke`, not through API Gateway.
- The Lambda implementation lives in [`assets/src/eval_engine`](assets/src/eval_engine).
- The Lambda contains only evaluator code and the minimal dependencies required to support `vm2`-based evaluation.
- The Torus browser/client contract remains stable through `/api/v1/variables`.
- The initial migration definitely retains `vm2`; replacing it is explicitly out of scope for the first cut.
- Build support should follow the existing node-bundle pattern already used for the rules Lambda so the evaluator compiles to a single deployable JavaScript artifact.

Bottom line on `vm2` in Lambda:

- `vm2` is technically usable in Lambda.
- `vm2` is not sufficient by itself for strong isolation of arbitrary untrusted code.
- Lambda helps only if the function is treated as the real blast-radius boundary: dedicated function, minimal IAM, no sensitive environment variables, no privileged network access, tight timeout/memory/concurrency settings, and no trust in the sandbox escaping problem being fully solved.

## Current-State Findings

### `authoring-eval`

Local inspection shows:

- The current service surface is extremely small: `POST /sandbox` calls `evaluate(req.body.vars, req.body.count)` from [`../authoring-eval/src/server.ts`](../authoring-eval/src/server.ts).
- The Express server and clustering are transport concerns only. The evaluator core is already synchronous, stateless request logic in [`../authoring-eval/src/eval.ts`](../authoring-eval/src/eval.ts).
- The project is very old operationally:
  - Node `>= 8.0.0`
  - TypeScript `3.0.1`
  - Jest `24`
  - `vm2 ^3.9.19`
- The deployment is currently container-oriented via [`../authoring-eval/Dockerfile`](../authoring-eval/Dockerfile) and [`../authoring-eval/docker-compose.yml`](../authoring-eval/docker-compose.yml).

### Torus Integration

Local inspection of Torus shows:

- Torus currently defaults variable substitution to a REST provider pointing at `http://localhost:8000/sandbox` in [`config/config.exs`](config/config.exs).
- Torus already has a stub Lambda provider at [`lib/oli/activities/transformers/variable_substitution/lambda_impl.ex`](lib/oli/activities/transformers/variable_substitution/lambda_impl.ex).
- The browser authoring UI does not call `authoring-eval` directly. It calls Torus `/api/v1/variables` through [`assets/src/data/persistence/variables.ts`](assets/src/data/persistence/variables.ts), and Torus proxies from there.

This is important because it means the main client-facing contract can remain unchanged.

## Proposed Architecture

### Invocation Path

Recommended request path:

1. Browser or authoring UI calls Torus `/api/v1/variables` as it does today.
2. Torus `VariableEvaluationController` calls `VariableSubstitution.Strategy.provide_batch_context/1`.
3. `VariableSubstitution.LambdaImpl` directly invokes the AWS Lambda function with the same logical payload shape currently sent to `/sandbox`.
4. Lambda validates the payload, evaluates variables, and returns JSON in the same shape Torus already expects.

This avoids introducing API Gateway, Function URLs, or another public surface unless there is a separate non-Torus caller that truly needs HTTP access.

### Lambda Shape

The Lambda should be a small Node.js function with:

- modern runtime: `nodejs22.x`
- a single handler such as `assets/src/eval_engine/index.ts`
- request validation and response normalization
- evaluator core extracted into a reusable module
- structured logging and metrics

Recommended logical module split:

- `assets/src/eval_engine/index.ts`
- `assets/src/eval_engine/evaluator.ts`
- `assets/src/eval_engine/sandbox/first_gen.ts`
- `assets/src/eval_engine/sandbox/module_gen.ts`
- `assets/src/eval_engine/contracts.ts`
- `assets/src/eval_engine/package.json` if dependency isolation or packaging constraints require a colocated manifest

### Build and Packaging Shape

The implementation should use the same packaging pattern already used for the rules Lambda.

Local findings:

- [`assets/webpack.config.node.js`](assets/webpack.config.node.js) currently bundles the rules Lambda from `assets/src/adaptivity/rules.ts`.
- [`assets/package.json`](assets/package.json) exposes `deploy-node`, which runs `webpack --mode production --config webpack.config.node.js`.
- The current node bundle output path is `priv/node` with CommonJS output.
- [`assets/tsconfig.node.json`](assets/tsconfig.node.json) is currently scoped to the rules entrypoint.

Recommended eval-engine build approach:

- add a new webpack node entry for the evaluator, parallel to `rules`
- compile the evaluator sources into a single JavaScript file under `priv/node`
- prefer an artifact name aligned with the Lambda function, such as `priv/node/eval.js`
- update `tsconfig.node.json` so the eval-engine entry is included, or broaden the node-build tsconfig to cover both Lambda entrypoints
- continue using the top-level `assets/package.json` build toolchain unless `vm2` packaging forces a separate nested package

For the first migration, prefer reusing the existing `assets` webpack build rather than introducing a separate packaging system.

### Security Boundary

Treat the Lambda function, not `vm2`, as the meaningful isolation boundary.

The function should run with:

- a dedicated IAM role with only CloudWatch logging permissions unless additional access is explicitly required
- no database credentials
- no Torus secrets
- no VPC attachment unless absolutely required
- low timeout
- bounded memory
- reserved concurrency sized intentionally

If sandboxed code escapes `vm2`, the attacker should gain almost nothing of value.

## `vm2` Viability In AWS Lambda

### What the web investigation shows

Research date: 2026-04-08.

Key findings:

- AWS Lambda supports current managed Node runtimes including `nodejs22.x`, and reuses warm execution environments between invocations. `/tmp` contents and in-memory objects can survive warm reuse.
- Lambda execution environments are isolated, but code inside one function still shares that function's permissions and environment.
- `vm2` is no longer in the exact state many teams remember from mid-2023:
  - GitHub advisory `GHSA-g644-9gfx-q4q4` was published on July 12, 2023 for a critical sandbox escape affecting old versions.
  - The `vm2` GitHub repository now shows active maintenance again and a latest release `v3.10.5` on February 17, 2026 with multiple sandbox-escape fixes in the release notes.
- The current `vm2` maintainers explicitly warn that in-process sandboxing is fundamentally fragile, that new bypasses will likely continue to be found, and that for completely untrusted code stronger isolation guarantees are recommended.

### Practical conclusion

`vm2` can run inside Lambda because it is a Node library and the current evaluator only uses `VM`, not `NodeVM`.

However, for this workload the correct answer is:

- usable: yes
- acceptable as the only isolation layer: no
- acceptable as a compatibility layer inside a dedicated low-privilege Lambda: yes, with caution

For this migration, that compatibility-layer approach is the chosen Phase 1 implementation strategy.

### Additional concerns from the current implementation

The current evaluator uses `new VM({ timeout: 300, sandbox: ... })` but does not set several defensive options that should be considered mandatory if `vm2` is retained:

- `allowAsync: false`
- `eval: false`
- `wasm: false`

The current `vm2` README also warns that:

- timeout protection only applies to synchronous code run through `run`
- operating on returned objects can reintroduce arbitrary code execution paths
- there are still ways to crash the Node process from inside the sandbox

For this reason, the Lambda implementation should additionally:

- accept only JSON-serializable outputs
- deep-clone or serialize sandbox results before returning them
- reject functions, class instances, Symbols, and non-plain objects
- reject or normalize oversized outputs

## Major Work Pieces

### 1. Modernize and extract the evaluator core

Create a new Lambda-friendly package boundary around the evaluation logic.

Major tasks:

- place the new implementation in [`assets/src/eval_engine`](assets/src/eval_engine)
- remove Express, `body-parser`, `express-cluster`, HAProxy, and container-only scaffolding
- upgrade the project to a modern Node/TypeScript toolchain
- retain `vm2` semantics for the first migration so behavior stays close to the existing service
- extract request parsing, evaluation, and response shaping into pure modules
- preserve the existing payload contract:
  - input: `{ vars, count }`
  - output: list of variable evaluations, including batch/module mode
- decide whether a colocated [`assets/src/eval_engine/package.json`](assets/src/eval_engine/package.json) is necessary; default to reusing the top-level `assets/package.json` unless `vm2` dependency management or deployment packaging requires isolation

### 2. Convert transport from HTTP server to Lambda handler

Implement a Lambda handler that:

- validates payload structure
- enforces request size and count limits
- invokes the evaluator core
- returns normalized JSON
- records failures and timing metrics

Recommended non-goals:

- do not emulate Express inside Lambda
- do not preserve the `/sandbox` route internally

### 2a. Add node bundle support for the eval engine

Build support must mirror the rules-engine Lambda pattern already present in Torus.

Major tasks:

- update [`assets/webpack.config.node.js`](assets/webpack.config.node.js) to add an `eval` entry alongside the existing `rules` entry
- compile the eval-engine TypeScript sources into a single CommonJS file in `priv/node`
- update [`assets/tsconfig.node.json`](assets/tsconfig.node.json) to include the new entrypoint
- keep using the existing [`assets/package.json`](assets/package.json) `deploy-node` script unless there is a concrete packaging reason to introduce a dedicated script or nested package manifest

### 3. Harden sandbox execution

Because the initial migration definitely keeps `vm2`:

- upgrade from `^3.9.19` to the current maintained line
- lock exact versions
- disable async/eval/wasm
- cap execution count and payload size
- serialize outputs before returning them
- add per-request guardrails for:
  - execution time
  - output size
  - variable count
  - module export count

Replacement of `vm2` can be investigated only as a later hardening phase after the Lambda migration is complete and stable.

### 4. Finish Torus Lambda integration

Implement [`lib/oli/activities/transformers/variable_substitution/lambda_impl.ex`](lib/oli/activities/transformers/variable_substitution/lambda_impl.ex) using the same pattern already used by [`lib/oli/delivery/attempts/activity_lifecycle/lambda.ex`](lib/oli/delivery/attempts/activity_lifecycle/lambda.ex).

Major tasks:

- send the same logical payload currently posted by `RestImpl`
- decode Lambda payloads into the same shape currently returned by `RestImpl`
- preserve `VariableEvaluationController` behavior
- drive provider selection through config and environment variables

### 5. Client invocation updates

For the main Torus authoring UI, the preferred path is compatibility rather than redesign.

Expected client work:

- keep [`assets/src/data/persistence/variables.ts`](assets/src/data/persistence/variables.ts) contract-stable
- confirm the `/api/v1/variables` Torus endpoint still returns the same `evaluations` shape
- update only any out-of-band callers, scripts, or tools that currently target the raw `/sandbox` service directly

This should keep frontend churn low and allow a server-side cutover.

### 6. Unit and integration tests

The migration should add tests rather than only port existing ones.

Required test areas:

- evaluator parity tests against current fixtures
- sandbox hardening tests:
  - async rejection
  - `eval` rejection
  - wasm rejection
  - non-serializable export rejection
  - timeout behavior
- Lambda handler contract tests
- Torus `LambdaImpl` tests for:
  - successful invoke
  - malformed payload
  - Lambda error handling
  - JSON decode failures
- Torus controller tests proving `/api/v1/variables` stays compatible

Important parity asset:

- reuse the real-world evaluation corpus in [`../authoring-eval/data/all.json`](../authoring-eval/data/all.json)

## Risks

- `vm2` escapes remain a live class of risk even on current versions.
- Warm Lambda reuse means data written to memory or `/tmp` can persist across invocations in the same environment.
- A sandbox escape inside the Lambda would still execute with the Lambda function's IAM role and network reachability.
- Toolchain modernization may uncover behavior differences because the current codebase targets Node 8 / TypeScript 3.
- Module-mode scripts may expose edge cases around exported object types and serialization.

## Recommended Decision

Proceed with the Lambda migration, but with this explicit posture:

- yes to Lambda
- yes to direct Torus-to-Lambda invocation
- yes to implementing the Lambda in `assets/src/eval_engine`
- yes to using the existing `assets` node bundle pipeline for the initial deployable artifact
- yes to keeping the browser contract stable
- yes to retaining hardened `vm2` for the initial migration
- no to assuming `vm2` plus Lambda automatically makes arbitrary untrusted code safe

If the requirement is truly "run arbitrary user-authored JavaScript safely," the long-term plan should assume defense in depth and potentially a stronger execution isolation model than in-process sandboxing alone.

## Sources

Primary sources reviewed on 2026-04-08:

- AWS Lambda runtimes: <https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html>
- AWS Lambda execution environment lifecycle: <https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html>
- AWS Lambda Node.js guide: <https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html>
- AWS Lambda Node.js zip packaging: <https://docs.aws.amazon.com/lambda/latest/dg/nodejs-package.html>
- `vm2` repository README: <https://github.com/patriksimek/vm2>
- `vm2` latest release `v3.10.5` on 2026-02-17: <https://github.com/patriksimek/vm2/releases/tag/v3.10.5>
- `vm2` critical advisory `GHSA-g644-9gfx-q4q4` published 2023-07-12: <https://github.com/patriksimek/vm2/security/advisories/GHSA-g644-9gfx-q4q4>
- Node.js `vm` documentation: <https://nodejs.org/api/vm.html>
