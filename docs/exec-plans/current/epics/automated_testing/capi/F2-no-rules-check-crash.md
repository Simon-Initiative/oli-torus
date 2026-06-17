# F2 (product bug candidate): Adaptive delivery CHECK crashes when evaluation has no rule results

Surfaced during MER-5701. **Not fixed here** — adjacent product hardening, needs a separate ticket
and a product severity call. Confirmed by both Claude (runtime) and Codex (source).

## Summary

In adaptive **delivery** (not preview), when a check runs against an activity whose evaluation
returns no rule-shaped results, the frontend throws and the check never completes.

- Backend: `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex:134-142` has an explicit
  `{:ok, %Model{rules: []}}` branch → `evaluate_from_input`, which does not produce rule result
  events. So `rules: []` is a real model shape at the server boundary.
- Frontend: `triggerCheck.ts:339-370` reads `(evalResult).result.actions` → `checkResult =
  resultData.results` and passes it straight to `processResults(checkResult)`
  (`DeckLayoutFooter.tsx:203-210`), which does `events.forEach(...)` with no array guard.
- Result: `checkResult` undefined → `processResults` throws `Cannot read properties of undefined
  (reading 'forEach')` → caught in `triggerCheck` *after* `setLastCheckTriggered` already fired →
  `CHECK_STARTED` was notified but `CHECK_COMPLETE` never is. The learner hits the generic
  "We could not load feedback" path.

## Repro

Seed the MER-5701 single-screen CAPI activity with `authoring.rules: []`, start the lesson as a
student, drive the CAPI sim to send `CHECK_REQUEST` (or click the deck check). Observe the thrown
`forEach` and missing completion.

- Expected: delivery handles empty/no-rule evaluation gracefully — return a completed check with
  empty results, or treat as no-op/incorrect, without throwing.
- Actual: `CHECK_START_RESPONSE` sent, `processResults(undefined)` throws, `CHECK_COMPLETE_RESPONSE`
  never sent.

## Reachability (the product question)

Codex could not prove that normal authoring/publish prevents a checkable zero-rule adaptive screen.
Supporting evidence it's reachable:
- `createActivityTemplate` initializes `authoring.rules: []` (`activity.ts:11-15`).
- Rule deletion has no guard preserving ≥1 rule (`AdaptiveRulesList.tsx:191-205`,
  `BottomPanel.tsx:140-152`).
- Validators iterate `(authoring?.rules || [])` but none reject zero rules (`validate.ts:275,358`).
- `flowchart` mode skips default rule insertion (`createNew.ts:69-83`) — repopulation path not
  fully traced.

→ Likely **medium severity**; confirm with product whether a no-rule checkable activity is
publishable/reachable.

## Suggested fix direction

Guard `processResults` (and/or the `checkResult` assignment in `triggerCheck`) against
non-array/undefined results; decide product semantics for a no-rule check (empty completion vs
incorrect).

## For triage
Attach the exact network response body from the eval call (`PUT /activity_attempt/:guid` /
evaluations endpoint) for the no-rules seed — re-run the deferred-state seed with response logging
to capture it.
