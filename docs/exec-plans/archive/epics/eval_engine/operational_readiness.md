# Eval Engine Lambda Operational Readiness

This note captures the expected bounded deployment posture for the Phase 1 `vm2`-based eval Lambda.

## Function Configuration

- Artifact: `priv/node/eval.js`
- Handler: `eval.handler`
- Runtime: current supported AWS Lambda Node.js runtime used by Torus for node-based Lambdas
- Function name source: `VARIABLE_SUBSTITUTION_LAMBDA_FN_NAME`
- Region source: `VARIABLE_SUBSTITUTION_LAMBDA_REGION`
- Timeout: bounded and short; target `3` seconds or less because `vm2` execution is internally capped at `300ms`
- Memory: bounded; start at `256 MB` unless profiling shows a higher floor is required
- Concurrency: leave unreserved by default or set a conservative reserved concurrency during initial rollout if environment-level protection is needed

## IAM and Network Posture

- Torus caller permissions should allow only `lambda:InvokeFunction` on the specific eval Lambda ARN
- The Lambda execution role should be limited to CloudWatch Logs write permissions plus any packaging/runtime minimums
- The Lambda should not require VPC attachment for Phase 1
- The Lambda should not require database access, private network access, or secret-store reads for Phase 1
- No authored payloads or evaluation results should be emitted to logs

## Logging and Telemetry Expectations

- Elixir emits sanitized telemetry and logs for Lambda invoke and response-decode stages
- The Lambda handler emits sanitized request-completion logs with outcome category, duration, and count-based metadata only
- Observable fields should remain limited to function name, region, request counts, response shape, duration, and coarse error category

## Phase 4 Scope Note

- Non-production rollout and rollback verification was intentionally skipped in this implementation pass per user instruction
- Real environment validation is still required before merge/release if `AC-009` and `AC-010` are being closed operationally
