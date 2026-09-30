# Nightly dependency failure: discovery and prior verification

## Status and traceability

On September 29, 2026, the user requested that the existing unstaged dependency and
workflow changes be captured and removed while CI strategy remains in discovery.
The three tracked files are retained; only the experimental edits are reverted.
Canonical requirements are FR-008, AC-022, AC-030, and AC-031 in `requirements.yml`.
All remain proposed with no current implementation proofs. Results below describe
the earlier experiment, not a passing implementation in the current working tree.

## Failure and cause

The nightly job failed during Playwright collection with
`Cannot find module 'json-rules-engine'`. `AdaptivePredicateEquivalence.ts` imports
that package, and Playwright loads its importing spec before applying the nightly
test-title selection. The dependency was declared by the parent product package but
not by the automation package installed in the nightly job. Local parent dependencies
could therefore mask the missing declaration.

## Captured changes for later implementation

1. In `assets/automation/package.json`, add the direct dependency
   `"json-rules-engine": "6.1.2"`, matching the resolved product version in
   `assets/yarn.lock` at discovery time. Recheck that lockfile when implementing.
2. Regenerate `assets/automation/package-lock.json` with npm. The experiment added
   `json-rules-engine` 6.1.2 and its previously absent dependencies: `clone` 2.1.2,
   `eventemitter2` 6.4.9, `hash-it` 5.0.2, `jsonpath-plus` 5.1.0, and
   `lodash.isobjectlike` 4.0.0. These are historical resolutions; use the package
   manager and validate compatibility rather than editing lockfile entries by hand.
3. In `.github/workflows/nightly-playwright.yml`, after `npm ci` and before browser
   installation, add the collection check in the automation working directory:

   ```yaml
   - name: Check nightly test collection
     run: npx playwright test --grep @nightly --list --reporter=line
   ```

The dependency update used this command from `assets/automation`:

```sh
npm install --save-exact --package-lock-only --ignore-scripts --no-audit --no-fund json-rules-engine@6.1.2
```

## Historical verification — September 28, 2026

An isolated temporary checkout contained the automation sources, imported product
sources, and their TypeScript configuration, but no parent `assets/node_modules`.

| Check | Observed result |
| --- | --- |
| Original automation `npm ci`, then nightly `--list` | Failed with the reported missing `json-rules-engine` import |
| Corrected lockfile, clean `npm ci`, then nightly `--list` | Collected all 10 nightly tests |
| `npx playwright test mer5865-archive-gates.spec.ts --reporter=line` | 48 passed; 2 private-archive fixture cases skipped |
| Workflow YAML parse and collection-step order | Passed |
| Resolved engine version compared with product Yarn lock | Both 6.1.2 |
| `git diff --check` | Passed |

Security and performance review found no issues in that scoped experiment. A full
remote browser run was not performed. Required target/asset/integration configuration
and failure-on-missing-configuration behavior were not established by these checks.
Repeat relevant verification after implementing the captured requirements.
