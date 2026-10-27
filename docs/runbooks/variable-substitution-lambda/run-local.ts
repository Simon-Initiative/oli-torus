// Invoke the staged eval Lambda package with its smoke-test event.
// Usage: node docs/runbooks/variable-substitution-lambda/run-local.ts <package-dir>
const fs: typeof import('fs') = require('node:fs');
const path: typeof import('path') = require('node:path');
if (process.argv.length !== 3) {
  console.error('Usage: run-local.ts <package-dir>');
  process.exit(1);
}
const dir = path.resolve(process.argv[2]);
(async () => {
  const event: unknown = JSON.parse(fs.readFileSync(path.join(__dirname, 'eval-event.json'), 'utf8'));
  const lambda = require(path.join(dir, 'package', 'eval.js')) as {
    handler: (event: unknown) => Promise<unknown>;
  };
  const result = await lambda.handler(event);
  fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify(result));
})().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
