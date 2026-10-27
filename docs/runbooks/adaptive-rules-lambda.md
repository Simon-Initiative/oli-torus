# Deploy the Torus adaptive rules Lambda

This runbook builds, deploys, and configures the adaptive rules function. Torus invokes it synchronously through Elixir's AWS client using `AWSLambdaEvaluator`. This procedure changes only this service; deploy the other evaluator independently using the [variable-substitution runbook](variable-substitution-lambda.md).

Use a staging environment first. The normal Torus release workflow compiles evaluator bundles but does not deploy Lambda functions. The commands below publish immutable versions and leave provider defaults unchanged until you explicitly configure Torus.

## Artifact and invocation contract

- Built artifact: `priv/node/rules.js`, with the additional files described in the packaging step.
- Lambda handler: `index.handler`.
- Torus provider: `AWSLambdaEvaluator`.

The function accepts `{state, rules, scoringContext}` and returns the result object from `check`. It must not return the base64 encoding used by the local Node bridge, an API Gateway response, or a JSON string. The checked-in wrapper explicitly passes `false` for `encodeResults`.

The function needs no Function URL, API Gateway, or public HTTP listener. Torus needs AWS credentials, invocation permission, and access to the regional Lambda API through its existing egress path or a Lambda interface VPC endpoint.

Source references: [bundle configuration](../../assets/webpack.config.node.js), [invocation client](../../lib/oli/delivery/attempts/activity_lifecycle/lambda.ex), [provider configuration](../../config/runtime.exs), and [Node pool startup](../../lib/oli/application.ex).

## 1. Prepare the build and AWS settings

Use a clean checkout of the Torus revision being deployed and the Node, Yarn, and Gleam versions specified by `.tool-versions`. Install AWS CLI v2, `zip`, and `unzip`. Run the shell blocks in order in one Bash session, starting at the repository root. Keep the temporary directory until rollout verification is complete.

Edit these example values for the target environment. Use separate function names for staging and production. This procedure assumes Torus and the function belong to the same AWS account. If deploying both evaluators, use a fresh shell for each runbook so their temporary-directory and function settings remain separate.

```bash
set -euo pipefail
export AWS_PROFILE=torus-staging
export AWS_REGION=us-east-1
export AWS_PAGER=""
FUNCTION_NAME=torus-staging-rules
EXECUTION_ROLE_NAME=torus-staging-rules
TORUS_ROLE_NAME=replace-with-torus-instance-role
SOURCE_SHA=$(git rev-parse HEAD)
PACKAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/torus-rules.XXXXXX")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws sts get-caller-identity
git status --short
```

Confirm the account, region, revision, and clean checkout before continuing. Deployment credentials need permission to create/update this function, publish versions, invoke it, and pass its execution role. The IAM setup below additionally requires permission to manage the specified roles/policies; use an existing approved role if role management belongs to another operator.

## 2. Build and package the function

```bash
yarn --cwd assets install --frozen-lockfile
yarn --cwd assets deploy-node
mkdir -p "$PACKAGE_DIR/package"
cp priv/node/rules.js priv/node/rules.js.LICENSE.txt "$PACKAGE_DIR/package/"
node assets/node_modules/typescript/bin/tsc \
  docs/runbooks/adaptive-rules-lambda/rules-handler.ts \
  --module commonjs --target es2022 --strict --skipLibCheck \
  --types node --typeRoots assets/node_modules/@types \
  --outDir "$PACKAGE_DIR/package"
mv "$PACKAGE_DIR/package/rules-handler.js" "$PACKAGE_DIR/package/index.js"
```

`deploy-node` compiles both evaluator bundles but does not upload either to AWS. This runbook packages and deploys only `rules.js`. `rules.js` exports `check`, so it needs the [checked-in wrapper](adaptive-rules-lambda/rules-handler.ts) compiled above using the existing TypeScript dependency. The deployment ZIP contains JavaScript, not the TypeScript source.

The TypeScript utilities live in [`adaptive-rules-lambda/`](adaptive-rules-lambda/) beside this runbook. Run them directly with the repository's Node 24 installation; no additional runner is needed. JSON inputs and IAM templates remain JSON.

Run the checked-in [local invocation script](adaptive-rules-lambda/run-local.ts) with the [rules smoke-test input](adaptive-rules-lambda/rules-event.json), then validate the response with the [result checker](adaptive-rules-lambda/check-result.ts). These checks exit nonzero on failure. Keep the smoke-test scripts and inputs outside the deployment ZIP.

```bash
node docs/runbooks/adaptive-rules-lambda/run-local.ts "$PACKAGE_DIR"
node docs/runbooks/adaptive-rules-lambda/check-result.ts "$PACKAGE_DIR/result.json"
(cd "$PACKAGE_DIR/package" && zip -q ../rules.zip ./*)
unzip -l "$PACKAGE_DIR/rules.zip"
printf '%s\n' "$SOURCE_SHA" > "$PACKAGE_DIR/source-sha.txt"
```

The JavaScript files must be at the ZIP root, without a containing `package/` directory. Retain the ZIP and source SHA with the release artifacts. Local checks verify packaging and representative payloads, not AWS permissions or production behavior.

## 3. Prepare the Lambda execution role

For first-time setup, create an execution role trusted by Lambda and grant CloudWatch logging access. This evaluator does not need database, S3, secret-store, or Lambda-invocation access. If reusing a role, skip creation and verify its trust and permissions instead.

```bash
aws iam create-role --role-name "$EXECUTION_ROLE_NAME" \
  --assume-role-policy-document "file://docs/runbooks/adaptive-rules-lambda/lambda-trust.json"
aws iam attach-role-policy --role-name "$EXECUTION_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

For either a new or existing role:

```bash
EXECUTION_ROLE_ARN=$(aws iam get-role --role-name "$EXECUTION_ROLE_NAME" \
  --query Role.Arn --output text)
```

Allow IAM propagation before creating the function. If Lambda reports that it cannot assume the role, verify the trust policy and retry after propagation.

## 4. Create the function or publish an update

Use the managed `nodejs24.x` runtime. AWS controls its patch version; the runtime identifier does not pin an exact Node patch. Check the deployed runtime version and AWS runtime-update status when responding to a security advisory. The build machine's `node -v` does not prove that Lambda has the same patch.

Start with 256 MB and a three-second timeout, then measure representative rule sets and cold starts before production. Avoid VPC attachment unless a concrete requirement calls for it.

**First deployment only:**

```bash
FUNCTION_VERSION=$(aws lambda create-function --function-name "$FUNCTION_NAME" \
  --runtime nodejs24.x --architectures x86_64 --handler index.handler \
  --role "$EXECUTION_ROLE_ARN" --memory-size 256 --timeout 3 \
  --description "Torus adaptive rules $SOURCE_SHA" \
  --zip-file "fileb://$PACKAGE_DIR/rules.zip" --publish --query Version --output text)
aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME"
```

**Subsequent deployments:** inspect the function's configuration first. Confirm the handler, runtime, architecture, role, timeout, and memory still match this runbook or the environment's deliberately tuned settings. Apply any required changes to the unpublished version using `update-function-configuration` and wait for `function-updated-v2` before uploading code. Coordinate deployments so two operators do not update the same function concurrently.

```bash
aws lambda get-function-configuration --function-name "$FUNCTION_NAME"
FUNCTION_VERSION=$(aws lambda update-function-code --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$PACKAGE_DIR/rules.zip" --publish --query Version --output text)
aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
```

Record the version number alongside the ZIP and source SHA. Torus will invoke that explicit version, so uploading new code does not silently change the live evaluator.

## 5. Invoke the published version before cutover

```bash
aws lambda invoke --function-name "$FUNCTION_NAME" --qualifier "$FUNCTION_VERSION" \
  --cli-binary-format raw-in-base64-out --payload "file://docs/runbooks/adaptive-rules-lambda/rules-event.json" \
  "$PACKAGE_DIR/result.json" > "$PACKAGE_DIR/invoke.json"
node docs/runbooks/adaptive-rules-lambda/check-invocation.ts "$PACKAGE_DIR/invoke.json"
node docs/runbooks/adaptive-rules-lambda/check-result.ts "$PACKAGE_DIR/result.json"
```

Lambda can return HTTP 200 with `FunctionError`. Check both invocation metadata and payload, as above. If either check fails, stop before changing Torus configuration. Inspect `/aws/lambda/<function-name>` in CloudWatch for initialization, timeout, and handler errors.

## 6. Grant Torus invocation access and configure the provider

Grant the Torus runtime role access to this exact function version. If IAM policies are managed elsewhere, apply the equivalent policy through that process. Preserve access to previous versions until the rollback window closes; the example uses a separate policy per function version and does not replace the other evaluator's policy.

```bash
FUNCTION_TARGET="$FUNCTION_NAME:$FUNCTION_VERSION"
node docs/runbooks/adaptive-rules-lambda/write-invoke-policy.ts \
  "arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_TARGET" \
  > "$PACKAGE_DIR/torus-invoke.json"
aws iam put-role-policy --role-name "$TORUS_ROLE_NAME" \
  --policy-name "TorusEvaluator-$FUNCTION_NAME-$FUNCTION_VERSION" \
  --policy-document "file://$PACKAGE_DIR/torus-invoke.json"
printf '%s\n' \
  'RULE_EVALUATOR_PROVIDER=AWSLambdaEvaluator' \
  "EVAL_LAMBDA_FN_NAME=$FUNCTION_TARGET" \
  "EVAL_LAMBDA_REGION=$AWS_REGION"
```

Save the existing three settings, including whether each was unset. Apply the printed values to the environment used by the Torus service or container, not just an interactive shell. Leave the other evaluator's provider and function settings unchanged. Use the normal restart/redeploy procedure.

Use the deployed Torus release's remote command to verify the effective configuration, substituting the actual release path:

```bash
/path/to/oli/bin/oli rpc 'IO.inspect(Application.fetch_env!(:oli, :rule_evaluator))'
```

Check that `:dispatcher` is `Oli.Delivery.Attempts.ActivityLifecycle.AWSLambdaEvaluator` and that `:aws_fn_name` and `:aws_region` match the selected version and region. Use Torus's existing AWS credential mechanism, such as the EC2 instance role; do not copy deployment credentials onto the server.

## 7. Verify behavior and runtime dependencies

In staging, through Torus itself:

- Submit correct and incorrect adaptive answers; verify feedback, score, and attempt behavior.
- Confirm invocations reach the intended version and that Torus logs show no invocation failures. Check Lambda duration, errors, and throttles under representative load, including cold starts.
- Confirm the actual Torus runtime role can invoke the function. Successful CLI tests with a deployment profile do not verify that role's access.

Repeat the approved checks after production cutover. Keep local Node available during the rollback window.

Changing this service alone does not establish that the entire deployment can remove local Node. Torus starts its Node pool when the rules provider is `NodeEvaluator` or the variable provider is `NodeImpl`. When both services use Lambda, neither condition applies. Check the other provider using the [variable-substitution runbook](variable-substitution-lambda.md) before removing the host dependency, and verify that this command returns `nil`:

```bash
/path/to/oli/bin/oli rpc 'IO.inspect(Process.whereis(NodeJS.Supervisor))'
```

A separate local REST evaluator may still need Node even when the Torus pool is absent. Development watchers and the dev/test-only rules API still use local Node. Build jobs must continue to install Node and compile the bundles. Removing Node from the shared Docker runtime image is a separate packaging change because other deployments may select a local provider. Node and JavaScript dependencies inside Lambda still need updates.

## Rollback and cleanup

Restore this service's prior provider, function/version, and region settings, then restart Torus and repeat its activity checks. Leave the other evaluator's settings and policies unchanged. For a later Lambda update, restoring the prior version-qualified function name selects the previous immutable code. For the initial migration, restore the previous rules provider (normally `NodeEvaluator`); local Node must still be available.

Do not delete previous versions or their invocation grants until rollback is no longer needed. Afterward, remove obsolete per-release IAM policies for this function to avoid accumulating inline policies. Retain the deployment ZIP, version number, source SHA, prior configuration, and verification results in the release record. Remove only the temporary directory created by this runbook once those records have been saved:

```bash
rm -rf -- "$PACKAGE_DIR"
```

## References and validation scope

- [Variable-substitution runbook](variable-substitution-lambda.md)
- [AWS Node.js runtime and handler documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html)
- [AWS CLI create-function](https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html)
- [AWS CLI update-function-code](https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html)

Local package loading and representative handler results can be verified without AWS. Function creation, IAM propagation, managed-runtime compatibility, and Torus cutover require target-environment verification; do not treat earlier automated tests as proof that a live rollout has occurred.
