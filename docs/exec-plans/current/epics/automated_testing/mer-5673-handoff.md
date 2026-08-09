## ⇥ HANDOFF — session boundary 2026-07-20 (read this first)

PR #6738 shipped as draft, one commit. Next: add teardown observability fix, then Codex review, then mark ready.

### SHIPPED

- `a9b0d93e1c` — [ENHANCEMENT] [MER-5673] Add Dazzling d-Orbitals adaptive lesson Playwright coverage (7 files, +536/-266) ✅
- PR #6738 created as draft, pushed to remote ✅
- TRIAGE-2416 created — follow-up ticket for compile-gated scenario-token adapter (linked to MER-5672 + MER-5673) ✅
- Rebased onto master (`56b95f21ea`) after MER-5672 PR #6731 merged ✅
- 7 rounds of cross-model code review (3 refactor + 4 spec compliance), all approved ✅

### NEXT

**Immediate:** Add teardown observability to `teardownAutomationCourse` in `assets/automation/src/systems/torus/tasks/AutomationSetupTask.ts:69-95`.

Both Claude and Codex independently recommend: fix now in PR #6738 (see `reviews/mer-5673-teardown-scope.md` locally). Constraints agreed by both assessments:

1. **Warnings only** — preserve the function's current resolve/non-fatal contract; do NOT throw on per-entity failures
2. After HTTP-success response, parse the teardown payload and emit one aggregated `console.warn` naming every failed entity and its server message
3. Include project and section slugs so leaked records can be located
4. Treat malformed/unreadable success payloads as a warning, not a rejection
5. Preserve existing non-2xx warning path unchanged
6. Don't change either spec's `afterAll` policy

Server response shape (`lib/oli_web/controllers/api/automation_setup_controller.ex:100-130, 262-275`):
```json
{
  "author_deleted": { "success": true },
  "section_deleted": { "success": false, "message": "..." },
  "project_deleted": { "success": true },
  ...
}
```

**After teardown fix:**
1. Run `prettier` on touched files
2. Codex review of the teardown change (one round, delegate skill)
3. Commit (human-gated): amend or new commit — user's call
4. `git push --force-with-lease`
5. Mark PR #6738 as ready for review

### HARD CONSTRAINTS

- **Commit gate:** human (Francisco) authorizes every commit. Default: suggest commit message + files, execute only on explicit "do it" / "commit" instruction.
- **Commit format:** `[ENHANCEMENT] [MER-5673] description` — single line, NO body, NO Co-Authored-By trailer
- **Review loop:** Claude writes, Codex reviews, human approves. Max 3 rounds or "nothing material"
- **Zero comments by default** — one-line max if WHY is non-obvious
- **No port in URLs** — never include `:4000` in localhost paths
- **Caveman mode active** — terse responses, drop articles/filler/pleasantries

### DEBT / OWED

- **Teardown observability** — the immediate next task (described above) ⚠️
- **TRIAGE-2416** — compile-gated adapter to replace per-env API key with scenario token. Low priority, trigger: when archive-backed suites multiply. NOT actionable now ✅
- **Shared infra follow-up** (from Codex spec review round 3): a stricter "cleanup failure fails the suite" policy requires aligning both consumers' afterAll behavior — separate decision, not this PR ⚠️

### GOTCHAS

- **Greenhouse spec diverged on disk:** `real-chem-greenhouse-molecules.spec.ts` was modified by a linter between sessions. The committed version is correct (refactored to use shared modules). If a diff looks odd, compare against `a9b0d93e1c`, not the working tree ✅
- **`teardownAutomationCourse` callers differ:** greenhouse has no catch in afterAll; d-orbitals catches + logs with 15s timeout via Promise.race. Any change that makes teardown reject would fail greenhouse silently but be caught in d-orbitals — asymmetric behavior. This is why both assessments say warnings-only ✅
- **Auth module path:** `lib/oli_web/playwright_auth.ex` NOT `lib/oli_web/plugs/playwright_auth.ex` (Codex caught this) ✅
- **Commit type:** Playwright test PRs use `[ENHANCEMENT]`, NOT `[TEST]` ✅

### POINTERS

- PR: https://github.com/Simon-Initiative/oli-torus/pull/6738
- Jira: https://eliterate.atlassian.net/browse/MER-5673
- Follow-up ticket: https://eliterate.atlassian.net/browse/TRIAGE-2416
- Nico's review on MER-5672: PR #6731
- Codex teardown scope assessment: `reviews/mer-5673-teardown-scope.md` (local, not committed)
- Codex architecture assessment: `reviews/mer-5673-nico-eval.md` (local, not committed)
- MER-5672 PR (merged, reference pattern): PR #6731
