// Check a local or AWS result against this runbook's smoke-test event.
// Usage: node docs/runbooks/variable-substitution-lambda/check-result.ts <result.json>
const assert: typeof import('assert').strict = require('node:assert/strict');
const fs: typeof import('fs') = require('node:fs');
if (process.argv.length !== 3) {
  console.error('Usage: check-result.ts <result.json>');
  process.exit(1);
}
const result: unknown = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
assert.deepEqual(result, [
  [{ variable: 'V1', errored: false, result: 2 }],
  [{ variable: 'answer', errored: false, result: 42 }],
]);
console.log('eval response contract passed');
