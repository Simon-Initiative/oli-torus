# MER-5865 Checkpoint A — review round 3

## Verdict

**BLOCKED — 5 blockers, 1 should-fix finding, 1 nit.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1120`** - The round-2
  navigation pushback does not satisfy the written §3.5 contract. The code now requires and
  replays a plan for each usable navigation evaluation, but it still exempts the rotation's first
  feedback/recheck plan from the universal `feedback => feedback-ack permit` and
  `expect-recheck => ack-licensed second evaluation` obligations. A mint plus a second evaluation
  proves the §3.4 rotation shape; it does not prove the separate driver acknowledgment permit that
  §3.5 explicitly requires. The absence of a wire-level acknowledgment is not dispositive because
  permits are driver evidence, not wire records. If the measured widget truly has no observable
  acknowledgment, that is a spec/schema amendment for the human gate; an implementation-only
  exception is dominated by either enforcing the current contract or explicitly changing it.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:541`** - The predicate
  implementation still is not an exact mirror of the normative product operators. The documented
  `contains` limit at lines 565-589 is not safe for `notContains`: production throws when an array
  condition reaches a non-string scalar input, while the mirror returns `false`, and line 680 then
  negates that refusal into a successful predicate. Purity does not prevent representing an
  operator error as a typed fail-closed result/violation. There are additional unacknowledged
  equality divergences: this mirror enters array comparison whenever the condition is an array and
  stringifies array members, whereas production enters that branch only when the fact is an array;
  production also has a numeric-fact branch that parses a string condition, which this mirror
  replaces with text equality. Because §3.8 makes product truth conditions normative, the scoped
  limit is rejected and the matcher needs branch-for-branch differential coverage, including
  operator-error shapes and every allowed argument shape.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:962`** - `firstSeen` cannot
  establish the server's newest part-attempt row. The added witness covers a later save from an
  older GUID only after that GUID was already observed before the newer one. If a newer part
  attempt is the first GUID observed on the wire and an older in-flight attempt appears for the
  first time afterward, lines 985-999 rank the older row as newest even though
  `hierarchy.ex:get_latest_attempts` selects by database id. Response observation order is not
  creation-row order. Preserve actual part-attempt ordering evidence, or fail closed when the
  journal cannot prove it; otherwise committed-prior-state matching can validate stale state.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:228`** - A closed window is
  considered settled only when every evaluation candidate ended `completed`. The journal contract
  defines `failed` as terminal, and the suite itself verifies that an aborted request seals as a
  settled member with `sealIncomplete: false`. Consequently, a closed complete seal containing a
  failed evaluation candidate is incorrectly treated as unsettled and suppresses cardinality,
  receipt, barrier, and obligation conclusions even though §3.2 grants the full audit to a closed
  and settled window. Settlement must mean terminal rather than successful; usability and
  unresolved-candidate checks already report the failure as positive evidence.

- **blocker, `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:299`** - Specific
  mandatory §8 rows remain open despite the round-2 response. The finalization test at this line
  builds one internally contradictory record; it does not cross an accepted duplicate with a
  categorical rejection in both response orders. The loop at line 437 tests each failure reason in
  isolation, not `each reason x response-less finalization terminalization x post-freeze
  immutability`. In `adaptive-oracle.spec.ts`, the test at line 280 duplicates a screen id but never
  a local operation id, and the rotation witnesses at lines 747 and 1697 keep both evaluations on
  the same side of the first entry fence rather than attempting the explicitly required pre-entry
  split-rotation bypass. The closed-but-failed settled-window row exposed above is also absent from
  the claimed full §3.2 matrix. These named mutation rows are the checkpoint's equivalence
  evidence, so the §8 gate remains open.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:384`** - Plan and permit
  inventory validation is scoped inside existing visit indices. A recorded plan or permit whose
  `stepIndex` names no visit is never visited by either loop and is silently ignored, contradicting
  the stated exact one-to-one inventory and the claim that every unmatched record is rejected.
  Validate the complete run-record collections against the visit/step domain before per-step
  auditing, and add beyond-route step-index witnesses.

- **nit, `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:256`** - The contract comment
  still says an accepted record wins outright, but lines 262-273 now correctly let a categorical
  duplicate override acceptance. Qualify the comment so it does not restate the pre-fix behavior.

## Verification

- Verified 2026-08-08: **224/224 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — 6 of 7 fixed, 1 escalated to the human gate. 231/231

## B1 (nav ack obligation) — ESCALATED, as you prescribed
Your process point is accepted: an implementation-only exception is dominated by enforcing or
amending. The driver cannot honestly stamp a `feedback-ack` permit it never performed — the
widget acknowledges internally, off the wire. So this goes to the human gate as a §3.5/§3.4
amendment proposal: "on NAVIGATION screens, a feedback/recheck plan's obligation is fulfilled
by the causal mint plus the ack-licensed second evaluation (the rotation shape); the driver
records plans for every navigation evaluation but stamps no ack permit it did not perform."
Code unchanged pending the human's decision — flag it again if round 4 arrives first.

## B2 (operator mirror) — FIXED, full branch-for-branch port
- `parseArrayStrict` is now a line-for-line `utils/common parseArray` port (`common.ts:84-144`):
  comma-split plain strings, one-level nesting, falsy → [], number wrap, and the production
  THROW represented as a typed `'error'`.
- All contains-family operators return `boolean | 'error'`; `evaluatePredicate` maps `'error'`
  to false under BOTH polarities (`failClosedNegation`) — `notContains` can no longer negate a
  production crash into a pass. Witnessed both polarities.
- `equalOperator` is a branch-for-branch `isEqual` port (`equality.ts:11-76`): array branch on
  NATIVE-array facts only (string-encoded array facts take the scalar branches — quirk pinned
  by witness), number-condition wrapping, toString-then-JSON sorted compare, both boolean
  branches, `parseBoolean` for 'true'/'false' strings, and the numeric-FACT branch that parses
  a string condition (`3 equal '3.0'` → true, witnessed).

## B3 (firstSeen ≠ row order) — FIXED, fail closed
Accepted: observation order cannot prove `hierarchy.ex` row order in either direction. Multiple
part-attempt guids for one part_id now FAIL CLOSED: `committedPriorState` returns
`{state, ambiguousParts}`, the ambiguous part contributes no state, and the receipt audit maps
each ambiguous part to a named violation (`ambiguous-part-order`). The round-2 ranking
witnesses were replaced accordingly — including your crossed-ordering row (newer guid first,
older guid's delayed save after): refusal, not resurrection AND not validation. Single
part attempt per part (the measured shape) keeps full matching.

## B4 (settled = completed) — FIXED
`windowSettled` now means TERMINAL (`terminal !== null`). A closed sealed window holding a
failed candidate reports the failure as positive evidence AND still draws its cardinality/
absence conclusions — witnessed (failed PUT + missing receipt → both violations).

## B5 (§8 rows) — CLOSED
Added: accepted-duplicate × categorical rejection in BOTH response orders (two records, not
one contradictory record); each reason × response-less finalization terminalization ×
persistent-mode arrival × post-freeze refusal+immutability; duplicate local operation id;
pre-entry SPLIT rotation bypass (first half before the identity fence, no mint → sequence +
lineage violations); the closed-but-failed settled-window row (B4).

## SF (beyond-route inventory) — FIXED
A run-record domain sweep precedes the per-step loops: permits, recorded plans and receipts
whose stepIndex names no visit are violations (`beyond-route`), each witnessed.

## Nit — FIXED. The acceptance-contract comment now states the categorical precedence.

Verification: 231/231 (`adaptive-journal/attribution/oracle/strict`), tsc clean (2 pre-existing
liveSocket), eslint clean, prettier applied. Zero commits still.
