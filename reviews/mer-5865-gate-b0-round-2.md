# MER-5865 gate B0 — round 2 shadow evidence

**Verdict:** GATE-BLOCKED

**Counts:** 3 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the claimed archive-independent contract still takes each screen's role
from the same private answers manifest that drives the shipped walker. That shared role controls
whether the shadow creates a receipt and audits verdict/payload, so a common malformed role can
still make both sides agree while suppressing the checks that would expose the defect.

## Round-2 questions

1. **M1 is not fully resolved.** Grading predicates and archive route facts are separately
   derived, but roles remain common-mode with the shipped driver (M1), and the replay does not run
   the archive-completeness validator that would make the extracted contract fail closed (M2).
2. **The five-class driver-evidence list is not sound as a closed list.** The observed violations
   in the supplied green captures are consistent with the documented driver gap, but
   `receipt-missing` is contract/projector evidence, not evidence only a future driver can supply.
   The gate also does not pin the observed class/count inventory, so this class can absorb a new
   projector/contract failure (M3).
3. **The evidence does not yet support the step-4 go decision.** Both green captures and the
   poison-stamped bail capture replay as documented, and the scoped test/static checks are clean
   apart from the two fenced `liveSocket` errors. Those successful executions do not close the
   false-green paths below.

## MATERIAL findings

### M1 — Screen roles still have the shipped answers manifest as a common source

**Location:** `<private scratchpad>/mer5865/extract_lote_facts.py:9,89-109`;
`assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:23-29,58,82-85`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:86-97,116-140,164-165`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:8-13`

The inspected extractor loads the private answers manifest used by the shipped strict walker and
copies its screen role into the purported archive manifest; it also seeds navigation actions and
answer directives from that source. This contradicts the evidence document's claim that roles
come from the archive. In the projector, that shared role decides whether a receipt exists, whether
a verdict is projected, and whether navigation transition handling applies. If both inputs
misclassify a graded screen as content, the walker and projection agree on role while the projector
omits the receipt and graded verdict; M3 then filters the resulting missing-receipt signal. This is
a direct common-mode false-green path, so the contract needs an archive-authored role derivation
that does not consult the shipped answers manifest.

### M2 — The replay accepts the extracted contract without its archive-completeness gate

**Location:** `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:9,34-35,54-55`;
`assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:193-199,420-424,448-477,498-505,520-539`

Both replay tests call only `validateAdaptiveManifest`. That validator explicitly says archive
completeness is a separate `validateRouteCoverage` gate because scenario-only coverage is
self-referential. The omitted validator is what cross-checks archive inventory and route edges,
resource identity, and—most importantly here—every authored prior-state rule reference against a
grading expectation. Without it, an extractor omission becomes the oracle contract itself: the
projector restates only the remaining expectations in its receipts, and the oracle has no
independent fact proving one was dropped. A malformed or incomplete extraction can therefore
preserve a clean shadow audit by leaning on the server verdict, which is the false-green case the
archive contract was introduced to prevent.

### M3 — `receipt-missing` is misclassified as future-driver evidence, and the gate does not pin the closed inventory

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:55-63,82-108,192-195,205-219`;
`assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:708-724`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:38-50`

Receipts are constructed now by `buildShadowInputs` from the archive contract; step 4 driver
stamps cannot be the missing evidence for them. Nevertheless, `isDriverEvidenceViolation`
classifies `receipt-missing` as an expected driver gap. If role derivation or receipt construction
drops a graded receipt, the oracle emits that code before running the graded payload audit, the
filter removes it from `inScope`, and `compareProjections` treats payload as clean because it looks
only for `payload-mismatch`. The test's purported exactness guard does not close this: it asserts
only a positive count, and `driverEvidence.every(isDriverEvidenceViolation)` is true by
construction because that array was produced with the same predicate. Pin the expected
code/detail/step inventory (or an independently derived per-class cardinality) and keep
contract/projector failures outside the driver-only allowlist.

## Recorded non-material findings

### N1 — Presence-only fallbacks reduce predicate strength but did not create these greens

**Location:** `docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:8-11,64-67`

The divergent-correct-rules and regex fallbacks check presence rather than the exact value
relation. This leaves those predicates weaker than the authored rules, but the reviewed captures
also passed the shipped payload correlation and server verdict, so the fallback did not turn a
shipped failure into either supplied green. Keep the limitation explicit and close it before this
projection is reused as the sole value-semantic oracle.

### N2 — The intentional-delta section still describes evidence the redesign removed

**Location:** `docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:14-19,57-67`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:99-107`

The round-2 disposition correctly says permits and plans are no longer synthesized, while the
later four-delta checklist still describes synthesized permits and replay-derived plans. The code
uses empty permits/plans, so this stale description does not affect the replay judgment; batch-fix
the evidence document so the reviewed scope is unambiguous.

## Verification performed

- The two capture-backed gate tests passed with the supplied private artifacts.
- The gate plus the adaptive-oracle suite passed (122 tests).
- Targeted ESLint and Prettier checks passed.
- TypeScript reported only the two explicitly fenced `liveSocket` errors.
- No additional security or performance finding met the materiality policy.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 3 MATERIAL + both recorded items fixed

## M1 — FIXED: roles derived from the archive alone
Extractor v3: navigation = a buttonwidget CAPI part drives the screen; graded = an enabled
correct rule conditions on the screen's own stage.* state; else content. The navigation
action's src_fragment also comes from the archive part. The v1 answers file is now a
CROSS-CHECK only (mismatches reported loudly, zero found on LotE) — nothing the projector
consumes originates in it.

## M2 — FIXED: both build gates run in the replay
`loadValidatedManifest` runs `validateAdaptiveManifest` AND `validateRouteCoverage` over the
extractor's ArchiveFacts (inventory, route start/edges/terminal, resource identity, dependency
and rule-reference coverage, totality). An extractor omission now fails the gate closed
instead of becoming the contract.

## M3 — FIXED: receipt-missing in scope; the gap is pinned
`receipt-missing` removed from the driver-evidence class (receipts are projector-built —
their absence is a contract failure). The gate asserts the driver-evidence MULTISET equals an
inventory computed independently from journal + manifest (`expectedDriverEvidence`:
per-class, per-count) — your by-construction tautology is gone; a projector failure can no
longer hide in the gap. Both greens: 65 = 65, class-exact.

## N1 recorded (presence-only strength — step-5 regex decision); N2 FIXED (stale delta
section replaced with the current truth).

Verification: gate 2/2 against the private artifacts, full suites 257/257, tsc/eslint/prettier
clean.
