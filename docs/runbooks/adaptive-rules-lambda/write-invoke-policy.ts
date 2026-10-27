// Print a Torus invocation policy for one version-qualified Lambda ARN.
// Usage: node docs/runbooks/adaptive-rules-lambda/write-invoke-policy.ts <function-version-arn>
if (process.argv.length !== 3) {
  console.error('Usage: write-invoke-policy.ts <function-version-arn>');
  process.exit(1);
}
console.log(JSON.stringify({
  Version: '2012-10-17',
  Statement: [{
    Effect: 'Allow',
    Action: 'lambda:InvokeFunction',
    Resource: process.argv[2],
  }],
}, null, 2));
