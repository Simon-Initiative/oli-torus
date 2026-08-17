# MER-5865 GATE-B-FOUNDATION implementation review

Frozen revision reviewed: `9855617ce3` (declared never-commit working-tree files excluded).

Predicate under review:

```text
GATE-B-FOUNDATION ⟺ SWAP-GREEN
SWAP-GREEN ⟺ WIRE ∧ SUITE ∧ DIFF ∧ ACCEPT ∧ EXIT-TOTAL
```

## Findings

### BLOCKER 1 — The claimed swapped-run differential cannot execute

**Locations:**

- `docs/exec-plans/current/epics/automated_testing/mer-5865-gate-b-foundation-evidence.md:139`
- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:243`
- `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:235`
- `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:76`

The evidence claims that `evaluateGreenCapture` produced `inScope 0` and `driverEvidence 65` on all four swapped greens. The routed spec's `shadow.dump` call does not supply a shipped `ledger`, and `AdaptiveShadowCapture.dump` writes only visits, correlation, the journal snapshot, and the supplied extras. All four claimed swapped green captures therefore lack the ledger that `validateGreenEnvelope` requires for DIFF.

I replayed the committed shadow gate over the four claimed swapped green captures and the poisoned swapped capture. Result: **5 passed / 4 failed**. The positive DIFF case failed at `mer5865-shadow-gate.spec.ts:76` with `green capture has no shipped ledger — differential comparison impossible`; W-D4 also failed because the shipped account was empty. The previously saved local `diff-swap-gate.txt` records the same defect.

**Failure scenario:** a swapped run is accepted without any actual shipped-vs-shadow comparison. The evidence document and W-D1 conformance entry report a green result that the committed real entry point cannot reproduce. `DIFF` is RED.

### BLOCKER 2 — EXIT-SCOPE still describes the 4c driver fixture, not the routed 4d entry point

**Locations:**

- `assets/automation/gate-evidence/mer-5865-exit-inv.json:111`
- `assets/automation/gate-evidence/mer-5865-exit-inv.json:208`
- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:176`
- `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:105`

The declared universe includes `adaptiveStrictDeck.ts`, an offline scripted test fixture that is not on the real LotE switched call graph, while the seven `armStrictRun` lifecycle exits are kept outside the inventory as merely `prospective`. The artifact says those exits are owned by the spec's single failure boundary, but `armStrictRun(page)` executes at line 176 and the spec's `try` does not begin until line 188.

I injected an `AdaptiveJournalRecorder.attach()` rejection in memory. `armStrictRun` threw before returning a handle, so there was no `strict` object to seal or dump and the spec boundary could not run. The same structural issue applies to constructor failure.

**Failure scenario:** recorder construction/attachment fails before the claimed boundary, leaving no terminal snapshot or typed producer. Conversely, the declared scripted fixture is absent from the real routed universe. W-E0a and W-E0b both fail; EXIT-SCOPE is RED.

### BLOCKER 3 — Thirteen inventoried sites have no at-that-site injection

**Locations:**

- `assets/automation/gate-evidence/mer-5865-exit-inv.json:347`
- `docs/exec-plans/current/epics/automated_testing/mer-5865-step4-driver-swap-contract.md:153`

The artifact contains 132 sites, but 13 are explicitly `not-injected`. Most are waived as repeats of the same callee/producer elsewhere; one (`new Map`) is waived as not faultable through the public surface. Under the adopted call-edge identity these remain distinct inventoried sites, and B4-EXIT-EM requires each site to be injected **at that site**.

**Failure scenario:** a branch-specific call edge can regress independently while the injection at a different line remains green. The current 60 named injections prove producer behavior for selected edges, not all 132 inventoried sites. EXIT-EM is RED.

### BLOCKER 4 — CONFORMANCE-MAP is neither total nor in its required evidence shape

**Locations:**

- `assets/automation/gate-evidence/mer-5865-conformance-map.json:1`
- `docs/exec-plans/current/epics/automated_testing/mer-5865-step4-driver-swap-contract.md:238`
- `assets/automation/gate-evidence/mer-5865-conformance-map.json:1731`

Fresh set comparison found all nine mandatory SUITE witnesses `W-U1` through `W-U9` absent. The normative row IDs `B4-CORE-S`, `B4-C12a`, and `B4-SUITE` also never appear as mapped rows. In addition, 104 of the map's 171 `tests` references omit `observed_locus`, although the contract requires every entry to record exact mutation parameters, expected locus, **observed locus**, and replay result.

**Failure scenario:** the map can declare itself total and replayed while omitting the witnesses that detect map incompleteness and weaker substitutions; a passing test stamp cannot show that the asserted rejection occurred at the required locus. W-U6 is RED.

### BLOCKER 5 — W-J5 is marked mapped and passed without a test or reported mutation

**Location:** `assets/automation/gate-evidence/mer-5865-conformance-map.json:1857`

W-J5 requires a consistent both-sides section substitution in the run record and finalization, rejected specifically by the setup-response anchor. Its entry has `tests: []`, nevertheless records a passed replay, and offers only positive live runs. The static anchor appears capable of rejecting the case, but the required mutation was not executed.

**Failure scenario:** journal correlation can remain internally consistent after both sides are swapped; only the setup anchor distinguishes it. Positive live triples do not prove that discriminating red arm. W-J5 and W-U8 are RED.

### BLOCKER 6 — W-X3 maps a strictly weaker identity mutation

**Locations:**

- `assets/automation/gate-evidence/mer-5865-conformance-map.json:2779`
- `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:182`

W-X3 requires two runs that share **one identity component** while the others differ. The mapped test loads the same capture twice and checks only the single minted-GUID `runIdentity`; it does not construct or reject a shared-section/shared-revision/shared-attempt component case. A synthetic pair with the same section and different revision/attempt passes the mapped whole-identity uniqueness check while violating C12b.

The four accepted private dumps do have four unique values in each of the three components, so the positive C12b observation is sound. It does not replace the missing discriminating W-X3 mutation. W-U8 is RED.

### BLOCKER 7 — The declared W-W7a inventory is not bidirectionally complete

**Locations:**

- `docs/exec-plans/current/epics/automated_testing/mer-5865-gate-b-foundation-evidence.md:33`
- `docs/exec-plans/current/epics/automated_testing/mer-5865-step4-driver-swap-contract.md:138`
- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:167`

The actual boundary is the direct, unmodified `violations.length === 0` check followed by `flavor === 'accepted'`, and no post-boundary completion assertion remains. However, the writer's declaration does not inventory the mutable outer globals (`seededCourse`, `manifest`, `lesson`) or the environment/configured control paths (`MER5865_SHADOW_DIR`, `MER5865_POISON_SCREEN`) by name, despite W-W7a explicitly requiring parameters, captures, helpers, exception paths, environment/config, and mutable outer state.

I instantiated seven licensing-state subcases (accepted flavor, completed driver outcome, shadow off, shadow on/successful, successful diagnostic formatting, satisfied null guard, initialized setup/manifest globals) with a returned violation; all seven remained red because the zero-length assertion dominates them. W-W7b and the derived W-W7d behavior are sound, but the required bidirectional comparison against the writer declaration is unequal. W-W7a, and therefore VERDICT-S, is RED.

### SHOULD-FIX 1 — Suite counts in the narrative are stale

**Locations:**

- `docs/exec-plans/current/epics/automated_testing/mer-5865-gate-b-foundation-evidence.md:92`
- `assets/automation/gate-evidence/mer-5865-expected-inv.json:7`
- `assets/automation/gate-evidence/mer-5865-expected-inv.json:1374`

The evidence still says `498 == 498`, and the artifact's `_owed` text still says the W-U7/W-U9 inner-loop conversion is not covered. The frozen artifact now contains 271 frozen plus 250 additive identities minus one justified removal = 520 expected, and the named-test conversion has landed. Current discovery is 522 = 520 expected + two explicitly classified uncommitted demo tests. The arithmetic itself is green; the prose should be refreshed so it does not describe an earlier reconciliation state.

## Four reviewer derivations

### 1. EXIT-SCOPE (W-E0a/b): RED

The real routed graph begins at `lote-plate-tectonics.spec.ts`, arms `AdaptiveStrictDriver.armStrictRun`, crosses the spec's own failure boundary, and then drives through `AdaptiveLessonTask`/`AdaptiveDeckPO`, `AdaptiveFamilyRegistry`, `AdaptiveManifest`, `AdaptiveTransitionPlanner`, and `AdaptiveJournal`. The artifact instead retains the offline `adaptiveStrictDeck.ts` fixture and excludes the routed arm lifecycle from the site inventory. Both comparison directions fail (BLOCKER 2).

### 2. EXIT-INV (W-E1): RED

**Call-edge amendment ruling: SOUND / ADOPTED for this review.** Adding callee and producing origin to `file:line + kind` is a conservative disambiguation: it preserves the contract coordinates while making one-producer identity satisfiable at shared source lines. It does not license collapsing two distinct call edges into one witness.

Within the narrower `driveStrictLesson` universe, the 132 call-edge rows agree with the source candidates under that identity. Against the required routed EXIT-SCOPE universe, the seven arm lifecycle sites are outside `sites`, and the scope inequality makes EXIT-INV red. Independently, the 13 uninjected rows make EXIT-EM red (BLOCKER 3).

### 3. VERDICT-S / VERDICT-L (W-W7a/b/d): RED

Derived direct inputs: the unmodified `auditRun(manifest, outcome.runRecord, snapshot)` result, its array identity and `.length`, the journal `flavor`, `expect`, and the rejection-only `formatViolations` formatter. Derived provenance/control inputs: mutable `seededCourse`/`manifest`/`lesson`, the correlated journal snapshot and setup-section anchor, shadow/poison environment controls, evidence-dump awaits, the catch/rethrow path, and the null guard.

Static shape and the seven licensing-state subcases show exact zero semantics with accepted flavor and no alternate green path. `AdaptiveStrictDriver` and `AdaptiveShadowCapture` also use separate inline DOM readers, so W-S6 passes. The writer's declared inventory is not bidirectionally equal to the derived inventory, leaving W-W7a red (BLOCKER 7).

### 4. CONFORMANCE-MAP (W-U6/U8): RED

The map has 132 top-level entries, but it omits W-U1–W-U9 and three mandatory row IDs, lacks required observed loci on 104 mapped test references, maps W-J5 to no test, maps W-X3 to a weaker mutation, and maps W-W7b to an import-only test that does not assert the boundary shape. ID presence and replay stamps therefore do not establish semantic conformance (BLOCKERS 4–6).

## Suite arithmetic and verification

- Current discovery: **522** identities.
- Expected committed set: **520** = 271 frozen + 250 additive − 1 justified removal.
- Classified never-commit demo identities: **2**.
- Bidirectional comparison: **0 missing, 0 unexplained extra**.
- Required ten-spec private-env replay: **516/516 passed** (fresh reviewer run).
- TypeScript: exactly the two fenced `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional errors.
- `git diff --check`: clean.
- Swapped-capture DIFF replay: **5/9 passed, 4 failed**; primary positive comparison failed for absent shipped ledger.

## Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **RED** | ENTRY/CORE/REG/MAN/BIJ and the direct verdict shape are exercised, but mandatory VERDICT-S remains red because W-W7a is not bidirectionally closed. |
| SUITE | **RED** | Discovery arithmetic and 516-test replay are green; CONFORMANCE-MAP totality and semantic conformance are red. |
| DIFF | **RED** | Real swapped captures have no shipped ledger; focused replay fails. |
| ACCEPT | **GREEN** | Canary + three fresh-seed runs completed with accepted freeze and zero violations; the four checked triples are distinct in every component; poison run is screen-attributed red. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE, EXIT-INV, and EXIT-EM are red; EXIT-MAP's record/path tests pass but cannot rescue the conjunction. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` is not claimed and remains deferred with `DEL` under A1.

**Summary: 7 BLOCKER, 1 SHOULD-FIX, 0 NIT.**

## Round 2

Revision reviewed: `9855617ce3`, with the supplied uncommitted round-10 fix set. Declared
never-commit/demo files remain excluded from the gate arithmetic as instructed.

### Prior-finding rulings

| Round-1 finding | Round-2 ruling | Evidence |
|---|---|---|
| BLOCKER 1 — swapped differential cannot execute | **CLOSED** | `validateSwappedGreenEnvelope` is committed source at `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:663`; the real env-gated gate invokes it at `assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:602`. All four supplied swapped dumps replayed green. |
| BLOCKER 2 — EXIT-SCOPE is not the routed universe | **STILL OPEN** | The artifact declares the routed spec but explicitly excludes `AdaptiveShadowCapture.ts / AdaptiveShadowProjector.ts` as having “no edge” at `assets/automation/gate-evidence/mer-5865-exit-inv.json:111-131`. The routed entry directly imports and invokes that path at `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:25,197,202,224,246-247,262-263`. It also keeps the strict arm lifecycle outside `sites` as `prospective` at `assets/automation/gate-evidence/mer-5865-exit-inv.json:210-230`. |
| BLOCKER 3 — thirteen sites are not injected at-site | **CLOSED** | The 13 formerly `not-injected` rows are now `injected`; the artifact has 73 direct injected rows, 59 structural wrapper rows marked `covered-by`, and no `not-injected` row. The added replay includes the 95 exit-emission cases and passes. |
| BLOCKER 4 — CONFORMANCE-MAP is not total/required shape | **STILL OPEN** | Structural ID coverage and observed-locus shape were expanded, but semantic conformance remains false. The map contains nonexistent aggregate test identities and mappings whose asserted mutation/locus is not exercised; details are under the Round-2 CONFORMANCE-MAP derivation. |
| BLOCKER 5 — W-J5 has no executed mutation | **CLOSED** | `adaptive-strict-run.spec.ts:427-449` now executes both arms: an internally consistent foreign section/finalization is accepted by the journal and rejected only by `assertSetupAnchor`, while the setup-issued section is accepted. |
| BLOCKER 6 — W-X3 maps a weaker mutation | **STILL OPEN** | The correct shared-one-component discriminator now exists and passed at `mer5865-shadow-gate.spec.ts:639-647`, but the W-X3 map still additionally claims the old same-capture/whole-identity test at `mer-5865-conformance-map.json:2886-2892`. W-U8 says any mapped weaker variant is red; adding a strong mapping does not make the false weaker mapping true. |
| BLOCKER 7 — W-W7a declaration is incomplete | **CLOSED** | The revised declaration at `mer-5865-gate-b-foundation-evidence.md:33-53` now matches the independently re-derived boundary inventory, including globals, env controls, dump/catch/null-guard paths, correlation, and the setup anchor. Exact-zero and all seven W-W7d licensing arms remain red under a returned violation. |
| SHOULD-FIX 1 — stale suite counts | **STILL OPEN** | The artifact now derives 538 expected identities, but the narrative still says `520 == 520` at `mer-5865-gate-b-foundation-evidence.md:99-108`, says 132 map entries/60 injections/516 replay at `:283-291`, and `_meta.replay` still describes 516/522 at `mer-5865-conformance-map.json:8`. |

### New BLOCKER 8 — The routed failure boundary can finish without producing the required bail dump

**Locations:**

- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:259-271`
- `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:104-106`
- `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:914-919`

The catch assumes every JavaScript rejection is an `Error` and reads
`(armError as Error).message` at line 266. A promise may reject with `null`, `undefined`, a string,
or another non-`Error` value. For `null`/`undefined`, the property read throws inside the catch
after `shadow.finish('bail')` but before `shadow.dump(...)`; the original failure is replaced and
the promised private bail capture is absent. A string produces a dump with the failure cause
silently omitted. This contradicts the routed boundary's own claim that every failure after
arming seals and dumps exactly once.

There is a related arming hole behind the still-open EXIT inventory: `armStrictRun` does not
return a handle until after `recorder.attach()`, while `attach()` registers three listeners
sequentially and sets `attached = true` only afterward. If the second or third `page.on` throws,
one or two listeners remain installed, assignment to `strict` at the call site never occurs, and
the catch has no handle with which to seal or detach them. The artifact's “nothing armed — no
orphan state” assertion is therefore not fail-total.

**Failure scenarios:** a non-`Error` rejection after arming loses the mandatory bail evidence; a
partial attach fault leaves an unreachable recorder/listener without a terminal snapshot. Both
are EXIT-TOTAL failures.

### Round-2 reviewer derivations

#### 1. EXIT-SCOPE (W-E0a/b): RED

Starting at the real switched `lote-plate-tectonics.spec.ts` entry, the live graph includes its
setup/runtime tasks, `AdaptiveLessonTask`/`AdaptiveDeckPO`, `AdaptiveStrictDriver`,
`AdaptiveStrictAnchor`, `AdaptiveJournal`, `AdaptiveFamilyRegistry`, `AdaptiveManifest`,
`AdaptiveTransitionPlanner`, and the directly invoked `AdaptiveShadowCapture` →
`AdaptiveShadowProjector` differential path. The offline `adaptiveStrictDeck.ts` fixture is also
legitimate in the fixture/injection half of the contract's “real entry-point + fixture dependency
graph” wording.

The declaration covers the strict-driver and fixture sides but expressly excludes the reachable
shadow path. Therefore W-E0a fails. I found no declared file that is absent from both the routed
and fixture graphs, so W-E0b passes; the conjunction remains red.

#### 2. EXIT-INV (W-E1): RED

The call-edge amendment remains sound: `file:line + kind + callee/origin` disambiguates producers
without collapsing distinct edges. The 132 `sites` rows are internally source-pinned for the
narrow `AdaptiveStrictDriver.ts` walk. They are not the inventory of the independently derived
routed universe: `adaptive-exit-inventory.spec.ts:1068-1086` derives candidates only from
`DRIVER_SRC`, explicitly accounts the arm lifecycle as `prospective`, and never enumerates the
routed spec/shadow calls. The full-set comparison therefore fails in the artifact → reviewer
direction and W-E1 is red.

#### 3. VERDICT-S / VERDICT-L (W-W7a/b/d): GREEN

The re-derived direct boundary inputs are the unmodified
`auditRun(manifest, outcome.runRecord, snapshot)` result, its identity/length, journal-produced
`flavor`, `expect`, and rejection-only `formatViolations`. Provenance/control inputs are mutable
`seededCourse`/`manifest`/`lesson`, the correlated snapshot and setup anchor, shadow/poison env
controls, evidence-dump awaits, catch/rethrow path, and null guard. This is bidirectionally equal
to the revised declaration.

The boundary at `lote-plate-tectonics.spec.ts:280-285` first requires the exact unmodified
`violations.length` to be zero, then requires `flavor === 'accepted'`; there is no alternate green
exit. Re-deriving the seven declared licensing states — accepted flavor, completed outcome,
shadow off, shadow on/successful, formatter success, satisfied null guard, initialized
setup/manifest globals — leaves every state red when a violation is returned. W-W7a, W-W7b, and
W-W7d are green at this revision.

#### 4. CONFORMANCE-MAP (W-U6/U8): RED

The rebuilt artifact has 154 top-level witness entries and 190 mapped test references. Its
top-level row/subcase ID set is structurally complete, but these semantic mappings are false:

- **W-X1:** `mer-5865-conformance-map.json:2838-2849` maps the old two-green test. That test checks
  only `runIdentity`, which is the minted GUID (`AdaptiveShadowProjector.ts:499-503`), not all
  three correlation components. The new W-X1 test at `mer5865-shadow-gate.spec.ts:630-637` is the
  executed locus but is absent from W-X1's `tests` mapping.
- **W-X3:** the correct discriminator is mapped, but the entry retains the weaker same-capture
  whole-identity case at `mer-5865-conformance-map.json:2886-2892`.
- **W-D2:** `mer-5865-conformance-map.json:2946-2952` claims the positive swapped-green test
  mutates a capture by adding a ledger and observes rejection. The test at
  `mer5865-shadow-gate.spec.ts:597-628` never performs that mutation. Static implementation of the
  inverse rule is correct, but the claimed executed mapping is not.
- **W-W8:** `mer-5865-conformance-map.json:2745-2754` cites one aggregate title that does not exist;
  the registry file has separate tests at `adaptive-family-registry.spec.ts:49-80,141-153`, and
  resolution-by-name and ownership ambiguity are distinct loci.
- **W-U7:** `mer-5865-conformance-map.json:3536-3553` likewise cites a nonexistent aggregate
  `prev/first/last/q:7` title. The four actual Playwright identities are generated separately at
  `adaptive-oracle.spec.ts:1858-1860`.

Because W-U8 explicitly makes any weaker mapped test red, the map cannot be semantically green
even though every referenced real test in the 534-test run passed.

### Suite arithmetic and verification

| Check | Round-2 result |
|---|---|
| Required ten-spec private-env replay | **534/534 passed** in 1.8 minutes, including the four swapped dumps and W-X1/W-X3 |
| Swapped dumps | Each: `in-scope=0`, `driver-evidence=65`, `diffs=22`; the 22 diffs are exactly the retired ledger-presence account |
| Expected inventory | **538** = 271 frozen + 268 additive − 1 justified removal |
| Current discovery | **540** = 538 expected + 2 explicitly excluded demo identities |
| Bidirectional suite comparison | **0 missing, 0 unexplained extra** |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional diagnostics |
| Whitespace | `git diff --check` clean |

### Predicate verdict

The swapped envelope preserves every ordinary `validateGreenEnvelope` obligation, removes only
the old “missing shipped ledger” complaint, and adds the inverse “ledger must be absent” rule at
`AdaptiveShadowProjector.ts:663-673`. All four real swapped captures satisfy that envelope. The
inverse implementation is sound, while its W-D2 map entry falsely claims an executed mutation.

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | ENTRY/CORE/REG/MAN/BIJ, setup anchoring, exact verdict boundary, and load-bearing strict path replay green. W-W7 and W-J5 are closed. |
| SUITE | **RED** | Inventory arithmetic and 534-test replay are green, but CONFORMANCE-MAP semantic conformance is red under W-U8. |
| DIFF | **GREEN** | The committed swapped gate executes over all four supplied captures; the retired account is absent, every other envelope obligation holds, and all differences are exactly classified. |
| ACCEPT | **GREEN** | Four accepted swapped runs audit to zero and are pairwise distinct on each of section, revision, and attempt identity components. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE and EXIT-INV omit reachable routed/shadow and arm-lifecycle exits; the routed catch/partial-attach scenarios are not fail-total. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-2 current summary: 4 BLOCKER (3 prior still open + 1 new), 1 SHOULD-FIX, 0 NIT.**

## Round 3

Revision reviewed: `9855617ce3`, with the supplied uncommitted round-2 fix set. The declared
never-commit/demo files and A1 deferrals remain outside this ruling as instructed.

### Open-finding rulings

| Round-2 finding | Round-3 ruling | Evidence |
|---|---|---|
| B2 — EXIT-SCOPE/EXIT-INV is not the routed universe | **STILL OPEN** | `AdaptiveShadowCapture.ts` is now declared and the projector exclusion is sound, but `AdaptiveOracle.ts` remains excluded at `assets/automation/gate-evidence/mer-5865-exit-inv.json:124-131` even though the routed spec imports/calls `auditRun` and `routed_layer` itself inventories that call at `:2210-2212`. The 16 routed entries also lack the contract-required file:line and exit kind and are not a bidirectional set; details are in the EXIT derivation below. |
| B4 — CONFORMANCE-MAP semantic conformance | **STILL OPEN** | Structural totality is now green (182 top-level entries and all 210 referenced file/title pairs exist), and W-W8/W-U7 are correctly remapped. W-X1 and W-D2 still retain the weaker/false mappings beside the new correct mappings, and the new W-E0a structural writer leg is weaker than its claimed loci. W-U8 remains red. |
| B6 — W-X3 maps a weaker same-capture mutation | **CLOSED** | W-X3 now maps only `a pair sharing ONE identity component is rejected by the same comparison (W-X3)` at `mer-5865-conformance-map.json:2980-2998`; the old same-capture mapping is absent. The discriminating test passed in the 541-test replay. |
| B8 — non-Error cause extraction and partial journal-listener attachment | **CLOSED** | `failureText` at `AdaptiveStrictAnchor.ts:27-33` is total over the tested Error/null/undefined/string/hostile-toString classes. `AdaptiveJournalRecorder.attach()` at `AdaptiveJournal.ts:914-930` removes partial registrations before rethrow; second- and third-listener hostile-page cases passed. The new blocker below concerns the enclosing shadow arm/cleanup, not these two repaired mechanisms. |
| SF1 — stale counts | **STILL OPEN** | Headline arithmetic is refreshed, but the map still contains 70 `ten-spec subset 494` stamps, 30 `ten-spec subset 516` stamps, nine `516-test replay` stamps, and W-U3 still says `expected 520` at `mer-5865-conformance-map.json:3600`. This contradicts the evidence claim at `mer-5865-gate-b-foundation-evidence.md:316-319` that replay stamps cite 541 and were refreshed. |

### New BLOCKER 9 — The shadow arm and catch cleanup are not fail-total

**Locations:**

- `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:105-185`
- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:259-271`
- `assets/automation/gate-evidence/mer-5865-exit-inv.json:2155-2160`

The fixed journal listener attachment is fail-atomic, but `armShadowCapture` is not atomic as a
whole. It successfully installs `page.exposeBinding` at line 114 and an init script at lines
126-181 before calling `recorder.attach()` at line 183 and before returning a `ShadowHandle`. If
the init-script installation or recorder attachment rejects after an earlier step succeeded,
assignment to `shadow` in the routed spec never occurs. The spec catch therefore has no handle
with which to finish or dump the partially installed shadow capture; journal listener rollback
does not undo the already installed binding/init script.

The catch itself also executes `shadow.finish('bail')` and `shadow.dump(...)` as unguarded awaits
at `lote-plate-tectonics.spec.ts:262-268`. If either cleanup operation rejects, the original error
is replaced, the final `throw armError` is not reached, and in the finish-failure case no bail dump
is attempted. Merely finding the strings `shadow.dump` and `throw armError` in source does not
prove this execution guarantee.

**Failure scenarios:** an attach fault after the shadow binding/init script leaves an unreachable
partial capture with no terminal dump; a shadow finish/dump fault inside the catch loses the
single-producer path promised by `routed_layer.producer`. EXIT-TOTAL is red independently of the
inventory-shape defects.

### Re-executed reviewer derivations

#### 1. EXIT-SCOPE (W-E0a/b): RED

The real switched graph begins at `lote-plate-tectonics.spec.ts` and includes the routed setup and
page tasks, `AdaptiveStrictDriver`, `AdaptiveStrictAnchor`, `AdaptiveShadowCapture`,
`AdaptiveJournal`, `AdaptiveFamilyRegistry`, `AdaptiveManifest`, `AdaptiveTransitionPlanner`,
`AdaptiveDeckPO`, and `AdaptiveOracle.auditRun`; the offline `adaptiveStrictDeck.ts` fixture is
also in the contract's fixture dependency graph. I verified there is no import edge from the
routed spec or `AdaptiveShadowCapture` to `AdaptiveShadowProjector`, so the rewritten projector
exclusion is sound.

The declaration still excludes `AdaptiveOracle.ts` while both the routed source and the writer's
own `routed_layer` name `auditRun`. A failure from that direct call crosses the same catch. W-E0a
therefore fails. I found no declared file absent from both the routed and fixture graphs, so
W-E0b passes; EXIT-SCOPE remains red.

#### 2. EXIT-INV (W-E1): RED

The 132 detailed driver rows remain internally source-pinned under the pending call-edge
amendment. The new `routed_layer.exits` array is not a contract-shaped extension of that set:
entries have only `{callee, owner}`, not `file:line + exit kind`, and no at-site emission witness.
It also omits actual throwing/rejecting call edges in the same region, including the
`AdaptiveLessonTask` and `HomeTask` constructors (`lote-plate-tectonics.spec.ts:204,207`),
`path.join`/`JSON.stringify` (`:238,241`), `poison.fired` (`:254,267`), and the catch-body cleanup
sites (`:260-269`). The one `strict.finish`/`shadow.finish` callee name cannot distinguish the
normal-path and catch-path sites required by file:line identity.

The three structural tests do not close this gap:

- The pre-try test at `adaptive-exit-inventory.spec.ts:1485-1496` rejects only `await ` and
  `arm[A-Z]`; a synchronous constructor or arbitrary call can be added before the try and pass.
- The routed-set test at `:1498-1512` checks only artifact → source with a suffix substring and
  “at least one” hit. It never derives source → artifact, so an unlisted source call is invisible.
- The catch test at `:1514-1525` checks textual presence, not whether finish/dump failure can
  bypass the dump and original rethrow.

The reviewer-derived set and artifact are unequal, so W-E1 is red.

#### 3. CONFORMANCE-MAP (W-U6/U8): RED

Structural results are now sound: 182 top-level entries = 154 witness entries + 28 B4 rows; the
status-class counts match evidence §5; all 210 recursively discovered map test references resolve
to identities in EXPECTED-INV. W-X3, W-W8, and W-U7 now name the real executed tests, and the new
smuggled-ledger test itself correctly adds a ledger to a real swapped capture and observes the
inverse-envelope complaint.

Semantic conformance is still false in three places:

- **W-X1:** `mer-5865-conformance-map.json:2936-2952` keeps the minted-GUID-only green-capture test
  inside `tests`, explicitly admitting it is weaker than the row. Labeling it “CORROBORATION ONLY”
  does not remove it from the mapping; W-U8 has no weaker-corroboration exception.
- **W-D2:** `mer-5865-conformance-map.json:3044-3050` still maps the positive W-D1 test while
  claiming that test adds a ledger and observes rejection. It performs no such mutation. The
  correct executed test at `:3051-3057` was supplemented, not substituted.
- **W-E0a writer leg:** its map claims “no action before the boundary,” full routed-set closure,
  and seal+dump+rethrow execution, while the structural tests prove only the weaker textual
  properties described in the EXIT-INV derivation.

Under the contract's explicit “a mapped test exercises a weaker variant” rule, any one is enough
to make W-U8 red. B4 therefore remains open even though the 541 tests all pass.

### Fresh verification

| Check | Round-3 result |
|---|---|
| Required ten-spec private-env replay | **541/541 passed** in 1.7 minutes, including all four swapped dumps and the six new routed/B8 tests |
| Swapped dumps | Each: `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, W-X3, and the executed W-D2 smuggle mutation passed |
| Expected inventory | **545** = 271 frozen + 275 additive − 1 justified removal |
| Current discovery | **547** = 545 expected + 2 explicitly excluded demo identities |
| Bidirectional suite comparison | **0 missing, 0 unexplained extra** |
| CONFORMANCE-MAP shape | **182** entries; all **210** referenced file/title identities exist |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional diagnostics |
| Security/performance sweep | No findings on the changed test-harness surface |
| Whitespace | `git diff --check` clean |

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | No new contrary evidence; entry/core/registry/manifest, setup anchoring, and exact verdict boundary remain green. B8's exact repaired mechanisms pass. |
| SUITE | **RED** | Inventory equality and replay are green, but W-U8 semantic conformance is red because weaker/false mappings remain. |
| DIFF | **GREEN** | Four swapped captures pass the committed differential, and the new inverse-ledger smuggle mutation executes and rejects correctly. |
| ACCEPT | **GREEN** | Four accepted swapped runs audit to zero and remain pairwise distinct on every identity component. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE and EXIT-INV are unequal; the shadow arm/catch cleanup is not fail-total. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-3 current summary: 3 BLOCKER (B2, B4, new B9), 1 SHOULD-FIX (SF1), 0 NIT.**

## Round 4

Revision reviewed: `9855617ce3`, with the supplied uncommitted round-3 fix set. The declared
never-commit/demo files and A1 deferrals remain outside this ruling as instructed.

### Open-finding rulings

| Round-3 finding | Round-4 ruling | Evidence |
|---|---|---|
| B2 — EXIT-SCOPE/EXIT-INV is not the routed universe | **STILL OPEN** | EXIT-SCOPE is now closed in both directions: the routed `auditRun` edge is declared and the projector exclusion remains sound. EXIT-INV is still red because the new derivation at `adaptive-exit-inventory.spec.ts:1543-1583` enumerates every `CallExpression`/`NewExpression`, not the contract's closed exit-kind set. It omits the actual `ThrowStatement` at `lote-plate-tectonics.spec.ts:280`, labels locally handled `strict.finish(...).catch(...)` as two rejecting-await exits at artifact lines 2341-2350, and cannot see failure-path returns, catch branches, or finally/cleanup exits by construction. Bidirectional equality against that same non-contract surface does not establish the required exit set. |
| B4 — CONFORMANCE-MAP semantic conformance | **CLOSED** | W-X1 now maps only the executed per-component comparison; W-D2's positive swapped-run false mapping is absent; and W-E0a's writer leg now states the limited AST/fault properties it actually proves while leaving the graph derivation reviewer-owned. The map has 182 top-level entries, 211 test-reference occurrences / 193 unique identities, and every reference resolves in EXPECTED-INV. I found no weaker or false mapping on the changed surface. The reviewer-owned W-E0a result is red under B2, but the map now represents that obligation truthfully rather than claiming the writer tests discharged it. |
| B9 — shadow arm and catch cleanup are not fail-total | **STILL OPEN** | The guarded catch is repaired: its last statement rethrows `armError`, `failureText` is total over the tested hostile values, and a finish failure still attempts the dump. The arm itself is not fail-total. After `page.exposeBinding` and `page.addInitScript` succeed, the installed script creates and arms a `MutationObserver` (`AdaptiveShadowCapture.ts:135-189`) which calls the installed binding; the binding mutates the orphan recorder core and `visits` (`:123-133`). If `recorder.attach()` then fails at `:192`, listener rollback cannot remove either irreversible install and assignment to `shadow` never completes. The new tests at `adaptive-strict-run.spec.ts:521-575` only count registrations and assert `listeners === []`; they never execute the installed script/binding, so they do not prove the claimed inertness. |
| SF1 — stale counts | **CLOSED** | The map contains no `494`, `516-test`, `ten-spec subset 516`, or `expected 520`-era text. EXPECTED-INV is 548 = 271 frozen + 281 additive - 4 justified removals; current discovery is 550 = 548 gated + 2 excluded demo identities; replay is 544/544. |

No new finding ID was added. The AST-shape defects are the still-open EXIT-INV half of B2, and
the surviving observer/binding is the original partial-arm condition in B9.

### Re-executed reviewer derivations

#### 1. EXIT-SCOPE (W-E0a/b): GREEN

The switched entry point's routed graph declares the spec, setup/page tasks, strict driver and
anchor, shadow capture, journal, registry, manifest, transition planner, deck PO, and the routed
`AdaptiveOracle.auditRun` face; the offline `adaptiveStrictDeck.ts` fixture remains declared for
the injection graph. The routed spec imports `auditRun` directly, and that edge now appears in
both `scope.declared` and `routed_layer.sites`. Neither the routed spec nor
`AdaptiveShadowCapture.ts` imports `AdaptiveShadowProjector.ts`. I found no reachable file absent
from the declaration and no declared file absent from both the routed and fixture graphs.
W-E0a and W-E0b pass.

#### 2. EXIT-INV (W-E1): RED

The 132 detailed driver rows and their 73 named at-site injections remain source-pinned under the
pending call-edge amendment. The routed extension is now mechanically exact against its own
45-row derivation, and deleting an artifact row would make that equality test fail. That is a
real improvement, but the derived set is not the contract set:

- The walker at `adaptive-exit-inventory.spec.ts:1561-1583` visits only calls and constructors.
  It never emits rows for `ThrowStatement`, `ReturnStatement`, catch branches, or finally/cleanup
  failures, despite those being members of the contract's closed kind list. In the current
  routed source, `throw armError` at `lote-plate-tectonics.spec.ts:280` is therefore absent; the
  `new Error` expressions at `:174`, `:218`, and `:284` are recorded as constructor exits instead
  of recording the enclosing explicit throws.
- Await-chain unwrapping at `adaptive-exit-inventory.spec.ts:1543-1559` marks both the handled
  operation and its handler call as `rejecting-await`. Thus `strict.finish('bail')` and its
  `.catch(() => {})` are both rows at artifact lines 2341-2350, even though the contract kind is
  a rejecting await **without** a local handler. The same duplication occurs for shadow finish
  and dump. A reviewer edge probe reproduced this shape: `await f().catch(() => {})` yielded two
  call rows while a sibling `throw armError` and failure-path `return` yielded none.
- The pre-try guard at `adaptive-exit-inventory.spec.ts:1596-1601` bans only rejecting awaits and
  names matching `arm*`/`new Adaptive*`. An arbitrary synchronous arming call or a constructor
  such as `new HomeTask(...)` can be inserted before the boundary and pass the guard. The current
  pre-region happens to contain only `test.setTimeout` and the setup-null explicit throw, but the
  structural claim is not pinned against that class of mutation.

The artifact therefore equals “all calls/constructors classified by the same algorithm,” not
the reviewer-derived exit-site set. W-E1 remains red. The routed rows also have no per-site
at-site injection/producer assertion: the map's 73 W-E2 injections cover the driver table, not
the 45 routed rows. Consequently the routed extension cannot make EXIT-EM/EXIT-MAP green even if
its membership algorithm is repaired.

#### 3. CONFORMANCE-MAP (W-U6/U8): GREEN

Structural totality remains sound: 182 top-level entries = 140 mapped + 7 mapped/live + 26 rows
covered by witnesses + 1 mapped/reviewer leg + 7 reviewer-owned + 1 deferred-A1. All 211 nested
test references (193 unique file/title identities) resolve in the 548-entry expected set.

The changed semantic mappings now match the executed assertions. W-X1 reads the accepted
finalization triple from each of the four swapped dumps and requires cardinality four for each
of section, revision, and attempt. W-D2 removes the false positive mapping and retains the
presence/removal mutations plus the executed inverse mutation that adds `ledger` to a real
swapped capture and observes the `retired account must be absent` complaint. W-E0a's writer leg
describes only AST set equality, pre-region name/kind checks, guarded-catch shape, and the stated
fault cases; its full graph comparison remains explicitly reviewer-owned. W-U6 and W-U8 pass.

### Fresh-eyes sweep

- The catch change at `lote-plate-tectonics.spec.ts:259-280` preserves the original cause and
  attempts later cleanup after a finish rejection. The AST catch-shape assertion correctly pins
  the final rethrow and the direct await wrappers.
- `failureText` remains total for Error, null, undefined, strings, and hostile `toString` values.
- `AdaptiveJournalRecorder.attach()` remains fail-atomic for second- and third-listener faults;
  the unresolved issue is specifically the enclosing shadow arm's irreversible page installs.
- The three replaced substring titles are individually recorded as additive removals at
  `mer-5865-expected-inv.json:3087-3104`; the prior frozen loop conversion remains separately
  justified and its four named replacements are discovered. No unexplained removal or rename
  remains.
- Security/performance sweep of the newly changed harness surface found no additional finding.
  `git diff --check` is clean.

### Fresh verification

| Check | Round-4 result |
|---|---|
| Required ten-spec private-env replay | **544/544 passed** in 1.7 minutes, including all routed/B9 witnesses and the four swapped dumps |
| Swapped dumps | Each: `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, W-X3, and the W-D2 smuggle mutation passed |
| Expected inventory | **548** = 271 frozen + 281 additive - 4 justified removals |
| Current discovery | **550** = 548 expected + 2 explicitly excluded demo identities |
| Bidirectional suite comparison | **0 missing, 0 unexplained extra** |
| CONFORMANCE-MAP shape | **182** entries; all **211** referenced occurrences / **193** unique file-title identities resolve |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional diagnostics |
| Whitespace | `git diff --check` clean |

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | No new contrary evidence; entry/core/registry/manifest, setup anchoring, and the exact verdict boundary remain green. |
| SUITE | **GREEN** | EXPECTED-INV equals gated discovery, 544/544 replayed tests pass, and the remapped CONFORMANCE-MAP is structurally and semantically conformant. |
| DIFF | **GREEN** | Four swapped captures pass the committed differential; each difference is the closed retired-account presence class, and the inverse ledger-smuggle mutation rejects. |
| ACCEPT | **GREEN** | The same four accepted swapped runs audit to zero and are pairwise distinct on every identity component. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE is green, but EXIT-INV does not derive the contract's exit kinds; the 45 routed rows lack per-site emission witnesses; and a failed shadow arm can leave the irreversible observer/binding active without a handle. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-4 current summary: 2 BLOCKER (B2, B9), 0 SHOULD-FIX, 0 NIT.**

## Round 5

Reviewed the uncommitted working tree at `9855617ce3` against the Round-4 open findings,
the Gate-B contract, the current evidence artifacts, and evidence document §4g.

### Closure rulings

| Finding | Round-5 ruling | Basis |
|---|---|---|
| B2 — EXIT-INV / routed inventory | **STILL OPEN** | The new walker fixes the Round-4 explicit-throw and double-row defects, but its artifact set is not the contract's closed exit-kind set. Three of the 44 `routed_layer.sites` rows are explicitly `locally-handled await (non-exit; recorded for closure)`, a kind absent from the contract, leaving 41 exit rows. Independent AST probes also found false local-handler classifications and one awaited-expression shape that loses its rejecting-await classification. |
| B9 — failed-arm inertness | **CLOSED** | `makeShadowStamp` executes the liveness guard before duplicate tracking, fence issuance, or visit mutation. `live` becomes true only after the final, fail-atomic `recorder.attach()` succeeds and becomes false before detach begins. The new tests execute a pre-live stamp, a live/duplicate sequence, and the real installed binding before and after `finish`; they establish zero pre/post-live effects and exactly one live journal-fenced visit. |

### EXIT-EM writer position: REFUSED

The writer position is a coherent lower-cost alternative, but it is not the evidence required by
the current contract. The contract says per-site injection must activate **that** site and prove
its pinned producer—and no other producer—before the boundary/seal. Bidirectional AST equality,
region ownership, catch-shape assertions, arm fail-totality, and live bail dumps prove important
adjacent properties; they do not prove reachability, cleanup state, or single-producer emission at
each routed site. Accepting the position would therefore relax EXIT-EM rather than discharge it.

The required redo is a **per-actual-exit-site live routed fault campaign**: activate each routed
exit through the outer test boundary and assert its one pinned producer, with no other producer,
before the boundary/seal. After separating the three recorded non-exits from the site universe,
the current artifact describes 41 such exit sites—not 44. The artifact's `exit_em_position`
paragraph also still says 45 live walks and must be reconciled with the final exit universe.

### B2 derivation — EXIT-INV remains red

The artifact and witness now agree bidirectionally on 44 rows, with region counts
`pre=2`, `try=26`, `catch=10`, and `post=6`. The kind counts are:

| Derived kind | Rows | Contract status |
|---|---:|---|
| `throw` | 28 | Contract exit kind |
| `rejecting await without local handler` | 12 | Contract exit kind |
| `catch branch` | 1 | Contract exit kind |
| `locally-handled await (non-exit; recorded for closure)` | 3 | **Not an exit kind and not in the contract's closed list** |

The ThrowStatement walk correctly emits `throw armError`; constructor expressions inside an
explicit throw are absorbed into that throw row. The three handled finish/dump chains are no
longer misreported as rejecting exits. The exact two-row pre-region set also closes the previous
name-based insertion hole.

The remaining problem is semantic, not set-comparison direction. Both implementations encode a
broader bookkeeping set than the contract's exit universe, while the witness's local-handler
test is too permissive:

- Any `.catch` property call is treated as handled even with no rejection callback:
  `await f().catch()` was classified as non-exit.
- Any two-argument `.then` is treated as handled even when the rejection slot is not a handler:
  `await f().then(ok, undefined)` was classified as non-exit.
- `await (flag ? f() : g())` emitted no rejecting-await row for the AwaitExpression because its
  direct expression is conditional; the nested calls later fell through as synchronous
  `throw` rows.
- `await f().catch(() => { throw new Error('handler') })` did retain the handler-interior
  explicit throw, `throw new Ctor()` retained the enclosing throw, and `await f(await g())`
  retained both nested direct awaits. These positive probes do not cure the preceding holes.
- The derivation text says failure-path returns and finally/cleanup failures “would emit if
  added,” but `deriveRoutedRows` has no ReturnStatement or finally-specific classifier. Those
  kinds are absent from today's routed source, so this is not a present set mismatch; it does
  mean the claimed contract-complete generator is not actually closed under those additions.

Separately authored walks and mutation-tested equality protect against artifact drift, but two
walks sharing these semantic omissions cannot establish W-E1. B2 therefore remains blocking.

### New finding

#### B10 — CONFORMANCE-MAP references the three removed Round-4 structural titles — BLOCKER

`mer-5865-expected-inv.json` correctly records seven justified removals, including the three
Round-4 routed structural titles, and discovers their three contract-kind replacements. However,
the W-E0a `writer_leg` in `mer-5865-conformance-map.json` still references the removed titles:

- `artifact routed set equals AST-derived site enumeration, both directions (W-E0a)`
- `the pre-try region arms nothing; every routed callee is inside the try`
- `the catch rethrows the original error and guards every cleanup await`

None of the three replacement titles is mapped. A static resolution sweep found 211 reference
occurrences / 193 unique file-title identities, with exactly those three identities absent from
EXPECTED-INV. The prose also describes the superseded Round-4 derivation rather than the current
contract-kind witness. Thus W-U6 reference resolution and W-U8 semantic conformance are red.

Required fix: replace the three stale references with the exact current discovered titles and
rebuild the W-E0a claims so each claim is supported by the replacement witness. Do not retain the
removed identities as supplemental mappings.

### Fresh-eyes sweep

- The liveness state in `AdaptiveShadowCapture.ts` is monotone over each arm lifecycle: false
  during both irreversible installs, true only after attach, and false before asynchronous
  teardown. A failed attach cannot expose a live handler. The MutationObserver chain terminates
  at the same guarded binding exercised by the tests.
- The pre-live test also seals the journal and observes zero fences, so it does not merely inspect
  the visit array. The real-binding test covers the installed-function wiring and post-finish
  behavior. No further B9 gap was found.
- The seven removals in EXPECTED-INV are arithmetically and individually accounted for. The defect
  is the conformance map's failure to follow three of those removals, not the removals themselves.
- Security and performance review of the new handler and AST-test surface found no additional
  finding. `git diff --check` is clean.

### Fresh verification

| Check | Round-5 result |
|---|---|
| Required ten-spec private-env replay | **547/547 passed** in 1.7 minutes |
| Swapped dumps | All four: `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, W-X3, and the W-D2 inverse-smuggle mutation passed |
| Expected inventory | **551** = 271 frozen + 287 additive - 7 justified removals |
| Current discovery | **553** = 551 expected + 2 explicitly excluded demo identities |
| Bidirectional expected/discovery comparison | **0 missing, 0 unexplained extra** |
| Routed artifact | **44 rows** = 41 exits + 3 explicitly recorded non-exits |
| CONFORMANCE-MAP shape | **182** entries; 211 referenced occurrences / 193 unique identities; **3 stale unresolved identities** |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional diagnostics |
| Whitespace | `git diff --check` clean |

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | No new contrary evidence; the entry/core/registry/manifest wiring and exact verdict boundary remain green. |
| SUITE | **RED** | EXPECTED-INV and the 547-test replay are green, but CONFORMANCE-MAP retains three removed titles and does not map their replacements. |
| DIFF | **GREEN** | Four swapped captures pass the differential, and the inverse ledger-smuggle mutation rejects. |
| ACCEPT | **GREEN** | The accepted swapped runs audit to zero and remain distinct on every required identity component. |
| EXIT-TOTAL | **RED** | B9 is closed and EXIT-SCOPE remains green, but EXIT-INV is not the contract's closed exit-kind set and the contract-required routed per-site EXIT-EM campaign is absent. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-5 current summary: 2 BLOCKER (B2, B10), 0 SHOULD-FIX, 0 NIT. EXIT-EM writer position REFUSED as part of B2.**

## Round 6

Reviewed the current uncommitted working tree at `9855617ce3`, evidence document §4h, the
new `AdaptiveStrictGatedRun.ts` boundary and `adaptive-gated-run.spec.ts`, the two routed AST
tables, EXPECTED-INV, and the changed CONFORMANCE-MAP entries. The intentional exclusions in the
submission remain outside this ruling.

### Closure rulings

| Item | Round-6 ruling | Basis |
|---|---|---|
| B2 — EXIT-SCOPE / EXIT-INV | **STILL OPEN** | `scope.declared` does not name the new `AdaptiveStrictGatedRun.ts` file and still describes arming/audit/catch as inline in the spec. The two new tables equal the writer walker, but `module_sites` contains four non-contract bookkeeping rows, the routed rows still have no per-row producer, and the walker's “handled” test is semantically false for the current two-armed `.then`: its callbacks can throw. |
| B10 — three removed Round-4 W-E0a titles | **CLOSED** | W-E0a's writer leg now names only the three current routed AST titles. None of B10's three superseded structural titles remains in that leg. A separate stale W-W7b reference remains and is a new conformance defect below, not a continuation of B10's exact title set. |
| SF1 — current counts/replay stamps | **STILL OPEN** | Set equality and replay are green, but the artifacts contradict the claimed decomposition and current replay shape: EXPECTED-INV stores `271 + 319 - 11 = 579`, not `271 + 320 - 12`; CONFORMANCE-MAP has 183 evidence entries plus `_meta`, not 182; and it still contains 137 `ten-spec subset` stamps although the current subset has eleven specs. |
| Round-5 EXIT-EM refusal redo | **STILL OPEN** | The new suite has 28 tests total, but W-E2-ROUTED maps only 25 tests (three are green-path tests), while the derived routed universe has 41 contract-kind exit rows after removing four bookkeeping non-exits. The campaign is neither a per-row mapping nor a proof of “pinned producer and no other,” and the catch displacement probe below is an executed counterexample. |

### New BLOCKER 11 — Catch logging can still replace the original boundary error

**Locations:**

- `assets/automation/src/systems/torus/tasks/AdaptiveStrictGatedRun.ts:169-179`
- `assets/automation/tests/torus/student_delivery/adaptive-gated-run.spec.ts:406-414`
- `assets/automation/tests/torus/student_delivery/adaptive-exit-inventory.spec.ts:1576-1597`

The bail dump is awaited through a two-armed `.then`, but both handlers invoke injectable
dependencies. If the dump succeeds and `deps.log` throws, or if the dump rejects and `deps.warn`
throws, the promise returned by `.then` rejects. The enclosing `await` then exits the catch before
`throw boundaryError`, replacing the original error.

I executed both paths against the real bundled `runGatedLote` function. In both probes the strict
bail finish, shadow bail finish, and shadow dump were attempted, but the value crossing the
boundary was the injected logging cleanup error, not the original object:

| Probe | Original preserved? | Cleanup displacement observed? |
|---|---:|---:|
| successful dump → hostile `deps.log` | no | yes |
| rejecting dump → hostile `deps.warn` | no | yes |

The existing hostile-log test does not distinguish this. Its one `log` dependency throws the same
`fault` first at the normal-path log on line 118 and again at the catch success handler on line
177, so `rejects.toBe(fault)` passes even though the second throw displaced the first. There is no
hostile-warn test. Consequently the module comment's “ORIGINAL error always crosses,” the AST
catch witness, and W-E2-ROUTED's semantic claim are false at the current source.

### New BLOCKER 12 — The revised conformance/verdict evidence is not current or semantically total

**Locations:**

- `assets/automation/gate-evidence/mer-5865-conformance-map.json:2745-2767`
- `assets/automation/gate-evidence/mer-5865-conformance-map.json:2926-2945`
- `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:503-513`
- `docs/exec-plans/current/epics/automated_testing/mer-5865-gate-b-foundation-evidence.md:33-46`

After normalizing the map's `tests/` path prefix, the reference sweep found **234 reference
occurrences / 217 unique identities / 1 unresolved identity**. The unresolved identity is the
removed title `the LotE spec imports the strict driver and audit, not the old walker`, retained by
W-W7b even though EXPECTED-INV individually records its replacement. The new identity test proves
that `runGatedLote` returns the exact array from `deps.audit`; it does not make the removed static
title resolve, and no mapped current test pins the spec's exact two assertion shapes.

W-W12 is also mapped to a weaker mutation. Its ban list scans both files, but it does not ban the
projection module or its other acceptance helpers (`AdaptiveShadowProjector`,
`projectFromJournal`, `compareProjections`, etc.), and it does not ban a generic `ledger`
acceptance dependency. Reintroducing any of those references would satisfy the mapped test while
violating C16/W-W12. The current sources are clean under an independent read; the mapped witness is
still weaker than the contract subcase, which makes W-U8 red.

### Re-executed derivations

#### 1. EXIT-SCOPE (W-E0a/b): RED

The real routed graph is now `lote-plate-tectonics.spec.ts → AdaptiveStrictGatedRun.ts →`
shadow/strict/anchor/lesson/home/audit dependencies, continuing through the previously declared
driver, journal, registry, manifest, planner, and deck surfaces. The offline
`adaptiveStrictDeck.ts` fixture remains in the injection graph.

`scope.declared` omits `AdaptiveStrictGatedRun.ts` entirely and its spec entry still says the spec
contains the arming, audit, and single catch. That is a direct W-E0a inequality. I found no
declared production/fixture file absent from both the routed and injection graphs, so W-E0b is
green; EXIT-SCOPE is red because W-E0a is red.

#### 2. EXIT-INV (W-E1): RED

The artifact mechanically matches the shared walker: 37 module rows and 8 spec-residual rows.
The actual kind counts are:

| Surface | Contract-kind rows | Bookkeeping non-exits | Total artifact rows |
|---|---:|---:|---:|
| `module_sites` | 33 | 4 (three locally handled awaits + one success return) | 37 |
| `spec_residual_sites` | 8 | 0 | 8 |
| Total | **41** | **4** | **45** |

The contract requires exact set equality over its closed exit-kind list, not equality over an exit
set plus success/non-exit closure rows. None of the 45 routed rows carries the required per-site
`producer` field.

I reran the Round-5 edge probes against the current walker. Argless `.catch()` and
`.then(ok, undefined)` classify as rejecting; a parenthesized ternary emits both rejecting
branches; nested direct awaits are retained; a throw inside a catch handler is retained; and
catch returns/finally are recorded. Those repairs are real.

The hardened walker still treats any argument whose source text is not literally `undefined` or
`null` as a “real handler.” Probes using `.catch(noHandler)` and `.then(ok, noHandler)` therefore
classified as locally handled even when `noHandler` is undefined at runtime. More importantly,
the current `await shadow.dump(...).then(success, failure)` is classified locally handled even
though either callback can throw; BLOCKER 11 executes that missed rejecting-await path. The two
walks share this semantic error, so bidirectional equality between them does not establish W-E1.

#### 3. EXIT-EM routed refusal redo: RED

`adaptive-gated-run.spec.ts` discovers 28 tests, while W-E2-ROUTED maps 25. The mapped set covers
21 normal/boundary cases plus four catch-cleanup cases; it is not a row-by-row map over the 41
contract-kind routed exits. Among the unmapped/distinct sites are `path.join`, `JSON.stringify`,
the later normal-path `deps.log` calls, normal-path `poison.fired`, both `failureText` sites, the
catch `deps.log`/`deps.warn` sites as independent faults, and the eight spec-residual exits.

The common assertion helper also uses containment rather than an exact producer set: it requires
selected finish/dump calls and bans only `shadow.dump:lote-green`. It does not assert exact
cardinality, absence of every other producer, or absence of the strict `writeFile` evidence call.
Thus the mapped tests are weaker than “the pinned producer and no other,” independently of the
executed displacement counterexample.

#### 4. VERDICT-S / W-W7a at the refactored boundary: RED

Fresh derivation at this source:

- Direct assertion inputs are `result.violations` (the exact `deps.audit` array), its `.length`,
  `result.flavor`, `expect`, and the rejection-only `formatViolations` diagnostic.
- Provenance/control inputs include the awaited `runGatedLote` import and result destructuring;
  `page`; mutable `seededCourse`/`manifest`/`lesson`; the two environment controls; the setup null
  guard; the module's exception/evidence paths; and the exported, mutable `GATED_RUN_DEFAULTS`
  object with its real arm/task/driver/audit/file/clock/logging dependencies.
- There is no spec fallback or catch: a module rejection is test-red; only exact zero violations
  followed by accepted flavor can return from both assertions.

The identity witness and source shape establish that no violation transformation was introduced.
However, evidence §1 still declares the old inline `auditRun(manifest, outcome.runRecord,
snapshot)` call, inline evidence awaits, and inline catch as the direct boundary. It does not
declare `result`, `runGatedLote`, or `GATED_RUN_DEFAULTS`. The required bidirectional comparison is
therefore unequal. The old seven W-W7d licensing-state executions also do not instantiate the new
default-dependency/result boundary at this revision. W-W7a is red; VERDICT-S is red under the
contract even though the observed assertion semantics remain fail-closed.

#### 5. CONFORMANCE-MAP (W-U6/U8): RED

- **W-E0a:** the three Round-5 B10 titles are correctly remapped, but the writer leg cannot cure
  the reviewer-derived scope inequality and its catch-shape claim is refuted by BLOCKER 11.
- **W-E2-ROUTED:** 25 mapped tests are described as 28 per-site activations; they do not map the
  41 contract-kind rows and their “no other” assertions are weaker than the subcase.
- **W-W7b:** the identity test is valid, but the entry retains one removed/unresolved test title
  and lacks a current mapped static assertion-shape witness.
- **W-W10:** the two-hop import binding is semantically conformant and passed.
- **W-W12:** both surfaces are scanned, but the ban list is not the contract's projection/ledger
  class; a prohibited reference can be reintroduced without making the test red.

Required top-level row/subcase coverage otherwise remains present, but reference resolution and
semantic conformance are not total. W-U6/W-U8 are red.

### Fresh-eyes sweep

- Arming, navigation, login, correlation, the anchor, walk, freeze, audit, and both dump paths do
  execute inside `runGatedLote`'s one try/catch. The spec is a thin one-call/two-assertion caller.
- The successful identity test is meaningful: `result.violations === SENTINEL_VIOLATIONS` by
  object identity. The spec consumes that returned array directly.
- Frozen-journal behavior is correctly distinguished from armed/unfrozen behavior in the covered
  tests; post-freeze faults do not request a second strict finish.
- The catch guards strict finish, shadow finish, dump rejection, and `poison.fired`, but not the
  success/failure logging callbacks after the dump. No additional security or performance issue
  was found beyond the correctness/evidence defects above.
- Two current private strict dumps (`lote-strict-1786904280178.json` and
  `lote-strict-1786906459491.json`) each record `completed`, `accepted`, frozen,
  `sealIncomplete=false`, and zero violations. This corroborates the stated live re-proof; it does
  not discharge the structural/per-site failures.

### Fresh verification and counts

| Check | Round-6 result |
|---|---|
| Required eleven-spec private-env replay | **575/575 passed** in 1.7 minutes after rerunning outside the Chrome sandbox |
| Initial sandboxed attempt | 516 passed / 59 Chrome-launch failures; every failure was `browserType.launch` with Chrome `SIGABRT`/`kill EPERM`, then the same command passed outside the sandbox |
| Swapped dumps | All four: `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, inverse W-D2, and W-X3 passed |
| Expected inventory set | **579** = 271 frozen + 319 additive - 11 artifact removals |
| Current discovery | **581** = 579 gated + 2 excluded demo identities |
| Bidirectional expected/discovery comparison | **0 missing, 0 unexplained extra** |
| Claimed count decomposition | **Stale:** evidence says 320 additive / 12 removals, artifact stores 319 / 11 |
| Routed artifact | 37 module + 8 residual = 45 rows; **41 contract kinds + 4 bookkeeping non-exits** |
| Routed W-E2 mapping | **25 mapped titles**, not 28; no row-level producer map |
| CONFORMANCE-MAP shape | **183** evidence entries plus `_meta`; 234 references / 217 unique / **1 unresolved**; 137 stale `ten-spec subset` stamps |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no additional diagnostics |
| Whitespace | `git diff --check` clean before this review append |

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **RED** | The two-hop entry/core binding and exact returned-array identity are sound, but W-W7a is unequal to the stale declaration and its new dependency/result inventory has not been re-instantiated under W-W7d. |
| SUITE | **RED** | The 575 replay and expected/discovery set equality are green; SF1 counts/stamps, one unresolved W-W7b reference, and weaker W-E2/W-W12 mappings make CONFORMANCE-MAP totality/semantic conformance red. |
| DIFF | **GREEN** | The four swapped captures replay with zero in-scope violations, exactly 65 driver-evidence violations, and exactly 22 classified presence diffs each; inverse mutations pass. |
| ACCEPT | **GREEN** | Current private routed evidence is completed/accepted/frozen with zero violations, and no contrary evidence was found against the previously established four-run distinctness. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE omits the new boundary file; EXIT-INV includes non-exits and shares a false handler classifier; routed sites lack per-row producers; the per-site campaign is incomplete; and hostile catch logging executes original-error displacement. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-6 current summary: 3 open BLOCKER findings (B2, B11, B12), 1 open SHOULD-FIX (SF1), 0 NIT. The EXIT-EM refusal remains undischarged within B2; B10 is closed.**

## Round 7

Reviewed the current uncommitted working tree at `9855617ce3`, evidence §4i/§4j, the
post-contract score-total extension, all four reviewer-owned derivations, and the private
archive/dump evidence. The required eleven-spec replay was run outside the Chrome sandbox.

### Validation audit (read and executed this round)

| Claim | Current source/artifact read | Independent execution | Ruling |
|---|---|---|---|
| B2 / EXIT-SCOPE + EXIT-INV | yes | AST inventory witness + reviewer set derivation | **STILL OPEN** |
| B11 / logging displacement | yes | both hostile logging witnesses passed | **CLOSED** |
| B12 / W-W7b + W-W12 | yes | static shape and full C16 ban-list witnesses passed | **CLOSED AS PREVIOUSLY FRAMED** |
| SF1 / counts and replay labels | yes | fresh discovery and set comparison | **STILL OPEN** |
| Round-6 EXIT-EM refusal redo | yes | row-by-row semantic comparison against fault tests | **STILL OPEN** |
| EXT-SCORE-TOTAL oracle + archive anchor | yes | two kill mutations + two real-artifact probes | **GREEN IN SUBSTANCE** |

### Round-6 disposition rulings

| Item | Round-7 ruling | Basis |
|---|---|---|
| B2 — EXIT-SCOPE / EXIT-INV | **STILL OPEN** | `scope.declared` now names the routed boundary and is bidirectionally complete, and the module table is correctly split into 35 exits + 4 non-exit closure rows. The score-total edit shifted every spec-residual site by five lines without refreshing the artifact, so file:line+kind set equality fails (B13). |
| B11 — catch logging displacement | **CLOSED** | `quietly()` guards both `.then` logging callbacks. The success-handler hostile `deps.log` and rejection-handler hostile `deps.warn` tests each preserve the original object, and both passed in the fresh replay. `GATED_RUN_DEFAULTS` is frozen and its witness passed. |
| B12 — stale W-W7b / weak W-W12 | **CLOSED AS PREVIOUSLY FRAMED** | W-W7b now maps only the identity witness and the current exact-two-assertion-shapes witness. W-W12 scans both the thin spec and boundary module for the full 15-token old-walker/ledger/projection class, including generic `ledger`; the sources are clean and the test passed. New map defects are B14, not continuations of those exact mutations. |
| SF1 — current counts and replay stamps | **STILL OPEN** | Evidence says +6 / 595 expected / 2 demo identities / 183 map entries. The artifacts and fresh discovery say +7 / 596 expected / 3 identities in the two excluded demo files / 184 map entries. §2.3 and §5 also retain the pre-extension 589/591 narrative. |
| Round-6 EXIT-EM refusal redo | **STILL OPEN** | The row activation map exists, but four rows point to tests that do not activate those sites (B14). The per-site discharge is therefore semantically false even though the correct tests also exist elsewhere in the suite. |

### B13 — The score-total edit invalidated the exact spec-residual exit inventory — BLOCKER

**Locations:**

- `assets/automation/gate-evidence/mer-5865-exit-inv.json:2421-2478`
- `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:165-191`
- `assets/automation/tests/torus/student_delivery/adaptive-exit-inventory.spec.ts:1727-1731`

The extension added five lines to the live spec before the gated test. The artifact still declares
the eight residual exit coordinates as `160/163/171/185/185/185/186/186`; the independent current
source derivation is `165/168/176/190/190/190/191/191`, with the same callees and kinds. Because
the contract fixes site identity as file:line + exit kind, semantic equivalence after a line shift
does not satisfy W-E1.

This is not a documentary-only discrepancy. The required eleven-spec command failed exactly at
the bidirectional residual comparison: **591 passed / 1 failed**. `SUITE` requires all executed
tests to pass, and `EXIT-INV` requires exact set equality, so both conjuncts are red.

### B14 — The conformance/activation maps still make false current-revision claims — BLOCKER

**Locations:**

- `assets/automation/gate-evidence/mer-5865-conformance-map.json:28`
- `assets/automation/gate-evidence/mer-5865-exit-inv.json:2619-2741`
- `assets/automation/tests/torus/student_delivery/adaptive-gated-run.spec.ts:590-623`
- `assets/automation/tests/torus/student_delivery/adaptive-gated-run.spec.ts:629-642`
- `assets/automation/tests/torus/student_delivery/adaptive-gated-run.spec.ts:677-710`

Reference resolution finds one stale map identity: W-E0a still cites removed title
`the module table equals the contract-kind derivation, both directions (W-E0a)`. The discovered
replacement is `the module EXIT table equals ...`; EXPECTED-INV already records the old identity
as a justified removal.

More materially, four `row_activation_map.module` rows cite the wrong fault mutation:

| Exit row | Artifact maps it to | Test that actually activates the row |
|---|---|---|
| `:129 deps.log` (correlation log) | hostile catch-success log | hostile normal-path correlated log |
| `:147 deps.log` (strict evidence log) | hostile catch-success log | hostile normal-path evidence log |
| `:158 poison?.fired` (green path) | hostile catch-path `fired()` | green-path `fired()` throw |
| `:161 deps.log` (green capture log) | hostile catch-success log | hostile capture-log after green dump |

The mapped catch tests cannot reach the cited normal/green sites: their mutations are conditional
on bail-capture text or occur only after a separately injected boundary error. The correct tests
exist and passed, but W-E2 requires a per-row mapping to the test activating **that site**, and
W-U8 makes a weaker/false mapping red rather than allowing another correct test to cure it.
Consequently EXIT-EM and CONFORMANCE-MAP semantic conformance remain red.

### Reviewer derivations

#### 1. EXIT-SCOPE (W-E0a/b): GREEN

The current routed graph is the thin LotE caller → `AdaptiveStrictGatedRun.ts` → shadow arm,
strict arm, poison, `AdaptiveLessonTask`/`HomeTask`, setup anchor, strict driver, journal, family
registry/deck, manifest/planner and routed `auditRun`. The offline `adaptiveStrictDeck.ts` remains
legitimate in the injection half. The declaration now names the boundary file, routed shadow
capture, anchor, driver/core surfaces, fixture, and the setup/task dependencies in the owning
entries. The projector and archive reader have no routed edge; they are offline judges. I found
no reachable routed/injection file absent from the declaration and no declared production/fixture
file absent from both graphs. W-E0a and W-E0b are green.

#### 2. EXIT-INV (W-E1): RED

Independent source enumeration yields 35 module exits and four separately recorded module
non-exits. Those sets and per-row producers agree with the current `runGatedLote` source. The thin
spec yields eight exits, but their exact coordinates disagree in both directions with the
artifact after the five-line extension shift (B13). EXIT-INV is red.

#### 3. VERDICT-S / VERDICT-L (W-W7a/b/d): GREEN

Fresh direct inventory: the exact `deps.audit` array returned as `result.violations`, `.length`,
the journal-produced `result.flavor`, `expect`, and rejection-only `formatViolations`. Fresh
provenance/control inventory: the awaited `runGatedLote` import and plain result destructure;
`page`; initialized `seededCourse`/`manifest`/`lesson`; the required score declaration carried by
that manifest; the null guard; `MER5865_SHADOW_DIR` and `MER5865_POISON_SCREEN`; module
exception/evidence paths; and the frozen `GATED_RUN_DEFAULTS` dependency bundle (arming, task,
driver, audit, file, clock and logging functions).

That is bidirectionally equal to evidence §1 plus §4j's declared score requirement. The identity
witness proves no transformation across `runGatedLote`, and the static witness pins exactly one
`violations.length === 0` assertion followed by exactly one accepted-flavor assertion. Rechecking
the licensing states (accepted flavor, completed/aborted outcome, shadow off, shadow successful,
poison inactive, successful evidence/logging/formatter paths, initialized globals/null guard,
declared score, and frozen defaults) leaves every case red when the returned array contains a
violation. There is no catch, fallback, filter, override or alternate green exit in the spec.
W-W7a/b/d and VERDICT-S/L are green.

#### 4. CONFORMANCE-MAP semantic conformance (W-U6/U8): RED

Structural top-level coverage is complete for the claimed foundation rows/subcases and includes
`EXT-SCORE-TOTAL`; B4-DEL remains explicitly deferred under A1. Fresh reference resolution found
**250 references / 233 unique identities / 1 unresolved identity**, the removed W-E0a title in
B14. The four false routed row activations also fail W-U8. The score extension's seven mapped
tests are semantically conformant and passed, but one sound entry cannot cure defects elsewhere
in the bidirectional map. CONFORMANCE-MAP is red.

### Post-contract extension — EXT-SCORE-TOTAL

The extension is **GREEN in substance**:

- `expected_total_score` is accepted only as a finite, non-negative number.
- On accepted, non-sealed snapshots, `auditRun` sums every evaluation record's wire
  `actions.score` (missing score contributes zero) and emits `score-total-mismatch` with count-only
  facts on inequality. Sealed runs and undeclared manifests do not invoke the rule.
- The independent archive reader reads page `custom.totalScore` into
  `ArchiveFacts.total_score`; `validateRouteCoverage` rejects both a missing declaration and a
  contradictory declaration.
- In an isolated temporary copy, neutering the oracle condition made the named mismatch test red,
  and neutering the archive-anchor condition made the missing-declaration arm red. The current
  sources then passed two reviewer probes over real artifacts: accepted dump 90 → `[]`, tampered
  91 → exactly `score-total-mismatch {count: 90, expectedCount: 91}`; archive page 397294 → 90 and
  a manifest 91 → the named contradiction.
- The claimed live dump is completed/accepted with 23 evaluations, wire total 90 and zero stored
  violations. The newer fresh-seed dump has the same 90/zero result. The archive page authors 90;
  all 22 activity `maxScore` values sum to 99, confirming that page `totalScore`, not the activity
  sum, is the selected anchor.

The suite-impact claim is stale: this extension added **seven** discovered tests, not six.

### Fresh verification and suite arithmetic

| Check | Round-7 result |
|---|---|
| Required eleven-spec private-env replay (outside sandbox) | **591 passed / 1 failed / 592 total**; sole failure is B13 |
| EXPECTED-INV | **596** = 271 frozen + 337 additive − 12 justified removals |
| Full current discovery | **599** = 596 gated + 3 identities in the 2 excluded never-commit demo files |
| Bidirectional expected/discovery comparison | **0 missing, 0 unexplained extra** after excluding those files |
| Eleven-spec vs full gated inventory | 592 = 596 − 4 `adaptive-authoring` identities; the requested subset intentionally omits that flaky file |
| Demo classification | Correct by file: both `mer5865-demo-*` files are in `excluded_uncommitted`; they currently contain 3 identities and are not counted |
| Swapped DIFF | Four dumps each `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, inverse W-D2 and W-X3 passed |
| ACCEPT artifacts | 4/4 completed, accepted and stored-zero; wire totals all 90; 4 distinct sections, revisions and attempts |
| CONFORMANCE-MAP | **184** evidence entries plus `_meta`; 250 references / 233 unique / 1 unresolved; semantic row-map defects in B14 |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` errors at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; nothing else |
| Whitespace | `git diff --check` clean before this append |

Security/performance review found no additional issue: the score scan is linear in the bounded
journal, diagnostics remain count-only, no secret was read into or written to the repository, and
the uncommitted tracker route is compile-time limited to dev/test. The never-commit artifacts stay
excluded from the gate set by file, as declared.

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | Entry/core/registry/manifest/archive wiring, exact verdict identity/shape, W-W7 derivation, score oracle and archive anchor are sound and exercised. |
| SUITE | **RED** | Expected/discovery membership is equal, but the required run has one real failure and CONFORMANCE-MAP has one unresolved identity plus false semantic row mappings. |
| DIFF | **GREEN** | Four swapped captures replay with only the 22 retired-account presence deltas and the exact 65-item retired inventory; inverse mutations pass. |
| ACCEPT | **GREEN** | Four accepted runs are completed/frozen, audit to zero under the 90-point declaration, and are distinct on every identity component. |
| EXIT-TOTAL | **RED** | EXIT-SCOPE and EXIT-MAP are green; EXIT-INV fails exact residual-site equality and EXIT-EM lacks a semantically correct per-row activation map. |

`SWAP-GREEN = RED`.

`GATE-B-FOUNDATION = RED`.

`GATE-B-CLOSE` remains unclaimed under A1 and is not part of this ruling.

**Round-7 current summary: 2 new BLOCKER findings (B13, B14); B2 and the EXIT-EM refusal remain open through them; B11 and B12 are closed; SF1 remains open.**

## Round 8

Reviewed the current uncommitted working tree at `9855617ce3` against the v6 contract plus A1,
evidence through §4k, all three gate artifacts, and Rounds 1–7. The required eleven-spec replay
was run outside the Chrome sandbox with the Round-7 reviewer environment. B4-DEL and the Real
Chem migrations remain intentionally deferred under A1 and are not findings in this round.

### Validation audit (read and executed this round)

| Claim | Internal source/artifact read | Independent execution | Verdict | Confidence |
|---|---|---|---|---|
| Round-7 change scope | current status/diff, file timestamps, and the three claimed files | status/diff scope comparison | **TRUE** | high-exhaustive for the available uncommitted tree |
| B13 residual-site re-coordination | thin spec + both exit-inventory tables | independent TypeScript AST derivation + 98-test inventory replay | **TRUE / CLOSED** | high-exhaustive |
| B14 four routed retargets | boundary source + harness + four row-map entries | exact row/test reachability derivation + full replay | **TRUE / CLOSED** | high-exhaustive |
| B14 stale W-E0a identity | current map + current discovery | full reference-resolution sweep | **TRUE / CLOSED** | high-exhaustive |
| SF1 count refresh | evidence prose + contract/map/inventory counts | fresh arithmetic and map classification | **PARTIAL** | high-exhaustive |

No external framework/spec evidence was required: these claims are determined by repository
source, artifacts, and executions. The only partial disposition is the non-blocking prose count
below.

### Change-scope verification

The branch and HEAD are unchanged: `MER-5865-adaptive-lessons-share-strict-verification-and-migrate-real-chem-specs`
at `9855617ce3`. Because Round 7 was not committed, Git has no native Round-7-to-Round-8 range;
the full status still shows the same branch-wide uncommitted implementation. The Round-7 review
file was last written at 11:48, and the only tracked review-scope files with later modification
times were exactly the declared three: `mer-5865-exit-inv.json` (12:35),
`mer-5865-conformance-map.json` (12:37), and the foundation evidence document (15:10). No source
or test file was touched after the Round-7 read. The current changes in those files are confined
to the B13 coordinates/twins, the B14 identity and four row retargets, `_meta.round_7`, §4k, and
the count-prose refresh. `git diff --check` is clean.

### Findings

No new blocking finding (B15+) was found.

#### SF1 — One current count sentence still says 26 §3 rows — SHOULD-FIX, STILL OPEN NARROWLY

**Location:** `docs/exec-plans/current/epics/automated_testing/mer-5865-gate-b-foundation-evidence.md:495`

Evidence §5 says the 184-entry map contains “all 26 §3 row IDs.” Fresh extraction from the
contract's §3 table yields **28** B4 row IDs, and the map contains exactly those same 28 with zero
missing or extra. The surrounding current counts are correct: 184 evidence entries, 73 named
driver exit injections, and 596 expected identities. The status-class numbers at lines 497–500
are explicitly labeled historical (“at the round-2-fix revision”) and are not stale current
claims.

This residual prose error does not make a conjunct unverifiable—the machine artifacts are total
and the 28/28 equality was independently established—but the claim that every count stamp was
refreshed is not literally true. Replace `26` with `28` before commit.

### Round-7 disposition rulings

| Item | Round-8 ruling | Basis |
|---|---|---|
| B13 — shifted spec-residual coordinates | **CLOSED** | Independent AST enumeration of the current thin test produced exactly 8 exits at `165/168/176/190×3/191×2`. `spec_residual_sites` at `mer-5865-exit-inv.json:2421` and its activation twins at `:2822-2878` match that set in both directions and match each other exactly. The focused inventory replay passed 98/98. |
| B14 — stale W-E0a reference | **CLOSED** | W-E0a now names the discovered title `the module EXIT table equals the contract-kind derivation, both directions (W-E0a)` at `mer-5865-conformance-map.json:29`. Fresh resolution found 0 unresolved identities. |
| B14 — four false routed activations | **CLOSED** | Rows `:129/:147/:158/:161` at `mer-5865-exit-inv.json:2619-2743` each contain one replacement activation, not the old mapping plus a new one. Source/harness reads confirm the cited tests inject at the exact correlation log, strict-evidence log, green-path `poison.fired()`, and post-green-dump capture log respectively (`adaptive-gated-run.spec.ts:629,677,688,700`). All four passed. |
| B2 / EXIT-INV residual and Round-6 EXIT-EM refusal | **CLOSED** | B13 restores exact residual equality; the module table remains 35 exits + 4 non-exit closure rows, and activation maps equal both exit tables exactly (35/35 module, 8/8 residual), with no unresolved activation identity. |
| SF1 | **STILL OPEN AS SHOULD-FIX ONLY** | Current inventory/discovery/map/replay arithmetic is correct; only the §5 `26` versus actual `28` row-count sentence remains stale. |

### Reviewer-owned derivations

#### 1. EXIT-SCOPE (W-E0a/b): GREEN

Fresh source tracing yields the same closed universe as Round 7: thin LotE caller →
`AdaptiveStrictGatedRun.ts` → shadow/strict arming, poison, lesson/home tasks, setup anchor,
strict driver, journal, family registry/deck, manifest/planner, and the routed `auditRun` face.
The offline `adaptiveStrictDeck.ts` remains a real injection dependency. The projector and archive
reader remain offline judges with no routed import edge. Every routed/injection file is represented
in `scope.declared`, and no declared production/fixture file is absent from both graphs. W-E0a and
W-E0b are green.

#### 2. EXIT-INV / EXIT-EM / EXIT-MAP: GREEN

The current module source derives **35 contract exits** plus **4 separately recorded non-exits**;
the thin spec independently derives **8 exits**. Both artifact tables compare bidirectionally with
source, every exit names one producer, and the module/spec activation maps are exact 35/35 and 8/8
set matches. The four Round-7 false activations are replaced by tests that reach their precise
sites. The focused 98-test run covers EXIT-INV, the 73 named driver injections, EXIT-MAP record/path
cases, and both routed AST equalities; all passed. EXIT-INV, EXIT-EM, and EXIT-MAP are green.

#### 3. VERDICT-S / VERDICT-L (W-W7a/b/d): GREEN

Fresh direct inputs are the exact `deps.audit` array returned as `result.violations`, its `.length`,
the journal-produced `result.flavor`, `expect`, and rejection-only `formatViolations`. Provenance
and control inputs are the awaited `runGatedLote` binding and plain destructure; `page`; initialized
`seededCourse`/`manifest`/`lesson`; the mandatory score declaration; the null guard;
`MER5865_SHADOW_DIR` and `MER5865_POISON_SCREEN`; module exception/evidence paths; and the frozen
`GATED_RUN_DEFAULTS` dependency bundle. This equals evidence §1 + §4j bidirectionally.

The module returns the audit array by object identity. The thin spec contains exactly one
`violations.length === 0` assertion followed by exactly one accepted-flavor assertion, with no
filter, catch, fallback, override, or alternate green exit. Every licensing state remains dominated
by the nonzero-length failure. W-W7a/b/d and VERDICT-S/L are green.

#### 4. CONFORMANCE-MAP semantic conformance (W-U6/U8): GREEN

The map has **184** evidence entries plus `_meta`, all **28/28** contract §3 rows, all claimed
foundation witness IDs (with W-E2 expanded per site and W-DEL1/2/3 deferred under A1), and
`EXT-SCORE-TOTAL`. Fresh discovery resolved **250 reference occurrences / 233 unique identities /
0 unresolved**. Mutation parameters, expected loci, and observed loci remain present at each mapped
reference or its containing case. The only changed semantic surface is now conformant: W-E0a names
the current title, and the four routed rows map only to their exact-site tests. The rest of the map
and all implementation/test sources are unchanged from the Round-7 full semantic pass, and the
complete reviewer-env replay passed. W-U6 and W-U8 are green.

### Suite arithmetic and executions

| Check | Round-8 result |
|---|---|
| Frozen inventory | **271** identities |
| Additive step 4 | **337** identities; zero overlap with frozen |
| Justified removals | **12**; every removal exists in the union and carries a substantive justification; all four named replacement references resolve |
| EXPECTED-INV | **596 = 271 + 337 − 12** |
| Full current discovery | **599** |
| By-file never-commit exclusions | **3 identities** in exactly the two declared `mer5865-demo-*` files |
| Gated discovery | **596**; 0 missing, 0 unexplained extra versus EXPECTED-INV |
| Required eleven-spec replay, reviewer env, outside sandbox | **592 passed / 0 failed / 0 skipped**; 592 = 596 − 4 intentionally omitted `adaptive-authoring` identities |
| Writer replay stamp | **Honest:** it states **584 passed / 0 failed** under its reconstructed env and explicitly attributes the 8-test difference to dump-conditioned shadow-gate skips; it does not borrow the reviewer count |
| Focused adaptive-exit-inventory replay | **98 passed / 0 failed** |
| DIFF replay | Four swapped captures each report `in-scope=0`, `driver-evidence=65`, `diffs=22`; W-X1, inverse W-D2, and W-X3 pass |
| ACCEPT evidence | The same four captures audit clean and the finalization triples are pairwise distinct on section, revision, and attempt |
| TypeScript | Exactly the two fenced TS2339 `window.liveSocket` diagnostics at `CourseManagePO.ts:130` and `ProductsPO.ts:93`; no others |
| Whitespace | `git diff --check` clean before this append |

WIRE, DIFF, ACCEPT, W-W7a/b/d, and EXT-SCORE-TOTAL remain green on current source. The score rule
still validates a finite non-negative declaration, runs only on accepted snapshots, sums wire
evaluation scores, emits count-only facts on mismatch, and is anchored to archive
`custom.totalScore`; its seven mapped tests and the real-archive gates passed in the replay. No new
security or performance issue was found: no implementation changed since Round 7, the score scan
remains linear in the bounded journal, and no secret was read into or written to the repository.

### Predicate verdict

| Conjunct | Ruling | Basis |
|---|---|---|
| WIRE | **GREEN** | Entry/core/registry/manifest/archive wiring, exact verdict identity/shape, W-W7 closure, and the score-total extension are sound and replayed. |
| SUITE | **GREEN** | EXPECTED-INV equals gated discovery, the required 592-test reviewer replay has zero failures, and CONFORMANCE-MAP is structurally total, fully resolved, and semantically conformant. The remaining SF1 sentence is non-gating prose. |
| DIFF | **GREEN** | Four swapped captures have only the 22 closed retired-account presence deltas and exactly the 65-item retired inventory; inverse mutations pass. |
| ACCEPT | **GREEN** | Four runs are accepted/audit-clean and distinct on every identity component. |
| EXIT-TOTAL | **GREEN** | EXIT-SCOPE, EXIT-INV, EXIT-EM, and EXIT-MAP are all green; B13 and B14 are closed by exact current-source derivation and execution. |

`SWAP-GREEN = GREEN`.

`GATE-B-FOUNDATION = GREEN`.

`GATE-B-CLOSE` remains unclaimed and deferred with `DEL` under A1.

**Round-8 current summary: 0 BLOCKER, 1 SHOULD-FIX (SF1's single `26`→`28` prose correction), 0 NIT. GATE-B-FOUNDATION is GREEN.**
