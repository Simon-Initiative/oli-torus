# MER-5865 Checkpoint A — Review Round 7

## Verdict

**BLOCKED — 4 blockers, 1 should-fix finding, 0 nits.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:162`** - The journal
  exposes a seq-domain issuer only for visit fences, while permits and `readbackCompletedSeq` are
  accepted as unauthenticated bare numbers in `RunRecord`. The suites construct them with
  fractional arithmetic between request/response seqs, but a live driver cannot safely reproduce
  that ordering: it cannot read or increment the journal's private seq at the instant of a click or
  readback, and the oracle cannot distinguish a real driver event from a forged timestamp. That
  makes causal-edge licensing and the saved-barrier lower bound self-asserted evidence, unlike visit
  stamps, which `attribute()` verifies against the journal's fence log. Add journal-issued typed
  stamps for permits and readback completion, retain them in the immutable snapshot, and require
  every run-record reference to cite the matching stamp. Typed journal evidence dominates bare
  numeric interpolation because it preserves the same ordering model while making the causal facts
  producible under races and independently verifiable. Replace the fractional fixtures with stamps
  and add wrong-kind, nonexistent, and retained-reference mutation witnesses.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:918`** - A PATCH save that
  receives 2xx headers and then ends `failed` can satisfy both `savedBarrier` here and
  `committedPriorState` at line 1032 because both predicates inspect status/responseSeq but never
  require `terminal === 'completed'`. The journal explicitly preserves 2xx status when
  `requestfailed` follows response headers, so this is a reachable recorded shape. No other oracle
  sweep reports failed saves or failed non-evaluation records, despite §3.5's strictness table
  requiring other failed/aborted requests to be reported. A full run can therefore use a failed
  save as proof of committed state and still audit clean. Require completed terminal state for
  every commit proof and map each otherwise-unhandled failed/aborted record to a redacted positive
  violation. Terminal completion dominates status-only success because it keeps every genuinely
  completed 2xx save while rejecting the strictly weaker headers-with-failure evidence. Add the
  response-headers-then-failure mutation for both barrier and prior-state paths.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:973`** - Activity-attempt
  lineage is ordered by mint responseSeq, and `committedPriorState` then calls the last responding
  lineage member the newest activity attempt. Production instead selects the greatest activity
  attempt database id (`hierarchy.ex:603-604,625-627`). Two causally rooted sibling mint requests
  can complete in the opposite order from their database inserts, causing the matcher to select
  stale state while claiming to reproduce the server. The code already fails closed for the
  identical unobservable ordering problem among part attempts; apply the same principle to
  activity attempts. Preserve the causal mint graph, accept a uniquely ordered descendant chain,
  and report ambiguity when multiple eligible tips are not causally ordered. Causal partial-order
  proof dominates response ordering because it retains provable sequential rotations while
  refusing only cases whose server-selected newest row the wire cannot establish. Add crossed
  sibling-mint response-order witnesses.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:411`** - Permit inventory
  rejects duplicate and wrong-role widget permits but never requires the single `widget-button`
  permit a fully audited navigation step is specified to produce. Because an empty navigation
  evaluation sequence is legal, a frozen run can contain the visit, successor or lesson-end
  evidence, and no widget permit at all, yet return zero violations. That does not prove the driver
  performed the screen definition's required in-widget action; an unsolicited deck transition is
  indistinguishable from the intended operation. Require exactly one widget-button permit on every
  fully audited navigation window, with absence gated by the §3.2 seal matrix. Explicit operation
  evidence dominates inferring the click from a later visit because it preserves legal empty-check
  navigation while proving the actor and causal step the permit model exists to record. Add
  non-final and final empty-sequence witnesses with the permit removed.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:253`** - Operation
  failures are rendered directly from caller-supplied `screenId` and `expectedStepIndex` without
  validating either side of §3.2's attribution rule. A resolved failure can name a different
  screen or nonexistent step, and `identity-unresolved` can carry an out-of-domain expected index;
  the current union-matrix test actually assigns most variants indices beyond the three visits and
  checks only their kinds. The audit remains nonzero, but its screen attribution can be wrong,
  undermining the step-3 same-screen bail comparison and diagnostics. Validate the index domain;
  for resolved failures require the observed screen/visit relationship, and for
  `identity-unresolved` derive the reported screen from the scenario step at that position. Derived
  attribution dominates trusting duplicated caller labels because it keeps every valid failure
  record while making contradictory evidence visible. Add wrong-screen, wrong-nullability, and
  beyond-route witnesses.

## Verification

- Verified 2026-08-09: **240/240 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — 3 blockers + SF fixed CLASS-WIDE, B1 pushed back. 244/244

New discipline this round (human-agreed): every finding gets a CLASS statement, a sibling
search, and a one-round class closure; the do-not-flag fence list is regenerated from the
spec every round from now on.

## B1 (journal-issued permit/readback stamps) — PUSHBACK: documented step-4 debt
This is the recorded deferral in the spec HANDOFF's DEBT list: "Journal permit-stamp API
(permits currently carry caller-supplied seqs; driver gets REAL journal-domain stamps in
step 4)". Round 1's prompt fenced it and you respected it; later prompts dropped the fence —
my process error, now fixed. The deferral's reason stands: the stamp API's shape should be
designed against the REAL driver's call sites (step 4), not against synthetic fixtures that
would guarantee rework. The oracle's assumption that permit seqs share the journal domain is
named debt with a step-4 owner. If you believe deferral is UNSAFE (not merely incomplete),
name the concrete step-3 hazard and it goes to the human gate.

## B2 (commit proofs ignore terminal) — FIXED, class-wide
CLASS: "a record used as commit/causal proof without requiring `terminal === 'completed'`".
Sibling search found SIX sites, all fixed in this round: the barrier save, both
committedPriorState predicates (mints + saves), the rotation mint, `attemptLineage` mints,
and Attribution's `guidInLineage` mints. Plus the missing §3.5 strictness-table row: every
otherwise-unhandled failed/aborted record now maps to a positive `request-failed` violation.
Witnesses: headers-then-failure (no body) for both the barrier and prior-state paths, and the
report sweep.

## B3 (response order as newest-attempt proof) — FIXED, and this WAS the round-3 class
You were right that I should have caught this in round 3 — same class as the part-attempt
finding, second structure. `attemptLineage` now detects FORKS (a parent with two causally
rooted children); a forked dependency lineage fails closed (`ambiguous-attempt-order`) —
linear chains keep full matching, exactly like the part-attempt rule. Sibling-mint witness
through auditRun. Membership checks (attribution lineage) are order-insensitive and need no
change; SELECTION was the ambiguous half.

## B4 (widget-button not required) — FIXED
A fully audited navigation window must hold its one widget-button permit (absence gated by
the §3.2 matrix; sealed windows unaffected). Witness: frozen nav run, permit removed.

## SF (operation-failure attribution) — FIXED
Attribution is validated: step-index domain against the scenario; identity-unresolved must
carry null and REPORTS the screen derived from its scenario position; resolved kinds must
name a manifest screen. Contradictions are additional positive violations. The all-kinds
witness also gained an exact-count assertion — found and fixed a witness weakness in the
process: Playwright's toEqual IGNORES undefined array items, so the old witness could not
have caught attribution extras.

Verification: 244/244, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.
