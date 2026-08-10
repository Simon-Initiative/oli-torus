**Verdict:** GATE-BLOCKED

**Counts:** 2 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the supplied artifacts themselves are credible, and both round-3 closures
survive independent mutation checks, but the replay gate is not fail-closed over its evidence.
A green capture with no shipped ledger still passes, and the purportedly pinned driver-evidence
inventory silently shrinks when mandatory first-screen traffic is removed. Both are direct
false-green paths under the adopted malformed-input/common-mode policy.

## Round-3 closure validation audit

| Claim | Internal evidence read | Mutation replayed | Verdict | Confidence |
|---|---|---|---|---|
| M1: local rule-reference completeness is non-vacuous | extractor v4, manifest extractor, `validateRouteCoverage` | fabricated uncovered local reference KILLED; one expectation removed while other expectations remained KILLED | TRUE | high-exhaustive for the supplied extractor/artifact path |
| M2: driver-evidence identity pins screen, step, and evaluation sequence | `expectedDriverEvidence`, `driverEvidenceInventory`, oracle violation facts | moved owner BREAKS equality; cross-screen same-class owner swap BREAKS equality | TRUE | high-exhaustive for the inventory functions |

The round-3 writer responses are therefore accurate as far as those two stated mutations go.
The new M2 below is a different defect: the individual keys are pinned correctly, but the
expected key set and cardinality are recomputed from the same possibly incomplete capture.

## MATERIAL findings

### M1 — A missing or truncated shipped ledger turns the differential comparison into a vacuous pass

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:221-275,287-293`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:53-74`

`evaluateGreenCapture` passes `dump.ledger ?? []` to `compareProjections`, and the comparison
iterates only the ledger entries that exist. The gate never validates that a green dump has a
ledger, that its length equals the archive route/shadow projection, or that the dump is an
accepted green outcome. I removed the ledger field from one supplied green capture and replayed
the exact B0 command: both tests still passed, reporting zero in-scope violations, zero
unexplained differences, and zero intentional differences for that capture. A truncated ledger
similarly leaves its omitted tail uncompared.

This is material because the gate can claim differential agreement without any shipped account
at all, masking every ledger-side disagreement. Require a validated green-capture envelope before
evaluation: `outcome === "green"`, frozen/accepted snapshot, a ledger array whose length exactly
matches both the validated scenario and shadow projection, and a distinct run identity for each
of the two required green runs. Make `compareProjections` compare the full union/max length so a
missing entry on either side is a difference. Add missing-ledger, short-ledger, wrong-flavor, and
duplicate-run mutation witnesses.

### M2 — The “pinned” inventory and delta checks adapt to missing mandatory journal evidence

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:82-119,221-275`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:53-74`

The actual violation keys now preserve screen/step/sequence identity, but
`expectedDriverEvidence` derives the expected key set from the same capture whose completeness it
is meant to guard. The test also accepts any number of intentional deltas, including zero. I
removed only the first evaluation of the mandatory first-screen rotation from one supplied green
capture, leaving the causal mint and navigating evaluation. The oracle then saw a legal navigating
singleton, the expected and actual driver inventories both shrank from 65 to 64, the required
observer-invisible delta disappeared, and the full B0 replay still passed. Removing every PATCH
save from that capture also passed, despite those saves being listed as mandatory live evidence.

This is material because recorder omissions become common-mode input to the oracle, projection,
and expected-inventory builder; the gate can preserve green while the evidence it is licensing is
absent. Pin the capture-level mandatory witnesses independently of the mutable journal: the exact
first-screen two-evaluation rotation and causal mint, at least one required intentional delta per
green, the reviewed driver-evidence cardinality/key set (or an equivalently independent contract),
and archive-derived save-barrier evidence. Add the two removal mutations above as rejecting gate
tests.

## Recorded non-material findings

### N1 — Detach is not finally-owned across the whole shadow-enabled live flow

**Location:** `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:183-213`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:180-201`

`finish` detaches in its own `finally`, but the success path calls it only after the completion
text assertion. If the shipped walker returns and that assertion throws, neither `finish` nor
`detach` runs and no partial dump is retained. This cannot make the reviewed gate green—the run
produces no green artifact—so it has no path to a current replay decision or screen attribution.
Owner: the step-3 capture harness; close before the next live capture by wrapping the entire
post-arm flow in one outer `try/finally` that seals/dumps or detaches exactly once.

### N2 — The private-output contract is advisory; any environment path is accepted

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:203-209`;
`assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:157-166`

The raw dump contains submitted values, but `dump` creates and writes any directory supplied by
`MER5865_SHADOW_DIR`, including a path inside the repository. The reviewed artifacts used the
private scratchpad, so this does not affect a live decision, replay comparison, causal license, or
screen attribution in this gate. Owner: the step-3 capture harness; close before the next live
capture by rejecting repository-contained destinations (or enforcing a dedicated private root)
before arming the recorder.

## B0 questions

1. **The four deltas are not collectively acceptable yet.** The presence-only predicate limit
   and observer-stamped fences are acceptable stand-ins for these supplied captures, with their
   named step-4/step-5 owners. The observer-invisible sequence and driver-evidence gap are not
   fail-closed in the replay because M2 lets required evidence and the advertised 65-key
   inventory disappear together. M1 separately allows the entire shipped side to disappear.
2. **The navigation `none` amendment is correctly scoped.** It is admitted only on navigation
   screens as the incorrect, non-navigating first half of the exact two-evaluation rotation;
   changed attempt, causal 2xx mint, correct navigating second evaluation, usability, lineage,
   and the two-evaluation ceiling remain binding. Non-navigation `none`, singleton `none`, a
   navigating first plan, a missing/late mint, and a non-navigating second plan remain illegal.
   The supplied live capture contains the claimed empty-actions first result without requiring
   any answer value in this review.
3. **The capture artifacts support the intended step-4 direction, but the gate implementation
   does not yet support the go decision.** Both supplied greens are full accepted captures with
   22 visits, a 22-entry ledger, 23 evaluations, one creation, 29 saves, and accepted page
   finalization; the supplied bail is sealed, complete, poison-stamped, and its stored walker
   error names the poisoned screen. M1/M2 show that none of those essential envelope/completeness
   facts is enforced strongly enough when the replay input is malformed or incomplete.

## Verification performed

- Replayed the supplied gate command: 2/2 passed; each green reported 0 in-scope, 65 pinned
  driver-evidence violations, 0 unexplained differences, and 1 intentional difference; the bail
  reported one same-screen violation.
- Replayed the round-3 M1 mutations: fabricated uncovered reference KILLED; retained refs with a
  dropped expectation KILLED.
- Replayed the round-3 M2 mutations against a real green capture: moved ownership and a
  cross-screen same-class owner swap both broke inventory equality.
- Negative gate mutations: missing green ledger PASSED incorrectly; missing first navigation
  evaluation PASSED incorrectly with 64/64 and no intentional delta; all PATCH saves removed
  PASSED incorrectly.
- `npx playwright test adaptive- --reporter=line`: 261/261 passed in this checkout.
- `npx tsc --noEmit`: only the two fenced `liveSocket` errors.
- Scoped ESLint passed. Scoped Prettier passed, with its existing unknown import-order option
  warnings.
- Security and performance checklists produced no other material finding.

---

# WRITER RESPONSE (Claude, 2026-08-10) — both MATERIAL fixed as a class + both recorded items closed, all with replayed witnesses

Both findings verified real before fixing: your three mutated dumps replayed against the
unmodified gate — all three passed incorrectly, exactly as reported. The class defect behind
both: the gate trusted CAPTURE-INTERNAL facts for completeness; nothing pinned the capture
envelope against capture-independent references.

## M1 — FIXED: fail-closed green envelope + union comparison + distinct-run identity

`validateGreenEnvelope(dump, manifest)` (projector) runs BEFORE any comparison and demands:
- `outcome === 'green'`, `flavor === 'accepted'`, snapshot `frozen/accepted`, no
  `sealIncomplete`, no `finalizationFailure`, no `freezeTimeout`;
- visits AND ledger each EXACTLY match the archive scenario route — length and per-index
  screenId (the reference is the manifest the archive build gates validated, never the
  capture under judgment);
- `compareProjections` now iterates the union length — a shadow step the ledger never
  covered is a `presence` diff, not silently uncompared.
`runIdentity(dump)` (the single terminal creation's server-minted guid) must be non-null and
DISTINCT across the greens — the duplicate-run hole is closed.

Witnesses replayed: your ledger-stripped dump → FAILS; truncated ledger → FAILS; bail passed
as green → FAILS; same green twice → FAILS ("green captures must be distinct runs").

## M2 — FIXED: mandatory witnesses must EXIST, pinned by capture-independent references

The evidence-doc mandatory list is now enforced, not advertised:
- first-screen rotation: when the scenario's first screen is navigation (manifest-derived),
  EXACTLY 2 owned evaluations on step 0;
- EXACTLY 1 terminal creation (the mint chain) and EXACTLY 1 terminal page finalization;
- every graded screen (manifest roles) carries ≥1 terminal save bound by the visit's
  `renderedAttemptGuid` — guid binding, not fence windows: measured on BOTH greens, 3 of 19
  graded screens' saves hit the wire before the observer stamps the next entry fence, so
  window attribution under-counts while the attempt guid is the direct causal binding;
- the intentional-delta set is asserted EXACTLY (manifest-derived: one
  observer-invisible-first-screen-traffic delta at step 0 when it is navigation) — a capture
  that loses the mandatory delta fails instead of passing with fewer deltas.

Witnesses replayed: your missing-first-evaluation dump → FAILS (rotation witness); your
all-saves-removed dump → FAILS (save witness). Plus in-repo deletion witnesses for the mint,
the finalization, and a broken route order.

## Reviewer guardrail — ADOPTED as a standing gate test

"Evidence gates require deletion mutations for every mandatory evidence source" is now
enforced in-repo: the new gate test `the envelope rejects a green capture with any mandatory
evidence removed` carries EIGHT deletion/corruption witnesses built in-memory from the real
capture (missing ledger, truncated ledger, wrong flavor, dropped rotation evaluation,
dropped saves, dropped creation, dropped finalization, broken route order) and replays
offline with the same env inputs. Recommended for the reviewer instructions as well —
writer-side it is now spec practice.

## N1 — FIXED: one failure boundary owns the whole post-arm flow (lote spec): the walk, the
ledger log and the completion assertion share one try — ANY failure seals and dumps the bail
capture exactly once before rethrowing; no armed run can end without a terminal snapshot.

## N2 — FIXED: `dump()` refuses any destination inside a git repository
(`assertPrivateDestination` walks the resolved path's ancestors for `.git`) — the private
contract is enforced, not advisory.

## Verification

- Baseline replay (unchanged artifacts): gate 3/3 — both greens in-scope 0, unexplained 0,
  intentional exactly the one required delta, 65=65 pinned; bail poison-stamped at its screen.
- All four negative env replays FAIL as required (your three + duplicate-run).
- `npx playwright test adaptive-` 261/261. Count reconciliation: the HANDOFF's "257" was
  stale — Codex measured 261 on the PRE-fix tree with the same filter, and the uncommitted
  diff removes no tests (the oracle spec change is a 1-for-1 flip of the nav-`none` witness).
- tsc: only the two fenced `liveSocket` errors. ESLint clean. Prettier applied and clean.
