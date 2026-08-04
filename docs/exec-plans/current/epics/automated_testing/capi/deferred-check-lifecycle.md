# RESOLVED: CAPI CHECK lifecycle (former items 1+2)

**Status: resolved 2026-06-16.** Test 3 (`runs the check lifecycle on CHECK_REQUEST`) now passes;
no longer `test.fixme`. This doc records how the deferral was resolved. The original "minimal seed
doesn't register the part / 403" framing was **wrong** — see the corrected root cause below.

## What it actually was (after instrumented pass + Codex cross-review)

The part *was* registered (DB + frontend confirmed). The CHECK_REQUEST path *does* reach the deck
check: `handleCheckRequest → onSubmit → AdaptiveDelivery.handlePartSubmit →
DeckLayoutView.handleActivitySubmitPart → triggerCheck → setLastCheckTriggered → CHECK_STARTED →
CHECK_START_RESPONSE`. All of that fired.

The break was only the **completion half**: our seed had `authoring.rules: []`, so the server took
the no-rules evaluation branch (`evaluate.ex:134-142`) and returned a response without rule-shaped
results. `triggerCheck` passed that `undefined` to `processResults` (`DeckLayoutFooter.tsx:210`,
`events.forEach`) → threw → caught after CHECK_START already fired → `CHECK_COMPLETE` never notified
→ no `CHECK_COMPLETE_RESPONSE`.

## The fix (F1)

Added one **non-navigating** trapstate rule (mutateState action) on `stage.capi_iframe_part.x` to
`capi_page.scenario.yaml`. With a rule present, the server takes the rule-evaluation path and returns
rule-shaped results, so the check completes and both `CHECK_START_RESPONSE` + `CHECK_COMPLETE_RESPONSE`
reach the sim. Non-navigating is deliberate: a navigating (correct→advance) rule would hit
`ActivityRenderer`'s CHECK_COMPLETE nav-suppression and the test could not assert the completion
message. Single screen suffices — Kevin's full layer/subscreen navigating structure is not needed
for the protocol round-trip (it remains a good basis for a future adaptivity/navigation test).

## Spun off
- **F2** (`F2-no-rules-check-crash.md`): the underlying `processResults(undefined)` crash is a latent
  delivery robustness bug, tracked separately for a product severity call. Not fixed in MER-5701.
- Benign anomaly: a spurious empty `handlePartSubmit({id: undefined})` was observed in instrumented
  runs (logs "part attempt guid for undefined not found"). It's a harmless early-return, was not
  root-caused, and is not implicated in the check lifecycle or its fix. Not chased further.

## Cross-review trail
Diagnosed over several rounds of Claude↔Codex cross-review (an internal review dialogue, not
committed to the repo).
