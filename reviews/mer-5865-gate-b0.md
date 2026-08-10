# MER-5865 gate B0 — shadow differential evidence

**Verdict:** GATE-BLOCKED

**Counts:** 3 MATERIAL; 5 recorded-non-material.

**Decisive reason:** the green judgment is not independent across the contract, causal-license,
and recorded-plan dimensions. The projector copies contract facts from the shipped ledger and
synthesizes permits/plans from the journal events they are meant to validate. Those paths can
preserve a zero-violation/zero-unexplained-diff result under exactly the common-mode and
self-asserted-evidence cases that the HANDOFF materiality policy makes blocking.

## B0 questions

1. **The four deltas are not collectively acceptable stand-ins.** Observer fences and the
   shadow-only regex projection are acceptable for this capture with the recorded limitations.
   The synthesized causal permits, omitted barrier stamps, and replay-derived plans are not
   acceptable as evidence of their corresponding invariants, and the ledger-derived contract
   compounds that problem.
2. **The navigation `none` amendment is correctly scoped.** `none` is admitted only as the
   incorrect, non-navigating first half of the two-evaluation navigation rotation; the causal
   mint, changed attempt, correct navigating second evaluation, and two-evaluation ceiling still
   bind. Non-navigation `none`, navigation singletons, navigating first plans, missing/late mints,
   and non-navigating second plans remain illegal. One captured occurrence is sufficient evidence
   for adding this observed legal shape; the rule does not infer that every navigation screen
   produces it.
3. **The capture itself is credible, but the projection methodology weakens the step-4 go
   decision.** The two supplied green captures replay as accepted freezes with clean audits, and
   the sealed poison capture yields one violation at the poisoned screen. Findings M1–M3 prevent
   those results from serving as the independent equivalence evidence required by B0.

## MATERIAL findings

### M1 — The oracle contract and two claimed projection fields are copied from the shipped ledger

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:108-128`,
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:246-255`,
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:295-302`

The shadow manifest's route, roles, grading expectations, and receipts all originate in the
shipped ledger. `projectFromJournal` then copies `role` and `expectedEvaluations` from that same
ledger, so their comparisons are identities rather than differentials. `payloadMatch` is only as
independent as an oracle whose manifest expectation and receipt were both made from the same
ledger receipt. A malformed role can suppress graded verdict/payload auditing, and a malformed
receipt can become both the asserted contract and the evidence said to satisfy it. This is a
direct common-mode false-green path under HANDOFF lines 51–60. B0 needs an independently derived
shadow map/scenario/role/expectation source, plus mutation witnesses showing that each projected
ledger field can disagree.

### M2 — Permits are back-filled from the evaluations they license, while barrier evidence is omitted

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:134-184`

Every navigation visit receives a widget permit unconditionally; every non-navigation first
evaluation receives a check permit positioned immediately before it; and a feedback ack is placed
between the response and second request (or just after the response) after those events are known.
The same synthesized receipt omits `savedBarrierPrefixes` and `readbackCompletedSeq`. Therefore an
unsolicited evaluation, a missing/early acknowledgment, or a save that does not satisfy the
readback-to-check barrier cannot make the shadow audit fail. The observed saves and mint remain
useful journal-capture evidence, but `auditRun: no violations` does not independently validate the
causal-license or barrier invariants. This finding is about the gate consuming self-asserted
permits, not the fenced journal permit-stamp API implementation that step 4 owns.

### M3 — Recorded-plan agreement is replayed with the oracle's helper and authored planner input is inferred from the response

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:187-220`,
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:237-256`,
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:303-306`,
`assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1347-1386`,
`assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1483-1511`

The projector creates each "recorded" plan with `planTransition`, and the oracle replays the same
record through the same function, so replay agreement cannot diverge. `combine_feedback` is also
inferred from result cardinality rather than read from the authored screen, then reused by both
sides. The only independent shipped comparison is the final transition kind on non-navigation
screens; navigation transitions are forced to `null`, and intermediate plans, ack shape, and plan
targets are not compared. A shared planner/coercion defect can therefore stay green, especially on
navigation and multi-evaluation paths. Real step-4 plan stamps will close this, but B0 cannot use a
tautological shadow replay as evidence that the seam is ready to swap.

## Recorded non-material findings

### N1 — The `pre-entry-traffic` label is broader than the captured fence evidence

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:281-291`,
`assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:83-150`

Any positive first-navigation count difference is classified as pre-entry without checking the
record's pre-entry flag. In the reviewed captures, the observer fence precedes the extra first-screen
evaluation, so the artifact proves shipped-observer-invisible first-screen traffic, not its exact
position relative to the future driver's identity-read fence. This does not change its screen owner
or bypass the navigation sequence audit, so it does not hold B0 independently; rename/tighten the
classifier when the step-4 driver supplies the real fence.

### N2 — Regex expectations are weakened to presence-only in shadow

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:69-96`

The projector cannot independently re-check regex value semantics. For these green captures, the
shipped walker already evaluated those receipts and its folded payload result is compared, so the
weakening does not create a current green from a shipped failure. It must not become the step-4
manifest conversion rule: encode exact v2 predicates where possible or assign the missing operator
before its first live consumer.

### N3 — The replayable bail assertion does not pin the poison-caused violation

**Location:** `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:41-52`,
`assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:164-165`

The caller discards `armPoison(...).fired()`, the dump carries no poison-fired stamp, and the replay
accepts any violation at the externally supplied screen. The reviewed artifact contains exactly the
expected wrong-verdict violation at that screen, so the present B0 attribution is not false-green.
Record the fired screen in the capture and assert the expected violation code before reusing this
gate.

### N4 — The shadow recorder remains attached after freeze/seal

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:180-191`

`finish` terminalizes the core but never detaches the Playwright listeners. The terminal snapshot is
immutable and the page is torn down after this test, so the reviewed evidence cannot change; add a
finally-owned detach when this harness is retained or reused.

### N5 — Scoped formatting verification is not clean

**Location:** `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:2073`

The focused Prettier check reports this modified witness file. ESLint passes, the 120 oracle tests
pass, the two capture-backed gate tests pass, and TypeScript reports only the two fenced existing
`liveSocket` errors. Batch-format the witness; this has no path to a gate decision.


---

# WRITER RESPONSE (Claude, 2026-08-09) — all 3 MATERIAL + all 5 recorded items fixed

## M1 — FIXED: the contract is now archive-derived
The extractor (Track A) was extended to translate grading expectations from the AUTHORED
CORRECT RULES (paths, operators, values — §3.8's operator identity mapping; session.* run-state
conditions correctly excluded). 19/19 LotE graded screens covered: 22 exact predicates, 2
presence-only on one divergent-correct-rules screen (extractor-noted). The projector consumes
that manifest (roles, route, combine_feedback included) — the shipped ledger contributes
comparison TARGETS only. Role and expectedEvaluations are no longer copied: role compares
manifest-vs-ledger; expectedEvaluations compares the shipped licensed count against the
journal-OBSERVED count.

## M2/M3 — FIXED: nothing is synthesized
No permits, no recorded plans, no ledger receipts. The oracle runs bare, and the violations
only a driver can discharge form a CLOSED documented list (`isDriverEvidenceViolation`):
causal edges, widget-button presence, recorded plans, feedback acks. They are REPORTED and
counted (65 per green run) as the shadow's stated gap, closed by step 4's real stamps — the
green claim is explicitly scoped to journal-derivable invariants. Replay tautology is gone
with the synthesized plans; combine_feedback now comes from the archive facts.

## N1..N5 — FIXED
Delta renamed `observer-invisible-first-screen-traffic`, classified only when the §3.4
sequence rule cleared the sequence in the same audit; bail dumps carry a poison-fired stamp
and the gate asserts `verdict-not-correct` at that screen; the recorder detaches in `finish`'s
finally; the witness file is formatted; N2 stands recorded as the step-5 regex-operator
decision.

## Round-2 evidence (same captures, independent judgment)
Green ×2: in-scope 0, unexplained 0, 1 classified delta, 65 driver-evidence (documented).
Bail (fresh run, stamped): verdict-not-correct at the poisoned screen.
