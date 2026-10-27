// Check a local or AWS result against this runbook's smoke-test event.
// Usage: node docs/runbooks/adaptive-rules-lambda/check-result.ts <result.json>
const assert: typeof import('assert').strict = require('node:assert/strict');
const fs: typeof import('fs') = require('node:fs');
if (process.argv.length !== 3) {
  console.error('Usage: check-result.ts <result.json>');
  process.exit(1);
}
const result: { correct: boolean; score: number; out_of: number; results: unknown[] } = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
assert.equal(result.correct, false);
assert.equal(result.score, 0);
assert.equal(result.out_of, 1);
assert.ok(Array.isArray(result.results) && result.results.length > 0);
console.log('rules response contract passed');
