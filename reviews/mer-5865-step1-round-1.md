# MER-5865 step 1 — implementation review round 1

**Verdict:** BLOCKED

**Counts:** 6 blockers, 4 should-fix, 0 nits

## Blockers

### B1. Live response ordering is stamped at body-parse completion, not at the observed response event

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:523`

`onResponse` starts `response.text()` and calls `core.ingestResponse` only when that promise settles; `ingestResponse` allocates `responseSeq` at that later time (`AdaptiveJournal.ts:159-168`). A follow-up request or identity fence can therefore enter the core after Playwright observed the response but before its body finishes reading, and receive a lower seq. That violates the journal's one observed-event order (§3.2/§3.3) and is weaker than the shipped observer, which stamps `responseSeq` synchronously in the `response` callback before parsing (`AdaptiveEvaluationObserver.ts:100-115`). In particular, a valid POST mint can acquire `responseSeq >=` the evaluation request it causally enabled, causing `guidInLineage` to reject a legal rotation; responses can also be moved across an entry fence. Reserve the response seq synchronously in `onResponse`, then complete the parsed fields asynchronously without changing that stamp or treating parsing completion as the wire event.

### B2. A request arriving between the outstanding drain and quiescence sampling makes accepted freeze throw

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:591`

After `outstanding()` reaches zero, `awaitFreeze` leaves the drain loop and enters `awaitQuiescence`. If a tracked request arrives before `awaitQuiescence` samples `wireEventCount`, that request is already included in `seen`; if it then remains outstanding for one quiescence interval, the counter stays stable, `awaitQuiescence` returns, and `markFrozenAccepted` throws on the outstanding guard (`AdaptiveJournal.ts:603-605`) instead of restarting drain → quiescence. This is the normal post-zero arrival race §3.2 and §8 explicitly require the adapter to absorb. Make drain plus quiescence a retrying guarded loop (or include `outstanding() === 0` in the quiescence success predicate) so an arrival cannot turn a valid lifecycle into an exception.

### B3. Terminalized response/failure events do not restart completed-failure quiescence

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:159`

Persistent terminalization marks outstanding and new requests `unterminated`. When one of those requests later produces a response or `requestfailed`, both ingestion methods return on `record.terminal !== null` before incrementing `wireEvents` (`AdaptiveJournal.ts:161-163,171-175`). The adapter can consequently freeze after `quiescenceMs` from terminalization even though a response/failure was observed inside that interval. That is not the full no-new-traffic interval required by §3.2's “quiescence judged over the terminalized stream,” and it weakens the residual bound around detach. Preserve the terminal record, but count subsequent observed terminal events for quiescence.

### B4. Completed-failure freeze can hang forever under a continuing terminalized stream

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:625`

`awaitQuiescence` has no total deadline; any request stream with gaps shorter than `quiescenceMs` restarts it forever. In completed-failure mode the requests are terminal immediately, but the recorder still never reaches `markFrozenCompletedFailure`. That contradicts §3.2's guarantee that post-deadline arrivals can restart quiescence but cannot hang the freeze. The completed-failure path needs a bounded terminalization/quiescence policy (or the spec must explicitly relax that guarantee); the current loop is unbounded.

### B5. Recursive lineage accepts child mints that happened before their parent attempt existed

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveAttribution.ts:106`

`guidInLineage` filters every mint only by `mint.responseSeq < evaluation.requestSeq`, then repeatedly closes the graph without respecting edge order. It therefore accepts this illegal sequence: `B -> C` mint completes, then `A -> B` mint completes, then an evaluation uses `C`; the fixed-point first adds `B` and then retroactively adds `C`, even though the `B -> C` request was not rooted when observed. §3.3 requires recursively rooted, causally ordered mints, not merely a graph whose edges all finish before the final evaluation. Grow lineage in event order and accept a mint only when its target was already in lineage before that mint request (and its response precedes the using evaluation).

### B6. Sealed/frozen journal data remains mutable through public core APIs

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:139`

`noteLessonEnd` has no state guard, so it can change `lessonEndSeq` after a failure snapshot has been sealed; two calls to `snapshot()` can then return different audited objects. In addition, `records()` and `fences()` return the core's live objects (`AdaptiveJournal.ts:188-193`): the array type is readonly, but each `JournalRecord`/`FenceStamp` remains writable, so retained callers can alter terminal records or fences after seal/freeze and those changes appear in later snapshots. `structuredClone` protects an already returned snapshot but does not close these mutation paths. Guard every mutator in terminal states and expose clones/deep-readonly views rather than internal objects so the audited object is immutable as §3.2 requires.

## Should-fix

### SF1. An accepted finalization does not win while any duplicate finalization is outstanding

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:203`

`finalizationStatus` returns `pending` if *any* page-finalization record is outstanding before it searches for an accepted record (`AdaptiveJournal.ts:204-206`). Thus one accepted correlated finalization plus one response-less duplicate times out as `missing` and takes completed-failure freeze, despite the method's own contract saying an accepted record wins outright. Search terminal accepted records first; only report pending when no accepted record exists and a candidate can still determine the result.

### SF2. A settled accepted finalization can be relabeled as a finalization failure

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:591`

If finalization is accepted but some other journal request does not settle before `settleTimeoutMs`, `awaitFreeze` calls `enterTerminalization('failed')` (`AdaptiveJournal.ts:594-597`). The resulting completed-failure snapshot claims `finalizationFailure: {reason: 'failed'}` even though its finalization record is accepted. §3.2 defines that failure record for missing/rejected finalization, so this invents an unnamed third completed-failure trigger and will make the later terminal audit misreport the evidence. Model an outstanding-drain failure separately, or amend the contract and failure union explicitly rather than attributing it to finalization.

### SF3. `sealIncomplete` trusts a caller-provided boolean instead of the sealed membership

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:318`

`finishSeal(true)` is accepted even with pre-cutoff records still outstanding; it then terminalizes those members while emitting `sealIncomplete: false`. Conversely, `finishSeal(false)` can mark a fully settled audited set incomplete. The recorder currently passes the expected value, but the pure core's public transition does not enforce §3.2's semantics. Derive/validate settled state from outstanding pre-cutoff members at the transition so a complete snapshot cannot contain an `unterminated` member.

### SF4. The §8 step-1 matrices omit the races and negative combinations most likely to expose the findings above

**Location:** `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:167`

The tests cover representative branches, not the exhaustive mutation-style matrices required by §8. Specific missing cases are:

- each wrong/missing correlation field crossed with non-2xx, wrong `result`, command failure, and `already_submitted`; an accepted record concurrent with a response-less duplicate;
- completed-failure freeze for every rejection reason, including a response-less finalization, a delayed terminalized response/failure during quiescence, and immutable state after both freeze flavors;
- an accepted-path request arriving after the zero-outstanding observation but before quiescence sampling, plus a response whose body parsing completes after a causally later request/fence;
- mismatched method/URL classification rows, rather than only each positive class;
- `finishSeal(true)` with an outstanding cutoff member and post-seal mutation attempts.

The three live adapter tests (`adaptive-journal.spec.ts:363-460`) route immediate responses and await every `fetch`, so none produces the genuinely asynchronous response completion or post-zero late traffic required by §8. Attribution also lacks a reversed recursive-mint test and an explicit proof that a foreign payload prefix cannot change window ownership (`assets/automation/tests/torus/student_delivery/adaptive-attribution.spec.ts:149-231`). Add those negatives so the tests fail under each defect above rather than only confirming the happy ordering.

## Nits

None.

---

## Writer response — round 1 (Claude, 2026-08-05)

All 6 blockers and 4 should-fixes accepted and addressed. No pushback.

- **B1 fixed** — responses are two-phase: `ingestResponse(handle, status)` stamps `responseSeq`
  synchronously at the observed event; `ingestResponseBody(handle, body)` fills parsed fields
  later and never moves the stamp. A record with a stamped event but unparsed body counts as
  outstanding, so freeze/settle still wait for evidence. Adapter stamps in the `response`
  callback before `response.text()`. Tests: "two-phase response stamping" describe block.
- **B2 fixed** — accepted path is one retrying drain→quiescence loop; the freeze predicate is
  `wireEventCount stable AND outstanding === 0` after a full interval. A post-zero arrival
  restarts the loop. Live test starts the freeze first, lands a delayed request mid-quiescence.
- **B3 fixed** — `ingestResponse`/`ingestRequestFailed` bump `wireEventCount` BEFORE the
  terminal-record guard, so terminalized-stream events restart quiescence while the terminal
  record itself stays immutable. Body-parse completion deliberately does not bump (it is not a
  wire event — B1). Test: "events for terminalized records still count".
- **B4 fixed** — `awaitFreeze` takes `freezeTimeoutMs` (default 60 s). In completed-failure mode
  the deadline freezes anyway (terminalization keeps outstanding at zero); live spam-interval
  test proves a sub-interval stream delays but cannot hang.
- **B5 fixed** — lineage is grown in event order with an entered-at map: a mint extends the
  lineage only when its target entered the lineage BEFORE the mint's requestSeq. The reversed
  B→C-then-A→B sequence is now a violation; an overlapping but causally ordered chain still
  roots. Both directions tested.
- **B6 fixed** — `noteLessonEnd` guarded to `armed`; `records()`/`fences()` return
  `structuredClone`s; sealed/frozen reject every mutator and late ingest calls are no-ops.
  Tests: "audited-state immutability" describe block.
- **SF1 fixed** — `finalizationStatus` scans for an accepted terminal record FIRST; pending only
  when no accepted record exists and a candidate is still in flight.
- **SF2 fixed by design choice** — an accepted finalization whose surrounding traffic never
  quiesces within `freezeTimeoutMs` now THROWS (`… seal instead`); the fixture's failure path
  seals and the sealed snapshot carries the evidence. No invented finalization-failure reason;
  §3.2's union remains finalization-only. `enterTerminalization('failed')` from the drain path
  is gone.
- **SF3 fixed** — `finishSeal()` takes no argument; `seal_incomplete` is derived from
  outstanding pre-cutoff members at the transition. A settled set cannot be marked incomplete
  and an unterminated member cannot hide in a "complete" snapshot. Post-seal-marker-outstanding
  case tested.
- **SF4 addressed** — added: mismatched method×URL classification rows; wrong-correlation-field
  × response-shape cross; correlated non-2xx and wrong-`result` rejections; accepted-wins-over-
  in-flight-duplicate; completed-failure snapshot for every rejection reason; terminalized-
  stream quiescence events; immutability after both freeze flavors and post-seal mutation
  attempts; genuinely async live tests (fire-and-forget fetches, delayed routes): post-zero
  arrival mid-quiescence, spam stream vs freeze deadline, accepted-but-hanging throw→seal;
  attribution reversed-recursive-mint and foreign-prefix-cannot-change-ownership.

State: 122/122 stub tests green (58 journal/attribution, 64 shipped strict untouched);
tsc/eslint/prettier clean on the four files.
