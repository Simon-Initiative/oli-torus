// Check AWS CLI invoke metadata; also run check-result.ts on the payload.
// Usage: node docs/runbooks/variable-substitution-lambda/check-invocation.ts <invoke.json>
const assert: typeof import('assert').strict = require('node:assert/strict');
const fs: typeof import('fs') = require('node:fs');
if (process.argv.length !== 3) {
  console.error('Usage: check-invocation.ts <invoke.json>');
  process.exit(1);
}
const metadata: { StatusCode?: number; FunctionError?: unknown } = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
assert.equal(metadata.StatusCode, 200);
assert.equal(metadata.FunctionError, undefined, JSON.stringify(metadata));
console.log('Lambda invocation metadata passed');
