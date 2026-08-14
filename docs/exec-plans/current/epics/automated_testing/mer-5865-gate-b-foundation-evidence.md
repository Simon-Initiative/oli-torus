# Gate B (GATE-B-FOUNDATION) — evidence for the single merged pass

**Contract:** `mer-5865-step4-driver-swap-contract.md` v6 + amendment A1.
**Predicate claimed:** `GATE-B-FOUNDATION ⟺ SWAP-GREEN = WIRE ∧ SUITE ∧ DIFF ∧ ACCEPT ∧ EXIT-TOTAL`.
`GATE-B-CLOSE` (∧ DEL) is NOT claimed — deferred with the follow-up ticket per A1.

**Status: IN PROGRESS (4d underway). This document accumulates writer-side evidence and
dispositions as they are produced; the claims table and final replay stamps land at the freeze
revision.**

## 1. The 4d switch (B4-ENTRY-S/L)

`lote-plate-tectonics.spec.ts` switched to `armStrictRun` + `driveStrictLesson` (family registry,
manifest v2, journal-issued fences/permits). Verdict boundary, deliberately minimal (B4-VERDICT-S,
W-W7b): the spec consumes the UNMODIFIED `auditRun(manifest, outcome.runRecord, snapshot)` result
with exact `violations.length === 0` semantics, conjoined with the journal's own freeze flavor
`=== 'accepted'` (the ACCEPT clause's "under accepted-freeze"); the driver's outcome flag is never
an input to green — an aborted walk reaches the same audit and reports as itself. Manifest v2
source: bucket key `mer-5674/answers-strict.json` (`{lesson, screens, scenario}`), the §10 Q3
side-by-side arm, seeded 2026-08-14 with a verified roundtrip.

Old-walker imports (`completeAdaptiveHappyPathStrict`, `AdaptiveStrictContract`) removed from the
spec. The old walker files stay in the tree untouched (A1: DEL deferred; the two Real Chem specs
keep importing them).

**Design consult (2026-08-14, `reviews/mer-5865-4d-design-consult.md`): 3 SOUND, 1
SOUND-WITH-AMENDMENT, 0 UNSOUND.** The amendment (applied same day): the post-boundary
completion-text assertion was a third effective green dependency contradicting B4-C15's `iff`
and redundant with the oracle's lesson-end + accepted-finalization obligations — removed from
the spec's pass/fail path, and the now-unconsumed `completion_text` field dropped from the
lesson-block requirement so it cannot read as a guarantee.

**W-W7a boundary data/control-flow inventory (declared per the consult's exact list):** the
`auditRun(manifest, outcome.runRecord, snapshot)` producer path; `violations` and its
zero-length access; the journal-produced `flavor` via `strict.finish('green')`; `expect` and
the rejection-only `formatViolations` diagnostic message; the null guard (unreachable: the
boundary rethrew); and the try/catch evidence-dump paths, which write files but feed no
assertion. `flavor === 'accepted'` is a SECOND RAW BOUNDARY DEPENDENCY (ACCEPT/B4-C3's
"under accepted-freeze"), NOT a transformation of the auditRun result — it takes its own
W-W7d licensing-state subcase: accepted flavor while `auditRun` returns a violation must
remain red (it does: the violations assertion precedes and is independent).

**Test identity note (SUITE):** the LotE spec is OUTSIDE the frozen `adaptive-`/`mer5865-`
discovery scopes, so its title change ("… with a strict ledger" → "… with zero audit violations")
is not an EXPECTED-INV delta. Recorded here for transparency: the old title named the old
contract's ledger, which the switched spec no longer produces; keeping it would have been a named
test that lies.

## 2. Live-run findings fixed during 4d (each with its witness)

### 2.1 Registry readiness: hidden backing stores (canary 1, 2026-08-14)

`spr-widget-fill-in-the-blanks@2` `ready()` waited for the declared `ready_selector` to become
VISIBLE. The widget wraps each native `<select>` in a jQuery-UI selectmenu: the declared control
(`#drop-1`) exists only as a hidden backing store and is never Playwright-visible, so readiness
timed out fail-closed on every one of LotE's five fill-in-the-blanks screens. Live witness:
canary-1 strict evidence (`readiness-timeout` at `q:1516177456571:380` step 2, 1 violation,
sealed) — the strict stack surfaced a typed, screen-attributed failure exactly as designed.

Fix: `widgetControlReady` gained a `state` parameter (default `'visible'`), and the family opts
into `'attached'` — the old walker's proven semantic (it polled attached `<select>` count and
swallowed the visible-wait). Fail-closed is preserved: an absent control still times out. The
declared `ready_selector` stays load-bearing (a screen-specific control must exist in the frame).

### 2.2 savedBarrier: the family cannot promise save-on-change (canary 2, 2026-08-14)

`spr-widget-general-drag-drop@6` on `q:1516194083316:719` (ConvectionCurrents, sim-hosted) commits
NO state save before the check: the drop state travels in the evaluation payload itself. Live
derivation from the product's own wire (old GREEN capture `lote-green-1786378384523.json`):
evaluation seq 83 carried the full `stage.ConvectionCurrents.Drag and Drop.*` state and graded
`correct=true`; the only post-answer save (seq 85) arrived AFTER the verdict and was 403. The
archive cannot distinguish this instance (both LotE dnd screens pin the identical
`spr-widget-general-drag-drop/6.*` src), so the family-level committed-save barrier was
unsatisfiable by product design on such screens.

Fix: the family declares `noSavedBarrier` — its receipts carry empty `savedBarrierPrefixes`
(exactly like every janus family already does). Soundness unchanged: spec §3.5 names the
savedBarrier a deliberate STRENGTHENING, never the license; answer evidence remains fully audited
by the §3.5 local matcher (submitted payload vs manifest expectations) plus the server verdict and
replay agreement. A check clicked before drop propagation grades incorrect → red run, never a
false green. Canary-2 strict evidence (`barrier-timeout`, 1 violation, sealed) is the live
witness for the defect; canary 3 (green, 0 violations, accepted freeze) for the fix.

### 2.3 SUITE additive manifest was stale (writer-found, 2026-08-14)

Pieces 2–4 and the W-U7/W-U9 conversion landed without updating
`gate-evidence/mer-5865-expected-inv.json`'s `additive_step_4`: discovery showed 156 unexplained
extras and 1 unexplained removal — the W-U1 conjunct was failing. Reconciled: every extra
attributed to its adding commit (`git log -S`; generated identities attributed to the conversion
commit `13fda67669`), and the one removal recorded as a `justified_removals` entry per contract
§6.7 — the frozen title `every disqualifying final-step target: prev, first, last, explicit id
(§8)` became four named tests, each carrying its case. Post-reconciliation equality:
**498 == 498, zero missing, zero extra, both directions** (excluded uncommitted demo file
classified as before). This entry IS the owed §6.7 justification for the W-U7 case-count change.

## 3. ACCEPT (canary + 3 fresh-seed runs)

Runs executed with the private env (dev server + MinIO bucket; shadow capture armed for DIFF).
Canary GREEN 2026-08-14: outcome `completed`, freeze flavor `accepted`, `auditRun` = **0
violations**; 22 visits, 19 receipts (all graded screens), 42 journal-issued permits, 22 entry
fences, 19 readback fences; journal `frozen`, sealIncomplete false. This is also the first routed
live exercise of the `armStrictRun` lifecycle (attach → correlate → freeze → detach) that the
exit inventory's 7 `prospective` rows deferred to 4d.

C12b evidence source: each run's accepted `page-finalization` record in the strict evidence dump
carries the full identity triple (sectionSlug / revisionSlug / attemptGuid); the journal accepts a
freeze only when that triple matches the one frozen from the server-rendered Delivery props before
the walk (B4-C4A), so pairwise-distinctness is read off the four dumps.

Three fresh-seed runs: PENDING (in flight).

## 4. Residuals and incidents (recorded before step 5, per DEBT)

- **Unrecoverable-by-audit capture class:** a capture written by the OLD recorder that relabelled
  a malformed evaluation as `activity-finalize` DISCARDED the body; no audit-time check can
  recover it. No current capture is affected (shadow replay unchanged through every hardening
  round). Any pre-fix capture would need re-capture, not re-audit.
- **Scratchpad reaper incident (2026-08-14):** macOS tmp cleanup emptied the prior session's
  scratchpad overnight. Lost: `lote-answers.json`, `lote.zip`, the extracted archive dir,
  `greenhouse.zip`, `gh-seed.json`, and `gen-exit-inv-v2.js` (the exit-inventory generator).
  Recovered from the bucket: v1 answers + course zip (archive re-extracted; archive gates replay
  48/48 against it). NOT recoverable: the generator — the committed artifact stands and its
  invariants are enforced by `adaptive-exit-inventory.spec.ts`; a regeneration would need the
  generator rebuilt. Private artifacts now live outside tmp (`~/mer5865-private`).
- **Prose line-cite refresh:** the `widgetControlReady` edit shifted `AdaptiveDeckPO.ts` by +3
  lines from :168; the exit-inventory artifact's six prose cites at :191/:231/:299/:339/:733/:838
  were updated to :194/:234/:302/:342/:736/:841 (referents verified). No inventoried SITE cites
  that file — all 132 sites cite the driver.

## 5. CONFORMANCE-MAP

Built incrementally at `gate-evidence/mer-5865-conformance-map.json` (lands with the freeze):
EXIT section extracted from the exit inventory's 60 named injection witnesses (each entry: site,
kind, producer, generated test identity, expected/observed locus, replay); W-E0a/b and the other
§7 reviewer derivations are marked PENDING-REVIEWER — an unexecuted reviewer conjunct stays RED
until the single gate pass executes it. Remaining witness families in progress.
