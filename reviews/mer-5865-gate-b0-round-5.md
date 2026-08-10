**Verdict:** GATE-BLOCKED

**Counts:** 3 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the round-4 green-envelope closures reject the four reported mutations,
but the envelope still accepts hollow save and finalization records, the archive build facts do
not pin `combine_feedback`, and the bail test does not prove that its artifact is a shipped bail
or a sealed failure. Each path was mutation-replayed against the supplied artifacts and preserved
a 3/3 green gate.

## Round-4 closure validation audit

| Claim | Mutation replayed | Verdict |
|---|---|---|
| missing/truncated shipped ledger is rejected | round-4 ledger-stripped capture | CLOSED — gate failed |
| missing mandatory first-screen evaluation is rejected | round-4 missing-first-evaluation capture | CLOSED — gate failed |
| missing save records are rejected | round-4 saves-removed capture | CLOSED — gate failed |
| duplicate green runs are rejected | same green file supplied twice | CLOSED — gate failed |

The union-length comparison, route/ledger envelope, exact intentional-delta set, run identity,
and eight standing deletion witnesses therefore close the defects they directly exercise. The
findings below are different deletions that those witnesses leave alive.

## MATERIAL findings

### M1 — Mandatory save and finalization witnesses can be hollowed out while their record shells keep the gate green

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:200-235`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:111-162`

`validateGreenEnvelope` proves only that one terminal page-finalization record exists and that
each graded visit has some terminal save whose URL attempt guid equals the rendered attempt guid.
It does not prove that the finalization record is completed, parsed, 2xx, correlated, and carries
the accepted result required by section 3.2. It also does not prove that a save contains any
screen state at all. The snapshot's `freezeFlavor: accepted` is trusted as a serialized assertion
instead of being recomputed from the captured finalization evidence.

Two independent deletion replays stayed green:

- removing every save record's `partInputs` while retaining the save shells produced 3/3 passed;
- removing the finalization record's parsed acceptance fields and status while retaining its
  terminal shell produced 3/3 passed.

This can mask recorder/body omissions while the gate still claims the mandatory save-barrier and
accepted-finalization evidence exists. The rendered-attempt-guid binding is sound and preferable
to observer fence windows for the measured early saves, but presence plus guid is too weak.

**Required fix:** keep the attempt-guid binding, but require each manifest-derived graded-screen
save witness to be a completed 2xx save whose parsed payload contains the required screen/state
path evidence. Recompute page-finalization acceptance from the record and the run correlation;
if the snapshot does not carry the immutable correlation needed for that proof, include it in the
private dump. Add deletion witnesses that remove save payloads and finalization acceptance fields,
not only whole records.

### M2 — `combine_feedback` is capture-independent in origin but is not pinned by the archive completeness gate

**Location:** `<private scratchpad>/mer5865/extract_lote_facts.py:14-22,127-135`;
`assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:364-402,479-542`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:111-115,302-308`

The extractor puts the archive's `combineFeedback` value only into the manifest. `ArchiveFacts`
has no total per-screen reference for it, and `validateRouteCoverage` therefore cannot detect its
loss. Both the expected driver-evidence inventory and journal projection then consume the same
possibly missing manifest flag.

I removed every `combine_feedback` field from the supplied manifest and replayed it against the
unchanged archive facts and captures. Both build validators accepted it and the full gate passed
3/3 with the same reported counts. The mandatory combine-feedback derivations are consequently
not fail-closed over their archive source; a malformed flag is common-mode input to both replay
consumers.

**Required fix:** add a total, explicit per-screen combine-feedback map to `ArchiveFacts`
(including explicit false entries), compare it exactly to every manifest screen in
`validateRouteCoverage`, and add a flag-deletion mutation witness.

### M3 — The deliberate-bail test does not validate a bail envelope

**Location:** `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:164-175`;
`assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:181-205`

The replay asserts only that `poisonFired` is truthy and that the oracle contains a
`verdict-not-correct` violation at that screen. It never checks `outcome === "bail"`,
`flavor === "sealed"`, sealed snapshot state/completeness, or evidence that the shipped walker
actually threw at the poisoned screen.

I removed the bail artifact's outcome, flavor, and walker-error fields, and relabeled its snapshot
as frozen/accepted. The complete gate still passed 3/3. The same-screen oracle violation therefore
does not prove the spec's required shipped-bail-to-failure-sealed-journal differential.

**Required fix:** add a fail-closed bail envelope that requires the bail outcome, sealed flavor,
sealed and complete snapshot, fired poison, and structured/redacted shipped-walker bail evidence
at the same screen before auditing. Add deletion/corruption witnesses for every bail-envelope
field, including a mutation that relabels the snapshot as accepted.

## Recorded non-material findings

### N1 — The claimed single post-arm failure boundary still starts after navigation and correlation

**Location:** `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:151-181`

The recorder is armed before `page.goto`, login, outline opening, and `shadow.correlate`, but the
`try/catch` begins only around the strict walk and completion assertion. A failure in any earlier
post-arm operation leaves the recorder without `finish`, detach, or a partial dump. This cannot
make the current replay green because it produces no artifact, so it has no path to a live gate
decision or screen attribution. **Owner:** the step-3 capture harness; close before its next live
capture by putting every operation after `armShadowCapture` inside the one failure boundary.

### N2 — The private-destination check can be bypassed through a symlink

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:25-39`

`assertPrivateDestination` checks lexical ancestors of `path.resolve(dir)` for `.git` but never
resolves symlinks. A path under a symlink that targets the repository can therefore pass the
check and write the private dump into the worktree. This has no path to the current gate decision,
replay comparison, causal license, or screen attribution, so it is recorded rather than blocking
under the adopted materiality policy. **Owner:** the step-3 capture harness; close before any
future live capture by resolving the nearest existing ancestor with `realpath`, validating the
resolved destination, and avoiding a check/write symlink race.

## B0 questions

1. **The four documented deltas are not collectively acceptable yet.** The exact
   observer-invisible-first-screen delta and the observer-stamped fence stand-in are adequately
   bounded for these captures, and the presence-only predicate limits remain explicitly owned by
   step 5. The driver-evidence gap is pinned by step/screen/evaluation identity, but M2 shows that
   its expected inventory and replay still share an unpinned archive fact. M1 separately shows
   that advertised mandatory green evidence can be removed beneath surviving record shells.
2. **The navigation `none` amendment is correctly scoped.** It is legal only on navigation
   screens as the incorrect, non-navigating first half of the exact two-evaluation rotation. The
   changed attempt, causal completed 2xx mint, correct navigating second evaluation, usability,
   lineage, and two-evaluation ceiling remain enforced. Navigation singletons deriving `none`,
   non-navigation `none`, navigating first plans, missing/late mints, and non-navigating second
   plans remain violations.
3. **The step-4 go remains weakened.** M1 leaves two mandatory live evidence sources
   presence-only, M2 leaves a planner input common-mode and unpinned, and M3 does not prove the
   required shipped-bail differential. These must be closed before B0 licenses the driver swap.

## Deliberate strengthening decisions

- **Save binding:** binding saves by `renderedAttemptGuid` instead of observer fence windows is
  sound for the measured timing. The strengthening is too weak only because it validates record
  presence rather than the saved evidence itself (M1).
- **Exact intentional-delta set:** sound for this fixed archive gate. It correctly turns loss of
  the mandatory first-screen delta into a red result and does not broaden the delta classifier;
  the same audit must still clear the navigation sequence.

## Verification performed

- Baseline offline gate: 3/3 passed; each green reported 0 in-scope violations, 65 pinned
  driver-evidence violations, 0 unexplained differences, and exactly 1 intentional difference;
  the bail reported its same-screen violation.
- Round-4 negative replays: ledger-stripped, missing-first-evaluation, saves-removed, and
  duplicate-run all failed the gate.
- New negative replay — all save payloads removed, save shells retained: **passed incorrectly**
  (3/3).
- New negative replay — finalization acceptance body/status removed, terminal shell retained:
  **passed incorrectly** (3/3).
- New negative replay — all manifest `combine_feedback` fields removed: **passed incorrectly**
  (3/3).
- New negative replay — bail outcome/flavor/walker-error removed and snapshot relabeled
  frozen/accepted: **passed incorrectly** (3/3).
- `npx playwright test adaptive- --reporter=line`: 261/261 passed.
- `npx tsc --noEmit`: only the two fenced `liveSocket` errors.
- Scoped ESLint passed. Scoped Prettier passed with the existing unknown import-order option
  warnings.
- Security and performance review found no additional material issue under the B0 policy.

---

# WRITER RESPONSE (Claude, 2026-08-10) — all three MATERIAL fixed as a class + both recorded items closed; hollowing guardrail adopted

All four of your negative replays were reproduced against the unmodified gate before any fix
(3/3 green each, exactly as reported). Class defect this round: witnesses proved records
EXIST, not that they CARRY their evidence. Fix: envelopes recompute content against
capture-independent or cross-source references, and the deletion-witness guardrail is
extended to HOLLOWING witnesses.

## M1 — FIXED: acceptance recomputed; saves must carry the screen's own state

- Finalization: `freezeFlavor` is no longer the license. The envelope recomputes §3.2
  acceptance from the record itself — terminal `completed`, status 2xx, `action=finalize`,
  `commandResult=success`, run-correlation fields present, and the record's section slug
  EQUAL to the one slug the entire wire proves (every `/state/course/<slug>/` URL in the
  capture must agree; a second slug is itself a violation). Cross-SOURCE, available on the
  existing captures.
- Saves: guid binding retained, plus the save must be terminal `completed` and its parsed
  `partInputs` must contain at least one part path prefixed by the OWNING screen's id — an
  empty shell or a foreign screen's state fails.
- Creation: the mint must carry its server-minted guid (hollowed mint also kills
  `runIdentity`).
- **Measured pushback on one detail of your required fix:** "completed 2xx save" would
  reject every GENUINE capture — the live deck 403s a stable subset of saves (16 of 29 on
  BOTH greens; 11 graded screens whose only save is 403, identical screen set across runs).
  The witness therefore requires completed + own-state payload, not 2xx; the 403 pattern is
  recorded in the evidence doc as a measured fact for step 4 to explain.
- Future strengthening shipped: `dump()` now records the delivery-props correlation (DOM
  source) beside the journal, so step-4 gates can pin the finalization against a second
  independent source on fresh captures.

## M2 — FIXED: combine_feedback pinned by the archive facts

`ArchiveFacts` gains a TOTAL per-screen `combine_feedback` map (explicit false included);
`validateRouteCoverage` enforces totality (absent key = missing evidence, extra key =
inventory mismatch) and EXACT per-screen equality against the manifest. The extractor emits
it (22 entries, 4 true — matching the manifest's 4 combining screens); facts regenerated.
Contract tests cover totality, mismatch both directions, and the exact match. Your
manifest-stripped replay now fails in the build gates, before any comparison.

## M3 — FIXED: fail-closed bail envelope

`validateBailEnvelope`: outcome `bail`, flavor `sealed`, snapshot sealed with NO freeze
flavor and not seal_incomplete, poison fired on an ON-ROUTE GRADED manifest screen, the
shipped walker's own error present and NAMING that screen, and visits forming a proper
prefix of the archive scenario. Your relabeled-bail replay fails it; the relabeled bail
passed as green fails the green envelope on route length.

## Guardrail extended — hollowing witnesses adopted

Your recommendation is implemented as a second standing gate test (`the envelopes reject
hollowed evidence, not just missing records`): save shells without payloads, saves carrying
another screen's state, hollowed finalization, finalization for another section, mint
without a guid, manifest stripped of combine flags, bail relabeled green, poison unfired,
walker error absent, walker error naming no screen — TEN witnesses, all in-memory from the
real captures.

## N1 — FIXED: the failure boundary now begins at arming — navigation, login, outline
opening and correlation are inside it; any post-arm failure seals and dumps exactly once.

## N2 — FIXED: the destination is resolved through its nearest EXISTING ancestor with
`realpath`, the `.git` scan runs on the REAL path, and that same real path is the one
written to — no lexical bypass, no check/write divergence.

## CLAIMS TABLE (what the green gate now proves, against what, with which witness)

| Claim | Checked against | Red witness (all replayed) |
|---|---|---|
| visit+ledger sequence = the selected route | archive `manifest.scenario` (build-gated) | ledger missing/truncated; route order swapped |
| snapshot is an accepted green | §3.2 acceptance RECOMPUTED from the finalization record + wire-slug cross-source | finalization hollowed; foreign section slug; bail relabeled green |
| exactly one real mint | creation record, server-minted guid | creation dropped; guid nulled |
| mandatory first-screen rotation | scenario-head role (manifest) + journal count = 2 | first rotation evaluation removed |
| every graded screen saved its own state | manifest roles + guid-bound saves carrying own-screen part paths | saves dropped; payloads emptied; foreign-screen payloads |
| combine_feedback correct per screen | ArchiveFacts total map, exact equality | manifest flags stripped (build gate) |
| driver-evidence gap exactly the expected multiset | inventory keyed step\|screen\|code\|detail\|seq from journal+manifest — cardinality is journal-derived; its completeness is pinned by the witnesses above | round-4 omission replays (64≠65 paths all red now) |
| intentional deltas exactly the required set | manifest-derived expected list | delta-erasing omission (r4 replay) |
| two distinct green runs | creation minted guid inequality | same file twice |
| bail = same-screen differential | bail envelope + oracle `verdict-not-correct` at `poisonFired` | relabel/strip/unfired/wrong-screen mutations |

Known-weak row, stated: the driver-evidence CARDINALITY row's reference is the journal
itself; it is acceptable only because every journal-completeness witness above is
capture-independent. If a reviewer can construct an omission that survives all of those AND
shifts the inventory, that row is the hole.

## Verification

- Baseline gate 4/4 on unchanged artifacts (greens: in-scope 0, unexplained 0, exactly 1
  intentional delta, 65=65; bail enveloped + poison-stamped).
- ALL EIGHT negative env replays fail: your four round-5 mutations + all four round-4
  mutations (no witness regressed).
- Full suites 262/262 (`adaptive-`; +1 = the combine_feedback contract test; one unrelated
  authoring-spec flake — modal backdrop — passed on retry and on the clean rerun).
- tsc: only the two fenced `liveSocket` errors. ESLint clean. Prettier applied.
