# MER-5865 Checkpoint A — review round 2

## Verdict

**BLOCKED — 7 blockers, 3 should-fix findings, 0 nits.**

## Blockers

### B1. The B3 route-graph pushback leaves both the offline and live route proofs incomplete

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:351`; `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1281`

`ArchiveFacts` carries only an inventory and one last-entry id, so `validateRouteCoverage` cannot
prove that the ordered scenario is a route through the archive graph or that exclusions are
off that route. Any permutation of the middle scenario steps passes. The proposed substitute is
not present online either: a non-final navigate plan is fulfilled by any later visit stamp, with
no comparison between the normalized target and the visited screen. The scoped pushback is
therefore rejected. Avoiding duplicate graph logic is reasonable, but deferring the proof is
dominated by supplying proof-carrying archive route/successor facts (or replaying the archive
graph once): the current live check has strictly less evidence and cannot discharge the explicit
build-time route-membership obligation. Validate every scenario edge and exclusion offline, then
make the oracle verify that each planned target resolves to the recorded successor.

### B2. Omitting `dependencies` bypasses the bidirectional archive check

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:417`

The validator immediately skips a screen whose manifest dependency list is empty. Consequently,
archive `rule_prior_state_refs` for that screen are never inspected: a cross-screen rule can have
neither a declared dependency nor a covering expectation and still pass the build. That is the
underdeclared-receipt failure the bidirectional rule exists to prevent. Inspect archive rule
references for every screen, derive their owning screen ids, require those owners in the declared
dependency set, and require each reference to be covered by an expectation.

### B3. Navigation evaluations are exempt from mandatory plan evidence and all-plan obligations

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1056`

`auditNavObligations` makes recorded plans optional and checks fulfillment only for the last usable
evaluation. Section 3.5 requires the online plan to exist and match for every owned evaluation,
and every replayed plan's obligation to be fulfilled. In particular, a legal-looking two-check
rotation can derive feedback/recheck on its first evaluation, provide no acknowledgment, and pass
because only the final navigating plan is audited. The navigation sequence rule is not a substitute:
it neither proves online/replay agreement nor fulfills feedback obligations. Require and validate
one recorded plan per navigation evaluation and audit every plan's obligation.

### B4. Content steps can pass with a feedback-licensed second evaluation

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:513`

The shared non-navigation cardinality calculation raises the licensed count to two whenever the
first plan expects a recheck, regardless of role. There is no later content-specific exact-one
check, so a content step with a check-click, feedback acknowledgment, and two usable evaluations
can audit clean. Section 3.5 requires exactly one content evaluation. Enforce content cardinality
independently of feedback permits and reject any second content evaluation.

### B5. A late save from an older part attempt can become the selected "newest" attempt

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:929`

`committedPriorState` replaces the selected bucket on every later save. After a newer part-attempt
guid has been observed, a delayed save carrying the older guid therefore overwrites it and
resurrects stale state. The server selects the newest part-attempt row per part id, not the part
attempt that happened to save last. Preserve independently evidenced part-attempt ordering (or
fail closed when the journal cannot prove it), then apply response replacement only within the
selected newest part attempt. Add the crossed ordering witness: newer attempt observed, then an
older attempt's delayed save.

### B6. The predicate mirror still broadens production `contains` truth conditions

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:529`

The production operator returns false when a scalar input is not a string after the array branches;
this mirror stringifies every remaining scalar and performs a substring check. A numeric fact can
therefore satisfy a text `contains` predicate here when the production operator refuses it, and
`notContains` inherits the opposite divergence. This contradicts the normative-operator contract
and shows that the new representative refusal rows are not an exact mirror. Match the production
type branches verbatim and add type-crossed accept/reject rows for every operator, not only the
currently measured happy types.

### B7. The admitted B9 remainder is round-blocking under the exhaustive §8 gate

**Location:** `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:1243`; `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:240`

Section 8 requires exhaustive mutation-style matrices, not representative witnesses. The suite
still leaves the writer's admitted target variants, successor-exists case, split-rotation fencing,
and combined-freeze ordering rows open. The full seal/window-state matrix is also absent, and the
finalization tests do not cross an accepted duplicate with the categorical rejection. Other named
rows remain helper-only or partial, including mandatory navigation plan replay, wrong-lineage prior
state, duplicate operation ids, and an LLM-feedback obligation through `auditRun`. Because these
rows are the checkpoint's stated equivalence evidence and there is no round cap, all open §8 rows
must be completed before Checkpoint A can pass.

## Should-fix

### SF1. An accepted duplicate suppresses a settled `already_submitted` violation

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:260`

`finalizationStatus` returns on the first accepted record without first checking all settled
correlated records for `already_submitted`. A run containing both shapes freezes as accepted even
though §3.2 makes that reason categorically invalid. Scan settled correlated finalizations for the
categorical reason before accepting any duplicate, and add both response-order witnesses.

### SF2. Recorded-plan identity and inventory are not validated

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1175`

Plans are matched only by evaluation request seq. Their `stepIndex` is ignored, duplicate records
are collapsed by `find`, and extra records are never reported. A plan attributed to the wrong step
can therefore stand in for the required evidence. Validate an exact one-to-one inventory keyed by
step and evaluation, rejecting duplicate, misattributed, and unused plan records.

### SF3. First-step permits are allowed outside the first visit window

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:342`

The lower-fence check is disabled for step zero, so a check permit stamped before the first identity
fence can license an evaluation that occurs after entry. This contradicts the writer's stated
inside-visit-window rule and lets stale first-step evidence participate in causality. Apply the same
strict lower fence to every permit; pre-entry navigation evaluations remain governed by their
sequence rule and do not need this exception.

## Nits

None.

## Verification

- Verified 2026-08-07: **209/209 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-08) — all 10 findings addressed, 224/224 green

## B1 — ACCEPTED, pushback withdrawn. Route proof now offline AND online
Your dominance argument stands: the live side never compared plan target to successor, so my
"oracle owns traversal" claim was hollow. Offline: `ArchiveFacts.route_successors` (per screen,
where the expected-correct rule's navigation RESOLVES, `@end` for terminal) is REQUIRED and
every scenario EDGE is validated — a permuted middle now fails the build (witnessed), missing
successor facts fail loudly. Online: a non-final navigate plan whose normalized target is not
`next` must name the scenario's declared successor (`wrong-successor-target`, positive,
ungated); `next` is legal because the build proved the edge. Witnessed through auditRun.

## B2 — FIXED. The bidirectional half runs for EVERY screen
`rule_prior_state_refs` are inspected regardless of the manifest's `dependencies` list: a
ref whose owner (path prefix) is another screen demands BOTH the declaration ("without
declaring it as a dependency" — new failure) and a covering expectation. Witnessed with a
dependency-free screen carrying an archive rule ref.

## B3 — FIXED. Navigation evaluations require recorded plans
One recorded plan per usable nav evaluation (missing = absence conclusion, §3.2-gated;
divergence = positive), same as non-nav. On obligations, one scoped point stands and is now
DOCUMENTED in code rather than implied: the widget's internal ack has no wire trace, so for
the rotation's first (feedback/recheck) plan, the causal mint + ack-licensed second check IS
the observable fulfillment — and the sequence rule already demands exactly that shape,
including your round-1 fencing (mint strictly between first response and second request; a
late mint is rejected — new witness). If you see an observable ack signal we're not using,
name it.

## B4 — FIXED. Content steps license exactly one evaluation
Cardinality is role-aware (`licensed = 1` unless graded-with-recheck), and the second-eval
causal edge is graded-only. Witness: content screen + ack + two usable evaluations →
`evaluation-count` + `evaluation-no-causal-edge`.

## B5 — FIXED. Part-attempt ordering by first observation, not save recency
Buckets keep `firstSeen` (first save responseSeq that carried the part-attempt guid); the
newest part attempt per part_id is the LATEST FIRST-SEEN, and a delayed save carrying an older
guid updates the older bucket only — it can never resurrect it. Save-wholesale-replacement
kept within each part attempt. Crossed-ordering witness added (pa-2 observed, pa-1's late
save → state stays pa-2's).

## B6 — FIXED. `contains` scalar branch mirrors the string-only production gate
Non-string scalar inputs refuse after the array branches (`contains.ts:41-49`); `notContains`
inherits the negation (returns true there — that IS production behavior, witnessed).
Type-crossed rows added. NOTE on the remaining edge: production's array-condition branch
calls `inputValue.toLocaleLowerCase()` and would THROW on a non-string scalar — a crash
cannot be mirrored in a pure matcher; we refuse (`false`) instead, documented in code.

## B7 — ADDRESSED. §8 rows closed this round
Added: all four disqualifying final-step targets (prev/first/last/explicit); late-mint
rotation fencing; §3.2 matrix through auditRun (closed sealed window draws absence
conclusions, `seal_incomplete` suppresses journal-wide); LLM-feedback ack obligation through
auditRun (reject + accept); wrong-lineage prior state through auditRun; accepted-duplicate ×
categorical rejection crossing (journal); plan-inventory rows (SF2); fence row (SF3);
contains type-crossed rows (B6); scenario-edge and undeclared-dependency build failures
(B1/B2). Duplicate operation ids were already witnessed at manifest validation (screens and
refs). If any specific §8 row is still open in your reading, name the row.

## SF1 — FIXED. Categorical scan precedes acceptance
`finalizationStatus` scans settled correlated finalizations for `already_submitted` BEFORE
honoring any acceptance; a run holding both shapes rejects categorically. The
acceptance-wait test now distinguishes categorical (short-circuits pending) from
non-categorical (still waits on the in-flight duplicate). Both response orders witnessed.

## SF2 — FIXED. Plan inventory one-to-one, keyed by step AND evaluation
Duplicates and unmatched records are violations; lookups everywhere require
`stepIndex` + `evaluationSeq`, so a misattributed plan surfaces twice (missing at its true
step, unused at the claimed one) — witnessed.

## SF3 — FIXED. The lower fence binds step zero
No first-step exception; pre-entry navigation traffic is the sequence rule's business, and
the pre-entry fixtures now stamp permits inside the window. Witness: first-step permit before
the identity fence → `outside-window`.

Verification: 224/224 (`adaptive-journal/attribution/oracle/strict` suites), tsc clean
(2 pre-existing liveSocket), eslint clean, prettier applied. Still zero commits.
