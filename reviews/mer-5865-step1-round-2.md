# MER-5865 step 1 — implementation review round 2

**Verdict:** BLOCKED

**Counts:** 3 blockers, 3 should-fix, 0 nits

## Round-1 verification

| Round-1 finding | Verification |
|---|---|
| B1 response-event sequencing | Resolved: `ingestResponse` now stamps synchronously before the asynchronous body read. A different response→failure lifecycle defect remains as R2-B1. |
| B2 post-zero accepted-freeze race | Resolved: outstanding drain and quiescence are one retrying predicate. |
| B3 terminalized events omitted from quiescence | Resolved in the core: response/failure events increment `wireEvents` before the terminal guard. The live adapter can still drop a post-response failure (R2-B1). |
| B4 unbounded completed-failure quiescence | Resolved: completed-failure has a forced freeze deadline. |
| B5 retroactive lineage graph closure | Resolved: response-ordered growth admits an edge only when its parent predates the mint request. |
| B6 terminal immutability | Not fully resolved: cloned accessors and state guards are present, but `issueFence` still returns the stored mutable object and correlation remains mutable (R2-B3). |
| SF1 accepted finalization blocked by duplicate | Resolved: a completed accepted record is checked first. |
| SF2 accepted finalization relabeled failed | The false finalization reason is removed, but the replacement throw→seal handoff lacks guaranteed positive audit evidence (R2-B2). |
| SF3 caller-controlled `sealIncomplete` | Resolved: `finishSeal()` derives it from cutoff members. |
| SF4 missing §8 negatives | Partially resolved; remaining contract gaps are listed in R2-SF3. |

## Blockers

### B1. A request that fails after response headers is recorded as completed and its `requestfailed` event is dropped

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:569`

`onResponse` deletes the request handle immediately, stamps the response, and lets `response.text()` finish the record. Playwright's documented lifecycle permits `requestfailed` to replace `requestfinished` even when a `response` event was already emitted ([Playwright Request lifecycle](https://playwright.dev/docs/api/class-request)); when that happens, `onRequestFailed` finds no handle and returns. The body-read rejection instead calls `ingestResponseBody(handle, null)`, which sets `terminal: 'completed'` (and, for evaluation/finalization, a parse error). The journal therefore loses the required terminal failed record and does not count the actual failure event for quiescence. The core is also not ready for this valid order: if `ingestRequestFailed` is called after phase 1 while the record is still pending, it overwrites the original `responseSeq` while retaining the response status (`AdaptiveJournal.ts:197-205`). Keep correlation through the network terminal event and explicitly model response-headers → requestfailed without rewriting the observed response stamp or misclassifying the record as completed.

### B2. The accepted-finalization throw→seal path can still produce a zero-violation bail

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:649`

Throwing and sealing is the right snapshot choice among the existing freeze flavors: accepted-freeze is dominated because it would certify a non-quiescent journal, and completed-failure freeze is dominated because it would fabricate a finalization failure. But the thrown freeze-timeout is not represented anywhere in the spec's closed operation-failure union or in the sealed journal. A stream of successfully completed informational PATCH saves (or non-required creations) can keep `wireEventCount` changing until the deadline while leaving zero outstanding; `awaitFreeze` throws, `seal()` produces a complete sealed snapshot, saves/creations remain informational, and sealed audits skip end-of-run invariants. Nothing then guarantees the §3.2 requirement that an ordinary bail maps to at least one positive violation. Preserve the throw→seal choice, but make this timeout typed positive audit evidence—requiring an explicit spec amendment to the closed failure union or an equivalent failure field the oracle must map. Do not alias it to an existing operation failure whose semantics differ.

### B3. Terminal immutability is still bypassable through retained fence and correlation references

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:143`

`issueFence` pushes `stamp` into `fenceLog` and returns that same mutable object. A caller can retain it, seal/freeze the journal, then change `stamp.screenId`; the next snapshot reflects the mutation despite cloned `fences()` access. The immutability test retains this object but mutates only a separate `fences()` clone, so it does not exercise the leak. `setRunCorrelation` is also unguarded and stores the caller's object by reference (`AdaptiveJournal.ts:138-140`): after an accepted freeze, changing or replacing it can make `finalizationStatus()` contradict the frozen flavor. Store/return copies and make correlation one-time/armed-only so no retained reference or post-terminal mutator can change audited terminal semantics.

## Should-fix

### SF1. A completed rejection is relabeled `missing` when a duplicate remains in flight until the deadline

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:642`

Without an accepted record, `finalizationStatus` deliberately stays pending while any candidate is in flight. At the timeout, however, `awaitFreeze` unconditionally calls `enterTerminalization('missing')`. Thus a completed correlated `already_submitted`/failed response—or a completed uncorrelated/malformed response—plus a response-less duplicate freezes with reason `missing`, discarding the observed rejection reason. This is precisely the §8 “each reason × terminalization of a response-less finalization” cross-product. At expiry, preserve the strongest completed rejection and use `missing` only when no rejection evidence exists; accepted must continue to dominate both.

### SF2. `freezeTimeoutMs` is not an overall deadline for all option combinations

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:629`

The finalization wait consults only `finalizationDeadline`, so `finalizationTimeoutMs > freezeTimeoutMs` can exceed the advertised overall freeze deadline before either freeze loop begins. Likewise, accepted quiescence sleeps the full `quiescenceMs` and can mark frozen after `freezeDeadline` without rechecking it (`AdaptiveJournal.ts:661-665`). If `freezeTimeoutMs` is an overall bound, every phase and sleep must use the remaining time and recheck before transition; if it is intended to bound only post-finalization traffic, that option is dominated by a phase-specific name/deadline because the current “overall” interpretation is misleading. Define and validate the relationship among the two timeouts and quiescence interval rather than relying on the safe default ordering.

### SF3. The revised tests still do not implement the full step-1 contract matrix

**Location:** `assets/automation/tests/torus/student_delivery/adaptive-journal.spec.ts:343`

The `every rejection reason` test passes each enum directly to `enterTerminalization`; it does not drive each actual rejection through `awaitFreeze` while a page-finalization request is response-less, so it misses SF1. Other missing negatives are:

- response headers followed by `requestfailed`, including the core's phase-1 → failure guard and the live adapter's handle lifetime (B1);
- mutating the object returned directly by `issueFence`, and changing/mutating correlation after seal/freeze (B3; the test at `adaptive-journal.spec.ts:418-437` mutates only accessor clones);
- accepted finalization plus indefinitely non-quiescent but fully settled informational traffic, proving the seal handoff still contributes typed positive audit evidence rather than relying on `sealIncomplete` or an unresolved evaluation (B2);
- `freezeTimeoutMs < finalizationTimeoutMs` and `quiescenceMs >` the remaining freeze time (SF2).

The finalization correlation matrix also crosses wrong fields only with parsed response shapes (`adaptive-journal.spec.ts:228-245`), not the full non-2xx/malformed outcome set named by §8. Add mutation-style cases for these branches rather than testing the corrected helpers only in isolation.

## Nits

None.

---

## Writer response — round 2 (Claude, 2026-08-05)

All 3 blockers and 3 should-fixes accepted.

- **B1 fixed** — the adapter keeps the request handle registered until the record is TERMINAL:
  `requestfailed` after response headers reaches the same record; a body-read rejection now
  calls `ingestRequestFailed`, never a completion. Core: `ingestRequestFailed` preserves an
  already-stamped `responseSeq`/status and ends the record `failed`; a straggling body after
  the failure is ignored. Core test covers phase-1→failure order and the late-body no-op.
  *Documented limit:* the headers-then-failure order cannot be forced through Playwright's
  route API in a live stub (fulfill is atomic), so the live-adapter half is covered by the
  handle-lifetime code path plus core semantics, not an end-to-end simulation.
- **B2 fixed (spec amendment required — at the human gate)** — new typed record
  `FreezeTimeout { outstanding }`: `markFreezeTimeout()` (armed-only, lesson-end required) is
  recorded before the throw; the sealed snapshot carries `freezeTimeout` and the oracle MUST
  map it to a violation. Not aliased to any driver-operation failure. Live test: accepted
  finalization + never-quiescing but fully settled PATCH-save stream → throw → seal →
  complete snapshot WITH positive evidence. Draft §3.2 amendment text is in the summary
  message to the human; code lands only the journal-side record.
- **B3 fixed** — `issueFence` returns a copy; `setRunCorrelation` is armed-only, one-time, and
  stores a copy. Tests mutate the RETURNED stamp and the caller's correlation object and prove
  the snapshot unaffected; post-seal `setRunCorrelation`/`markFreezeTimeout` throw.
- **SF1 fixed** — at acceptance-wait expiry the adapter terminalizes with
  `settledRejectionReason() ?? 'missing'`: a completed rejection survives a response-less
  duplicate. New core method + unit matrix (already_submitted, uncorrelated, nothing-settled)
  and a live test (settled already_submitted + stalled duplicate → completed-failure with
  reason already_submitted).
- **SF2 fixed** — `freezeTimeoutMs` is now the OVERALL bound: the finalization deadline is
  `min(finalization, freeze)`; the accepted path refuses to start a quiescence interval that
  cannot finish inside the budget (throws for the seal path); the completed-failure loop
  sleeps `min(quiescence, remaining)` and freezes at the deadline. Live tests:
  `finalizationTimeoutMs 60s / freezeTimeoutMs 600ms` completes ~600ms; `quiescenceMs 10s /
  freezeTimeoutMs 400ms` throws instead of freezing late.
- **SF3 addressed** — added: headers→failed core order; fence-return and correlation mutation
  tests (the real leak, not accessor clones); settled-informational-stream bail with typed
  evidence surviving into a COMPLETE sealed snapshot; both SF2 budget combinations; wrong
  correlation field × non-2xx (uncorrelated) and × unreadable response (malformed — parse
  precedence documented); settled-rejection-vs-duplicate matrix. The rejection-reason
  enumeration keeps its core-level state-machine test; the through-`awaitFreeze` cross is
  covered live for the strongest case (already_submitted with a response-less duplicate) —
  the remaining reasons differ only in `settledRejectionReason` classification, unit-tested.

State: 133/133 stub tests green (69 journal/attribution, 64 shipped strict untouched);
tsc/eslint/prettier clean.
