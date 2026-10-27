# Nightly dependency failure: discovery and prior verification

## Status and traceability

On September 29, 2026, the user requested that the existing unstaged dependency and
workflow changes be captured and removed while CI strategy remains in discovery.
The three tracked files are retained; only the experimental edits are reverted.
The current dependency fix is tracked by FR-008, AC-022 and AC-030 in `requirements.yml`.
The experiment’s separate collection step was superseded: AC-031 now requires direct
nightly execution without `--list`. Follow the FDD and requirements for implementation.
All remain proposed with no current implementation proofs. Results below describe
the earlier experiment, not a passing implementation in the current working tree.

## Failure and cause

The nightly job failed during Playwright collection with
`Cannot find module 'json-rules-engine'`. `AdaptivePredicateEquivalence.ts` imports
that package, and Playwright loads its importing spec before applying the nightly
test-title selection. The dependency was declared by the parent product package but
not by the automation package installed in the nightly job. Local parent dependencies
could therefore mask the missing declaration.

## Historical experiment

1. Added `"json-rules-engine": "6.1.2"` directly to `assets/automation/package.json`,
   matching `assets/yarn.lock` at discovery time. The current implementation should
   recheck the product lockfile version.
2. Regenerated `assets/automation/package-lock.json` with npm, adding
   `json-rules-engine` 6.1.2 and its previously absent dependencies: `clone` 2.1.2,
   `eventemitter2` 6.4.9, `hash-it` 5.0.2, `jsonpath-plus` 5.1.0, and
   `lodash.isobjectlike` 4.0.0. These are historical resolutions; use the package
   manager and validate compatibility rather than editing lockfile entries by hand.
3. Added a collection check after `npm ci` and before browser installation in
   `.github/workflows/nightly-playwright.yml`. This step is historical and must not
   be restored; the approved design runs tagged tests directly:

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
Repeat dependency isolation/version checks during implementation, and verify direct
nightly execution against the current requirements rather than restoring the old
collection-step ordering check.
