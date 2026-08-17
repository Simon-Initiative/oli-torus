# MER-5865 unit 4c implementation review — strict driver

## Blocker

1. **The widget-button permit can be issued before the widget control exists, and the later click can still make the run green**

   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:158`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:698`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:703`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:1173`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:565`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:577`

   `widgetButtonReady()` treats any visible matching iframe as ready because `widgetFrame()`
   swallows the `.button-widget` ready-selector timeout and still returns a non-null
   `FrameLocator`. The driver then issues the `widget-button` permit. `clickWidgetButton()` calls
   the same helper and its Playwright click can auto-wait another eight seconds. Therefore this
   concrete ordering can audit green: iframe visible, control absent through the readiness wait,
   permit issued, control appears during the later click's auto-wait, click/evaluation/navigation
   succeed. The journal proves that it issued the permit before the request, but the premise that
   authorized issuance — control present — was false. This is a B4-STAMP/B4-EXIT-EM false green
   based on self-asserted causal evidence. The ready-selector wait must fail closed, or the
   readiness API must test the actual control without going through a helper that deliberately
   swallows selector absence.

2. **The catch-all abort path has no unique typed producer for reachable non-operation failures and loses the failing screen**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:226`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:239`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:344`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:440`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:500`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:549`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:577`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:602`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:615`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:638`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:652`

   The outer catch converts every exception into `aborted`, but records an `OperationFailure`
   only when the exception came through `fail()`. Direct journal stamp calls, planner calls,
   receipt construction, the navigation-plan sweep, logging, the last `lessonEnded()` read, and
   other direct awaits bypass `perform()`. Those exits return `failure: null`. A concrete valid-
   journal path is the caller-supplied `log` callback: it runs after a step's transition,
   quiescence and plan recording, but before the next identity fence. If it throws, the wrapper
   seals with that otherwise-valid step as the open last window. The oracle suppresses the open
   window's absence conclusions and reaches its generic `seal-without-evidence` fallback with
   `screenId: null`, not the screen whose log boundary failed. That violates B4-EXIT-EM's one
   producer rule and the checkpoint's same-screen attribution requirement. Malformed runtime
   `actions.results` is a second untyped path: the journal regards it as usable and the shared
   planner can throw before a plan record exists.

   The source-level producer is also not single-valued today: for example, the same
   `waitForDeckReady()` rejection becomes `identity-unresolved` through `runStep()` and
   `readiness-timeout` through registry `ready()`, while the same `widgetFrame()` null exit can
   become readiness, answer, or widget-button failure. A per-site injection can pass one call path
   while another emits a different producer. Use a private typed/sentinel exit for expected stop
   paths and rethrow unknown programming exceptions, or amend the closed union with an honest
   driver-internal failure carrying the active step/screen. In either design, each helper site and
   call edge needs one deterministic producer before seal.

## Should-fix

1. **The navigation plan sweep omits the normative first-screen pre-entry evaluation**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:356`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:601`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:183`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:369`

   `recordObservedPlans()` keeps only evaluations with `requestSeq > fence.seq`. Section 3.3 and
   the HANDOFF explicitly require LotE Cover's init-time evaluation, which occurs before the first
   identity fence, to belong to the first navigation window. The oracle requires a recorded plan
   for every usable owned navigation evaluation once that window closes. The scripted Cover emits
   its only evaluation from `clickWidgetButton()`, after the fence, so the positive test cannot see
   the omission. The first live LotE run with the required pre-entry evidence will report
   `plan-divergence/missing-recorded-plan`. The sweep needs the first window's journal-start lower
   bound (and the normal fence lower bound on later screens), with a regression test that actually
   injects a pre-fence evaluation.

2. **The “unconsumed extra evaluation” test never creates an extra evaluation**

   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:590`

   The test observes the two evaluations that the driver intentionally performs on `q:1` and
   asserts that two plans were recorded. It does not inject the claimed third evaluation, so it
   stays green if check-click steps later start sweeping unexpected evaluations. Add a genuinely
   unsolicited third evaluation and assert both that no plan is recorded for its seq and that the
   frozen audit rejects it at the causal-edge/cardinality locus.

3. **The positive harness bypasses the live recorder/boundary and makes request, response, and body completion atomic**

   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:68`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:246`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:280`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:416`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:432`

   The test is load-bearing for driver/oracle composition, but not for live-wire fidelity. It
   injects directly into `AdaptiveJournalCore`, settles every evaluation/save request and body in
   one clock callback, manually freezes the core, and never exercises `armStrictRun()`,
   `AdaptiveJournalRecorder`, correlation, `awaitFreeze()`, sealing, or detach. Its CAPI save also
   cannot represent “request after readback fence, response after check permit”; request and
   response receive adjacent seqs atomically. This common simplification hid blocker 1 and the
   pre-entry defect above. Keep the deterministic core test, but add an adapter-level routed-page
   case with independently delayed request/response/body events and the live handle's
   correlate/finish/snapshot path. At minimum the saved-barrier integration needs both response
   orders around the check permit.

4. **The free-form abort cause is outside the redacted-by-construction evidence model**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:241`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:658`

   `OperationFailure` is deliberately value-free, but `cause` copies arbitrary downstream error
   text. Playwright locator/call-log errors can embed selector text or values derived from the
   private answer manifest. No current consumer exists, but the later verdict/reporter boundary is
   precisely where this field is likely to be printed. Do not expose raw exception messages from
   answer/readback operations; keep them private or map them to closed redacted diagnostics before
   first live use.

5. **Several closed failure kinds describe a different operation than the one that failed**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:373`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:380`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:593`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:630`

   Check readiness versus click-no-effect is separated honestly. The other two challenged mappings
   are not: a transition that already happened but whose traffic never quiesces is not a
   `navigation-timeout`, and “gate primitive absent / video did not start / carousel did not
   advance” is not uniformly a `readiness-timeout`. `flashcard_flip_all` is a valid manifest gate
   but currently falls into “no driver primitive” and is still labelled readiness. These remain
   red, so they do not create a false green, but they make the closed evidence union and exit
   inventory semantically dishonest. Add/choose closed kinds for quiescence and gate execution, or
   document and test a narrower meaning that is true at every mapped site before those families'
   first live use.

## Nit

1. **Polling repeatedly clones the entire journal, including parsed payloads**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:273`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:313`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:333`

   Every 100 ms poll calls `records()`, which `structuredClone`s the full lesson log and its
   `partInputs`. The cost grows with both elapsed wait time and accumulated payload size. It is not
   a demonstrated gate defect, but an incremental “records after seq”/peek API would avoid the
   repeated copies while keeping the immutable public snapshot contract.

## Independent exit-site derivation (B4-EXIT-SCOPE / B4-EXIT-INV)

### Source universe

Included from the intended live entry and its failure-crossing call graph:

- `AdaptiveStrictDriver.ts`: `armStrictRun`, `driveStrictLesson`, and every nested helper.
- `AdaptiveJournal.ts`: stamp/read APIs used by the driver and the recorder
  attach/correlation/freeze/seal/detach/snapshot wrapper.
- `AdaptiveFamilyRegistry.ts`: resolver, ownership helpers, and all six currently registered
  entries.
- `AdaptiveDeckPO.ts`: only primitives reached by the driver or those six entries, plus their
  private helpers.
- `AdaptiveManifest.ts`: `resolveOperations` only.
- `AdaptiveTransitionPlanner.ts`: `planTransition` and `selectProcessedEvents`.

Excluded, bidirectionally:

- `AdaptiveOracle.ts`, `AdaptiveAttribution.ts`, and `AdaptiveShadowProjector.ts`: downstream of
  seal/freeze; they judge evidence but cannot make the driver exit before the boundary.
- `AdaptiveArchiveReader.ts`, `AdaptiveArchiveGates.ts`, and
  `AdaptivePredicateEquivalence.ts`: build-time manifest gates, not reachable from the run entry.
- `AdaptiveHappyPathTask.ts`, `AdaptiveEvaluationObserver.ts`, and
  `AdaptiveStrictContract.ts`: the old entry graph; the new driver imports none of them.
- `validateAdaptiveManifest` / `validateRouteCoverage` in `AdaptiveManifest.ts`: fixture/build
  preconditions that must fail loudly before the driver runs; the current scripted spec bypasses
  them, but they are not exits from `driveStrictLesson`.
- Other `AdaptiveDeckPO` methods (compat dropdown/FIB/grouping/ordering/etc.): no call edge from
  the six gate-B registry entries or this driver.
- `AdaptiveJournalRecorder`'s event callbacks: they can terminalize journal records, but their
  asynchronous callback exceptions do not reject an awaited driver call. The recorder lifecycle
  methods themselves remain included.
- `ScriptedDeck` and test helpers: test-only substitute graph, not the live gate source universe.

### Producer legend

- `OF(x)` — one `OperationFailure` of kind `x`.
- `JR(unusable)` — the already-emitted unusable/unresolved evaluation journal record.
- `RP(illegal)` — the already-emitted recorded plan the oracle judges illegal/unfulfilled.
- `JF(x)` / `FT` — journal finalization-failure / freeze-timeout record.
- `∅` — no admissible typed producer is guaranteed before the boundary/seal. A conditional
  `seal-without-evidence` oracle fallback is not an emitted producer and does not satisfy
  B4-EXIT-EM.
- Slash-separated producers mean the source site is currently multi-valued and therefore also
  fails the “ONE typed producer” rule.

| file:line | exit kind | the ONE typed producer that must be emitted before any boundary/seal |
|---|---|---|
| `AdaptiveStrictDriver.ts:106` | rejecting await/throw from recorder attach | `∅` (currently escapes before a handle exists) |
| `AdaptiveStrictDriver.ts:112-126` | catch branch + failure-path early return from correlation read/parse | `∅` guaranteed; `JF(uncorrelated)` occurs only if the caller continues through a captured finalization |
| `AdaptiveStrictDriver.ts:127-131` | rejecting await/throw from correlation stamp | `∅` |
| `AdaptiveStrictDriver.ts:138-142` | catch branch around freeze | `FT` only for the explicit accepted/quiescence timeout; otherwise `∅` |
| `AdaptiveStrictDriver.ts:140` | rejecting await without a local handler inside the catch branch (seal) | `∅` |
| `AdaptiveStrictDriver.ts:144` | rejecting await without a local handler (ordinary seal) | `∅` |
| `AdaptiveStrictDriver.ts:146-150` | finally/cleanup failure | `∅` (detach failure is swallowed) |
| `AdaptiveStrictDriver.ts:154` | throw from premature/failed snapshot | `∅` |
| `AdaptiveStrictDriver.ts:199-214` | throw before the outer try (options/manifest initialization) | `∅`; contrary to “one catch converts any throw” it propagates |
| `AdaptiveStrictDriver.ts:223` | throw from `fail` | `OF(the call site's closed kind)` |
| `AdaptiveStrictDriver.ts:228` | throw from `stop` | `JR(unusable)` / `RP(illegal)` — multi-valued at this source site |
| `AdaptiveStrictDriver.ts:239-242` | catch branch around `perform` | `OF(call-site kind)` — multi-valued at this source site |
| `AdaptiveStrictDriver.ts:248-254` | rejecting awaits without a local handler while polling quiescence | `∅` |
| `AdaptiveStrictDriver.ts:255` | failure-path early return from quiescence | `OF(navigation-timeout)` at both current callers |
| `AdaptiveStrictDriver.ts:273-283` | rejecting await/throw from journal clone/filter/sort | `∅` |
| `AdaptiveStrictDriver.ts:285-291` | failure-path early return on settled unusable evaluation | `JR(unusable)` |
| `AdaptiveStrictDriver.ts:293-300` | failure-path timeout return | `OF(check-click-no-effect)` / `OF(ack-no-effect)` — call-edge dependent |
| `AdaptiveStrictDriver.ts:301` | rejecting await without a local handler (poll sleep) | `∅` |
| `AdaptiveStrictDriver.ts:313-325` | rejecting await/throw from barrier journal scan | `∅` |
| `AdaptiveStrictDriver.ts:327-333` | barrier timeout throw | `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:335` | rejecting await without a local handler (poll sleep) | `∅` |
| `AdaptiveStrictDriver.ts:344-345` | throw while planning or before recording the plan | `∅` |
| `AdaptiveStrictDriver.ts:357-361` | throw while sweeping/recording navigation plans | `∅` |
| `AdaptiveStrictDriver.ts:373-377` | rejecting media await in undeclared-gate branch | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:380-390` | throw/reject/early return for declared gate | `OF(readiness-timeout)` (semantically dishonest for execution/unsupported-gate failures) |
| `AdaptiveStrictDriver.ts:399-405` | rejecting part-inventory await | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:411-419` | throw/reject from registry resolution/directive validation | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:420-424` | throw/failure return from ownership detection | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:425-427` | rejecting family-readiness await | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:428-430` | rejecting family-answer await | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:431-433` | rejecting family-readback await | `OF(readback-failed)` |
| `AdaptiveStrictDriver.ts:434` | throw from unwrapped saved-barrier derivation | `∅` |
| `AdaptiveStrictDriver.ts:440` | throw from unwrapped readback-fence issuance | `∅` |
| `AdaptiveStrictDriver.ts:442` | rejecting barrier await | `OF(barrier-timeout)` only for its own timeout; internal rejection is `∅` |
| `AdaptiveStrictDriver.ts:452` | throw while cloning manifest expectations | `∅` |
| `AdaptiveStrictDriver.ts:465-472` | rejecting transition/lesson-end await | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:491-495` | failure-path stop on `none` plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:497-499` | rejecting feedback-open await | `OF(feedback-never-opened)` |
| `AdaptiveStrictDriver.ts:500` | throw from unwrapped ack-permit issuance | `∅` |
| `AdaptiveStrictDriver.ts:502-504` | rejecting acknowledgement await | `OF(ack-no-effect)` |
| `AdaptiveStrictDriver.ts:513-518` | failure-path stop on illegal non-graded recheck | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:520` | rejecting/timeout second-evaluation await | `JR(unusable)` / `OF(ack-no-effect)` |
| `AdaptiveStrictDriver.ts:521` | throw before second-plan record | `∅` |
| `AdaptiveStrictDriver.ts:522-529` | failure-path stop on illegal second plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:534-535` | throw reading malformed scenario step outside `perform` | `∅` |
| `AdaptiveStrictDriver.ts:537-546` | throw/reject/early failure resolving identity | `OF(identity-unresolved)` |
| `AdaptiveStrictDriver.ts:549` | throw from entry-fence issuance | `∅` |
| `AdaptiveStrictDriver.ts:565-576` | throw/reject/false from widget readiness | `OF(widget-button-unavailable)` |
| `AdaptiveStrictDriver.ts:577` | throw from widget-permit issuance | `∅` |
| `AdaptiveStrictDriver.ts:579-589` | throw/reject/false from widget click | `OF(widget-button-unavailable)` |
| `AdaptiveStrictDriver.ts:590-592` | rejecting navigation await | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:593-600` | failure-path quiescence exit | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:601-602` | throw during plan sweep or log callback | `∅` |
| `AdaptiveStrictDriver.ts:606` | rejecting gate await | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:609` | rejecting answer await | one of answer/readiness/readback/barrier kinds; array-push failure is `∅` |
| `AdaptiveStrictDriver.ts:612-614` | rejecting check-readiness await | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:615` | throw from check-permit issuance | `∅` |
| `AdaptiveStrictDriver.ts:617-619` | rejecting check click | `OF(check-click-no-effect)` |
| `AdaptiveStrictDriver.ts:621-626` | rejecting/timeout first-evaluation await | `JR(unusable)` / `OF(check-click-no-effect)` |
| `AdaptiveStrictDriver.ts:627-628` | throw/reject while planning/following transition | typed only in the individually wrapped subpaths; otherwise `∅` |
| `AdaptiveStrictDriver.ts:630-637` | failure-path quiescence exit | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:638-641` | throw from log callback | `∅` |
| `AdaptiveStrictDriver.ts:646` | rejecting `runStep` await crossing the outer boundary | `OF(pending kind)` only when an inner `fail` set it; otherwise `∅` |
| `AdaptiveStrictDriver.ts:650` | rejecting final lesson-end read / throw from lesson-end stamp | `∅` |
| `AdaptiveStrictDriver.ts:652-659` | outer error boundary | emits `OF(pending)` only; `pending === null` returns an unproduced abort |
| `AdaptiveJournal.ts:208-215` | throw from entry-fence issuance | `∅` at the direct driver call |
| `AdaptiveJournal.ts:224-233` | throw from permit issuance | `∅` at direct driver calls |
| `AdaptiveJournal.ts:241-250` | throw from readback-fence issuance | `∅` at the direct driver call |
| `AdaptiveJournal.ts:261-267` | throw from lesson-end stamp | `∅` at the direct driver call |
| `AdaptiveJournal.ts:333-335` | throw from structured journal clone | `∅` in unwrapped polling/sweep paths |
| `AdaptiveJournal.ts:560-581` | throw from snapshot | `∅` |
| `AdaptiveJournal.ts:703-708` | malformed runtime actions accepted as usable, later planner throw | required `JR(unusable)`; current producer is `∅` |
| `AdaptiveJournal.ts:785-791` | throw from recorder attach | `∅` |
| `AdaptiveJournal.ts:816-902` | throw/reject/catch boundary during freeze | `JF(reason)` or `FT` only on specified lifecycle branches; unexpected rejection is `∅` |
| `AdaptiveJournal.ts:906-912` | rejecting seal await / seal state throw | `∅` |
| `AdaptiveJournal.ts:793-798` | finally/cleanup failure from detach | `∅` (caller swallows it) |
| `AdaptiveFamilyRegistry.ts:61-72` | throw from required-field / part-id validation | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:80-102` | throw or failure return from Janus ownership | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:109-131` | throw or failure return from CAPI ownership/version check | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:157-162` | rejecting await/throw from CAPI readiness | `OF(readiness-timeout)` |
| `AdaptiveFamilyRegistry.ts:187-190,225-228,268-272,298-306,326-336,349-364` | directive-validation throws | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:193-195,231-233,275-277` | rejecting deck-readiness await | `OF(readiness-timeout)` |
| `AdaptiveFamilyRegistry.ts:196-200,234-243,278-281,307-319,338-344,366-377` | rejecting answer await / failure return | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:201-207,245-252,282-286` | rejecting readback await / mismatch throw | `OF(readback-failed)` |
| `AdaptiveFamilyRegistry.ts:399-436` | registry-resolution throw | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:47-58` | rejecting attachment await; footer catch is non-failing | `OF(identity-unresolved)` / `OF(readiness-timeout)` — same site, two producers |
| `AdaptiveDeckPO.ts:147-155` | catch branch rethrow from check readiness | `OF(readiness-timeout)` |
| `AdaptiveDeckPO.ts:158-160` | failure-path false from widget readiness | `OF(widget-button-unavailable)`; currently false readiness can also return true (blocker 1) |
| `AdaptiveDeckPO.ts:163-169` | explicit throw or rejecting click await | `OF(check-click-no-effect)` |
| `AdaptiveDeckPO.ts:172-178` | explicit throw or rejecting click await | `OF(ack-no-effect)` |
| `AdaptiveDeckPO.ts:180-188` | catch branch rethrow from feedback wait | `OF(feedback-never-opened)` |
| `AdaptiveDeckPO.ts:191-198` | timeout throw / rejecting poll await | `OF(navigation-timeout)` |
| `AdaptiveDeckPO.ts:201-210` | timeout throw / rejecting poll await | `OF(navigation-timeout)` |
| `AdaptiveDeckPO.ts:258-288` | caught page-eval failure followed by identity throw | `OF(identity-unresolved)` |
| `AdaptiveDeckPO.ts:296-320` | catch branch returns empty inventory | `OF(answer-failed)` only when a required owner is consequently absent; otherwise no producer |
| `AdaptiveDeckPO.ts:440-474` | failure-path false from MCQ visibility/click/readback | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:572-585` | rejecting count await / swallowed item read yielding wrong count | `OF(readback-failed)` |
| `AdaptiveDeckPO.ts:589-595` | failure-path false or rejecting fill await | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:599-603` | catch branch returns empty readback | `OF(readback-failed)` |
| `AdaptiveDeckPO.ts:698-709` | failure-path null / swallowed selector timeout / rejecting settle await | `OF(readiness-timeout)` / `OF(answer-failed)` / `OF(widget-button-unavailable)` — multi-valued, and selector absence currently emits none |
| `AdaptiveDeckPO.ts:772-794` | rejecting count await or click-failure early break | `OF(readiness-timeout)` for a declared gate; undeclared-media path can emit none |
| `AdaptiveDeckPO.ts:797-836` | rejecting count await or caught playback/ended failure | `OF(readiness-timeout)` for a declared gate; undeclared-media path can emit none |
| `AdaptiveDeckPO.ts:847-883` | throw after failed drag / finally cleanup failure | `OF(answer-failed)` for the drag; viewport restore failure is swallowed |
| `AdaptiveDeckPO.ts:912-944` | failure-path false or rejecting verified drag | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:993-1034` | missing-widget / retry-exhaustion throw | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:1053-1166` | failure-path false, timeout throw, or registration throw | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:1173-1184` | failure-path false from missing frame/click rejection | `OF(widget-button-unavailable)` |
| `AdaptiveManifest.ts:631-637` | no explicit exit; malformed non-array operations can throw before a producer | `∅` for runtime-shape faults (fixture validation is the intended precondition) |
| `AdaptiveTransitionPlanner.ts:61-89` | throw on malformed runtime `actions.results` shape | required `JR(unusable)`; current producer is `∅` |

This is not yet a closable B4-EXIT-INV set: every `∅` and every slash-separated row must be
resolved before the writer's inventory can equal a reviewer-derived set with exactly one producer
per site.

## Design-call conclusions

### a. Aborts as data

Unsound as implemented. Expected operation failures can be data, but the single catch does not
distinguish them from programmer/runtime-shape defects and it does not actually cover setup before
line 644. Correct sealing prevents a clean sealed audit via the oracle's
`seal-without-evidence` fallback, so the ordinary `failure: null` path is fail-red rather than
green. It still violates EXIT-EM and loses screen attribution, and an unknown exception must not be
presented as if it were one of the closed operation outcomes.

### b. One typed producer per exit

A journal-side producer is acceptable only when it was already emitted, is typed, and is unique to
that exact exit: the settled unusable evaluation and an already-recorded illegal plan satisfy that
principle at their individual call sites. `stop()` as a shared helper does not itself have one
producer, and the direct/unwrapped exits in the table have none. Readiness versus check-click is
honest; quiescence-as-navigation and gate-execution-as-readiness are not.

### c. Receipt expectations

The receipt identity check is intentionally tautological in the narrow sense that the driver
copies the manifest and the oracle compares the copy back to the same manifest. The run verdict is
not tautological: for local steps, `auditGradedStep` compares those archive-gated expectations with
the journal's actual evaluation `partInputs`; cross-screen steps compare them with committed prior
state and the checking evaluation. B4-MAN/B4-PRED provide the independent source leg. The registry's
`expectedPayload()` is therefore not needed by this driver now and remains correctly reserved for
later computed/cross-screen work.

### d. Check sweep versus navigation sweep

The split is sound in principle. Check-click evaluations have explicit permit edges, and an extra
unswept evaluation is still rejected by causal-edge/cardinality/plan-inventory checks. Navigation
evaluations have no click permit and must all be plan-recorded for the whole-sequence replay. The
navigation sweep does not launder extras: the oracle independently rejects illegal sequence sizes,
rotation shapes, and unused/mismatched plans. Its defect is the omitted pre-entry lower bound, not
laundering.

## Harness fidelity conclusions

The positive zero-violation test is load-bearing for composition: visits, journal-issued stamps,
registry calls, recorded plans, receipts, operation failures, and the real `auditRun` must agree.
It is not independent proof of the manifest or planner: driver and oracle intentionally share the
manifest and `planTransition`, with independence supplied elsewhere by B4-MAN/B4-PRED and the
product-source planner contract. Its weakest live gaps are the no-op readiness methods, direct core
ingestion, atomic request/response/body settlement, absence of pre-entry traffic, and bypass of the
real recorder/correlation/freeze/seal lifecycle. The deterministic clock therefore hides recorder
races and the two-sided CAPI save race even though it makes its represented order deterministic.

## Type moves, deletion sweep, and contract resolution

- `CheckActions` moved byte-for-byte in shape from `AdaptiveStrictContract.ts` into the journal's
  parsing domain. No changed or committed core file imports the doomed contract through this type.
- `CapturedLedgerEntry` intentionally narrows the deserialized replay shape to the fields
  `compareProjections()` consumes. Extra legacy JSON fields remain harmless, and the projector no
  longer imports the doomed ledger type.
- The only non-old-core references found outside docs/reviews are the current LotE/old strict tests
  and the two Real Chem compat specs. No new core file references any doomed filename.

Contract §1 stage 2 is internally inconsistent with the staged migration: deleting
`AdaptiveHappyPathTask.ts` breaks both compat specs before steps 7-8. The right implementation is to
extract `completeAdaptiveHappyPath` and `LessonAnswers` into a compat-owned module, switch the two
spec imports without changing behavior, then delete the three strict files at gate B. That move is
not currently licensed by the contract's closed gate-B scope/delta list, so §1/§6 must explicitly
add the behavior-preserving compat extraction/import switch (and its regression witness); merely
moving code without amending the closed delta would make DIFF/DEL green under an unauthorized
change. Compat deletion remains steps 9-10.

## Verification

- `adaptive-strict-run.spec.ts`: **12 passed / 0 failed**.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on all five requested files: clean.
- Prettier check on all five requested files: clean (existing ignored-plugin-option warnings).
- `git diff --check` on the three tracked modifications: clean.

Security review found the free-form `cause` issue above and no added authorization, credential, or
injection surface. Performance review found only the repeated full-journal clone noted as a nit.

## Summary

2 blockers, 5 should-fix, 1 nit. Verdict: **BLOCKED**.

## Round 2

Fresh-eyes review of the current seven-file working-tree material, against the amended §3.2
failure union and the unchanged B4-EXIT-SCOPE / B4-EXIT-INV / B4-EXIT-EM rules. Round 1 remains
above as the historical record; line references in this section are to the round-2 working tree.

### Blocker

1. **The blanket `stopped` exemption still has a path with no screen-attributed producer**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:249`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:542`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:685`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:243`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:748`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1606`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:847`

   The exemption is sound for the unusable-evaluation stop and the two plans the oracle judges
   positively illegal (`none`, or a non-navigating second plan). It is not sound for the stop at
   `followPlan()`'s non-graded recheck guard. A content screen can return a first evaluation whose
   plan is `feedback {ack: recheck}`. The driver records that plan, opens and acknowledges the
   feedback, sets `stopped = true`, and throws without an `OperationFailure`.

   The recorded first plan is not itself illegal to `auditTransitions()`: the oracle reports the
   missing second evaluation only under `fullAudit`. The failure seal leaves the current (last)
   visit window open, so `windowClosed()` is false; content cardinality and the missing-recheck
   obligation are both suppressed. If the recheck request starts after the seal cutoff (or never
   starts), the sealed audit reaches only `seal-without-evidence`, whose `screenId` is null. Thus
   this live failure can be reported at the run rather than at the content screen that violated
   §3.5. This rejects the fold's blanket claim that every `stop()` site already has a pinned
   journal-side producer. Emit a typed screen-bearing failure for this guard, or add an ungated
   positive oracle violation for the recorded content/recheck combination before retaining the
   exemption. The site needs a regression test that seals before any recheck request enters the
   audited set and asserts exactly one producer naming the content screen.

### Should-fix

1. **The prospective exit universe is still not closable: fixture lifecycle exits have no typed producer and several helper sites remain multi-valued**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:104`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:111`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:134`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:154`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:47`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:163`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:724`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:798`
   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:823`

   The new catch closes the direct, post-visit `driveStrictLesson()` `∅` rows with
   `driver-internal`, but it does not cover `armStrictRun()`: attach can throw before a handle
   exists; correlation can return false or have its stamp rejected; an unexpected freeze failure
   can be converted to a seal carrying no typed record; seal and snapshot can themselves throw.
   There is no live caller yet, so accepting the routed-page test's scheduling deferral to 4d is
   reasonable, but those rows remain unresolved inputs to the next unit rather than closed round-1
   rows.

   The one-producer-per-source-site problem also remains. For example, the same
   `waitForDeckReady()` rejection becomes `identity-unresolved` on the identity call edge and
   `readiness-timeout` through a Janus registry `ready()` call. The same
   `widgetControlReady()` failure becomes `widget-button-unavailable` for navigation and
   `readiness-timeout` for CAPI answer readiness. `widgetFrame()` failure is
   `widget-button-unavailable` through `clickWidgetButton()` and `answer-failed` through CAPI
   answer primitives. The media helpers are `readiness-timeout` in the undeclared sweep and
   `gate-unsatisfied` when called for a declared gate. Under the contract's identity
   `file:line + exit kind`, these are still multi-valued helper sites even though every call edge
   is red. Before B4-EXIT-INV is frozen, either make call-edge identity an explicit contract
   amendment or give each reachable helper failure one pinned producer.

2. **The browser regression tests exercise the new primitive, not the driver-visible widget readiness method**

   `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:183`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:777`
   `assets/automation/tests/torus/student_delivery/adaptive-strict-run.spec.ts:786`

   The production fix is correct: `widgetButtonReady()` delegates to the fail-closed
   `widgetControlReady()` and the permit follows that result. But both real-page tests call
   `widgetControlReady()` directly. Replacing `widgetButtonReady()` with the old
   `widgetFrame() !== null` behavior would leave both tests green, and the scripted driver uses
   its own fake `widgetButtonReady()`. Call the public driver-visible method in at least the
   absent-control case (and preferably both cases) so the exact blocker-1 wiring is load-bearing.

3. **The “every operation-failure union member” matrix still enumerates only the old ten kinds**

   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:40`
   `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:1452`

   The amended union now has thirteen members, but the deterministic §8 test omits
   `gate-unsatisfied`, `traffic-unsettled`, and `driver-internal`. The generic oracle loop maps
   all three correctly today, so this is not a current false green. The claimed exhaustive matrix
   is nevertheless stale, and a filter or special case affecting only a new kind would survive
   it. Derive the test list in an independently fixed way and include all thirteen; the later
   per-site EXIT-EM matrix should then prove their concrete producers separately.

4. **The journal hardening validates only the outer `results` array, while downstream planners assume its nested members are objects and action lists are arrays**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:703`
   `assets/automation/src/systems/torus/tasks/AdaptiveTransitionPlanner.ts:41`
   `assets/automation/src/systems/torus/tasks/AdaptiveTransitionPlanner.ts:48`
   `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:555`
   `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:151`

   The precise round-1 non-array path is closed: `results: {}` now leaves the record unresolved.
   But `results: [null]`, or a result whose `params.actions` is non-array, still passes
   `wellFormed`; `navigationActions()` then dereferences or iterates the malformed nested value.
   In the driver this becomes `driver-internal` and stays red, but `auditRun()` or shadow replay
   can throw instead of returning a typed violation. The current journal test covers absent
   actions, non-2xx, failed, and outstanding responses, not the new non-array case or these nested
   variants. Either validate the complete planner-consumed shape at the journal boundary or make
   the planner total over unknown wire input, and pin the malformed shapes in the journal plus
   shadow/oracle path.

### Nit

1. **The repeated full-journal clone remains, and its deferral is acceptable**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:302`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:342`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:333`

   Polling still clones all records and parsed payloads. This remains avoidable work, but there is
   no measured gate impact and changing the journal read API during the correctness work would
   broaden the unit. Retain it as a performance follow-up unless live acceptance runs show a
   material cost.

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

This is a fresh derivation. It is deliberately an input to the next unit, not the writer's missing
inventory artifact. Because 4d has not introduced the real switched spec/fixture, final
B4-EXIT-SCOPE closure is impossible in this round; the intended live-handle segment is included
prospectively so it cannot disappear from the later bidirectional comparison.

#### Source universe

Included:

- `AdaptiveStrictDriver.ts`: `armStrictRun`, `driveStrictLesson`, and every nested helper.
- `AdaptiveJournal.ts`: core stamp/read methods and the recorder lifecycle called by the handle.
- `AdaptiveFamilyRegistry.ts`: resolver, ownership helpers, and the six registered entries.
- `AdaptiveDeckPO.ts`: every primitive reachable from the driver or those six entries, including
  their private helper paths.
- `AdaptiveManifest.ts`: `resolveOperations`.
- `AdaptiveTransitionPlanner.ts`: `planTransition` and `selectProcessedEvents`.

Excluded, bidirectionally:

- `AdaptiveOracle.ts`, `AdaptiveAttribution.ts`, and `AdaptiveShadowProjector.ts`: downstream
  judges, not pre-boundary exit producers. They were still read to verify each proposed producer
  actually maps to a positive, screen-attributed violation.
- `AdaptiveArchiveReader.ts`, `AdaptiveArchiveGates.ts`, and
  `AdaptivePredicateEquivalence.ts`: build-time validation, not reachable from the walk.
- The old walker/observer/contract: no new-core import edge; their remaining spec consumers belong
  to B4-DEL/compat decisions outside this review.
- `validateAdaptiveManifest` / `validateRouteCoverage`: intended fixture/build preconditions. The
  final 4d entry must demonstrate this edge before invalid-manifest initialization can be excluded
  from EXIT-SCOPE rather than merely assumed away.
- Test-only `ScriptedDeck` and helpers: substitute graph, not the live source universe.
- Recorder event callbacks: they mutate/terminalize the journal asynchronously; their exceptions
  do not reject an awaited driver call. Recorder attach/freeze/seal/detach/snapshot remain in.

#### Producer legend

- `OF(x)` — exactly one driver `OperationFailure` of kind `x`.
- `OF(DI)` — boundary-produced `driver-internal` for the active visited screen.
- `OF(IU)` — boundary-produced `identity-unresolved`, `screenId: null`, attributed by scenario
  position because no visit exists.
- `JR(unusable)` — the already-terminal unusable/unresolved evaluation record.
- `RP(illegal)` — the already-recorded plan that the oracle positively rejects on an open seal.
- `JF/FT` — journal finalization-failure / freeze-timeout evidence.
- `∅` — no unique typed producer is guaranteed before seal/boundary. The conditional
  `seal-without-evidence` fallback is not an emitted producer and is screenless.
- Slash-separated producers are still multi-valued at the source site.

| file:line | exit kind | pinned producer in the current tree |
|---|---|---|
| `AdaptiveStrictDriver.ts:106` | attach throw before handle | `∅` (prospective 4d fixture edge) |
| `AdaptiveStrictDriver.ts:112-131` | correlation catch/false return or correlation-stamp throw | `∅` |
| `AdaptiveStrictDriver.ts:138-145` | freeze catch; rejecting seal in either branch | `FT` only on the named accepted/quiescence timeout; otherwise `∅` |
| `AdaptiveStrictDriver.ts:146-151` | cleanup failure | swallowed, no exit; must be justified as an exclusion in the final inventory |
| `AdaptiveStrictDriver.ts:154` | premature/failed snapshot throw | `∅` |
| `AdaptiveStrictDriver.ts:199-219` | initialization throw before the outer try | `∅` unless 4d proves validated, typed inputs as an entry precondition |
| `AdaptiveStrictDriver.ts:245-247` | `fail` throw | `OF(call-site kind)` |
| `AdaptiveStrictDriver.ts:255-258` from `:316` | stop on terminal unusable evaluation | `JR(unusable)` |
| `AdaptiveStrictDriver.ts:255-258` from `:522` | stop on first `none` plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:255-258` from `:543` | stop on content/non-graded recheck | `∅` — blocker above |
| `AdaptiveStrictDriver.ts:255-258` from `:552` | stop on illegal second plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:267-271` | `perform` catch | `OF(call-site kind)` |
| `AdaptiveStrictDriver.ts:274-285` | journal/sleep rejection while quiescing | `OF(DI)` after a visit; false deadline return is `OF(traffic-unsettled)` at both callers |
| `AdaptiveStrictDriver.ts:302-330` | journal clone/filter/sleep rejection; unusable record; timeout | `OF(DI)` / `JR(unusable)` / `OF(check-click-no-effect or ack-no-effect)` by call edge |
| `AdaptiveStrictDriver.ts:342-364` | barrier scan/sleep rejection or deadline | `OF(DI)` / `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:368-390` | planner/record/sweep throw | `OF(DI)` |
| `AdaptiveStrictDriver.ts:398-405` | undeclared media sweep rejection | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:408-419` | declared gate throw/rejection/unsupported gate | `OF(gate-unsatisfied)` |
| `AdaptiveStrictDriver.ts:428-462` | inventory/resolution/detect/readiness/answer/readback failure | `OF(answer-failed)` / `OF(readiness-timeout)` / `OF(readback-failed)` at the named call sites |
| `AdaptiveStrictDriver.ts:463-484` | saved-barrier derivation, receipt clone, readback-fence, or barrier helper throw | `OF(DI)` except the helper's `OF(barrier-timeout)` deadline |
| `AdaptiveStrictDriver.ts:493-501` | terminal/navigation wait rejection | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:520-559` | plan stop, feedback wait, ack stamp/click, second evaluation/plan/transition | the four site-specific rows above; otherwise `OF(feedback-never-opened)`, `OF(ack-no-effect)`, `OF(navigation-timeout)`, or `OF(DI)` |
| `AdaptiveStrictDriver.ts:563-575` | malformed step access or identity operation failure | `OF(IU)` |
| `AdaptiveStrictDriver.ts:578-587` | entry-fence/visit-stamp failure before a visit exists | `OF(IU)` by the contested pre-visit rule |
| `AdaptiveStrictDriver.ts:589-592` | operation resolution/filter failure after visit | `OF(DI)` |
| `AdaptiveStrictDriver.ts:597-624` | widget readiness/click/navigation failure | `OF(widget-button-unavailable)` / `OF(navigation-timeout)`; permit-stamp failure is `OF(DI)` |
| `AdaptiveStrictDriver.ts:625-632` | transition quiescence or navigation plan sweep failure | `OF(traffic-unsettled)` / `OF(DI)` |
| `AdaptiveStrictDriver.ts:636-658` | gates/answer/check/evaluation/plan/follow failure | nested site producer; direct check-permit/plan faults become `OF(DI)` |
| `AdaptiveStrictDriver.ts:660-666` | post-transition quiescence or log sink | `OF(traffic-unsettled)`; log exceptions are swallowed and are not exits |
| `AdaptiveStrictDriver.ts:677` | final lesson-end read or lesson-end stamp throw | `OF(DI)` on the last visited screen (`OF(IU)` only for an invalid empty route) |
| `AdaptiveStrictDriver.ts:679-702` | outer error boundary | preserves pending `OF(x)`; otherwise `OF(DI)` after visit or `OF(IU)` before visit; suppresses a second record when `stopped` |
| `AdaptiveJournal.ts:208-250` | fence/permit/readback-fence refusal | `OF(IU)` for entry fence; otherwise `OF(DI)` |
| `AdaptiveJournal.ts:261-267` | lesson-end stamp refusal | `OF(DI)` |
| `AdaptiveJournal.ts:333-335` | record clone throw | `OF(DI)` in every driver polling/sweep call |
| `AdaptiveJournal.ts:703-720` | malformed evaluation response | non-array results: `JR(unusable)`; malformed nested array members: planner throw / `OF(DI)` (should-fix above) |
| `AdaptiveJournal.ts:792-798` | recorder attach throw | `∅` through `armStrictRun` |
| `AdaptiveJournal.ts:823-909` | freeze rejection | `JF/FT` on specified lifecycle branches; unexpected rejection reaches handle seal with no guaranteed typed producer |
| `AdaptiveJournal.ts:913-920` | seal begin/wait/finish rejection | `∅` through the current handle |
| `AdaptiveFamilyRegistry.ts:61-131` | directive/ownership/version throw | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:157-165` | CAPI readiness false/rejection | `OF(readiness-timeout)` at registry call; same DeckPO source is multi-valued with widget readiness |
| `AdaptiveFamilyRegistry.ts:189-382` | per-family validation/readiness/answer/readback failure | `OF(answer-failed)` / `OF(readiness-timeout)` / `OF(readback-failed)` by operation call site |
| `AdaptiveFamilyRegistry.ts:402-439` | resolution throw | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:47-57` | deck readiness rejection | `OF(IU)` / `OF(readiness-timeout)` by call edge; multi-valued |
| `AdaptiveDeckPO.ts:147-155` | check readiness rejection | `OF(readiness-timeout)` |
| `AdaptiveDeckPO.ts:163-180` | widget-control absent/timeout | `OF(widget-button-unavailable)` / `OF(readiness-timeout)`; multi-valued |
| `AdaptiveDeckPO.ts:189-235` | strict check/ack/feedback/navigation failure | the matching check/ack/feedback/navigation `OF` kind |
| `AdaptiveDeckPO.ts:284-315` | strict identity failure | `OF(IU)` when it crosses; transition polling catches it locally |
| `AdaptiveDeckPO.ts:322-346` | inventory catch returning empty | `OF(answer-failed)` only when ownership then fails; otherwise not an exit |
| `AdaptiveDeckPO.ts:466-628` | MCQ/text answer or readback failure | `OF(answer-failed)` / `OF(readback-failed)` |
| `AdaptiveDeckPO.ts:724-735` | widget frame absent / swallowed ready timeout | `OF(answer-failed)` / `OF(widget-button-unavailable)` by consumer; multi-valued; the swallowed timeout is not itself an exit |
| `AdaptiveDeckPO.ts:798-863` | carousel/video throw or zero result | undeclared sweep `OF(readiness-timeout)` on rejection; declared gate `OF(gate-unsatisfied)`; multi-valued |
| `AdaptiveDeckPO.ts:938-969,1019-1060,1079-1191` | current CAPI answer failure | `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:1199-1210` | widget click false/rejection | `OF(widget-button-unavailable)` |
| `AdaptiveManifest.ts:631-637` | operation resolution runtime-shape throw | `OF(DI)` after visit; intended validation remains a fixture precondition |
| `AdaptiveTransitionPlanner.ts:41-89` | planner throw | `OF(DI)` unless the journal rejects the wire shape first; an already-recorded legal return is judged normally |

The current set is therefore improved but not closed: the content/recheck `∅` is material, the
prospective fixture lifecycle retains `∅` rows, and several helper sites still have more than one
producer under the contract's present site identity.

### Fold attacks and contested rulings

- **`stopped` exemption:** rejected as a blanket rule. It is sound at three call sites and unsound
  at the content/non-graded recheck site described in the blocker.
- **`activeScreenId`:** after a visit is stamped it always names that visit's screen in the paths
  reviewed. Resetting it before the next identity read prevents a transition fault from being
  mislabeled as the previous screen. No wrong-screen assignment found in the typed boundary.
- **`driver-internal`:** honest for direct post-visit helper/stamp/programming faults. It does not
  mask an operation-specific failure because `perform()` preserves the first named kind. The
  nested malformed-results case should be rejected at the journal boundary, but it remains red.
- **Fail-closed widget readiness:** blocker 1's concrete ordering is closed. The real control must
  be visible before `widgetButtonReady()` returns; Playwright click auto-wait can no longer rescue
  a control that was absent throughout the readiness wait. A later disappear/reappear race is a
  normal non-atomic DOM observation bound, not the former swallowed-timeout defect.
- **Undeclared media as `readiness-timeout`:** accepted. In that branch the sweep is preparatory
  work for making the screen's check path available; a declared media obligation uses the new
  `gate-unsatisfied` kind. The distinction is now honest.
- **Pre-visit `identity-unresolved`:** accepted as the current representable rule. Even an entry
  fence refusal occurs before a visit exists; emitting a resolved screen-bearing failure would be
  contradictory under the oracle's visit-anchored validation. The expected scenario position
  still gives deterministic screen reporting.
- **No record at `stop()` sites:** acceptable only when the existing journal/plan is already a
  positive, screen-level finding under the actual sealed-window scope. It is not true merely
  because some evidence object exists.

### Deferral rulings and harness fidelity

- The scripted harness now separates save request from response and proves the check permit waits
  for the save to commit. That closes the round-1 saved-barrier half.
- Deferring the routed-page `armStrictRun` + real-recorder + correlation + freeze/seal/detach case
  to the unit that introduces its first live caller is acceptable **as scheduling**, provided it
  lands before that caller is gate evidence. It does not retroactively resolve the prospective
  lifecycle `∅` rows listed above.
- The deterministic core test remains load-bearing for driver/oracle composition, not independent
  proof of planner or manifest semantics. CORE-L/REG-L mutations through the switched live entry
  remain correctly owned by gate B.
- The full-journal clone is correctly deferred as a performance nit.

### Round-1 disposition

| Round-1 item | Round-2 disposition |
|---|---|
| Blocker 1 — swallowed widget readiness | **Closed in code.** The failure class was also fixed in CAPI registry readiness. The public-method regression gap is round-2 should-fix 2. |
| Blocker 2 — untyped exits / lost screen | **Partially folded; not closed.** Direct post-visit faults now become `driver-internal`, cause text is closed, and malformed non-array results no longer reach the planner. The `stopped` content/recheck path remains material; prospective lifecycle `∅` and multi-valued helper sites remain inventory work. |
| Should-fix 1 — missing pre-entry sweep | **Closed.** First-screen lower bound is journal start and the test injects a genuine pre-fence evaluation. |
| Should-fix 2 — hollow unsolicited-evaluation test | **Closed.** A real second evaluation is present, left unrecorded, and rejected by the audit. |
| Should-fix 3 — harness bypasses recorder / atomic save | **Partially folded.** Save request/response ordering is now faithful. Routed recorder/fixture integration is accepted as a 4d deferral, not waived. |
| Should-fix 4 — free-form cause | **Closed.** Only driver-authored strings leave the boundary. |
| Should-fix 5 — dishonest failure kinds | **Closed for the challenged live meanings.** `gate-unsatisfied` and `traffic-unsettled` are honest; the two contested mappings are accepted above. The exhaustive kind matrix is stale (round-2 should-fix 3). |
| Nit — repeated full journal clone | **Open, correctly deferred.** Counted again as a non-blocking nit. |

### Type moves and consumer checks

- `CheckActions` remains byte-for-byte equivalent to the old walker type and now lives with the
  parser that owns it.
- `CapturedLedgerEntry` contains every field read by `compareProjections`; extra fields in legacy
  JSON captures remain structurally harmless.
- Exact non-array `actions.results` hardening makes shadow projection skip the plan rather than
  changing the valid-capture path. Archive gates have no journal dependency. The public strict
  subset passed with the private archive/capture cases skipped for absent environment variables;
  the writer's private replay result remains the evidence for those nine cases.
- No new core file imports any of the three doomed walker filenames. Remaining references are the
  old walker/tests and the two compat specs already owned by B4-DEL/the human contract question.

### Verification

- Requested nine-file Playwright subset: **348 passed / 0 failed / 9 skipped** without the private
  archive/capture environment (357 discovered). The dedicated new driver spec: **18 passed / 0
  failed**.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on all seven review files: clean.
- Prettier check on all seven review files: clean (existing ignored-plugin-option warnings).
- `git diff --check`: clean before appending this round.

Security review found no new answer-value, credential, injection, or authorization exposure; the
closed cause fold is sound. Performance review found only the retained full-journal clone nit.

### Summary

1 blocker, 4 should-fix, 1 nit. Verdict: **BLOCKED**.

## Round 3

Fresh-eyes review of the full current ten-file material at base
`df8c85b115719511e1262d8ec821f9874e7f6cc7`, including the shared planner's oracle and shadow
consumers. The round-2 content/recheck blocker is closed, but the malformed-wire fold creates a
different live and replay false-green path.

### Blocker

1. **Malformed nested result/action shapes are normalized into the navigation rotation's legal
   `none` plan, so a malformed live response or capture can audit green**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:703`
   `assets/automation/src/systems/torus/tasks/AdaptiveTransitionPlanner.ts:47`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:914`
   `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:647`
   `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:670`
   `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:2185`

   The journal rejects only a non-array outer `actions.results`. It still resolves
   `actions: {correct: false, results: [null]}`, a result whose `params.actions` is an object or
   string, and an action list containing only non-objects as a usable evaluation. The new planner
   then removes the malformed members and returns `{kind: 'none'}`.

   `none` is deliberately legal for the first, incorrect evaluation of the measured navigation
   rotation when a causal 2xx mint and a correct navigating second evaluation follow. The driver
   records that normalized plan, the oracle replays the same planner, and the shadow projector
   consumes the same audit. Consequently the malformed first response can satisfy all three
   consumers: no `evaluation-unusable`, no `navigation-sequence`, and no `plan-divergence`. This is
   common-mode agreement over a malformed shared input, not merely a loss of diagnostic detail.

   The new seven-shape test protects the masking by asserting `none`; it never runs those shapes
   through the legal-rotation branch or `evaluateGreenCapture`. The journal tests cover only the
   outer object/scalar cases that are already rejected.

   Keep the planner total, but preserve invalidity. Live classification must reject the complete
   planner-consumed shape, and captured dumps need an independent audit/deserialization check that
   maps malformed nested members to a typed positive violation rather than to the measured empty
   action list. Add the killing witness: an incorrect navigation evaluation with malformed nested
   results, a causal mint, and a correct navigating second evaluation must make both `auditRun`
   and shadow evaluation red.

   **Class:** blocker — this can preserve a false green on both the live driver path and archived
   shadow replay.

### Should-fix

None.

### Nit

1. **Repeated whole-journal cloning remains deferred**

   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:302`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:342`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:333`

   Polling still clones every record and parsed body. No gate-impact measurement was supplied and
   this round does not change the cost, so the round-2 deferral remains proportionate.

### Round-2 fold attacks and disposition

| Round-2 item | Round-3 disposition |
|---|---|
| Blocker — content/non-graded recheck stopped without a screen producer | **Closed.** The driver waits for the second evaluation, records its plan, then stops. The oracle's non-navigation causal-edge loop rejects evaluation 2 on a content screen without a graded recheck licence, and that rule is ungated. If no evaluation settles, `awaitEvaluation` emits screen-bearing `ack-no-effect`. A request still outstanding at that timeout is included by the later seal cutoff and the operation failure remains positive evidence; a request beginning after cutoff cannot erase it. Sealing cannot begin while the driver is still waiting, so a response that settles during the wait is recorded before stop. Window ownership remains on this visit until the next identity fence, and a foreign attempt also emits a lineage violation. |
| Should-fix 1 — origin-site identity leaves shared helpers multi-valued | **Not folded in code; contract ruling below.** The problem is real under the current wording. A call-qualified identity is the right semantic correction, with the origin-preservation qualification below. |
| Should-fix 2 — browser tests bypassed `widgetButtonReady` | **Closed.** Both real-page tests now exercise `widgetButtonReady`; the absent-control case also proves the old swallowing `widgetFrame` still returns a frame, so reverting the public delegation makes the test fail. |
| Should-fix 3 — operation-failure matrix omitted three union members | **Closed.** The test-authored `Record<OperationFailureKind, true>` lists all thirteen values; removing one fails type-check and no emitter-owned enumeration is shared. |
| Should-fix 4 — malformed nested shapes could throw outside the typed contract | **Fold rejected.** Throws were removed, but invalidity was erased. The legal navigation-rotation `none` branch turns that erasure into the blocker above. |
| Nit — repeated full journal clone | **Open, correctly deferred.** |

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

This is a new derivation over the current dependency/call graph. The real routed fixture is still
absent: `driveStrictLesson` is called only by the scripted spec and `armStrictRun` has no caller.
The fixture-lifecycle rows therefore remain prospective owed rows, as the request explicitly
allows; they cannot be declared closed before 4d supplies the real entry.

#### Source universe

Included:

- `AdaptiveStrictDriver.ts`: handle lifecycle, driver, and every nested helper.
- `AdaptiveJournal.ts`: stamps, snapshots, recorder attach/freeze/seal paths.
- `AdaptiveFamilyRegistry.ts`: resolver, ownership, and all six entries.
- `AdaptiveDeckPO.ts`: every primitive reachable from the driver/entries.
- `AdaptiveManifest.ts`: `resolveOperations`, the runtime operation-selection edge.
- `AdaptiveTransitionPlanner.ts`: both exported planning functions and their new normalization.

Excluded, bidirectionally:

- `AdaptiveOracle.ts`, `AdaptiveAttribution.ts`, and `AdaptiveShadowProjector.ts` are downstream
  judges, not producers before the driver/fixture boundary. They were inspected directly for the
  planner blast radius; an exception there makes the verdict path red rather than letting a driver
  bail audit green.
- Archive reader/gate/predicate modules are build-time inputs and import neither the journal nor
  planner. Their private-gate consumers remain unchanged.
- The old walker/observer/contract and compat specs remain B4-DEL/human-amendment material.
- Manifest validation/route coverage remain fixture preconditions. Until 4d proves that edge, the
  driver's malformed-input initialization row stays prospective rather than silently excluded.
- Scripted test doubles are not the live source universe. Recorder callbacks that cannot reject an
  awaited call are excluded; attach/freeze/seal/detach/snapshot remain represented.

#### Producer legend

- `OF(x)`: one driver operation failure of kind `x`.
- `OF(DI)` / `OF(IU)`: driver-internal after a stamped visit / identity-unresolved before one.
- `JR(unusable)`: an already-terminal journal record the oracle rejects.
- `RP(illegal)`: an already-recorded plan that produces a positive plan violation.
- `CE(unlicensed)`: the observed evaluation/permit/role facts produce an ungated causal-edge
  violation.
- `JF/FT`: finalization-failure / freeze-timeout journal evidence.
- `∅`: no unique typed producer before seal/boundary. The screenless seal sentinel is not a
  substitute.

| Origin or producer call edge | Source exit | Pinned producer in the current tree |
|---|---|---|
| `AdaptiveStrictDriver.ts:106` → recorder attach | attach throw before handle exists | `∅` (prospective fixture edge) |
| `AdaptiveStrictDriver.ts:112-131` | correlation read/parse false path or stamp throw | `∅` |
| `AdaptiveStrictDriver.ts:134-145` | freeze catch; either seal rejection | `FT` for the named accepted/quiescence timeout; otherwise `∅` |
| `AdaptiveStrictDriver.ts:146-151` | detach cleanup failure | swallowed, no crossing exit; final inventory must justify exclusion |
| `AdaptiveStrictDriver.ts:154` | premature/failed snapshot | `∅` |
| `AdaptiveStrictDriver.ts:199-219` | malformed/unvalidated initialization before outer `try` | `∅` until 4d proves validated inputs |
| `AdaptiveStrictDriver.ts:245-247` | `fail` throw | `OF(call-edge kind)` |
| `AdaptiveStrictDriver.ts:255-258` from `:316` | stop on terminal unusable evaluation | `JR(unusable)` |
| `AdaptiveStrictDriver.ts:255-258` from `:522` | stop on first `none` plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:255-258` from `:550` | stop after content/non-graded recheck | `CE(unlicensed)` — round-2 `∅` resolved |
| `AdaptiveStrictDriver.ts:255-258` from `:557` | stop on illegal second plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:267-270` | `perform` catch | `OF(call-edge kind)` |
| `AdaptiveStrictDriver.ts:274-285` | journal/sleep rejection or false quiescence deadline | `OF(DI)` / caller `OF(traffic-unsettled)` |
| `AdaptiveStrictDriver.ts:302-330` | clone/filter/sleep rejection, unusable record, deadline | `OF(DI)` / `JR(unusable)` / caller timeout `OF(check-click-no-effect or ack-no-effect)` |
| `AdaptiveStrictDriver.ts:342-365` | barrier scan/sleep rejection or deadline | `OF(DI)` / `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:368-390` | record/sweep failure | `OF(DI)`; the planner no longer throws for JSON-derived shapes |
| `AdaptiveStrictDriver.ts:402-405` → media helpers | undeclared-media rejection | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:409-419` → same media helpers | declared-gate throw/rejection/zero result | `OF(gate-unsatisfied)` |
| `AdaptiveStrictDriver.ts:428-464` → registry | inventory, resolution, detect, readiness, answer, readback | call-edge `OF(answer-failed)` / `OF(readiness-timeout)` / `OF(readback-failed)` |
| `AdaptiveStrictDriver.ts:463-484` | barrier derivation, receipt copy, readback fence, barrier helper | `OF(DI)` except deadline `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:493-501` | terminal/navigation wait rejection | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:520-564` | plan stop, feedback, ack, second evaluation/plan/transition | `RP(illegal)`, `OF(feedback-never-opened)`, `OF(ack-no-effect)`, `CE(unlicensed)`, `OF(navigation-timeout)`, or `OF(DI)` at the named edge |
| `AdaptiveStrictDriver.ts:568-580` | step access / deck readiness / identity failure | `OF(IU)` |
| `AdaptiveStrictDriver.ts:583-592` | entry-fence/visit stamping before active visit | `OF(IU)` |
| `AdaptiveStrictDriver.ts:594-596` | runtime operation selection/filter fault | `OF(DI)` |
| `AdaptiveStrictDriver.ts:602-632` | widget readiness/click/navigation/quiescence | `OF(widget-button-unavailable)` / `OF(navigation-timeout)` / `OF(traffic-unsettled)`; permit refusal is `OF(DI)` |
| `AdaptiveStrictDriver.ts:641-667` | gates/answer/check/evaluation/plan/follow or direct stamp | nested edge producer; direct faults become `OF(DI)` |
| `AdaptiveStrictDriver.ts:668-671` | logging failure | swallowed, no crossing exit |
| `AdaptiveStrictDriver.ts:682` | lesson-end read/stamp | `OF(DI)` on the last visit; `OF(IU)` only for an invalid empty route |
| `AdaptiveStrictDriver.ts:684-707` | outer boundary | preserves pending `OF(x)`; otherwise `OF(DI)`/`OF(IU)`; `stopped` now has positive `JR`/`RP`/`CE` at every current call edge |
| `AdaptiveJournal.ts:208-250` → driver stamps | fence/permit/readback refusal | call-edge `OF(IU)` for entry fence; otherwise `OF(DI)` |
| `AdaptiveJournal.ts:261-267` → driver completion | lesson-end refusal | `OF(DI)` (or invalid-empty-route `OF(IU)`) |
| `AdaptiveJournal.ts:333-335` → driver polling/sweep | clone throw | `OF(DI)` |
| `AdaptiveJournal.ts:703-720` | malformed evaluation body | wrong outer `results`: `JR(unusable)`; malformed nested member: no exit and potentially no violation — blocker above |
| `AdaptiveJournal.ts:792-798` → `armStrictRun` | attach throw | `∅` |
| `AdaptiveJournal.ts:823-909` → handle finish | freeze rejection | `JF/FT` on specified lifecycle paths; unexpected rejection remains `∅` |
| `AdaptiveJournal.ts:913-920` → handle finish | seal rejection | `∅` |
| `AdaptiveFamilyRegistry.ts:61-131` → driver resolve/detect | directive, ownership, version throws/false | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:157-165` → driver readiness | CAPI readiness false/rejection | `OF(readiness-timeout)` |
| `AdaptiveFamilyRegistry.ts:189-382` → driver family calls | validation/readiness/answer/readback exits | edge-specific `OF(answer-failed)` / `OF(readiness-timeout)` / `OF(readback-failed)` |
| `AdaptiveFamilyRegistry.ts:402-439` → driver resolution | resolver throws | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:573` → `AdaptiveDeckPO.ts:47-57` | deck-ready rejection | `OF(IU)` |
| `AdaptiveStrictDriver.ts:454` → registry ready → `AdaptiveDeckPO.ts:47-57` | same helper rejection | `OF(readiness-timeout)` |
| `AdaptiveDeckPO.ts:147-155` → driver check readiness | rejection | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:609` → `AdaptiveDeckPO.ts:184-185` → `:163-180` | widget control absent/timeout | `OF(widget-button-unavailable)` |
| `AdaptiveStrictDriver.ts:454` → registry `:162` → Deck `:163-180` | same control helper absent/timeout | `OF(readiness-timeout)` |
| `AdaptiveDeckPO.ts:189-235` → driver strict actions | check/ack/feedback/navigation failure | matching check/ack/feedback/navigation `OF` kind |
| `AdaptiveDeckPO.ts:284-315` → driver identity | strict identity throw | `OF(IU)`; transition polling catches locally and its caller times out as navigation |
| `AdaptiveDeckPO.ts:322-346` → driver inventory | caught read returning empty | later `OF(answer-failed)` when ownership fails; no crossing exit otherwise |
| `AdaptiveDeckPO.ts:466-628` → registry answer/readback | MCQ/text failure | edge-specific `OF(answer-failed)` / `OF(readback-failed)` |
| registry answer → Deck helpers `:724-735` | widget frame absent / swallowed ready timeout | `OF(answer-failed)` at answer edges; swallowed timeout itself excluded |
| driver widget click → Deck `:1199-1210` → `:724-735` | same frame helper absent/click false | `OF(widget-button-unavailable)` |
| driver media edges → Deck `:798-863` | carousel/video throw or zero result | call-edge `OF(readiness-timeout)` / `OF(gate-unsatisfied)` |
| Deck `:938-969,1019-1060,1079-1191` → registry answer | CAPI interaction/readback failure | `OF(answer-failed)` |
| `AdaptiveManifest.ts:631-637` → driver operation selection | malformed runtime operation shape | `OF(DI)`; valid precondition otherwise |
| `AdaptiveTransitionPlanner.ts:47-105` → driver/oracle/shadow | JSON-derived malformed result/action data | total, no crossing exit; current coercion can false-green (blocker) |

Compared with round 2: the content/recheck `∅` is resolved; the planner's malformed-input throw is
removed; no lifecycle `∅` is resolved because the routed fixture is intentionally deferred. The
shared Deck/registry/media origins remain multi-valued only under the contract's current
origin-only identity. They split cleanly under the qualified call-edge amendment below.

### Contract ruling — exit-site identity

**Agree with the call-edge direction, but `caller file:line → callee + exit kind` alone is not
precise enough.** It would collapse two distinct throw/early-return origins inside one callee when
they share a source kind, weakening W-E1 and allowing W-E2 to inject only one of them.

Replace §1 step 1 and the B4-EXIT-INV row with this wording:

> **EXIT-INV — within the independently closed EXIT-SCOPE universe, inventory every reachable
> exit instance. Its identity is the tuple `(source exit origin file:line, source exit kind,
> producer call edge caller file:line → callee symbol)`, where the producer call edge is the edge
> at which that outcome is mapped to, or allowed to cross as, one typed producer. The same source
> origin reached through different producer call edges is a distinct instance; distinct source
> origins never collapse merely because they share a callee or exit kind. The artifact must equal
> the reviewer-derived tuple set bidirectionally, and every tuple pins exactly one typed producer.

Amend W-E1 to compare that tuple set. Amend W-E2 to inject the named source origin while executing
the named producer edge, then assert its pinned producer — and no other — before boundary/seal.
W-E3 remains the mutation that exits at that origin before the named edge can produce. This keeps
shared helpers honest without flattening readiness, widget, answer, or gate failures into one
misleading kind.

The compat-walk extraction amendment remains sound as read in round 1; nothing in the current type
moves changes that ruling.

### Consumer, security, and performance review

- `CheckActions` and `CapturedLedgerEntry` remain correctly owned by the journal/replay modules;
  archive gates have no new dependency on either shared core change.
- Oracle and shadow replay do not throw on the new malformed cases, but they share the false-green
  coercion identified above. The unchanged private replay therefore does not kill that mutation.
- The content/recheck outcome cause remains driver-authored and screen-attributed. No answer value,
  selector-derived exception text, credential, authorization surface, or new external input sink
  escapes the reviewed boundary.
- No new unbounded concurrency or I/O was introduced. Apart from the retained snapshot-clone nit,
  the planner and journal folds are linear in the captured result size.

### Verification

- Requested nine-file Playwright subset: **351 passed / 0 failed / 9 skipped** locally without the
  private archive/capture environment (360 discovered). The new driver spec contributes **19
  passed / 0 failed**. The supplied private run remains **360 passed / 0 failed** evidence.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`.
- ESLint on all ten review files: clean.
- Prettier on all ten review files: clean, with the existing ignored-plugin-option warnings.
- `git diff --check`: clean before appending this round.

### Summary

1 blocker, 0 should-fix, 1 nit. Verdict: **BLOCKED**.

## Round 4

Fresh-eyes review of the full current ten-file material at base
`df8c85b115719511e1262d8ec821f9874e7f6cc7`, including the oracle front door, every downstream
shadow consumer, the archive-gate call graph, and the full driver exit universe. The round-3 fold
rejects the three exact shapes in its new witnesses, but it does not implement the claimed
complete planner-input validation. Two independently reproducible malformed-response classes still
produce a zero-violation frozen audit.

### Blockers

1. **Both shape legs accept malformed object shells and malformed LLM feedback, so the driver and
   oracle still agree on legal `none`/`feedback` plans**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:703`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:729`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:221`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:158`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:385`
   `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:2214`

   `plannableResults` and `replayableActions` are separately written, but they have the same
   incomplete acceptance boundary. They prove only that each result, `params`, and action member
   is truthy and `typeof === 'object'`. They accept arrays as objects, accept a result with no
   `params`, accept `params` with no `actions`, and accept action shells such as `{}` even though
   `CheckActions` requires `action.type: string`. They also do not validate the result-level
   `params.correct` that `selectProcessedEvents` reads at
   `AdaptiveTransitionPlanner.ts:80`, or the `llm_feedback.text` that `planTransition` reads at
   `:96`. The journal copies malformed `llm_feedback` through at `AdaptiveJournal.ts:715`; neither
   audit-time leg checks it.

   These are planner-consumed fields, not unused defensive narrowing. On the actual modules, I
   constructed the measured navigation rotation, accepted finalization, froze the journal, and
   supplied matching recorded plans. Each of these first responses followed by a causal mint and
   a correct terminal second response produced `auditRun(...).map(code) === []`:

   - `results: [{}]` resolved as an evaluation and planned `none`;
   - `results: [{params: {correct: false, actions: [{}]}}]` resolved as an evaluation and planned
     `none`;
   - `llm_feedback: {text: 7}` resolved as an evaluation and planned feedback/recheck.

   The driver-local `usable` predicate is equally shallow, so the navigation sweep records those
   plans and gives replay exactly the evidence it expects. The new killing witnesses cover
   `null`, a non-array action collection, and a non-object action member only; none covers a
   malformed object shell, a malformed planner-read field, an array masquerading as an object, or
   malformed LLM feedback. The replay witness at `adaptive-strict-run.spec.ts:743` likewise covers
   only a string action collection.

   Validate the actual planner input contract on both independent legs: non-array record objects,
   the required result `params`/`actions` shape, boolean result `params.correct` where the footer
   consumes it, action `type`, action `params`/recognized-action fields, and LLM feedback text. Add
   live and captured legal-rotation witnesses for object-shaped poison, not only scalar poison.

   **Class:** blocker — this is the same common-mode live/replay false green as round 3, through
   malformed shapes that the new predicates still classify as usable.

2. **`type: 'success'` launders a malformed evaluation payload into an informational activity
   finalize, removing the candidate from every evaluation audit**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:709`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:716`
   `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts:302`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:520`
   `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:143`

   The response resolver tests `parsed.type === 'success'` after `wellFormed` fails, without
   distinguishing a genuinely bare-success activity finalize from a response that contains a
   malformed `actions` field. Thus
   `{type: 'success', actions: {correct: false, results: [null]}}` becomes
   `resolution: 'activity-finalize'`, `actions: null`, and no parse error. The driver explicitly
   filters that record out while awaiting an evaluation, and `auditRun` constructs its evaluation
   set only from `resolution === 'evaluation'`; the unresolved-candidate check cannot see it either.

   The actual-module diagnostic above, using that response as the first half of a navigation
   rotation, produced `firstResolution === 'activity-finalize'` and a zero-code frozen audit after
   the causal mint and valid terminal second evaluation. A capture written by this recorder has
   already discarded the malformed body from `JournalRecord.actions`, so the independent oracle
   predicate cannot recover it. The current test proves only that a response containing exactly
   `{type: 'success'}` is informational; it has no mixed-shape refusal row.

   Only absence of an `actions` member should be eligible for the bare-success finalize branch.
   Presence of an invalid evaluation-shaped member must remain an unresolved candidate with typed
   positive evidence, and the wire matrix needs the mixed `type + malformed actions` witness.

   **Class:** blocker — this erases malformed owned traffic from cardinality, usability, sequence,
   and replay, preserving a live and serialized false green.

### Should-fix

None.

### Nit

1. **The new response-time validator is documented as request-time validation**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:724`

   `plannableResults` is called from `resolveResponse` after the response body is parsed. Request
   time fixes the wire class; response time resolves evaluation versus finalize. The incorrect
   comment blurs the exact fail-closed boundary this fold is intended to repair.

   **Class:** nit — documentation only; it does not create the false green.

### Round-3 disposition

| Round-3 item | Round-4 disposition |
|---|---|
| Blocker — malformed nested shapes normalized to legal navigation `none` | **Partially closed, still blocking.** The three scalar/container poisons in the new tests now become unresolved live or `evaluation-unusable` on replay. Object shells, arrays-as-objects, malformed planner-read fields, and malformed LLM feedback remain common-mode usable (blocker 1). A malformed actions payload carrying `type: 'success'` is removed from the audited class entirely (blocker 2). |
| Self-flagged downstream suppression risk | **Redness preserved for every shape the new oracle predicate actually rejects.** Detailed verdict/payload/plan/navigation findings are intentionally not derived from untrusted fields, but `evaluation-unusable` is emitted first and remains screen-attributed. Cardinality, provenance, unresolved-candidate, permit inventory, and other safe positive checks still use the full owned set. This is a deliberate replacement by one defensible typed violation, not a false green. The blockers arise before this reasoning because the predicate does not reject the full malformed space. |
| Repeated whole-journal clone | **Still deferred by the prior ruling and explicitly out of scope for findings in this round.** |
| Call-edge exit identity amendment | **View unchanged.** Retain `(source origin, exit kind, producer call edge)` so neither shared origins nor distinct exits inside one callee collapse. |
| Compat-walk extraction amendment | **View unchanged.** Still human/contract material, not a code finding. |

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

The current dependency graph yields the same source universe as round 3. The real routed fixture
is still absent: `driveStrictLesson` is called only by the scripted spec and `armStrictRun` has no
live caller. Fixture-lifecycle exits remain prospective owed rows until 4d. The next unit still
owes the independently closed inventory artifact, bidirectional comparison, per-site fault
injection, and CONFORMANCE-MAP; this table is input, not a substitute.

Included: `AdaptiveStrictDriver.ts`, reachable journal/recorder paths, all registry entries,
reachable `AdaptiveDeckPO.ts` primitives, `AdaptiveManifest.resolveOperations`, and the transition
planner. Excluded bidirectionally: oracle/attribution/shadow modules are downstream judges;
archive reader/gate/predicate modules are independent build-time inputs; old walker/observer/
contract files are deletion/compat material; scripted doubles are not live producers. Manifest
validation and route coverage remain fixture preconditions, so initialization/lifecycle rows stay
prospective rather than disappearing.

Producer legend: `OF(x)` is one operation failure of kind `x`; `OF(DI)`/`OF(IU)` are
driver-internal/identity-unresolved; `JR(unusable)` is a rejected terminal journal record;
`RP(illegal)` is an illegal recorded plan; `CE(unlicensed)` is a causal-edge violation; `JF/FT`
is finalization-failure/freeze-timeout evidence; `∅` means no unique typed producer before the
boundary. The screenless seal sentinel is not a substitute.

| Origin or producer call edge | Source exit | Pinned producer in the current tree |
|---|---|---|
| `AdaptiveStrictDriver.ts:106` → recorder attach | attach throw before handle exists | `∅` (prospective fixture edge) |
| `AdaptiveStrictDriver.ts:112-131` | correlation read/parse false path or stamp throw | `∅` |
| `AdaptiveStrictDriver.ts:134-145` | freeze catch; either seal rejection | `FT` for the named accepted/quiescence timeout; otherwise `∅` |
| `AdaptiveStrictDriver.ts:146-151` | detach cleanup failure | swallowed; no crossing exit, final inventory must justify exclusion |
| `AdaptiveStrictDriver.ts:154` | premature/failed snapshot | `∅` |
| `AdaptiveStrictDriver.ts:199-219` | malformed/unvalidated initialization before outer `try` | `∅` until 4d proves validated inputs |
| `AdaptiveStrictDriver.ts:245-247` | `fail` throw | `OF(call-edge kind)` |
| `AdaptiveStrictDriver.ts:255-258` from `:316` | stop on terminal unusable evaluation | `JR(unusable)` |
| `AdaptiveStrictDriver.ts:255-258` from `:522` | stop on first `none` plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:255-258` from `:550` | stop after content/non-graded recheck | `CE(unlicensed)` |
| `AdaptiveStrictDriver.ts:255-258` from `:557` | stop on illegal second plan | `RP(illegal)` |
| `AdaptiveStrictDriver.ts:267-270` | `perform` catch | `OF(call-edge kind)` |
| `AdaptiveStrictDriver.ts:274-285` | journal/sleep rejection or quiescence deadline | `OF(DI)` / caller `OF(traffic-unsettled)` |
| `AdaptiveStrictDriver.ts:302-330` | scan/sleep rejection, unusable record, deadline | `OF(DI)` / `JR(unusable)` / caller check-or-ack timeout; an activity-finalize misclassification has no producer (blocker 2) |
| `AdaptiveStrictDriver.ts:342-365` | barrier scan/sleep rejection or deadline | `OF(DI)` / `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:368-390` | record/sweep failure | `OF(DI)`; accepted malformed planner input can falsely produce no exit (blocker 1) |
| `AdaptiveStrictDriver.ts:402-405` → media helpers | undeclared-media rejection | `OF(readiness-timeout)` |
| `AdaptiveStrictDriver.ts:409-419` → media helpers | declared-gate throw/rejection/zero result | `OF(gate-unsatisfied)` |
| `AdaptiveStrictDriver.ts:428-464` → registry | inventory, resolution, detect, readiness, answer, readback | edge-specific answer/readiness/readback `OF` |
| `AdaptiveStrictDriver.ts:467-484` | receipt/barrier derivation, stamp, copy, wait | `OF(DI)` except deadline `OF(barrier-timeout)` |
| `AdaptiveStrictDriver.ts:493-501` | terminal/navigation wait rejection | `OF(navigation-timeout)` |
| `AdaptiveStrictDriver.ts:520-564` | plan stop, feedback, ack, second evaluation/plan/transition | `RP(illegal)`, feedback/ack/navigation `OF`, `CE(unlicensed)`, or `OF(DI)` at the named edge |
| `AdaptiveStrictDriver.ts:568-580` | step access / deck readiness / identity failure | `OF(IU)` |
| `AdaptiveStrictDriver.ts:583-592` | entry-fence/visit stamping before active visit | `OF(IU)` |
| `AdaptiveStrictDriver.ts:594-596` | runtime operation selection/filter fault | `OF(DI)` |
| `AdaptiveStrictDriver.ts:602-632` | widget readiness/click/navigation/quiescence | widget/navigation/traffic `OF`; permit refusal is `OF(DI)` |
| `AdaptiveStrictDriver.ts:641-667` | gates/answer/check/evaluation/plan/follow or direct stamp | nested edge producer; direct faults become `OF(DI)` |
| `AdaptiveStrictDriver.ts:668-671` | logging failure | swallowed; no crossing exit |
| `AdaptiveStrictDriver.ts:682` | lesson-end read/stamp | `OF(DI)` on last visit; `OF(IU)` only for invalid empty route |
| `AdaptiveStrictDriver.ts:684-707` | outer boundary | preserves pending `OF`; otherwise `OF(DI)`/`OF(IU)`; every current `stop` edge retains JR/RP/CE evidence |
| `AdaptiveJournal.ts:208-250` → driver stamps | fence/permit/readback refusal | entry edge `OF(IU)`; otherwise `OF(DI)` |
| `AdaptiveJournal.ts:261-267` → driver completion | lesson-end refusal | `OF(DI)` (or invalid-empty-route `OF(IU)`) |
| `AdaptiveJournal.ts:333-335` → driver polling/sweep | clone throw | `OF(DI)` |
| `AdaptiveJournal.ts:694-720` | malformed evaluation response | currently rejected container/scalar shapes → unresolved `JR`; accepted object-shell/LLM poison → no exit (blocker 1); malformed actions + `type: success` → informational/no producer (blocker 2) |
| `AdaptiveJournal.ts:811-817` → `armStrictRun` | attach throw | `∅` |
| `AdaptiveJournal.ts:842-928` → handle finish | freeze rejection | `JF/FT` on specified lifecycle paths; unexpected rejection remains `∅` |
| `AdaptiveJournal.ts:932-939` → handle finish | seal rejection | `∅` |
| `AdaptiveFamilyRegistry.ts:61-131` → driver resolve/detect | directive, ownership, version throws/false | `OF(answer-failed)` |
| `AdaptiveFamilyRegistry.ts:157-167` → driver readiness/readback | CAPI readiness/readback false/rejection | readiness/readback `OF` |
| `AdaptiveFamilyRegistry.ts:189-382` → family calls | validation/readiness/answer/readback exits | edge-specific answer/readiness/readback `OF` |
| `AdaptiveFamilyRegistry.ts:402-439` → resolution | resolver throws | `OF(answer-failed)` |
| `AdaptiveStrictDriver.ts:573` → `AdaptiveDeckPO.ts:47-57` | deck-ready rejection | `OF(IU)` |
| `AdaptiveStrictDriver.ts:454` → registry ready → Deck `:47-57` | same helper rejection | `OF(readiness-timeout)` |
| `AdaptiveDeckPO.ts:147-155` → driver check readiness | rejection | `OF(readiness-timeout)` |
| driver widget edge → Deck `:184-185`/`:163-180` | widget control absent/timeout | widget or readiness `OF` according to call edge |
| `AdaptiveDeckPO.ts:189-235` → strict actions | check/ack/feedback/navigation failure | matching check/ack/feedback/navigation `OF` kind |
| `AdaptiveDeckPO.ts:284-315` → identity | strict identity throw | `OF(IU)`; transition polling catches locally and caller times out as navigation |
| `AdaptiveDeckPO.ts:322-346` → inventory | caught read returning empty | later `OF(answer-failed)` when ownership fails; no crossing exit otherwise |
| `AdaptiveDeckPO.ts:466-628` → registry | MCQ/text failure | edge-specific answer/readback `OF` |
| registry answer → Deck `:724-735` | widget frame absent / swallowed ready timeout | `OF(answer-failed)` at answer edge; swallowed timeout excluded |
| driver widget click → Deck `:1199-1210` → `:724-735` | frame absent/click false | `OF(widget-button-unavailable)` |
| driver media edges → Deck `:798-863` | carousel/video throw or zero result | readiness/gate `OF` according to call edge |
| Deck `:938-969,1019-1060,1079-1191` → registry | CAPI interaction/readback failure | `OF(answer-failed)` |
| `AdaptiveManifest.ts:631-637` → driver | malformed runtime operation shape | `OF(DI)`; valid fixture precondition otherwise |
| `AdaptiveTransitionPlanner.ts:47-105` → driver/oracle/shadow | JSON-derived malformed planner data | total; no crossing exit; upstream accepted malformed shapes can false-green (blocker 1) |

Compared with round 3, no new source origin or producer call edge was added. The journal row is now
split three ways: the three witnessed malformed shapes have `JR` evidence, while the two untested
classes above remain producer-less. Lifecycle `∅` rows remain intentionally prospective. The
qualified call-edge amendment remains necessary because shared Deck/registry/media origins map to
different producer kinds at different callers.

### Self-flagged risk verdict and consumer blast radius

For a record that remains `resolution: 'evaluation'` and fails `replayableActions`, the stated
reading is correct with one qualification:

- `evaluations` includes it at `AdaptiveOracle.ts:520`, and `evaluation-unusable` is emitted at
  `:646-655` before the navigation sequence returns at `:936-938`.
- Cardinality and causal-edge accounting use all resolution-evaluations; provenance also runs over
  all of them. Permit/receipt inventory and unresolved-candidate checks are unaffected.
- Verdict comparison, local payload matching, recorded-plan replay, navigation sequence details,
  cross-screen matching, and plan obligations skip the unusable record. Those more specific
  violations are therefore not co-reported. That is appropriate: they depend on fields already
  declared untrustworthy. The generic positive violation replaces them without changing screen
  attribution or gate redness; no rejected record disappears entirely.

Direct consumer trace:

- `evaluateGreenCapture` keeps `evaluation-unusable` in `inScope`; it is not on the driver-evidence
  allowlist. A malformed capture the predicate rejects is therefore red before projection diffs.
- `projectFromJournal` independently counts every resolution-evaluation and still plans from its
  last non-null actions. It can normalize malformed input, but cannot neutralize a non-empty
  `inScope`. For the shapes in blocker 1, both legs accept, so this safety premise fails.
- `compareProjections` consumes the already-separated in-scope list only for diff classification;
  it never removes violations.
- `expectedDriverEvidence` uses a weaker local usable approximation. On a shape the oracle rejects,
  any inventory disagreement fails equality; it cannot make `inScope` empty. On the accepted
  object-shell shapes, common-mode audit acceptance remains the blocker.
- The archive-gate implementation is not downstream of `auditRun` in the call graph; it imports
  archive/manifest/predicate modules. The shadow gate is the archive-backed consumer that invokes
  `evaluateGreenCapture`.
- Well-formed behavior did not change in the private replay: both greens remained in-scope 0,
  driver-evidence 65, unexplained 0, intentional 1; the bail remained one violation at its poisoned
  screen.

### Security, performance, and verification

No reviewed change exposes answer values, credentials, selector-derived exception text, or a new
authorization/external-input sink. The malformed-input gap is integrity/fail-closed behavior, not
data disclosure. The new checks and planner normalization are linear in response size; no new
unbounded work or concurrency was introduced. The previously deferred full-journal clone was not
re-raised.

- Exact requested subset with private env: **363 passed / 0 failed**. The two green replays retained
  `0 / 65 / 0 / 1`; bail retained one violation.
- Actual-module diagnostic: all four poison rows above reached the claimed resolution/plan and
  produced a zero-code frozen audit; no repository test file was added.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on all ten review files: clean.
- Prettier on all ten review files: clean, with the existing ignored-plugin-option warnings.
- `git diff --check`: clean before appending this round.

### Summary

2 blockers, 0 should-fix, 1 nit. Verdict: **BLOCKED**.

## Round 5

Fresh-eyes review of the full current ten-file material at base `df8c85b115`, with the response
acceptance boundary traced into the real server response constructor, `triggerCheck`, the deck
footer, the driver, the oracle, and the archive shadow gate. Round 4's two exact defects are closed,
but the claimed boundary is still incomplete in two independently reproducible ways.

### Blockers

1. **Fields that the product always emits, or a recognized footer action requires, remain optional;
   hollowing them preserves a green legal rotation**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:741`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:762`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:768`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:225`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:232`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:247`
   `assets/src/apps/delivery/layouts/deck/DeckLayoutFooter.tsx:210`
   `assets/src/apps/delivery/layouts/deck/DeckLayoutFooter.tsx:550`
   `assets/src/adaptivity/rules-engine.ts:577`
   `lib/oli_web/controllers/api/attempt_controller.ex:762`

   Both validators explicitly accept absent `actions.results`. That is not a product-legal optional:
   the rules engine always returns `results` in its `CheckResult`, the controller returns that whole
   object as `actions`, `triggerCheck` immediately reads `resultData.results`, and the footer reads
   `lastCheckResults.results.length`. The current capture sample agrees: all 46 evaluations in the
   two gate greens have a non-empty results array. The `107/107` number in the source comment is the
   seven-file shadow directory total (four historical greens plus three bails), not the two current
   gate greens, but all 107 also carry `results`.

   This is material, not theoretical strictness. Against the actual modules I changed the first
   incorrect evaluation of the measured rotation to `{actions: {correct: false}}`, then supplied
   the causal mint, valid navigating second evaluation, accepted finalization, and matching plans.
   The journal resolved the first record as `evaluation` and the frozen `auditRun` returned zero
   codes. I then deleted only `actions.results` from the first incorrect evaluation in the real
   `lote-green-1786378384523.json`: `validateGreenEnvelope` returned `[]`, shadow `inScope` remained
   `[]`, and there were no unexplained diffs. Missing data has been normalized to the rotation's
   licensed `none` plan.

   The same incompleteness exists one level lower. Every current product action union member has an
   object `params`; more importantly, a recognized `feedback` action is dereferenced as
   `fAction.params.feedback` by the footer. Both predicates accept `{type: 'feedback'}`. Replacing
   the first rotation result's empty actions with that malformed recognized action in a real green
   capture also left the envelope, in-scope audit, and unexplained diff set empty. Unknown string
   action types and extra fields should remain accepted because `processResults` ignores them; the
   fix is recognized-action validation, not a closed action-type allowlist.

   Finally, the LLM limit can now be derived from product source. The controller adds
   `llm_feedback` only as `%{"text" => text, "ai_generated" => true}`; otherwise it omits the member.
   A present `{}` is therefore malformed, not an observed alternate shape. Both predicates accept
   it and a real-green mutation to `llmFeedback: {}` again stayed completely shadow-green. The
   proportionate boundary is: absent/null, or a non-array object with a required string `text`.
   `ai_generated` and unrelated extra fields need not be gate-critical because the planner does not
   consume them. A string may remain empty: the server can return one and the product treats it as
   no feedback.

   **Class:** blocker — each hollow product field can be common-mode normalized into the legal
   first half of the measured navigation rotation, preserving a live or capture green.

2. **The replay predicate never validates the outer `record.actions` object or reconciles its
   duplicated verdict, so mixed-recorder captures bypass the independent leg**

   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:221`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:232`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:254`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:265`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:45`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:75`
   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:76`

   `replayableActions()` begins at `record.actions?.results`; it never proves that `record.actions`
   itself is a non-array object with boolean `correct`. If `actions` is an array, optional access
   yields `results === undefined` and the predicate returns true. `usable()` separately trusts the
   duplicated top-level `record.correct`, so the malformed outer body has all the evidence needed
   to pass. The same split accepts an object whose `actions.correct` is non-boolean or contradicts
   `record.correct` as long as the duplicated record field remains boolean.

   I replaced the first incorrect evaluation's `actions` in a real green capture with `[]`, leaving
   its recorder-derived `record.correct === false`. The green envelope returned no problems,
   `evaluateGreenCapture().inScope` was empty, and there were no unexplained diffs. The journal leg
   would refuse that wire body, but the audit leg exists specifically for captures written without
   the current live guard; this divergence is therefore in the unsafe direction. Require an outer
   non-array object, boolean `actions.correct`, and consistency with the duplicated `record.correct`
   before inspecting results.

   The nested `Array.isArray` (journal) versus `instanceof Array` (oracle) difference is otherwise
   equivalent for JSON-parsed/currently deserialized captures. A cross-realm array is rejected only
   by the oracle, so that residual divergence is fail-closed. The outer-object omission is not.

   **Class:** blocker — a malformed mixed-recorder record passes the supposedly independent audit
   boundary and preserves the supplied archive green.

### Should-fix

None.

### Nit

1. **The changed journal file is not Prettier-clean**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:731`

   The formatter collapses `isPlainObject` to one line. This has no runtime effect, but the supplied
   “Prettier clean” state is no longer true for the ten-file review set.

### Round-4 disposition

| Round-4 item | Round-5 disposition |
|---|---|
| Blocker 1 — object shells and malformed LLM text passed both legs | **Partially closed, still blocking at the boundary.** The ten new witnessed nested poisons and non-string LLM text are rejected. Absent results, recognized actions missing footer-required params, a hollow present LLM object, and malformed outer capture actions still pass (round-5 blockers 1–2). |
| Blocker 2 — mixed `type: success` laundered malformed actions | **Closed.** Only absent/null actions reach `activity-finalize`; the mixed row remains an unresolved candidate and the bare/null success rows stay informational. |
| Nit — response validator documented as request-time | **Closed.** The comment now names response-body parse time. |
| Self-flagged downstream suppression ruling | **Still sound once a record actually fails `replayableActions`.** `evaluation-unusable` remains in-scope and screen-attributed; the new blockers are acceptance omissions before that ruling applies. |
| Repeated full-journal clone | **Still intentionally deferred; not re-raised.** |
| Qualified call-edge identity amendment | **View unchanged.** Retain `(source origin, source exit kind, producer call edge)`. |
| Compat extraction amendment | **View unchanged.** Human/contract material, not a 4c code finding. |

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

The reachable source universe is unchanged from round 4: the strict handle/driver, journal and
recorder lifecycle, all six registry entries, driver-reachable Deck PO primitives,
`resolveOperations`, and the transition planner. Downstream oracle/shadow judges, archive build
gates, old walker graph, and test doubles remain excluded as producers. Manifest validation and
route coverage are still prospective 4d entry preconditions. The routed `armStrictRun` lifecycle
still has no live caller, so those rows remain owed rather than silently closed.

Legend: `OF(x)` is one operation failure; `OF(DI)`/`OF(IU)` are driver-internal/pre-visit
identity-unresolved; `JR` is a terminal unusable or unresolved journal record; `RP` is an illegal
recorded plan; `CE` is the ungated causal-edge finding; `JF/FT` is finalization/freeze evidence;
`∅` has no guaranteed unique producer before the boundary.

| Origin or producer call edge | Source exit | Current pinned producer |
|---|---|---|
| `AdaptiveStrictDriver.ts:106` → recorder attach | attach throws before a handle exists | `∅` — prospective 4d fixture row |
| `AdaptiveStrictDriver.ts:112-131` | correlation read/parse false or stamp throw | `∅` |
| `AdaptiveStrictDriver.ts:134-145` | freeze catch or either seal rejection | named timeout `FT`; unexpected lifecycle rejection `∅` |
| `AdaptiveStrictDriver.ts:146-151` | detach cleanup failure | swallowed, non-crossing; final inventory must justify exclusion |
| `AdaptiveStrictDriver.ts:154` | premature/failed snapshot | `∅` |
| `AdaptiveStrictDriver.ts:199-219` | invalid initialization before outer try | `∅` until 4d proves validated entry inputs |
| `AdaptiveStrictDriver.ts:239-270` | `fail`, `stop`, or `perform` boundary | call-edge `OF`; stop edges retain `JR`, `RP`, or `CE` |
| `AdaptiveStrictDriver.ts:274-365` | quiescence/evaluation/barrier scan, sleep, or deadline | `OF(DI)`, `JR`, or caller-specific timeout `OF` |
| `AdaptiveStrictDriver.ts:368-390` | plan derivation/record/sweep | `OF(DI)` live; accepted hollow capture input has no exit and is judged downstream (blockers above) |
| `AdaptiveStrictDriver.ts:393-425` → media/gate helpers | undeclared media or declared gate failure | `OF(readiness-timeout)` / `OF(gate-unsatisfied)` by qualified edge |
| `AdaptiveStrictDriver.ts:428-484` → registry/barrier | ownership, readiness, answer, readback, receipt, stamp, barrier | edge-specific answer/readiness/readback/barrier `OF`; direct fault `OF(DI)` |
| `AdaptiveStrictDriver.ts:493-564` | transition, feedback, ack, recheck, second plan | `RP`, transition/feedback/ack `OF`, `CE`, or `OF(DI)` at named edge |
| `AdaptiveStrictDriver.ts:567-596` | step access, deck readiness, identity, fence, operation selection | pre-visit `OF(IU)`; post-visit direct fault `OF(DI)` |
| `AdaptiveStrictDriver.ts:602-671` | widget action, navigation, gates, answer, check, evaluation, plan, logging | edge-specific `OF`; direct fault `OF(DI)`; logging swallowed |
| `AdaptiveStrictDriver.ts:678-707` | run loop, final lesson-end stamp, outer boundary | preserves pending `OF`; otherwise `OF(DI)`/`OF(IU)`; stop retains `JR`/`RP`/`CE` |
| `AdaptiveJournal.ts:208-267` → driver stamps | fence/permit/readback/lesson-end refusal | entry edge `OF(IU)`; other edges `OF(DI)` |
| `AdaptiveJournal.ts:333-335` → driver scans | clone failure | `OF(DI)` |
| `AdaptiveJournal.ts:694-727` | evaluation response classification | witnessed malformed shapes and mixed success → unresolved `JR`; missing results / hollow recognized fields still produce a usable evaluation (blocker 1) |
| `AdaptiveJournal.ts:790-920` → strict handle | attach/freeze/seal lifecycle rejection | specified `JF/FT`; otherwise prospective `∅` |
| `AdaptiveFamilyRegistry.ts:61-131,157-177,183-440` → driver | validation, ownership, readiness, answer, readback, resolution | qualified-edge answer/readiness/readback `OF` |
| `AdaptiveDeckPO.ts:47-235` → driver/registry | deck/check/widget/feedback/navigation readiness or action failure | qualified-edge identity/readiness/widget/check/ack/navigation `OF` |
| `AdaptiveDeckPO.ts:284-346` → identity/inventory | strict identity throw or caught empty inventory | `OF(IU)` or later `OF(answer-failed)` |
| `AdaptiveDeckPO.ts:466-628,724-735,798-863,938-1210` → registry/driver | Janus/CAPI/media/widget interaction failure | qualified-edge answer/readback/readiness/gate/widget `OF` |
| `AdaptiveManifest.ts:631-637` → driver | malformed runtime operation selection | post-visit `OF(DI)`; intended validated precondition otherwise |
| `AdaptiveTransitionPlanner.ts:47-105` → driver/oracle/shadow | malformed planner data | total/no crossing exit; upstream accepted hollow data can false-green (blocker 1) |
| `AdaptiveOracle.ts:221-263` → audit boundary | malformed serialized evaluation | rejected nested poison → `evaluation-unusable`; malformed outer actions / duplicated-verdict split has no violation (blocker 2) |

Compared with round 4, no driver or fixture origin changed. The journal row now rejects the
round-4 object-shell and mixed-success witnesses, but retains the new hollow-field hole. The oracle
row also gains the explicit outer-actions divergence. Every lifecycle `∅` remains prospective and
owed to 4d/gate B. The next unit still owes the closed kind list, independently closed
`B4-EXIT-SCOPE`, bidirectional inventory equality, one qualified producer per tuple, per-site fault
injection, and CONFORMANCE-MAP; this review table is input, not that artifact.

### LLM bound and old-recorder residual

The zero-observation LLM limit is acceptable only after using the product-source derivation above.
That derivation is available now and makes the current absent-text allowance too loose: the server
either omits feedback or emits an object with string `text` and `ai_generated: true`. Requiring
`text` when the object is present is compatible with current product source and still permits extra
fields. Gate B should add one routed LLM-capable lesson before claiming coverage beyond the
non-capable LotE archive; until then, first live use is intentionally fail-closed but source-backed.

The old-recorder residual is accurately described: once that recorder relabelled malformed
evaluation traffic as `activity-finalize`, it stored neither the malformed actions nor enough raw
body evidence for the oracle to reconstruct the candidate. The current two gate captures contain
no such traffic and replay unchanged. Recording DEBT before step 5 is sufficient if it pins the
affected recorder version/era, requires recapture or rejection when provenance is unknown, and
states that an old `activity-finalize` record cannot prove absence of evaluation traffic. A generic
note without capture provenance would not be sufficient for accepting future legacy artifacts.

### Security, performance, and verification

No answer value, credential, raw downstream exception, selector-derived private value, or new
authorization surface escapes the reviewed boundary. The remaining defects are integrity and
evidence-schema defects. The validators are linear in response size; no new unbounded I/O or
concurrency was introduced.

- Exact requested private subset: **365 passed / 0 failed**. Both greens remained
  `in-scope=0 / driver-evidence=65 / unexplained=0 / intentional=1`; bail remained one violation.
- Reviewer-only actual-module probes: **5 passed**. They reproduce live missing-results green,
  real-capture missing-results green, outer-actions-array green, recognized feedback-without-params
  green, and hollow-present-LLM green. The probe file stayed under `/private/tmp`.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on all ten review files: clean.
- Prettier: nine files clean; `AdaptiveJournal.ts:731` fails by one line-wrap (nit above), with the
  existing ignored-plugin-option warnings.
- `git diff --check`: clean before appending this round.

### Summary

2 blockers, 0 should-fix, 1 nit. Verdict: **BLOCKED**.

## Round 6

Scoped audit of the closed evaluation-body derivation only.

1. **The derivation is incomplete.** The listed planner fields are all real reads, but the table
   omits three acceptance constraints on fields the product consumes:

   - `actions.correct` must agree with every non-empty `results[].params.correct`. The rules engine
     derives the outer verdict, filters the returned events to that same verdict, and emits both
     together (`rules-engine.ts:517-530,577-581`). The product then uses the outer value for attempt
     and verdict behavior (`triggerCheck.ts:340,405-424`) but independently recomputes the footer
     verdict from the inner values (`DeckLayoutFooter.tsx:420`), which also changes the
     combine-feedback event selection mirrored by the planner. A capture can currently supply two
     individually boolean but contradictory verdicts and both validators accept it.
   - For `type: 'mutateState'`, `action.params.target` is a string,
     `action.params.operator` is an accepted apply-state operator, and `action.params.value` is
     present (with a string value for `bind to` / `anchor to`). The footer reads these at
     `DeckLayoutFooter.tsx:452-475,509-530`; `applyState` dereferences `target.trim()` and dispatches
     on `operator` at `scripting.ts:404-478`. These mutations update the state supplied to later
     checks, so malformed or hollow members can change a later verdict while the planner/audit
     normalize the current action to `none`.
   - For `type: 'feedback'`, `action.params.feedback` must be an object with an array
     `partsLayout`, not merely be present. The footer reads the object at
     `DeckLayoutFooter.tsx:550,761-765`; `FeedbackRenderer.tsx:229-270` dereferences it and passes
     `partsLayout` to `PartsLayoutRenderer.tsx:120-123`, which calls `.map`. The current predicate
     accepts `feedback: null` and `feedback: {}` even though the product path cannot render them.

   The activation-point `kind`/`prompt` reads at `triggerCheck.ts:69-79` do not affect a transition
   plan or verdict: malformed/missing values simply fail the optional trigger predicate. They do
   not add a material row to this scoped boundary.

2. **The two validators agree with each other on the rows currently in the table, but neither
   matches the complete product boundary.** `plannableResults` / `plannableAction` and
   `replayableActions` both omit the three constraints above, so that common-mode divergence is
   not fail-closed. Conversely, both require `action.params` to be an object for *every* string
   action type (`AdaptiveJournal.ts:773-779`; `AdaptiveOracle.ts:253-261`), while the table says an
   unknown action type stays legal and derives no required params for it. That extra rejection is
   fail-closed but is stronger than the table. The `Array.isArray` versus `instanceof Array`
   implementation difference is not unsafe for JSON-parsed/deserialized records; any residual
   disagreement rejects rather than licenses a product record.

3. **The `actions.score` / `actions.out_of` validator exclusion is sound for the named framework
   consumers.** No audit, transition plan, verdict comparison, or shadow projection reads either
   member. `triggerCheck.ts:341-342,356-357,455,545-546` does consume them for attempt/session
   scoring and Redux output, so they are not unread fields; they are correctly excluded only
   because that scoring state is outside the audited plan/verdict projection.

The nine fixture edits do not hide a signal. Those tests exercise journal classification,
attribution, lifecycle, or immutability rather than malformed-response acceptance; adding
`results: []` gives them the required, consumer-tolerated `CheckResult` envelope without loosening
the guard.

**Verdict: incomplete with the verdict-reconciliation, `mutateState`, and feedback-payload rows
above.**

## Round 7

Full fresh-eyes review of the current eleven-file implementation material at base `df8c85b115`,
including the two untracked files, the revised §3.2 acceptance contract, the product emitter and
consumer paths, and every named downstream consumer. The verdict-agreement change is sound, and
the feedback-render bound stands. Two common-mode acceptance gaps still preserve false greens.

### Blockers

1. **An empty `actions.results` array is accepted even though the product emitter always replaces
   it with the default-wrong event; deleting the sole result becomes the legal rotation `none`**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:753`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:243`
   `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:68`
   `assets/src/adaptivity/rules-engine.ts:506-530`
   `assets/src/adaptivity/rules-engine.ts:577-586`

   Both acceptance legs prove only that `results` is an array. `every(...)` then accepts an empty
   one vacuously, including the outer/inner verdict-agreement check. That does not match the
   product emitter: after folding and filtering the matched events, `check()` explicitly installs
   `[defaultWrong]` whenever the result set is empty, then emits that non-empty array. The same
   fallback exists in the locally available predecessor history, so this is not a recent emitter
   quirk. The measured navigation rotation has one incorrect event with an empty **actions** array;
   it does not have an empty **results** array. Spec §3.2 currently conflates those two facts at
   line 734 by saying `results` may be empty.

   Concrete capture ordering: take the first incorrect evaluation in the legal navigation
   rotation, retain `actions.correct: false`, the causal mint, the correct navigating second
   evaluation, the visit/permit evidence and finalization, but replace its one default-wrong result
   with `results: []`. The journal leg would resolve that same body as an evaluation; the replay leg
   calls it usable; `planTransition([], null, ...)` returns `none`; and the navigation sequence
   expressly licenses `none` as the rotation's first half. The remaining mint, second evaluation,
   and terminal evidence therefore preserve the green. A current product response cannot have
   supplied that empty array.

   The tests reinforce the mistaken boundary: the journal helper at line 68 constructs
   `{correct, results: []}` as its normal evaluation envelope, while the malformed-response table
   rejects empty results only when a separately malformed LLM member is present. Require
   `results.length > 0` independently in both legs, replace lifecycle fixtures with one minimal
   product-shaped event, and witness the empty-result poison in both the live-wire classifier and
   a captured legal rotation.

   **Class:** blocker — malformed captured evidence is common-mode normalized into a specifically
   licensed plan and can preserve a false green.

2. **The `mutateState` decline has a terminal silent-error ordering; a later check is not
   guaranteed to expose the lost mutation**

   `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:777-785`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:257-268`
   `assets/src/apps/delivery/layouts/deck/DeckLayoutFooter.tsx:450-538`
   `assets/src/adaptivity/scripting.ts:395-496`

   The recorded bound depends on every malformed mutation affecting a later audited check. The
   product path does not guarantee that. For example, use a `mutateState` action with a valid
   string target (`variables.x`), present value, and an unknown operator, followed in the same
   result by navigation to `endOfLesson`. The footer builds the operation and calls
   `bulkApplyState`; `applyState` returns `{error: true}` for the unknown operator rather than
   throwing. The footer stores that result in the unused `_mutateResults`, continues through its
   score/feedback/navigation branches, and finalizes the lesson. No later evaluation exists in
   which the unapplied state can affect verdict or submitted payload.

   Both current validators accept that action because all unrecognized per-type fields fall
   through to `true`. The planner ignores it, the driver records the same terminal plan, and the
   oracle reads neither the mutation nor the ignored apply-state result. The run can therefore
   freeze green even though the response did not perform its declared state update. The same edit
   to a captured terminal evaluation is invisible to both acceptance legs.

   Closing this row does not require copying Janus state evaluation into the recorder. The
   proportionate wire check is the small product-derived surface from round 6: non-empty string
   `target`; an operator from `adding | + | subtracting | - | bind to | anchor to | setting to | =`;
   a present `value`; and a string value for `bind to`/`anchor to`. Apply that shape check
   independently in both legs and add terminal-navigation witnesses. Expression evaluation and
   mutation effects can remain product-owned.

   **Class:** blocker — the live product silently ignores the malformed mutation and can still
   reach accepted terminal evidence, preserving a false green with no later audit opportunity.

### Should-fix

None.

### Nits

None.

### Round-6 dispositions

| Round-6 item | Round-7 disposition |
|---|---|
| Outer verdict must agree with every returned event verdict | **Closed and accepted.** Both legs enforce it, including capture and live-wire witnesses. No legitimate current product path that violates it was found; false-red analysis is below. |
| Validate `mutateState` target/operator/value | **Still blocking.** The decline's “later evaluation exposes it” premise fails for the silent-error + terminal-navigation ordering in blocker 2. |
| Validate feedback payload as an object with `partsLayout` array | **Decline accepted.** Missing/non-array `partsLayout` aborts the React render before the feedback-open control can commit; the driver records `feedback-never-opened`. A renderable alternate payload follows the same audited plan and is outside the plan/verdict projection. |
| Code required `action.params` for every type while the table did not | **Closed.** The table now states the stronger rule. Unknown action types with object params remain intentionally forward-compatible. |
| Exclude `score` / `out_of` | **Accepted.** Those fields affect scoring state but no reviewed plan, verdict, attribution, or oracle comparison. |

### False-red attack on verdict agreement

I found no legitimate current product path that emits a mixed outer/inner verdict:

- The rules engine computes `isCorrect` as a disjunction over non-default matched events, then
  filters `resultEvents` to correct-only or incorrect-only before emitting the same `isCorrect` as
  the outer value (`assets/src/adaptivity/rules-engine.ts:517-530,577-581`). The default-wrong
  fallback is false in both positions.
- Trap-state scoring runs only after that filtering and changes `score`, not the selected events or
  `correct` (`rules-engine.ts:533-575`). Manual grading likewise zeros only the score.
- `combine_feedback` is a footer-side selection rule over the already returned list. It does not
  create the server response. Indeed, a mixed response would make `triggerCheck` trust the outer
  value while `DeckLayoutFooter` recomputes `every(results[].params.correct)`, causing two current
  product consumers to disagree; rejecting it is fail-closed detection, not a false red.
- The default server evaluator calls the same rules bundle through `NodeJS.call({"rules", :check})`
  (`lib/oli/delivery/attempts/activity_lifecycle/node.ex:9-17`), and the controller returns that
  decoded object unchanged as `actions` apart from score roll-up and optional LLM feedback. An
  externally deployed Lambda that returned mixed events would be incompatible with the current
  frontend for the same reason, not a legitimate alternate shape. Gate B should nevertheless run
  through the actually configured evaluator provider so deployment skew is observed rather than
  inferred away.

Thus the agreement rule is appropriately strict. The homogeneous LotE captures are only
corroboration; the ruling comes from the current emitter, both frontend consumers, and local source
history, not from sample uniformity.

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

The current call graph yields the same source universe as round 5: `armStrictRun` and the strict
driver; the journal core/recorder lifecycle; all six registry entries; driver-reachable Deck PO
identity, readiness, action, readback, media, feedback and navigation primitives;
`resolveOperations`; and the transition planner. The oracle/shadow/archive gates are judges, not
source-exit producers; the old walker and test doubles are substitute graphs. There is still no
routed live caller for `armStrictRun`, so lifecycle rows remain prospective rather than closed.

Legend: `OF(x)` is one operation failure; `OF(DI)`/`OF(IU)` are driver-internal/pre-visit
identity-unresolved; `JR` is an unresolved or unusable journal record; `RP` is an illegal recorded
plan; `CE` is the ungated causal-edge finding; `JF/FT` is finalization/freeze evidence; `∅` has no
guaranteed unique producer before the fixture boundary.

| Origin or producer call edge | Source exit | Current pinned producer |
|---|---|---|
| `AdaptiveStrictDriver.ts:104-106` → recorder attach | attach throws before a handle exists | `∅` — prospective fixture row |
| `AdaptiveStrictDriver.ts:111-154` | correlation false/stamp throw; freeze/seal/snapshot rejection | named timeout `FT`; other lifecycle exits remain prospective `∅`; detach failure at `:146-151` is swallowed/non-crossing |
| `AdaptiveStrictDriver.ts:199-219` | invalid initialization before the outer try | `∅` until validated entry preconditions are proved |
| `AdaptiveStrictDriver.ts:239-390` | fail/stop/perform, polling, quiescence, barrier, plan recording/sweep | qualified `OF`, `JR`, `RP`, `CE`, or direct `OF(DI)`; accepted empty-results and mutation poisons currently have no producer (blockers 1–2) |
| `AdaptiveStrictDriver.ts:393-565` | media/gate, registry answer/readback/barrier, feedback/ack/navigation/recheck exits | qualified readiness/gate/answer/readback/barrier/feedback/ack/navigation `OF`; direct faults become `OF(DI)` |
| `AdaptiveStrictDriver.ts:567-672` | identity/fence/operation resolution, widget, gates, answer, check, evaluation, plan, settle | pre-visit `OF(IU)`; post-visit qualified `OF` or direct `OF(DI)`; journal/plan stop retains `JR`/`RP`/`CE` |
| `AdaptiveStrictDriver.ts:674-709` | run loop, lesson-end read/stamp, outer boundary | preserves the first pending `OF`; otherwise `OF(DI)`/`OF(IU)`; stopped paths retain journal/plan/edge evidence |
| `AdaptiveJournal.ts:208-267,333-335` → driver stamps/scans | fence/permit/readback/lesson-end refusal or clone failure | entry `OF(IU)`; other edges `OF(DI)` |
| `AdaptiveJournal.ts:694-799` | evaluation response classification | witnessed malformed shapes → unresolved `JR`; empty results and malformed mutation internals still become usable (blockers 1–2) |
| `AdaptiveJournal.ts:820-1002` → strict handle | attach/freeze/seal lifecycle rejection | specified `JF/FT`; unexpected rejection remains prospective `∅` |
| `AdaptiveFamilyRegistry.ts:61-445` → driver | validation, ownership, readiness, answer, readback, resolution | qualified answer/readiness/readback `OF` |
| `AdaptiveDeckPO.ts:47-235,284-346` → driver/registry | deck/check/widget/feedback/navigation/identity/inventory exits | qualified identity/readiness/widget/check/ack/navigation `OF`; caught empty inventory becomes later answer `OF` |
| `AdaptiveDeckPO.ts:466-628,724-735,798-863,938-1216` → registry/driver | Janus/CAPI/media/widget interaction/readback exits | qualified answer/readback/readiness/gate/widget `OF`; deliberately swallowed readiness timeout remains non-crossing |
| `AdaptiveManifest.ts:631-637` → driver | malformed runtime operation selection | post-visit `OF(DI)`; validated fixture precondition otherwise |
| `AdaptiveTransitionPlanner.ts:47-114` → driver/oracle/shadow | malformed captured planner data | total/no crossing exit; upstream accepted empty results or mutation poison can false-green (blockers 1–2) |
| `AdaptiveOracle.ts:221-280` → audit boundary | malformed serialized evaluation | rejected shapes produce screen-attributed `evaluation-unusable`; empty results and mutation poison currently produce none (blockers 1–2) |

No new driver/fixture origin or producer call edge appeared since round 5; only the acceptance row's
classification changed. The next unit still owes the independent closed `B4-EXIT-SCOPE`, the
closed kind list, bidirectional inventory equality, one qualified producer per `(source origin,
source exit kind, producer call edge)` tuple, per-site fault injection, and CONFORMANCE-MAP. The
routed attach/correlate/freeze/seal/detach proof also remains owed with the first live caller, as
previously agreed.

### Consumer blast radius

- `auditRun` reports `evaluation-unusable` before the more specific verdict/payload/plan rules for
  a record that `replayableActions` rejects. `evaluateGreenCapture` keeps that code in `inScope`;
  it is not driver evidence. Therefore a newly rejected record cannot be made green by later
  projection work.
- Today both blockers pass `usable()`, so that safety path never starts. Empty results replay as
  `none`; malformed mutations are absent from the plan by design. `projectFromJournal` applies the
  same total planner to the last evaluation and reproduces those projections.
- `compareProjections` classifies diffs after receiving the already separated in-scope list; it
  never removes violations. With the blockers accepted by both legs, however, there is no
  violation for it to preserve and the shipped/shadow projection can agree.
- `expectedDriverEvidence` uses the weaker `resolution === evaluation && actions !== null`
  approximation. Empty-result and mutation-poison records remain in its expected inventory; the
  actual audit produces the same permit/plan evidence classes, so inventory equality does not
  detect either substitution. Once `evaluation-unusable` exists, the mismatch and non-empty
  in-scope list both fail closed.
- The raw archive gates do not call `usable()` or `auditRun`; they prove the manifest against the
  archive. The archive-backed **shadow gate** is the consumer that invokes `evaluateGreenCapture`.
  Consequently archive corroboration cannot repair a poisoned response body at this boundary.

The current captures remain unchanged: each green has in-scope 0, driver-evidence 65,
unexplained 0, intentional 1; the bail has one violation. Those results demonstrate no regression
on the sampled artifacts, but neither blocker is represented by them.

### Security, performance, and verification

No reviewed change introduces an answer-value disclosure, credential leak, authorization bypass,
or unredacted downstream exception. The two blockers are integrity/fail-closed defects. The added
shape checks are linear in response size and constant work per mutation; they do not justify the
deferred full-journal-clone concern being reopened.

- Exact requested private subset: **366 passed / 0 failed**. Both green shadow replays retained
  `0 / 65 / 0 / 1`; the bail retained one violation.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on the eleven reviewed implementation/test files: clean.
- Prettier on the same files: clean, with the existing ignored-plugin-option warnings.
- `git diff --check`: clean before appending this round.

### Summary

2 blockers, 0 should-fix, 0 nits. Verdict: **BLOCKED**.

## Round 8

Full fresh-eyes review of the current eleven-file implementation/test change at base
`df8c85b11571`, including both untracked strict-driver files, the revised §3.2 contract, every
scoped implementation file, the current product emitters and consumers, and all named downstream
gate consumers. The two round-7 blockers are closed. I found no new material defect.

### Blockers

None.

### Should-fix

None.

### Nits

None.

### Round-7 dispositions

| Round-7 item | Round-8 disposition |
|---|---|
| Reject empty `actions.results` independently in both acceptance legs | **Closed and accepted.** `AdaptiveJournal.ts:752-760` and `AdaptiveOracle.ts:242-248` reject the empty list before any vacuous `every`/loop can turn it into the rotation's licensed `none`. The capture poison and raw-wire poison are both exercised at `adaptive-oracle.spec.ts:2214-2330,2439-2515`. |
| Validate the declared `mutateState` shape in both acceptance legs | **Closed and accepted.** The journal leg checks the closed operator set, non-empty string target, present value, and string bind/anchor value at `AdaptiveJournal.ts:804-823`; the independently written replay leg repeats those decisions at `AdaptiveOracle.ts:276-299`. The capture poisons cover unknown operator, empty target, and non-string bind at `adaptive-oracle.spec.ts:2237-2281`; the raw-wire terminal ordering is retained at `:2470-2491`. |
| Outer verdict agrees with every result verdict | **Remains accepted.** Both legs still enforce agreement (`AdaptiveJournal.ts:765-775`; `AdaptiveOracle.ts:253-261`), and the current emitter still constructs a homogeneous result list before returning the same outer verdict. |
| Feedback render bound | **Remains accepted.** No new path makes a missing/non-renderable feedback payload reach accepted terminal evidence; the earlier decline remains sound. |
| Object `params` required for every action, including unknown types | **Remains accepted for current traffic.** Every current action producer reviewed emits an object `params`; recognized actions then receive their type-specific checks. Unknown object-shaped actions remain forward-compatible. |
| Exclude `score` / `out_of` from this projection | **Remains accepted.** No reviewed plan, verdict, attribution, or projection consumer reads those fields. |

### Emitter-derived mutation contract and false-red attack

The accepted operator set is complete with respect to the current runtime and every current
literal producer I found:

| Source | Emitted or consumed spelling | Ruling |
|---|---|---|
| `assets/src/adaptivity/scripting.ts:412-470` | `adding`, `+`, `subtracting`, `-`, `bind to`, `anchor to`, `setting to`, `=` | This is the closed runtime dispatch surface, and both validators accept exactly these eight spellings. |
| `assets/src/apps/authoring/components/AdaptivityEditor/AdaptiveItemOptions.ts:23-28` | `=`, `adding`, `bind to`, `setting to` | Every user-selectable authoring spelling is accepted. |
| `assets/src/apps/authoring/components/AdaptivityEditor/AdaptivityEditor.tsx:324-333` | new-action default `=` | Accepted. The temporary editor value is not server traffic until the authored action is persisted and evaluated. |
| `assets/src/apps/authoring/components/Flowchart/rules/create-state-action.ts:5-22` and the generated Flowchart rule files | `adding`, `setting to`, `=` | Accepted. |
| `assets/src/apps/delivery/store/features/groups/actions/deck.ts:123-195`, `assets/src/apps/delivery/store/features/adaptivity/actions/triggerCheck.ts:122-174,414-504`, `assets/src/apps/delivery/layouts/deck/DeckLayoutView.tsx:1003-1008`, and `assets/src/apps/delivery/layouts/deck/DeckLayoutFooter.tsx:597-602,639-662` | `=`, `+` | All delivery-side generated mutations are accepted. |

`subtracting`, `-`, and `anchor to` are not current literal authoring choices, but they are live
runtime compatibility spellings. Keeping them in the validator does not admit an operator the
product cannot execute. Repository history for the authoring selector did not reveal another
persisted spelling.

I also attacked the broader response boundary for legitimate-product false reds:

- **Empty results:** the rules engine filters its matched events and installs `[defaultWrong]`
  when filtering leaves no result (`assets/src/adaptivity/rules-engine.ts:506-530`), then returns
  that non-empty list at `:577-581`. Rejecting `results: []` therefore refuses capture corruption,
  not a current product response. An empty event **actions** list remains legal and accepted.
- **Mutation target/value:** current product actions supply string targets and a value; bind/anchor
  are the only runtime cases that require a string value (`scripting.ts:435-459`). Leading or
  trailing target whitespace is still accepted because the runtime trims it. A whitespace-only
  target reaches a parser error at `scripting.ts:280-304,408-483` before footer navigation, so it
  cannot be a successful legitimate terminal ordering that this validator falsely rejects or
  falsely licenses. Expression syntax and mutation effects remain product-owned, as declared.
- **Verdict agreement:** `rules-engine.ts:517-530,577-581` derives the outer verdict, selects only
  result events of that verdict, and returns them together. The server's local evaluator uses that
  rules bundle. A mixed result would also make the current attempt consumer and footer consumer
  disagree, so rejecting it is fail-closed rather than a false red.
- **Action params:** current feedback, navigation, mutation, and activation-point producers all
  create object params (including `AdaptivityEditor.tsx:316-350` and the Flowchart action
  creators), matching the shared action types at `assets/src/apps/authoring/types.ts:48-82`.
  Requiring object params for an unknown action is stricter than `processResults` needs, but no
  legitimate current producer without them was found. Unknown types with object params remain
  accepted.

The two acceptance legs still make these decisions independently: the journal uses
`Array.isArray`, a shared constant plus `indexOf`, and `plannableMutation`; the oracle uses
`instanceof Array` and an explicit comparison chain. Their decisions agree for JSON wire bodies
and deserialized captures without sharing the implementation that could reproduce one bug in both
places.

### Fixture-rewrite proof preservation

The product-shape rewrites did not change what the affected tests prove:

| Spec | Rewrite | Why the original proof is preserved |
|---|---|---|
| `adaptive-attribution.spec.ts:30-68` | The two evaluation helpers now wrap the verdict in one minimal product-shaped result event with an empty action list. | Attribution is decided from request path, attempt GUID, lineage, and fence/visit sequencing. The added result envelope contributes no navigation, feedback, mutation, or ownership fact, so the attribution assertions exercise the same cause. |
| `adaptive-journal.spec.ts:65-68,153-191,230-278,538-540,638-644,782-786` | Normal successful evaluation fixtures now carry the same one-event envelope; malformed-body tests still supply their malformed bodies directly. | Lifecycle, stamping, immutability, request classification, and freeze proofs retain their original requests and assertions. The added empty action list plans `none` but none of those rewritten cases uses it to prove a transition. Malformed-shape acceptance remains isolated in the explicit negative rows. |
| `adaptive-oracle.spec.ts:2214-2515` | Control evaluations use the minimal product event; capture poisons mutate the captured `actions` body and raw-wire poisons are sent as exact response bodies. | The legal navigation rotation, ownership, permits, and terminal evidence are unchanged. Each test compares a product-shaped control with one altered acceptance field, so the new envelope strengthens the claimed boundary instead of supplying the expected finding through a helper artifact. |

### Re-derived exit-site set (B4-EXIT-SCOPE / B4-EXIT-INV input)

The source universe is unchanged from round 7: `armStrictRun` and the strict driver; journal
core/recorder lifecycle; all registry entries; every driver-reachable Deck PO identity, readiness,
action, readback, media, feedback, and navigation primitive; `resolveOperations`; and the
transition planner. Oracle, shadow, and archive code are judges rather than source-exit producers;
the old walker and test doubles are substitute graphs. `armStrictRun` still has no routed live
caller outside its declaration, so its lifecycle rows remain prospective.

Legend: `OF(x)` is one operation failure; `OF(DI)`/`OF(IU)` are driver-internal/pre-visit
identity-unresolved; `JR` is an unresolved or unusable journal record; `RP` is an illegal recorded
plan; `CE` is the ungated causal-edge finding; `JF/FT` is finalization/freeze evidence; `∅` has no
guaranteed unique producer before the fixture boundary.

| Origin or producer call edge | Source exit | Current pinned producer |
|---|---|---|
| `AdaptiveStrictDriver.ts:104-106` → recorder attach | attach throws before a handle exists | `∅` — prospective fixture row |
| `AdaptiveStrictDriver.ts:111-154` | correlation false/stamp throw; freeze/seal/snapshot rejection | named timeout `FT`; other lifecycle exits remain prospective `∅`; detach failure at `:146-151` is swallowed/non-crossing |
| `AdaptiveStrictDriver.ts:199-219` | invalid initialization before the outer try | `∅` until validated entry preconditions are proved |
| `AdaptiveStrictDriver.ts:239-390` | fail/stop/perform, polling, quiescence, barrier, plan recording/sweep | qualified `OF`, `JR`, `RP`, `CE`, or direct `OF(DI)`; empty results and malformed declared mutation shape now stop as `JR` rather than entering the planner |
| `AdaptiveStrictDriver.ts:393-565` | media/gate, registry answer/readback/barrier, feedback/ack/navigation/recheck exits | qualified readiness/gate/answer/readback/barrier/feedback/ack/navigation `OF`; direct faults become `OF(DI)` |
| `AdaptiveStrictDriver.ts:567-672` | identity/fence/operation resolution, widget, gates, answer, check, evaluation, plan, settle | pre-visit `OF(IU)`; post-visit qualified `OF` or direct `OF(DI)`; journal/plan stop retains `JR`/`RP`/`CE` |
| `AdaptiveStrictDriver.ts:674-709` | run loop, lesson-end read/stamp, outer boundary | preserves the first pending `OF`; otherwise `OF(DI)`/`OF(IU)`; stopped paths retain journal/plan/edge evidence |
| `AdaptiveJournal.ts:208-267,333-335` → driver stamps/scans | fence/permit/readback/lesson-end refusal or clone failure | entry `OF(IU)`; other edges `OF(DI)` |
| `AdaptiveJournal.ts:688-836` | evaluation response classification | malformed outer body, empty results, verdict disagreement, malformed nested action, invalid mutation, and invalid LLM feedback remain unresolved and become `JR` |
| `AdaptiveJournal.ts:858-1035` → strict handle | attach/freeze/seal lifecycle rejection | specified `JF/FT`; unexpected rejection remains prospective `∅` |
| `AdaptiveFamilyRegistry.ts:61-445` → driver | validation, ownership, readiness, answer, readback, resolution | qualified answer/readiness/readback `OF` |
| `AdaptiveDeckPO.ts:47-235,284-346` → driver/registry | deck/check/widget/feedback/navigation/identity/inventory exits | qualified identity/readiness/widget/check/ack/navigation `OF`; caught empty inventory becomes later answer `OF` |
| `AdaptiveDeckPO.ts:466-628,724-735,798-863,938-1216` → registry/driver | Janus/CAPI/media/widget interaction/readback exits | qualified answer/readback/readiness/gate/widget `OF`; deliberately swallowed readiness timeout remains non-crossing |
| `AdaptiveManifest.ts:631-637` → driver | malformed runtime operation selection | post-visit `OF(DI)`; validated fixture precondition otherwise |
| `AdaptiveTransitionPlanner.ts:47-114` → driver/oracle/shadow | malformed captured planner data | total/no crossing exit; both acceptance legs now prevent the round-7 poisons from reaching it as usable evidence |
| `AdaptiveOracle.ts:221-314` → audit boundary | malformed serialized evaluation | rejected shape becomes screen-attributed `evaluation-unusable`; empty results and malformed declared mutation shape now take this path |

No new driver/fixture origin or producer call edge appeared since round 7. The next unit remains
the independent closed `B4-EXIT-SCOPE`, closed kind list, bidirectional inventory equality,
exactly one qualified producer for every `(source origin, source exit kind, producer call edge)`
tuple, per-site fault injection, and CONFORMANCE-MAP. The first routed live caller still owes the
attach/correlate/freeze/seal/detach proof.

### Consumer blast radius

- `replayableActions` refusal makes `usable` false at `AdaptiveOracle.ts:221-314`; `auditRun` then
  emits screen-attributed `evaluation-unusable` before verdict, payload, navigation, or plan
  agreement can license that record.
- `evaluateGreenCapture` retains `evaluation-unusable` in `inScope`
  (`AdaptiveShadowProjector.ts:638-653`); that code is not in the driver-evidence partition. A
  poisoned record therefore makes the green gate fail even if every later projection agrees.
- `projectFromJournal` is intentionally a simpler ledger projection and may still derive a total
  plan from the captured record (`AdaptiveShadowProjector.ts:541-570`). It cannot erase the
  already-retained oracle violation. `compareProjections` only adds shipped/shadow differences
  and consults oracle violations for classifications (`:576-635`); it never removes a violation.
- `expectedDriverEvidence` deliberately uses the weaker resolved-evaluation approximation. A
  poisoned record can therefore leave its expected driver inventory unchanged, but that does not
  restore green: the non-empty in-scope list independently fails. If the poison also changes
  actual driver evidence, bidirectional inventory comparison adds a second failure.
- The raw archive gates validate archive and manifest facts and do not reinterpret response
  bodies. The archive-backed shadow gate calls `evaluateGreenCapture`; archive corroboration
  therefore cannot launder a malformed evaluation into accepted runtime evidence.

### Security, performance, and verification

No reviewed change introduces answer-value disclosure, credential leakage, authorization bypass,
or an unredacted exception path. The two new guards do constant work per action/result while
traversing an already-consumed response, so there is no material performance regression or new
unbounded operation.

- Exact requested private subset: **366 passed / 0 failed**. Both green shadow replays retained
  `in-scope=0`, `driver-evidence=65`, `unexplained=0`, `intentional=1`; the bail replay retained one
  `auditRun` violation.
- `tsc --noEmit`: exactly the two fenced `liveSocket` errors at `CourseManagePO.ts:130` and
  `ProductsPO.ts:93`, no others.
- ESLint on the eleven reviewed implementation/test files: clean.
- Prettier on the same files: clean, with only the existing ignored import-order-option warnings.
- `git diff --check`: clean before appending this round.

### Summary

0 blockers, 0 should-fix, 0 nits. Verdict: **DONE — NOT BLOCKED** for the current strict-driver
implementation review. The separately scoped gate-B exit-inventory unit listed above remains the
next unit; it is not a defect in this reviewed implementation increment.

## Round 9 — exit-site inventory and per-site fault injection

Fresh review of the five-file piece-4 material at base `b5aaadc039`, using the current working tree
and independently re-deriving the source universe and exit set. The 80-test focused run
(`adaptive-exit-inventory` + `adaptive-strict-run`) passes, but the evidence is green while several
mandatory EXIT predicates are false.

### Blockers

1. **B4-EXIT-SCOPE is not closed, and the claimed interior collapse is false.**
   `assets/automation/gate-evidence/mer-5865-exit-inv.json:33-45` declares that a fault anywhere in
   a wrapped callee's transitive interior reaches `perform(K)`, but the production PO deliberately
   catches many such faults. For example, `AdaptiveDeckPO.ts:53-57` swallows the footer-readiness
   rejection and returns normally from `waitForDeckReady`, and `:64-69` turns an evaluation failure
   into `false`; a one-shot fault at either interior site can therefore emit no `OperationFailure`
   at all. The artifact individually excludes only the `widgetFrame` readiness timeout
   (`mer-5865-exit-inv.json:72-75`). It also omits the actually executed fixture module
   `tests/torus/student_delivery/adaptiveStrictDeck.ts` from `scope.declared`, even though
   `driveScripted` constructs and passes that implementation to the real driver at `:485-503` and
   faults from its methods cross the driver's outer boundary. This is W-E0a red; F-3's disposition
   at `mer-5865-exit-inv.json:102-106` is not true.

2. **F-2 remains open: initialization can still escape before the boundary, and W-E1 cannot see it.**
   `AdaptiveStrictDriver.ts:221` still executes `new Map()` before the `try`; faulting that
   constructor exits with no run record. The same is true of throwing getters/proxy traps while
   normalizing `options.timeouts`, `options.sleep`, or `options.now` at `:199-201`. The artifact's
   exclusion calls these operations total and cites stale line numbers
   (`mer-5865-exit-inv.json:76-79`), while its W-E2-PRETRY case faults only
   `manifest.screens.map` inside the boundary at `AdaptiveStrictDriver.ts:677`. The source-derived
   regex at `adaptive-exit-inventory.spec.ts:72-91` does not match `new Map`, `now()`, or option
   normalization, so the supposedly independent set check cannot discover these omissions.

3. **The artifact does not preserve the agreed origin qualification and therefore does not pin one
   producer per site.** `mer-5865-exit-inv.json:10-12` claims every call-edge row is single-valued,
   but EX-23 pins two producers (`:422-429`), EX-69 pins `JR | OF(ack-no-effect)`
   (`:1066-1073`), EX-95/96 pin two and five producers (`:1430-1451`), EX-102/104 pin unions
   (`:1528-1563`), EX-108 says `every producer above` (`:1612-1619`), and EX-111 pins both
   pre/post-visit kinds (`:1654-1661`). Several are incomplete as well: the `awaitSavedBarrier`
   edge at driver `:473` can reject with its barrier timeout or with `OF(driver-internal)` from
   `journal.records`/`sleep`; both `awaitEvaluation` edges can additionally reject with
   `OF(driver-internal)`; and `followPlan` can additionally retain `JR` or emit
   `OF(driver-internal)` from `issuePermit`/`recordPlan`. Round 7 required one tuple per
   `(source origin, source exit kind, producer call edge)`. The test at
   `adaptive-exit-inventory.spec.ts:586-596` only rejects an empty producer string, so every union
   passes its “exactly one” assertion.

4. **W-E2/W-U8 is weaker than the sites it claims, and many `covered-by` dispositions do not drive
   the cited edge.** The “PO interior” witness at `adaptive-exit-inventory.spec.ts:317-321` injects
   `ScriptedDeck.selectMcqByText` (`adaptiveStrictDeck.ts:217-220`), not the real
   `AdaptiveDeckPO.selectMcqByText` and its caught/retried interior (`AdaptiveDeckPO.ts:466-500`).
   The artifact-to-run check then looks up rows by line only and accepts substring membership
   (`adaptive-exit-inventory.spec.ts:665-673`), so it neither proves the named callee nor exact
   producer identity. Concrete false `covered-by` citations include EX-34: W-E2-MEDIA throws at
   driver `:405`, so `deck.clickThroughCarousels` at `:406` is never called
   (`mer-5865-exit-inv.json:576-587`); EX-43: the cited unknown-family test exits at
   `resolveFamily`, before `validateDirective` (`:702-713`); EX-22 cites the `none`-plan test at
   driver `:524`, not the unusable-evaluation stop at `:318`; and EX-72 explicitly cites a sibling
   arm that never reaches the re-check-kind guard (`:1108-1119`). The polling citations are also
   non-equivalent: returning `outstanding() === 1` takes `sleep` at driver `:284` and never executes
   `wireEventCount`/the quiescent sleep at `:280-282`. This fails per-site activation even though
   all 60 tests pass.

5. **W-E4/W-E5 covers a sample, not the required journal matrix.** The test titled “a
   completed-failure freeze” at `adaptive-exit-inventory.spec.ts:801-807` calls
   `beginSeal`/`finishSeal`; it never enters terminalization or calls
   `markFrozenCompletedFailure`, so it is another ordinary sealed snapshot. The only existing
   completed-failure audit case uses `already_submitted`
   (`adaptive-oracle.spec.ts:1199-1224`); the other four closed reasons (`missing`, `uncorrelated`,
   `malformed`, `failed`, declared at `AdaptiveJournal.ts:17-22`) are crossed only with journal
   state-machine assertions, not with `auditRun`. The new W-E5 case at
   `adaptive-exit-inventory.spec.ts:810-820` leaves its operation-failure record present rather
   than suppressing it, so it does not test the contract's open-window zero-positive boundary.
   `freeze_timeout` has an existing positive audit witness and the closed/seal-incomplete
   distinction has an existing sampled witness, but freeze flavor × reason and open/closed ×
   complete/incomplete are not total.

### Should-fix

None separate from the blockers.

### Nits

None.

### Coverage-disposition rulings

| Disposition | Ruling |
|---|---|
| 6 `prospective` | Accepted as intentionally deferred with the first routed `armStrictRun` caller. The constructor edge at driver `:105` is nevertheless absent from the prospective list. |
| 3 `not-faultable` | Accepted on the reachable domain: `submittedPaths` receives journal-normalized arrays, `planTransition` receives plain captured/live data, and all current `savedBarrier` implementations are pure templates. |
| 6 `excluded` | The local logging and detach catches are sound. EX-02/EX-03/EX-12 are not exit sites and should not be counted as inventory rows. The freeze fallback is only journal-evidenced for a real freeze-timeout, not for an arbitrary injected rejection. The scope-level exclusion list is not exhaustive over reachable PO catches. |
| 54 `covered-by` | Not acceptable as a class. Wrapper/delegation rows are covered only when a named child injection actually reaches that exact wrapper with a single qualified origin. EX-34, EX-43, EX-22, EX-72, EX-17/18/19 and the multi-producer delegation rows above fail that test. Execution of a sibling or normal-path call is not W-E2 fault injection. |

### Delta-discipline ruling

The harness extraction is sound and does not require the production delta-list amendment. The
base and current `adaptive-strict-run.spec.ts` each expose the same 20 test titles in the same
order, and `adaptiveStrictDeck.ts` is a non-spec support module. The extraction changes neither
the file+title test identities nor the production compat/strict graph. This is materially different
from moving the compat walker, which would change the production graph DIFF/DEL are supposed to
constrain.

### Derived EXIT-SCOPE

Files in my current source universe:

1. `assets/automation/src/systems/torus/tasks/AdaptiveStrictDriver.ts` — entry and outer boundary.
2. `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts` — core stamps/scans and prospective recorder lifecycle.
3. `assets/automation/src/systems/torus/tasks/AdaptiveFamilyRegistry.ts` — resolver and all six entries.
4. `assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts` — production identity/readiness/action/readback/media/navigation primitives.
5. `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts` — runtime `resolveOperations` path.
6. `assets/automation/src/systems/torus/tasks/AdaptiveTransitionPlanner.ts` — online planner path.
7. `assets/automation/tests/torus/student_delivery/adaptiveStrictDeck.ts` — the fixture implementation actually passed to the driver by both reviewed specs.

Accepted file exclusions: `AdaptiveOracle.ts` (post-walk judge), shadow/archive/predicate modules
(separate judges), and the old walker modules (substitute production graph). The injection spec
itself is evidence machinery, not a source producer. Non-crossing site exclusions must still list
each reachable local catch; the current artifact does not do that for the production PO.

Bidirectional comparison: file 7 is derived-but-undeclared (W-E0a). No declared production file is
absent from my universe (no W-E0b file mismatch), although the declared `AdaptiveDeckPO` interior
is not exercised by the current W-E2 harness.

### Derived exit-site list at the current revision

Call-edge identity is used per the human ruling, with the round-7 origin-preservation qualification.
Comma-separated line numbers below are separate sites; `x2` means two distinct callees on one line.

| Producer / disposition | Current source sites |
|---|---|
| Prospective lifecycle, no producer yet | driver `:105` constructor, `:106` attach, `:127` correlation stamp, `:136` lesson-end read, `:140` and `:144` seal, `:154` snapshot |
| Non-crossing exclusions | driver `:113-125` correlation read/catch, `:138-141` freeze fallback only when the journal already recorded the failure, `:148-151` detach, `:204-209` log; plus every reachable PO-local caught site, beginning at PO `:53-57` and `:64-69` |
| Pre-boundary, no producer (artifact omissions) | driver `:199` timeout normalization, `:200` sleep option/default, `:201` now option/default, `:221` empty `Map` construction |
| `OF(identity-unresolved)` | driver `:574`, `:575`, `:576`, `:577`, `:579`, `:585`, `:677` `manifest.screens.map`, and the distinct `new Map(...)` edge also at `:677` |
| `OF(driver-internal)` direct/unwrapped | driver `:279`, `:280`, `:281`, `:282`, `:284`, `:305`, `:332`, `:345`, `:366`, `:389`, `:392`, `:465`, `:471`, `:483`, `:531`, `:550`, `:596`, `:616`, `:632`, `:638`, `:652`, `:664`, `:667`, `:685` x2; omitted `now()` edges at `:277`, `:286`, `:302`, `:324`, `:342`, `:358` |
| Wrapped `OF(readiness-timeout)` | driver `:404→405/406`, `:456→457`, `:649→650` |
| Wrapped `OF(gate-unsatisfied)` | driver `:411→413`, `:411→417`, `:411→420` |
| Wrapped `OF(answer-failed)` | driver `:430→435`, `:442→443`, `:442→448`, `:451→452`, `:451→453`, `:459→460` |
| Wrapped `OF(readback-failed)` | driver `:462→463` |
| Wrapped navigation/feedback/ack/widget failures | driver `:496→497`, `:501→502`, `:528→529`, `:533→534`, `:604→610/611/612`, `:618→624/625`, `:629→630`, `:654→655` |
| Typed failure-path exits | driver `:325` split by caller origin into check-click and ack; `:359` barrier; `:633` traffic; `:668` traffic |
| Journal-side stop exits | driver `:318` JR, `:524` RP, `:552` CE, `:559` RP; generic `stop` at `:259` is qualified by these origins, not a fifth union-valued site |
| Delegating sites that require origin expansion | driver `:473` barrier/DI; `:549` JR/ack/DI; `:643` readiness/gate; `:646` answer/readiness/readback/barrier/DI; `:658` JR/check/DI; `:665` RP/CE/JR/feedback/ack/navigation/DI; `:681` every qualified `runStep` origin |
| Outer boundary | driver `:687`, qualified by the preserved pending/stopped origin; it is not one `OF(driver-internal) | OF(identity-unresolved)` site |

Artifact-only rows absent from my exit set: EX-02 (`recorder.core` property), EX-03 (a second row
for the same `page.evaluate` expression head), and EX-12 (`paths.push` mislabeled as not a call).
EX-04, EX-07, and EX-10 are exclusion evidence, not members of the closed exit set. Derived-but-
absent sites are driver `:105`, `:199-201`, `:221`, the six `now()` calls, the `new Map` call edge
at `:677`, the fixture module's crossing methods, and the reachable PO-local catches that disprove
the fold. Multi-producer artifact rows must be replaced by the qualified tuples listed above.

### Security, performance, and verification

No new credential/answer disclosure or authorization surface was found. The test-only extraction
does not add a production performance path. Focused verification: **80 passed / 0 failed** in
19.3 seconds. Static base/current title comparison: **20 vs 20, identical order and content**.

### Summary

5 blockers, 0 should-fix, 0 nits. Verdict: **BLOCKED — EXIT-SCOPE, EXIT-INV, EXIT-EM and EXIT-MAP
are red despite the green focused suite.**
