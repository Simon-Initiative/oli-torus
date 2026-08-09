# MER-5865 Checkpoint A — review round 4

## Verdict

**BLOCKED — 3 blockers, 2 should-fix findings, 0 nits.**

## Findings

- **blocker, `docs/exec-plans/current/epics/automated_testing/option-c-spec.md:372`** - The
  human-approved navigation-ack amendment is not present in the normative contract. Section 3.4
  still says a `feedback-ack` permit alone licenses every optional second evaluation, and §3.5 at
  line 427 still requires every feedback plan to have that permit and every recheck to be
  ack-permit-licensed. The implementation at `AdaptiveOracle.ts:1171` instead applies the approved
  navigation exception: the widget's internal ack is represented by the causal mint plus the
  second evaluation, with no driver-stamped ack permit. The implementation-only exception therefore
  still contradicts the checked-in source of truth even though the human decision is now settled.
  Record the approved navigation-specific fulfillment rule in both §3.4 and §3.5; leaving either
  universal statement in place keeps the contract internally contradictory.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:779`** - The navigation
  rotation accepts any non-navigating first plan, including `none`. Its predicate checks only
  `!transitionNavigates(firstPlan)`, while `auditNavObligations` replays every plan but applies
  transition legality and fulfillment only to the last one. Consequently, an incorrect first
  evaluation deriving `none`, followed by the causal mint and a correct navigating evaluation,
  satisfies the measured-rotation shape without any violation. Section 3.5 explicitly makes
  `none` illegal after every check, and the approved navigation amendment is scoped to fulfillment
  of a feedback/recheck plan, not to broadening which first plans are legal. Require the first
  rotation plan to be feedback/recheck (or apply `plan-illegal` to every navigation evaluation) and
  add the missing mutation witness.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:508`** - The claimed
  branch-for-branch production mirror still changes operator truth conditions. The local
  `parseNumString` pre-trims and converts with `Number`, while `utils/common.ts:156` first uses
  `Number` only as the eligibility check and then converts with `parseFloat`; whitespace-only and
  base-prefixed numeric strings therefore normalize differently. The local `parseBooleanMirror`
  at line 573 also omits production's accepted `on` spelling. More seriously, the boolean-condition
  branch at line 607 uses safe `String(input)` where production calls `factValue.toString()`; a
  null fact therefore throws in production but returns false here, which `notEqual` negates into a
  passing predicate instead of preserving the typed fail-closed operator error. Because §3.8 makes
  production truth conditions normative, port the utility behavior exactly, carry every production
  throw through `OpResult`, and add differential witnesses for these branches.

- **should-fix, `docs/exec-plans/current/epics/automated_testing/option-c-spec.md:704`** - The other
  human-approved round-1 amendment is also absent. Section 7 still moves directly from the shadow
  differential gate in step 3 to the first behavior switch in step 4, while the review-model summary
  at lines 39-40 still schedules checkpoint B only after step 4 and checkpoint C only after step 8.
  That preserves the exact exposure SF3 identified: the equivalence evidence is not independently
  reviewed before it governs the replacement, and manifest/registry defects can compound through
  both migrations before review. Record the approved gate after step 3 and the approved split of
  checkpoint C in both the summary and §7 schedule.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:613`** - Receipt
  inventory is not exact within the visited domain. `find` audits only the first receipt for a
  graded step; a second contradictory receipt is silently ignored, as is any receipt attached to a
  content or navigation step. The new beyond-route sweep closes only nonexistent step indices, so
  these in-domain extras still evade the receipt identity contract even though plans and permits
  reject their analogous duplicate or unused evidence. Validate zero receipts for non-graded
  steps and exactly one for each graded step under the same full-audit absence gating, while always
  treating present duplicate or wrong-role receipts as positive evidence; add both witnesses.

## Verification

- Verified 2026-08-09: **231/231 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 5 findings addressed. 234/234

## B1 (spec text) — FIXED. Both human-approved amendments are now IN the spec
§3.4 gained the navigation-ack fulfillment bullet (widget acks internally; mint + second
evaluation fulfill; the driver records plans for every nav evaluation but stamps no permit it
did not perform) and its rotation description now REQUIRES a feedback first plan; §3.5's
universal feedback/recheck obligations are scoped to non-navigation screens with the nav
exception stated inline. Both carry the "human-approved 2026-08-09" stamp.

## B2 (rotation accepts `none`) — FIXED
The rotation predicate now requires `firstPlan.kind === 'feedback'` AND non-navigating, and
`auditNavObligations` applies `plan-illegal` to EVERY usable navigation evaluation deriving
`none` — not only the last. Witness: none-first rotation with a causal mint → both
`navigation-sequence` and `plan-illegal`.

## B3 (utility ports) — FIXED
- `parseNumString` is now the `common.ts:156-167` port: `Number` is eligibility only,
  `parseFloat` converts — `' '` → NaN, `'0x10'` → 0 (witnessed via the equal array branch).
- `parseBooleanMirror` accepts `on` (witnessed: `'on' equal 'true'`).
- Both boolean branches of `equalOperator` return the typed operator ERROR for a null fact
  (production `factValue.toString()` throws) — and `notEqual` keeps it fail-closed instead of
  negating it (witnessed both polarities), while a null fact against a string condition still
  legally compares false → `notEqual` true (witnessed — the legal path is not over-closed).

## SF1 (review-model spec text) — FIXED
§7 gained step 3-bis (gate B0: the shadow evidence reviewed before step 4 consumes it) and
step 6-bis (checkpoint C1: manifests + registry reviewed before either migration), step 8
notes C2; the HANDOFF review-model summary lists A, B0, B, C1, C2 with the amendment stamp.

## SF2 (receipt inventory) — FIXED
Per step: receipts on non-graded steps and duplicate receipts on graded steps are positive
violations (`receipt-mismatch: wrong-role | duplicate`), before any receipt is consumed; the
beyond-route sweep already covers nonexistent step indices. Both witnessed.

Verification: 234/234, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.
