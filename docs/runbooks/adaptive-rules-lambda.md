# Deploy the Torus adaptive rules Lambda

This runbook builds, deploys, and configures the adaptive rules function. Torus invokes it synchronously through Elixir's AWS client using `AWSLambdaEvaluator`.

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

Edit these example values for the target environment. Use separate function names for staging and production. This procedure assumes Torus and the function belong to the same AWS account.

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
cp docs/runbooks/adaptive-rules-lambda/index.js "$PACKAGE_DIR/package/"
```

`deploy-node` builds `rules.js` but does not upload it to AWS. `rules.js` exports `check`, so it needs the [JavaScript wrapper](adaptive-rules-lambda/index.js) copied above. No separate wrapper compilation is needed.

Invoke the packaged handler with the [smoke-test input](adaptive-rules-lambda/rules-event.json) and check its response using Node. A failed invocation or assertion exits nonzero. Keep the input outside the deployment ZIP.

```bash
node - "$PACKAGE_DIR" <<'NODE'
const assert = require('node:assert/strict');
const path = require('node:path');
const { handler } = require(path.resolve(process.argv[2], 'package/index.js'));
const event = require('./docs/runbooks/adaptive-rules-lambda/rules-event.json');
handler(event).then((result) => {
  assert.equal(result.correct, false);
  assert.equal(result.score, 0);
  assert.equal(result.out_of, 1);
  assert.ok(Array.isArray(result.results) && result.results.length > 0);
  console.log('rules response contract passed');
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
NODE
(cd "$PACKAGE_DIR/package" && zip -q ../rules.zip ./*)
unzip -l "$PACKAGE_DIR/rules.zip"
printf '%s\n' "$SOURCE_SHA" > "$PACKAGE_DIR/source-sha.txt"
```

The JavaScript files must be at the ZIP root, without a containing `package/` directory. Retain the ZIP and source SHA with the release artifacts. Local checks verify packaging and representative payloads, not AWS permissions or production behavior.

## 3. Prepare the Lambda execution role

For first-time setup, create an execution role trusted by Lambda and grant CloudWatch logging access. This evaluator does not need database, S3, secret-store, or Lambda-invocation access. If reusing a role, skip creation and verify its trust and permissions instead.

```bash
cat > "$PACKAGE_DIR/lambda-trust.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
JSON
aws iam create-role --role-name "$EXECUTION_ROLE_NAME" \
  --assume-role-policy-document "file://$PACKAGE_DIR/lambda-trust.json"
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
node - "$PACKAGE_DIR" <<'NODE'
const assert = require('node:assert/strict');
const path = require('node:path');
const dir = path.resolve(process.argv[2]);
const metadata = require(path.join(dir, 'invoke.json'));
assert.equal(metadata.StatusCode, 200);
assert.equal(metadata.FunctionError, undefined, JSON.stringify(metadata));
const result = require(path.join(dir, 'result.json'));
assert.equal(result.correct, false);
assert.equal(result.score, 0);
assert.equal(result.out_of, 1);
assert.ok(Array.isArray(result.results) && result.results.length > 0);
console.log('Lambda invocation and response passed');
NODE
```

Lambda can return HTTP 200 with `FunctionError`. Check both invocation metadata and payload, as above. If either check fails, stop before changing Torus configuration. Inspect `/aws/lambda/<function-name>` in CloudWatch for initialization, timeout, and handler errors.

## 6. Grant Torus invocation access and configure the provider

Grant the Torus runtime role access to this exact function version. If IAM policies are managed elsewhere, apply the equivalent policy through that process. Preserve access to previous versions until the rollback window closes; the example uses a separate policy per function version.

```bash
FUNCTION_TARGET="$FUNCTION_NAME:$FUNCTION_VERSION"
cat > "$PACKAGE_DIR/torus-invoke.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "lambda:InvokeFunction",
    "Resource": "arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_TARGET"
  }]
}
JSON
aws iam put-role-policy --role-name "$TORUS_ROLE_NAME" \
  --policy-name "TorusEvaluator-$FUNCTION_NAME-$FUNCTION_VERSION" \
  --policy-document "file://$PACKAGE_DIR/torus-invoke.json"
printf '%s\n' \
  'RULE_EVALUATOR_PROVIDER=AWSLambdaEvaluator' \
  "EVAL_LAMBDA_FN_NAME=$FUNCTION_TARGET" \
  "EVAL_LAMBDA_REGION=$AWS_REGION"
```

Save the existing three settings, including whether each was unset. Apply the printed values to the environment used by the Torus service or container, not just an interactive shell. Use the normal restart/redeploy procedure.

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

Before removing Node from a Torus host, verify that no remaining runtime workloads or rollback procedures require it. Build jobs still need Node to compile the bundle, and Node and JavaScript dependencies inside Lambda still need updates.

## Rollback and cleanup

Restore this service's prior provider, function/version, and region settings, then restart Torus and repeat its activity checks. For a later Lambda update, restoring the prior version-qualified function name selects the previous immutable code. For the initial migration, restore the previous rules provider (normally `NodeEvaluator`); local Node must still be available.

Do not delete previous versions or their invocation grants until rollback is no longer needed. Afterward, remove obsolete per-release IAM policies for this function to avoid accumulating inline policies. Retain the deployment ZIP, version number, source SHA, prior configuration, and verification results in the release record. Remove only the temporary directory created by this runbook once those records have been saved:

```bash
rm -rf -- "$PACKAGE_DIR"
```

## References and validation scope

- [AWS Node.js runtime and handler documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html)
- [AWS CLI create-function](https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html)
- [AWS CLI update-function-code](https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html)

Local package loading and representative handler results can be verified without AWS. Function creation, IAM propagation, managed-runtime compatibility, and Torus cutover require target-environment verification; do not treat earlier automated tests as proof that a live rollout has occurred.
