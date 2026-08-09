# MER-5865 Checkpoint A — Review Round 8

## Verdict

**BLOCKED — 2 blockers, 1 should-fix finding, 0 nits.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1104`** - The committed-prior-state reconstruction considers only PATCH saves. A successful activity-attempt PUT also persists its submitted part responses before returning, so it is part of the database state that `get_latest_attempts` later supplies to a dependent evaluation. Ignoring PUT commits can reject a valid evaluation-only dependency, or accept an older PATCH state after a later PUT replaced it. That means the matcher does not reproduce the server's newest-attempt/newest-part response state required by §3.6. Fold every successful terminal commit carrying part inputs into the per-part reconstruction, with ordering or fail-closed ambiguity handling where the wire cannot prove database commit order. Add public-oracle witnesses for an evaluation-only dependency and for crossed PATCH/PUT replacement; the current suite's committed-state baseline at `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:883` proves only the save-only subset.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:943`** - A prefix expectation without a predicate returns `underPrefix.length > 0`, so it ignores `min_count` entirely and does not deduplicate paths. One observed path, or repeated entries for that same path, therefore satisfies any declared count. This leaves §8's duplicate-label distinct-path `min_count` row open for the predicate-less schema branch and reintroduces the R4-SF3 undercount class. Compute distinct matching paths before applying `min_count` for both predicate-bearing and presence-only prefix expectations; add the missing presence-only one-path, duplicate-path, and distinct-path witnesses alongside `adaptive-oracle.spec.ts:833`.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:279`** - The round-7 operation-failure fix still validates a resolved failure only by checking that its `screenId` belongs to the manifest. It never requires that screen to equal the scenario screen at `expectedStepIndex`. A resolved failure can therefore name a different valid manifest screen and the base violation is reported against that wrong screen without any contradiction finding. This is a concrete step-3 hazard: the mandatory shipped-bail comparison requires the oracle violation to name the same screen, so contradictory evidence can create a false same-screen divergence. Compare every resolved failure against the expected scenario reference (and the visit when present), and add an in-range witness whose screen is valid but belongs to another step; the matrix at `adaptive-oracle.spec.ts:2414` covers nullability and domain errors but not this row.

## Round-7 pushback disposition

Accepted. Caller-supplied permit and readback seqs are explicitly recorded in the HANDOFF debt list with the real journal-domain stamp API owned by step 4. I found no separate concrete step-3 hazard that overrides that documented deferral; the step-3 hazard above is caused by operation-failure screen validation, not permit-stamp provenance.

## Verification

- Verified 2026-08-09: **244/244 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 3 findings fixed. 248/248

## B1 (PUT commits invisible to the matcher) — FIXED
CLASS: "wire records that persist part responses". Sibling search: PATCH saves (had it),
successful activity-attempt PUTs (evaluations AND finalizes — both persist partInputs; now
folded), nothing else writes part state. `committedPriorState` reconstructs over COMMITS with
response-order replacement, and commit order is trusted only for NON-OVERLAPPING requests:
two in-flight commits to one part are server-order opaque → `ambiguousParts`, fail closed.
Witnesses through the public oracle: evaluation-only dependency (no save at all) audits
clean; a later PUT replaces an earlier PATCH; overlapping commits refuse.

## B2 (presence-only min_count) — FIXED
Presence-only prefix expectations count DISTINCT paths against `min_count ?? 1` — the
R4-SF3 rule now covers both schema branches. Witnesses: duplicated single path fails a
min_count of 2, distinct paths pass.

## SF (resolved failure naming another step's screen) — FIXED
A resolved failure inside the scenario domain must name EXACTLY its expected step's screen;
a valid-but-foreign screen is `screen-mismatch` (your step-3 false-divergence hazard).
Witness: `c:1` claimed at step 1.

Verification: 248/248, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.
