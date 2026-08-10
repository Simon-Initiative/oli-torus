# MER-5865 gate B0 — round 3 shadow evidence

**Verdict:** GATE-BLOCKED

**Counts:** 2 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the invoked archive-completeness gate is not supplied the local rule
references it is meant to prove. The current facts artifact declares no rule references, so a
local grading-expectation omission can still become both the shadow contract and the basis for a
clean payload judgment.

## Round-3 questions

1. **A common-mode contract path remains.** Screen roles are now archive-derived and compare
   independently against the shipped ledger, resolving round-2 M1. However, the archive facts do
   not enumerate local `stage.*` rule references, so manifest expectation extraction can still
   self-validate and lean on the server verdict (M1 below).
2. **The pinned-inventory scheme is not yet sound under this gate's attribution policy.** It pins
   code/detail totals, but discards `screenId` and `stepIndex`. Equal same-class errors on different
   screens are therefore indistinguishable, and the gate can accept a misattributed driver gap (M2).
3. **The evidence does not yet support the step-4 go decision.** The two green captures and the
   poison-stamped bail capture replay as documented, and round-2's missing-receipt absorption is
   closed. M1 can still mask a payload divergence; M2 can still mis-attribute a violation's screen.

## MATERIAL findings

### M1 — The archive facts provide no local rule-reference proof, making expectation completeness self-asserted

**Location:** `<private scratchpad>/mer5865/extract_lote_facts.py:57-87`;
`<private scratchpad>/mer5865/extract_lote_manifest_v2.py:18-67`;
`assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:358-362,396-401,520-539`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:43-50`

`validateRouteCoverage` is now called, but its expectation-completeness proof is only as strong as
`ArchiveFacts.rule_prior_state_refs`. The facts extractor scans exclusively for paths prefixed by
another screen id; it never records the current screen's local `stage.*` facts. The supplied facts
artifact consequently declares an empty rule-reference list for every screen, despite the manifest
containing graded rule expectations. The validator's coverage loop therefore proves nothing about
the local expectations produced by the second extractor. If that extractor drops or mistranslates
a local correct-rule condition, both the receipt contract and payload audit omit it and the gate can
lean on the server verdict derived from the same authored rules. That is the common-mode false-green
the archive build gate was intended to prevent. Populate the facts with every local and cross-screen
fact referenced by enabled correct rules, then require each to be covered by the manifest.

### M2 — The pinned driver-evidence multiset erases screen ownership

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:78-117`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:66-71`;
`assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:193-198`

`Violation` carries both `screenId` and `stepIndex`, but `driverEvidenceInventory` keys actual
evidence only by `code|detail`, and `expectedDriverEvidence` returns the same aggregate shape.
The equality assertion therefore accepts an expected violation on one screen and an actual
same-class violation on another whenever the aggregate count is unchanged. No later gate assertion
checks the driver-evidence locations. This can absorb a projector/ownership attribution defect and
meets the policy's independent blocking condition for mis-attributing a violation's screen. Pin at
least `stepIndex|screenId|code|detail`; include an evaluation ordinal/sequence identity for classes
that occur more than once on one screen.

## Recorded non-material findings

### N1 — Zero-cardinality expected classes are materialized as map entries

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:82-104`

`bump(key, usable.length)` inserts a key even when the count is zero, while the actual inventory
contains no corresponding key. A future legal capture with no usable evaluation in one of those
branches can fail equality as `{class: 0}` versus an absent class. Every class inserted this way is
positive in the reviewed captures, so this is a false-red risk only; skip zero-count inserts when
the helper is retained.

### N2 — The v1 role cross-check reports mismatches but does not fail extraction

**Location:** `<private scratchpad>/mer5865/extract_lote_facts.py:116-117,151-161`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:217-218`

The extractor appends role mismatches to a printed problem list, still writes both artifacts, and
exits successfully. The reviewed artifact reports no mismatch, and any mismatch present in a green
replay is independently exposed by the per-screen manifest-versus-ledger role comparison, so this
cannot preserve the current green. Make the extraction command non-zero on problems to keep the
described "loud cross-check" from depending on a human reading stdout.

## Verification performed

- The two capture-backed gate tests passed with the supplied private artifacts.
- The gate plus the non-browser attribution, journal-core, and oracle suites passed (184 tests).
- Targeted ESLint and Prettier checks passed.
- TypeScript reported only the two explicitly fenced `liveSocket` errors.
- A broader browser-backed run could not be used as evidence in this sandbox because browser
  processes aborted at launch; the gate itself passed independently before and during that run.
- No additional security or performance finding met the materiality policy.

---

# WRITER RESPONSE (Claude, 2026-08-09) — both MATERIAL + both recorded items fixed, with mutation witnesses

## M1 — FIXED: local rule references recorded; coverage proof no longer vacuous
The extractor collects EVERY stage reference of the enabled correct rules: local `stage.*`
facts verbatim, cross-screen `<sid>|stage.*` with owner. All 19 graded screens now declare
refs (24 local; LotE has zero cross-screen). Local collection is scoped to GRADED screens —
content/navigation verdicts are unasserted by design (§3.5), so their rules are not
grading-expectation material. `validateRouteCoverage` exercises them for real; two mutations
prove it fails closed:
- a fabricated uncovered local ref → KILLED ("rule references prior state ... with no coverage")
- a graded screen's expectations dropped, refs intact → KILLED at its first real ref
  (`stage.Recap.Is Correct`)
An extractor omission of a local correct-rule condition can no longer become the contract.

## M2 — FIXED: inventory pinned `stepIndex|screenId|code|detail|requestSeq`
Both `expectedDriverEvidence` and `driverEvidenceInventory` key the full identity; every
class that can occur more than once per screen carries the evaluation's `requestSeq` (your
ordinal ask — the oracle stamps `facts.seq = requestSeq` on all three such classes; the one
keyless class, `permit-mismatch|missing`, occurs at most once per navigation step and is
pinned by step+screen). Mutations prove attribution now binds:
- one violation moved to a different screen/step → equality BREAKS
- two same-class violations swapped across screens (all per-class totals unchanged) →
  equality BREAKS
Both greens still pass, 65 = 65 under the finer keys — the projector's window attribution
agrees with the oracle's per step and per evaluation, not just in aggregate.

## N1 — FIXED by construction: the expected inventory bumps once per concrete
evaluation/step; zero-count entries can no longer be materialized.

## N2 — FIXED: the extractor exits non-zero when its problem list is non-empty.

Verification: gate 2/2 against the regenerated private artifacts; both mutation scripts run
and reported above; full suites 257/257; tsc (only the two fenced liveSocket errors),
eslint, prettier clean.
