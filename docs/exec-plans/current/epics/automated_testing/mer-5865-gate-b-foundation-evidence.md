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

**W-W7a boundary data/control-flow inventory (REVISED AGAIN at the round-6 refactored shape —
this declaration adopts the round-6 reviewer's own fresh derivation verbatim):**

*Direct assertion inputs:* `result.violations` — the EXACT array `deps.audit` (= `auditRun`)
produced, passed through `runGatedLote`'s return unmodified (identity-witnessed with a sentinel
array); its `.length` access; `result.flavor` (the journal-produced freeze flavor); `expect`;
and the rejection-only `formatViolations` diagnostic. The two assertion SHAPES are pinned by a
static witness (exactly one occurrence each, fed by the plain destructure of the module result).
*Provenance/control inputs:* the awaited `runGatedLote` import and result destructuring; `page`;
the mutable spec globals `seededCourse`/`manifest`/`lesson` (set once in `beforeAll`, null-
guarded); the two environment controls (`MER5865_SHADOW_DIR` — evidence gating only;
`MER5865_POISON_SCREEN` — wire poisoning on shadow-armed runs); the module's exception and
evidence paths (a module rejection is test-red — there is no spec fallback or catch); and the
exported defaults object `GATED_RUN_DEFAULTS`, now `Object.freeze`d (witnessed) so it is no
longer mutable outer state. `flavor === 'accepted'` remains a SECOND RAW BOUNDARY DEPENDENCY
(ACCEPT/B4-C3's "under accepted-freeze"), NOT a transformation of the audit result.

**W-W7d licensing-state subcases:** the round-10 reviewer executed seven at the pre-refactor
shape (all red — the zero-length assertion dominates); the round-6 reviewer confirmed at the
refactored source that "only exact zero violations followed by accepted flavor can return from
both assertions" with no alternate green exit. The per-dependency instantiation at the CURRENT
revision remains the reviewer's derivation; the executed writer-side legs are the identity
witness, the frozen-defaults witness, and the boundary fault injections in adaptive-gated-run.spec.ts (every one red; count per the map).

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
**596 == 596, zero missing, zero extra, both directions** (271 frozen + 337 additive − 12
justified removals — the exact stored decomposition; each removal individually justified: the
loop conversion plus the structural/binding titles superseded across the fix rounds; the two excluded
never-commit demo files classified by file; discovery 599 = 596 + the 3 identities in those files.
Historical note: the post-reconciliation state read 589==589/discovery 591 before the §4j score
extension added its 7 tests and the second demo file appeared). The reconciliation is POST-HOC and disclosed
as such — the manifest was not continuously current while pieces 2–4 landed, and W-U1 was red
during that window. This entry IS the owed §6.7 justification for the W-U7 case-count change.
Counts move with each fix round; the FINAL stamp is taken at the freeze revision.

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

Three fresh-seed runs: GREEN 2026-08-14 — each `completed`, freeze `accepted`, `auditRun` = 0
violations; the four accepted finalization triples pairwise distinct on every component
(B4-C12b). A fifth, POISONED run (`MER5865_POISON_SCREEN=q:1516177456571:380`) went red with
`verdict-not-correct` at exactly the poisoned screen — the same locus as the step-3 bail.

One non-run red is recorded for completeness: a live attempt hit a server 500 on the evaluate
call at `q:1516192147167:415` (the open FU-2 class, `mer-5674-followups.md`); the strict path
surfaced it as a typed `unresolved-candidate-owned` violation naming that screen and sealed.
That is the framework doing its job on a genuine product fault, not a framework defect; the
subsequent run on the same revision was green. A second infrastructure-only failure (Playwright
trace artifact ENOENT — the known traced-context corruption class the spec header documents)
occurred on a run whose verdict itself was green (completed/accepted/0 violations, dump
retained); re-run clean.

### §6.1 driver-evidence retirement mapping (closed, element-level)

Every green capture — old walker and swapped runs alike — carries exactly 65 driver-evidence
violations when audited from the capture alone, in exactly these classes; on the swapped path
each class is now discharged by the LIVE oracle over the strict run record (auditRun = 0
violations on the same runs):

| Retired class (capture-alone audit) | Count/run | Live predicate now auditing it |
|---|---|---|
| `evaluation-no-causal-edge` | 21 | journal-issued check/ack/widget permits claimed in the runRecord; whole-tuple issuance check (`not-journal-issued`) + position rules (§3.4) |
| `plan-divergence` | 23 | driver-recorded plans replayed against `planTransition` per owned evaluation (§3.5) |
| `obligation-unfulfilled` | 20 | feedback-ack permits + navigation/terminal fulfilment from journal + visit evidence (§3.5) |
| `permit-mismatch` | 1 | the widget-button permit on the navigation entry screen, journal-issued and claimed |
| total | 65 | matches the archive-pinned 65=65 inventory recorded at gate B0 |

Verified on all four swapped green captures **through the COMMITTED gate entry point**
(gate-B round-10 blocker 1 closed): `mer5865-shadow-gate.spec.ts`'s swapped-run describe
(env `MER5865_SWAPPED_GREEN_DUMPS`) runs `validateSwappedGreenEnvelope` (every green-envelope
obligation, with ledger-presence inverted — a swapped capture CARRYING a ledger is laundering
and is rejected), asserts `inScope 0`, asserts EVERY diff is the retired-account presence class
and nothing else (unmapped DIFF difference = RED), pins the driver-evidence inventory to
`expectedDriverEvidence` exactly (65, identical class split across all four runs), and asserts
the four finalization triples pairwise distinct on every component. The earlier hand-run
`evaluateGreenCapture` evaluation is superseded by this committed, replayable gate.

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

## 4b. Witness-gap closure (writer-derived 2026-08-14, before the gate pass)

Deriving the CONFORMANCE-MAP surfaced witness subcases with no test at their contract locus.
All were closed the same day (22 new named tests + one journal fix + one validator change),
each carrying its witness ID in its title:

- **B4-STAMP's runtime half was entirely unasserted**: `permit-mismatch`/`receipt-mismatch`
  with `not-journal-issued` had zero red tests. Closed with three (forged tuple, relabeled
  tuple, forged readback fence).
- **W-R1** (visit deletion → `route-shape/count-mismatch`), **W-J10** (mint before the first
  rotation evaluation), **W-ST3** (permit issued after the evaluation request), **W-ST4** (the
  ack-licensing edge for a graded re-check, green + red arms — the green arm audits fully
  clean, so the red arm's violation is the ack position alone).
- **W-J12/J13/J15 disentangled**: parse-error creation with an apparent GUID in the bytes;
  EMPTY-string minted GUID — this one found a REAL defect (`''` passed the string check and
  could extend lineage; fixed in the journal, and the fix is mutation-tested: the pre-fix code
  fails the new test); hollow creation (empty body) as its own mutation.
- **W-S1/S2/S3/S5**: `correlate()` had never been called by any test. Closed with four
  lifecycle tests on `armStrictRun` against rendered Delivery props (positive freeze + accepted
  finalization; absent element; hollow fields; same-node `data-react-props` rewrite after the
  freeze — the retained VALUE triple still governs).
- **W-W10/W-W12**: static binding of the switched spec (imports the strict entry point;
  ban-list scan finds no shipped-walker/ledger/projection reference).
- **W-D2/D4**: `compareProjections` had never been asserted RED. Closed with a tuple-field
  swap diff and presence diffs (truncated and empty accounts).
- **W-M2** (absent archive dir is a loud reader failure — the private-env SKIP is
  suite-membership, not the build's absence behavior), **W-M5** (presence-only expectations now
  rejected at manifest validation by name — §6.3's scope is empty under its resolved arm (a);
  the oracle stays total over presence-only receipts), **W-M7 static half** (the raw reader's
  only cross-module imports are type-only — nothing shared at runtime to mutate).

Late in the same pass the writer found the C4A SECTION ANCHOR itself missing: the switched spec
froze the triple but never cross-anchored `sectionSlug` to the setup response. Implemented
2026-08-14: the journal core gained a `runCorrelation()` copy-getter and the spec refuses to
walk when the frozen section differs from `seededCourse.section.slug`. W-J5's both-sides swap is
what this anchor catches (a consistent swap satisfies the freeze binding but not the setup
response); it has no offline fixture — anchor code + live greens are its evidence.

Honest residuals for the reviewer: W-S4 composes from one-time freeze + by-copy retention +
per-field rejection (no single navigation-replacement test); W-S6 is the reviewer's static
no-shared-helper check (the two correlation readers are duplicated inline `page.evaluate`
bodies); W-W7a/W-W7d and the four §7 derivations remain reviewer-owned.

## 4c. `adaptive-authoring.spec.ts:133` flake — DIAGNOSED with a trace-equipped failing run (§6.4)

Reproduced 2026-08-14 on the first traced attempt (fail; a later same-day untraced attempt
passed — the recorded retry §6.4 requires). **Measured mechanism, this occurrence:** the run
died AFTER a fully successful authoring + publish — the failure screenshot shows the Publish
page reading "Latest Publication: v0.2.0 … Published 7 seconds ago … no changes since the
latest publication". The product created every screen and published them. What consumed the
clock: `publishProject()`'s tail calls `Utils.modalDisappears()`, and the bootstrap
`.modal-backdrop.fade.show` never left the DOM after `clickOk()` — the util's hidden-wait timed
out, it reloaded the page (its logged "Restart page to remove modal shadow" fired), and the
test's remaining budget died there. This refutes the "the editor does not create the screen"
reading for this occurrence: the failure is SUITE-side (stuck bootstrap backdrop + unbounded
budget consumption inside a 180s serial builder), not a product defect.

Honest scope: the flake has at least two surface signatures — the recorded one
(`BasicPracticePagePO.ts:399` waits 30s for `.flowchart-node` count) and this one (post-publish
backdrop). Both live inside the same long serial builder where any stuck overlay wait starves
whatever step the clock runs out on; the :399 signature was not itself reproduced under trace
in this session. Also recorded: the Playwright trace artifacts for the failing attempt were
themselves corrupted (`ENOENT … recording3.trace`) — the same traced-context corruption class
the LotE spec header documents; the screenshot and error-context survived and carry the
diagnosis. Suggested suite-side fix for the owner: bound `modalDisappears()`'s wait tightly and
force-remove the backdrop the way `CurriculumPO`'s delete-modal path already does, instead of
reloading. Owner: suite health (human-assigned); not a MER-5865 gate conjunct beyond §6.4's
recorded retry, which this section supplies.

## 4d. Gate-B round-10 findings — all seven blockers disposed (2026-08-14)

The merged gate pass returned RED with 7 blockers + 1 should-fix (`reviews/mer-5865-gate-b-review.md`).
Writer dispositions, all FIXES (no push-backs — every finding was real):

1. **DIFF hand-run evidence** → committed swapped-run gate (above, §3). The reviewer's replay
   command now exercises it via `MER5865_SWAPPED_GREEN_DUMPS`.
2. **Arming outside the boundary** → `armShadowCapture`/`armStrictRun` moved INSIDE the spec's
   try (a constructor/attach fault lands in the catch with nothing armed — no orphan state);
   the artifact's declared scope rewritten to the ROUTED universe with the offline fixture
   retained and justified as the injection harness; the discharged-deferral text revised.
3. **13 waived sites** → all injected AT-SITE (95 exit-inventory tests now; the `new Map`
   waiver was WRONG — a hostile iterable makes the constructor itself throw, and the new
   `W-E2-MAP-ITERATOR` witness refutes it). Screen-gated, clock-delegating injections were
   built for the barrier-region clock edges so the scripted timers keep firing.
4. **Map not total / not in evidence shape** → rebuilt: all 26 §3 row IDs and W-U1..W-U9 are
   top-level entries; every mapped test carries mutation, expected locus, OBSERVED locus and
   replay; 182 entries.
5. **W-J5 stamped without a test** → the anchor is now `assertSetupAnchor` (own module, called
   by the routed spec) with an EXECUTED both-sides-swap red arm and a green arm; the dishonest
   `tests: []` + passed stamp is replaced by the real mapping.
6. **W-X3 weaker mutation** → committed per-component distinctness comparison over the swapped
   dumps + a synthetic shared-section pair asserted red.
7. **W-W7a not bidirectional** → the declaration now carries the reviewer's derived inventory
   verbatim (globals, env controls, dump/catch paths) and records the seven executed W-W7d
   licensing-state subcases (§1).
SF1 (stale counts) → refreshed each round; current numbers in §2.3 and §5.

## 4e. Gate-B round-2 findings — dispositions (2026-08-15)

Round 2 (`reviews/mer-5865-gate-b-review.md` "Round 2"): closed B1/B3/B5/B7; WIRE, DIFF and
ACCEPT went green; 3 prior blockers still open + 1 new. All disposed as fixes:

- **B2 (EXIT-SCOPE/INV, still open)** → the artifact now DECLARES the routed layer: scope
  includes `AdaptiveShadowCapture.ts` (routed differential-capture leg) and the routed spec; a
  new `routed_layer` section enumerates all 16 exit-bearing callees inside the spec's try with
  ONE producer (the spec catch: seal + bail dump via `failureText` + rethrow); the projector's
  exclusion is re-justified with the verified no-import-edge fact. Three structural witnesses
  re-derive the boundary from the spec source each run (pre-try purity, all callees inside,
  catch shape with the round-2 defect pattern banned).
- **NEW B8 (boundary not fail-total)** → two code fixes, both witnessed: `failureText(thrown)`
  replaces the unguarded `.message` read (total over null/undefined/string/hostile-toString —
  unit-tested), and `AdaptiveJournalRecorder.attach()` is now FAIL-ATOMIC (a partial listener
  registration removes what it installed and rethrows — two hostile-page witnesses prove
  nothing stays armed and a retry is legal).
- **B4 (map semantics, still open)** → the five false mappings fixed by REMOVAL or replacement
  with executed tests: W-X1 → the new per-component distinctness test (the minted-GUID check
  demoted to labeled corroboration); W-X3 → weaker same-capture mapping REMOVED; W-D2 → an
  EXECUTED smuggle mutation (ledger added to a real swapped capture → envelope red); W-W8 →
  the eight real discovered titles, resolution-by-name vs ownership-ambiguity loci named;
  W-U7 → the four real generated titles.
- **B6 (weaker W-X3 mapping)** → covered by the W-X3 removal above.
- **SF1** → all narrative counts refreshed to the round-2-fix revision.

## 4f. Gate-B round-3 findings — dispositions (2026-08-15)

Round 3 closed B6/B8; still open B2/B4/SF1 + new B9. All disposed as fixes:

- **B2 (EXIT-SCOPE/INV)** → the routed layer is now AST-DERIVED AND BIDIRECTIONAL (the
  reviewer's own guardrail recommendation): `routed_layer.sites` carries every
  CallExpression/NewExpression in the gated test body as `{line, callee, kind, region}` (45
  rows across pre/try/catch/post, each region with a named owner), generated from the
  TypeScript AST; the witness test RE-DERIVES the set each run and asserts set equality in
  BOTH directions (mutation-tested: a deleted artifact row turns it red). The three substring
  tests are REPLACED by AST witnesses: pre-try purity (no rejecting-await, no arming callee),
  catch shape (last statement IS the rethrow of the original; every cleanup await
  `.catch()`-wrapped or two-armed `.then()`). Scope: `AdaptiveOracle.ts`'s routed `auditRun`
  edge is now DECLARED (a routed_layer row); the module's judge face keeps its exclusion with
  the reason split accordingly.
- **B9 (shadow arm + catch cleanup not fail-total)** → `armShadowCapture`'s ordering is now
  the documented fail-totality argument: the two Playwright-irreversible installs (binding,
  init script) come first and are INERT without the rest (the binding stamps into a core
  nothing reads; the init script optional-chains the binding); the one detachable step —
  fail-atomic `recorder.attach()` — runs LAST. Three fault-injection witnesses (init-script
  fault, attach fault, healthy ordering) prove no listeners survive a failed arm. The spec
  catch is now fail-total: finish faults still attempt the dump (`.catch(() => 'sealed')`),
  dump faults are logged via `failureText` without displacing the cause, and the rethrow is
  unconditional — witnessed by the AST catch-shape test.
- **B4 (three semantic map defects)** → fixed by REMOVAL, per the no-weaker-mapping rule:
  W-X1's minted-GUID corroboration removed from the mapping (stays an ordinary suite test);
  W-D2's false mapping onto the positive swapped test removed; the W-E0a writer leg rebuilt
  with claims stating EXACTLY what each AST/fault witness proves.
- **SF1** → every replay stamp in the map de-duplicated to one freeze-refreshed reference
  (zero `494`/`516`-era stamps remain); W-U3's wording de-versioned.

## 4g. Gate-B round-4 findings — dispositions (2026-08-15)

Round 4 closed B4/SF1 and EXIT-SCOPE (both directions); still open: B2's EXIT-INV half and B9's
arm inertness. Both disposed:

- **B2/EXIT-INV** → the routed derivation is rebuilt on the CONTRACT's closed kind list:
  ThrowStatements are rows (their argument constructors absorbed — `throw armError` is now a
  row); the catch clause is a `catch branch` row; awaited chains are exits ONLY without a local
  handler (a `.catch(...)`/two-armed-`.then` chain is recorded as `locally-handled await
  (non-exit)` — no more double rows for the op and its handler); everything else callable is a
  potential synchronous `throw`. 44 rows; bidirectional set equality mutation-tested again
  (dropping the `throw armError` row turns the witness red). The pre-try region is pinned to an
  EXACT two-row allowlist (any new pre-boundary call/throw/await is a set inequality, closing
  the round-4 guard-bypass class), and the catch interior is a closed allowlist
  ({failureText — total by witness, poison?.fired — closure read, console.log/warn}).
  **EXIT-EM on routed rows — writer position (recorded in the artifact for the reviewer/human
  to rule):** these rows have no run-record producer BY DESIGN; per-site injection would mean
  one faulted live walk per row to assert Playwright's own failure semantics. The discharge is
  the mutation-tested set equality + region ownership + AST catch shape + executed arm/binding
  fail-totality witnesses + live bail dumps. Refusal ⇒ a per-row live fault-injection campaign.
- **B9** → inertness is now EXECUTED, not argued: the page binding is produced by the exported
  `makeShadowStamp(recorder, visits, isLive)` and GUARDED by liveness — `live` turns true only
  after every arming step (fail-atomic `attach()` last) and false again at detach. Witnesses
  run the actual handler: a stamp before liveness leaves zero visits and a zero-fence sealed
  journal; a live stamp records exactly one journal-fenced visit (duplicate suppressed); a
  post-finish stamp through the REAL installed binding on a stub page changes nothing
  end-to-end.

## 4h. Gate-B round-5 findings — dispositions (2026-08-16)

Round 5 closed B9 and ruled the EXIT-EM writer position REFUSED (its named redo: activate each
routed exit through the real boundary). The human chose the injectable-boundary path. All open
items disposed:

- **B2 + the refused position → DISCHARGED BY EXECUTION.** The routed failure boundary was
  EXTRACTED into `AdaptiveStrictGatedRun.ts` (`runGatedLote(page, inputs, deps)`): arming,
  poison, navigation, login, correlation, the anchor, the walk, the freeze, the audit and both
  private evidence dumps all execute inside it, every external edge is an injectable dep
  (defaults = the real implementations), and the spec is now a thin caller holding only the two
  verdict assertions. `adaptive-gated-run.spec.ts` (28 tests) activates EVERY module exit site
  per-site through the REAL boundary and asserts the pinned producer and no other: seal when
  armed-and-unfrozen; frozen-journal-KEPT when the fault postdates the green freeze (a second
  finish would be wrong); bail dump with the total `failureText` cause; identical-object
  rethrow; no green evidence on any failure path. The catch's own cleanup faults are injected
  too (rejecting seal / bail finish / bail dump / hostile `poison.fired()` in argument
  position — a displacement hole found and fixed during this work) — the ORIGINAL error always
  crosses. VERDICT-S is preserved: the module returns `deps.audit`'s result as the SAME object
  (identity-witnessed with a sentinel array), and the spec asserts `violations.length === 0`
  on exactly that object.
- **B2/EXIT-INV walker semantics** → the derivation is hardened per the round-5 probes: an
  argless `.catch()` or `.then(ok, undefined)` does NOT handle; awaited parenthesized/ternary
  shapes unwrap and classify each branch; ReturnStatement and finally classifiers are active
  (returns recorded for closure; failure-path early returns by region). Two tables now:
  `module_sites` (37 rows over runGatedLote) and `spec_residual_sites` (8 rows — the thin spec:
  guards, the single awaited `runGatedLote` exit, and the verdict assertions), each with
  bidirectional set-equality witnesses; the spec residual additionally asserts NO arming
  callee and exactly one awaited exit.
- **B10** → the W-E0a writer leg remaps to the current discovered titles (stale round-3 titles
  gone); W-W10/W-W12 static witnesses retarget to the two-hop binding (spec → runGatedLote →
  strict driver/audit) and the ban list scans BOTH surfaces.

## 4i. Gate-B round-6 findings — dispositions (2026-08-16)

Round 6 closed B10 and confirmed the boundary semantics (identity, thin caller, live greens);
open items B2/SF1/refusal-redo plus new B11/B12. All disposed:

- **B11 (logging displacement — REAL, executed by the reviewer)** → the catch's `.then` logging
  handlers are now `quietly()`-wrapped function literals (total by construction); BOTH reviewer
  probes are now committed witnesses (hostile `deps.log` at the bail-capture success handler;
  hostile `deps.warn` on a rejecting dump — the ORIGINAL error crosses in each). The AST catch
  witness now also asserts the quietly-wrapping. `GATED_RUN_DEFAULTS` is `Object.freeze`d
  (witnessed), removing the mutable-outer-state dependency the round-6 W-W7a derivation named.
- **B2/EXIT-SCOPE** → `scope.declared` now names `AdaptiveStrictGatedRun.ts` as THE routed
  failure boundary and rewrites the spec entry as the thin caller it is.
- **B2/EXIT-INV** → the tables are now EXACTLY the contract exit universe: locally-handled
  awaits and success returns moved to separate `non_exit_closure` lists; every exit row carries
  its per-site `producer`; the handler test requires a FUNCTION LITERAL (identifier-valued
  slots like `.then(ok, noHandler)` do not handle — the reviewer's runtime-undefined probe class
  is closed); the witnesses compare sites AND closure lists bidirectionally.
- **Refusal redo completion** → `routed_layer.row_activation_map` maps EVERY exit row (35
  module + 8 spec-residual) to the test(s) activating THAT site or its named structural/live
  witness — zero unmapped; five new at-site injections close the gaps the reviewer listed
  (path.join via non-string dir, JSON.stringify via hostile toJSON, both normal-path log lines,
  the post-green-dump log, green-path `poison.fired`); the shared producer assertion now checks
  EXACT cardinalities (≤1 bail seal, exactly 1 bail dump, no green dump, evidence write only
  when the fault postdates it).
- **B12** → W-W7b drops the removed title and gains a mapped STATIC shape witness (the two
  assertion shapes exactly once each, fed by the plain destructure); W-W12's ban list is the
  full C16 class (15 tokens incl. every projection/ledger acceptance symbol and the generic
  `ledger` token), scanned over both surfaces.
- **SF1** → prose states the exact stored decomposition (at that round: 271 + 319 − 11 = 579); the
  map counted 183 evidence entries (plus `_meta`) before EXT-SCORE-TOTAL (now 184); all `ten-spec`
  stamps replaced (the replay subset is eleven specs since `adaptive-gated-run` joined). CURRENT
  decomposition lives in §2.3: 271 + 337 − 12 = 596.
- **W-W7a** → §1's declaration replaced with the round-6 reviewer's own derived inventory at
  the refactored shape (above).

## 4j. Post-round-6 extension: the score-total rule (user-directed, 2026-08-16)

Declared for the reviewer rather than discovered: a rule OUTSIDE the frozen contract rows, added at the
human's direction to complete the pass contract — "a student answering everything correctly reaches the end
WITH the declared maximum score". All-verdicts-true alone does not prove the grading pipeline pointed
correctly (points could be mis-assigned with every verdict true).

- Oracle: `score-total-mismatch` — on an ACCEPTED run with `manifest.expected_total_score` declared, the sum
  of every evaluation's wire-reported `actions.score` must equal the declaration. Sealed runs and undeclared
  manifests keep the rule silent (a partial sum decides nothing). Reporter emits counts only (§3.7).
- Manifest: `expected_total_score` validated (finite, non-negative); the LotE spec now REFUSES a manifest
  that does not declare it.
- Falsified: rule neutered via `if (false && …)` (matched once, content changed) → the named test
  "a run total differing from the declared expected total is a violation" went red (with its sibling pinning
  the same rule); restored → 190/190 green.
- Replay witness on the REAL accepted green dump (`lote-strict-1786911315019`): expected 90 → `[]`;
  expected 91 → exactly `[score-total-mismatch {count:90, expectedCount:91}]`.
- The 90 was MEASURED from that dump's wire records before being pinned, then proven live: fresh-seed run
  2026-08-16 (`lote-strict-1786928655662`) — accepted, wire total 90, 0 violations, spec green in 4.6m with
  the declaration required.
- Suite arithmetic: +7 tests in `additive_step_4` (6 rule/validator tests + the archive-anchor test; 596==596 bidirectional, zero missing/extra in scope).
- ANCHORED to the ingested content (user-directed, same day): `readArchivePage` extracts the page's authored
  `custom.totalScore` (validated finite) into `ArchiveFacts.total_score`, and `validateRouteCoverage` refuses a
  manifest whose `expected_total_score` is missing or different whenever the archive declares it — the 90 is
  read out of the archive, never hand-typed. Falsified (named test red under `if (false && …)`, restored,
  191/191) and witnessed against the REAL archive: page 397294 → B4-MAN/B4-BIJ green with 90; a tampered
  91-manifest fails with "contradicts the archive's authored totalScore=90". Fact note: per-screen `maxScore`
  sums to 99, but the authored page total is 90 and the real wire sums to 90 — the page's `totalScore` is the
  normative number. No author-defined passing threshold exists in the page custom: the rule is a run CHECKSUM
  for the certified all-correct scenario, not a student pass gate.
- Map: `EXT-SCORE-TOTAL` entry with all seven tests, mutations, loci and both executed witnesses.

## 4k. Gate-B round-7 findings — dispositions (2026-08-17)

- **B13** (score extension shifted the thin spec's exact residual coordinates) → the eight
  `spec_residual_sites` rows and their `row_activation_map.spec_residual` twins re-coordinated
  (+5: 165/168/176/190×3/191×2); the bidirectional source-derivation test that caught it (the
  round-7 replay's single failure) passes again, and the full inventory spec is green (98).
- **B14** (one unresolved map identity + four false routed activations) → W-E0a's reference
  updated to the current discovered title (`the module EXIT table equals …`); the four
  `row_activation_map.module` rows at `:129/:147/:158/:161` were mapped to catch-path tests that
  cannot reach those normal/green-path sites — each REPLACED (per W-U8, never supplemented) with
  the test that activates that exact site: the two hostile normal-path log tests, the green-path
  `poison.fired()` throw test, and the hostile capture-log-after-green-dump test.
- **SF1** → every count stamp refreshed to the current state (596 expected = 271 + 337 − 12;
  discovery 599 = 596 + 3 identities in the 2 excluded never-commit demo files; map 184 entries;
  §4j says +7). Historical numbers are kept but labeled as such.
- Reviewer guardrail suggestion (routed-spec edits should force inventory regeneration +
  reference resolution) — adopted as a freeze-checklist item: before any freeze/commit of the
  routed spec or boundary module, run `adaptive-exit-inventory` + the map reference resolution,
  which is exactly the pair that caught B13/B14.

## 5. CONFORMANCE-MAP

Committed at `gate-evidence/mer-5865-conformance-map.json` (rebuilt across the gate fix
rounds): **184 evidence entries** (plus `_meta`, including the declared post-contract
`EXT-SCORE-TOTAL` extension) — all 28 §3 row IDs (B4-DEL marked deferred-A1/not-claimed), every §4
witness subcase including W-U1–W-U9, and the **73** named exit injections (the 13 formerly
waived edges now injected at-site). Status classes at the round-2-fix revision: 140 mapped,
7 mapped+live-evidence, 26 rows covered-by-witnesses, 1 mapped+reviewer-leg, 7 reviewer-owned
(the four §7 derivations, W-U6/W-U8's totality/semantic sweeps, W-S6's static check), 1
deferred-A1 — each reviewer entry names its RED condition and stays UNEXECUTED-RED until the
gate pass executes it. Every mapped test carries mutation, expected locus, OBSERVED locus and
replay; weaker mappings were REMOVED, not supplemented, per W-U8 (round-2 blockers 4/6).
Replay stamps reference the FREEZE run, executed 2026-08-17 on the cleaned tree that this very
commit batch freezes (the commit carrying this document is the frozen revision): eleven-spec subset
**584 passed / 0 failed** under the writer's private-env reconstruction (8 dump-env-conditioned
shadow-gate tests skip there; the round-8 reviewer's own env collected and passed **592/592**), tsc
at exactly the two fenced liveSocket errors. Round-8 verdict on this state: GATE-B-FOUNDATION =
GREEN (0 blockers; the single should-fix, a 26→28 prose count, is applied). Discovery: 599 = 596
expected + 3 identities in the 2 excluded never-commit demo files.
