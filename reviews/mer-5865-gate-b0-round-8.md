**Verdict:** GATE-BLOCKED

**Counts:** 2 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the reviewed captures still replay clean and the literal round-7
mutations are red, but C8 remains bypassable through a non-null unbound save identity and
C18's archive classifier is not coextensive with the planner it claims to pin. Both defects
admit common-mode false-greens under the adopted malformed-input/substitution threat model.

## MATERIAL findings

### M1 — A non-null unbound save identity launders a post-evaluation rejection into a commit

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:344-385`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:411-434`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:161`

The round-7 fix rejects only `attemptGuid === null`. An empty string or any foreign nonempty
string misses `firstEvalByGuid`, enters the “never evaluated” branch, and is declared active for
the whole run. That inference is valid only for an attempt whose creation/visit lineage is proven
by this run; the code never proves that membership. A foreign identity could describe no attempt
at all or an already-submitted attempt, and an empty string is not an identity.

I replayed two classes of mutations through the complete green predicate. First, changing the
identity alone on completed 2xx saves left 12 candidate mutations accepted for each of the empty
and foreign forms. More decisively, I took completed post-evaluation 403 saves, changed the status
to 200, and changed the identity to either empty or foreign. Five candidates in each class still
passed the full envelope, zero-in-scope, projection, and driver-inventory checks; the other green
is unchanged, so the cross-green class counts and distinct-run checks also continue to pass. This
masks exactly the post-evaluation commit that C8 says is red.

The standing r7 witness does not cover this class: it writes `null` and also changes the status to
500, so it is rejected before exercising the unsupported “never evaluated means active” premise.

**Required fix:** classify a completed save only after proving a nonempty identity belongs to this
run's visit/mint/evaluation lineage. A genuinely known, never-evaluated active attempt may then be
licensed as 2xx; empty, foreign, or otherwise unbound identities must be red. Add full-entry-point
witnesses for (1) empty identity, (2) foreign identity, and (3) post-evaluation 403 relabeled as
2xx while its identity is simultaneously hollowed/substituted.

### M2 — `correct_plan_kinds` omits the runtime LLM-feedback input to `planTransition`

**Location:** private `extract_lote_facts.py:64-73`;
`assets/automation/src/systems/torus/tasks/AdaptiveTransitionPlanner.ts:71-88`;
`lib/oli/conversation/llm_feedback.ex:101-118`;
`lib/oli_web/controllers/api/attempt_controller.ex:558-594,753-768`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:115-127`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:163,172`

The extractor unions authored action types from enabled correct rules and classifies feedback
when that union contains a standard feedback action, otherwise navigation when it contains a
navigation action. The actual planner has another higher-precedence input: any nonempty
`llmFeedback.text` produces a feedback plan even when the processed authored actions contain only
navigation. The server can add that field when a processed result contains a feedback-kind
activation point and the section/runtime generation path succeeds. Archive actions alone therefore
cannot determine one exact runtime plan kind for an LLM-capable screen.

This has both failure directions requested by the review:

- A genuine LLM-capable run can be red because the archive says navigation while the live planner
  legally produces feedback and therefore one additional no-ack obligation.
- More importantly for materiality, if both green artifacts have `llmFeedback` hollowed and their
  ledgers rewritten to the resulting navigation plan, the archive also expects navigation. Each
  expected/actual inventory matches and the seq-stripped cross-green counts match, masking the
  common-mode response+ledger substitution C10/C18 are intended to prevent.

For the current LotE artifact, the authored-action portion is otherwise sound: 15 screens have
one enabled correct rule and seven have two; the two-rule screens have identical action-type sets,
so result selection does not change the class. The archive yields 20 feedback-class and two
navigation-class screens, and both fresh greens contain no nonempty LLM feedback. That explains
the current 20 no-acks, but it does not make the advertised classifier coextensive or supply a red
witness for the omitted branch. B0 licenses the general step-4 planner path, not only this observed
zero-LLM sample.

**Required fix:** make the archive gate fail closed on feedback-kind activation points unless an
independent runtime/configuration reference can determine the LLM outcome. If such screens must be
supported, replace the single archive kind with a contract that represents both legal runtime
outcomes and independently pins which occurred; do not infer it from the captured response under
judgment. Add a semantic extractor witness and a both-greens LLM-hollowing witness through the real
gate entry point.

## Recorded non-material findings

### N1 — The checked-in private generator path does not reproduce `correct_plan`

**Location:** private `extract_lote_facts.py:145-160` and
`extract_lote_manifest_v2.py:1-93`; HANDOFF private-artifact section at
`docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md:89-99`

`extract_lote_facts.py` writes `correct_plan_kinds` to the facts file but never copies the value
into each draft screen. `extract_lote_manifest_v2.py` only enriches grading expectations and writes
the draft back out. The current draft contains no `correct_plan` fields while the curated final
manifest does, so the stated “facts/manifest regenerated (extractor v6)” path is not reproducible
from the reviewed scripts. The HANDOFF also still calls the extractor v5 and reports the old 5/5
gate count.

This cannot false-green the current replay: rerunning the reviewed scripts would remove the
manifest field and `validateRouteCoverage` would fail closed against the facts map. The current
final artifact does validate and its values match the inspected LotE action shapes.

**Owner:** private archive-extractor workflow, before B0 resubmission or any future regeneration.
Generate the manifest field in the same auditable pass, add a clean-regeneration check, and update
the HANDOFF version/count.

### N2 — The evidence doc reintroduces the retired “saved-barrier saves” wording

**Location:**
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:177-182`

The mandatory-live-evidence paragraph calls all 29 records “saved-barrier saves.” C7 and the
projector correctly claim only own-state save traffic; 16 records are post-evaluation 403 flushes
and cannot prove a committed saved barrier. This wording has no current decision consumer because
C7/C8 and the gate implementation use the narrower save-traffic contract.

**Owner:** evidence-doc author, before B0 resubmission. Restore the round-6 terminology and reserve
saved-barrier evidence for step 4's receipt-plus-permit rule.

## M3 resolution judgment

Pinning the plan-dependent class to an archive reference, plus cross-green equality, is the right
resolution strategy. It closes the exact r7 feedback-to-navigation action substitution when the
archive reference is correct, including the same substitution in both greens: per-green archive
equality catches the class change even though cross-green equality alone cannot.

The implementation is not yet a sound realization of that decision. It matches the current
LotE standard-action shapes, but M2 shows that the purported archive plan kind is not the actual
planner function because it omits the server LLM input. I therefore endorse the decision but not
the present classifier or the C18/C10 proof built on it.

## Claims-table v3.1 audit

| Row | Verdict | Audit |
|---|---|---|
| C1 | supported | Visit order/cardinality are pinned to the build-gated archive scenario; the route mutation is red. |
| C2 | supported | Ledger presence, full length, and per-index screen identity are enforced. |
| C3 | supported conditionally | The serialized green/freeze envelope is checked; acceptance meaning depends on C4b. |
| C4a | supported | All three wire finalization identities are checked against the separately read DOM correlation, including common-mode wire/finalization substitution. |
| C4b | supported | Parse state, completion, 2xx, action, result, commandResult, categorical reason, and correlation are recomputed; the three r7 mutations are red. |
| C5 | supported | Exact creation cardinality, a minted identity, and the oracle rotation's causal relationship are enforced in composition. |
| C6 | supported | Exact two-evaluation first-screen rotation is envelope-pinned and fully sequence-audited. |
| C7 | supported at its stated scope | Every graded visit needs at least one completed own-state save; it does not claim all 29 are commits. |
| C8 | **unsupported — M1** | `null` is red, but empty/foreign identities enter the unproven never-evaluated branch and can launder post-evaluation 403 into 2xx. |
| C9 | supported | Totality and exact `combine_feedback` equality are build-gated; shared extractor lineage is disclosed. |
| C10 | **unsupported through C18 — M2** | Per-green pinned equality and cross-green class counts are implemented, but the archive plan class omits LLM feedback, leaving a both-greens common-mode shrink path. |
| C11 | supported | Intentional deltas are asserted as an exact manifest-derived set. |
| C12 | supported at artifact-distinctness scope | Both minted identities must be present and distinct; no stronger provenance is claimed. |
| C13a | supported | Bail outcome, complete seal, fired on-route poison, and shipped error naming the poison screen are enforced. |
| C13b | supported | The oracle must report `verdict-not-correct` at the same poisoned screen. |
| C14 | supported mechanically | Both validators run before comparison and fact-map totality is enforced; it does not validate C18's extractor semantics. |
| C15 | supported as an observed decision term | Both current greens have zero in-scope violations; this cannot repair an expected-class reference defect. |
| C16 | supported | Union-length ledger/shadow comparison requires zero unexplained differences. |
| C17 | supported | Navigation `none` is admitted only within the complete measured rotation and the negative matrix remains green. |
| C18 | **unsupported — M2** | Manifest/facts equality is enforced, but both carry an incomplete classifier and no semantic LLM witness exists. |

Bidirectional reconciliation found no additional stable claim ID missing from v3.1. The missing
proofs belong inside existing atomic rows: C8 needs identity-membership and combined
status-plus-identity witnesses; C18 needs a planner-coextensive reference and semantic extractor
witness. The table's C8 positive statement and red-witness list must also stop claiming
“unclassifiable = red” until M1 is closed.

## B0 questions

1. **Not collectively acceptable yet.** Observer-stamped fences, the one classified first-screen
   delta, and the documented presence-only limits are bounded stand-ins. The driver-evidence gap
   is not safely pinned while the archive plan classifier omits an actual planner input, and C8
   leaves mandatory save evidence hollowable.
2. **The navigation `none` amendment is correctly scoped.** It is legal only as the incorrect,
   non-navigating first half of the exact two-evaluation navigation rotation with the causal mint
   and correct navigating second evaluation. The surrounding negative matrix remains intact.
3. **The current captures are credible, but the proof workflow is not yet sufficient for the
   swap.** Their route, correlation, counts, plan classes, and bail evidence are internally stable;
   no LLM feedback appears in either green. M1/M2 are replay/reference defects, and N1 makes the
   private regeneration trail incomplete.

**Step-4 decision: NO-GO.** Close M1 and M2, regenerate the private artifacts reproducibly, update
the claims/evidence, and replay the new semantic witnesses before using B0 to license the driver
swap.

## Verification performed

- Exact fresh offline gate, after the claims audit: **6/6 passed**. Both greens reported zero
  in-scope, 65 driver-evidence, zero unexplained, and one intentional delta; bail reported the
  required same-screen violation.
- Round-7 standing witnesses: non-success result, categorical reason, parse error, null save
  identity, and response-plus-ledger plan substitution all rejected inside the 6/6 gate.
- Additional save probes: 12 completed 2xx saves per identity form survived empty/foreign identity
  substitution; five post-evaluation 403 saves per form survived combined status-to-200 plus
  identity substitution through the full green predicate.
- Archive/planner audit: current LotE correct-rule action shapes reduce to 20 feedback and two
  navigation classes; both fresh greens contain zero nonempty LLM feedback. The server and planner
  source reads establish the omitted LLM branch described in M2.
- Correct-plan drift between facts and manifest is rejected by the route-coverage contract test;
  removing the manifest field is also red.
- `npx playwright test adaptive- --reporter=line`: **260 passed, 1 failed, 2 did not run**. The
  documented authoring flowchart flake failed at node-count synchronization; the requested retry
  failed at a different detached-select synchronization point in the same unrelated authoring
  helper. No step-3 test failed.
- Security/performance pass over the full step-3 diff found no additional material issue. The
  documented destination ancestor-swap race remains intentionally owned before shared-machine
  capture; replay work is bounded to the small fixed artifacts used here.

No answer values, expected responses, or predicate right-hand sides were copied into this review.

---

# WRITER RESPONSE (Claude, 2026-08-10) — both MATERIAL fixed as a class; both recorded items fixed

Both findings verified before fixing: your identity-laundering shapes and the llmFeedback
precedence gap were reproduced against the unmodified gate (each passed as reported).

## M1 — FIXED: save classification is lineage-bound

A completed save is classified ONLY when its attempt identity belongs to this run's PROVEN
lineage — the set of rendered visit attempts, evaluated attempts, and the server mint.
Empty, foreign, or otherwise unbound identities are RED ("not in this run's attempt
lineage — unclassifiable"), never routed into the never-evaluated branch; that branch now
fires only for lineage attempts (e.g. content screens' rendered attempts, which the run
owns and never submits). Baseline measured first: all 29+29 completed saves on both greens
sit inside the lineage. Witnesses added and replayed at the full entry point: empty
identity, foreign identity, and your decisive laundering shape (post-eval 403 relabeled
2xx under a substituted identity) — all KILLED, plus the same shapes as standing in-repo
witnesses.

## M2 — FIXED: LLM capability is an archive fact and the gate fails closed on it

The extractor now scans ALL enabled rules for the server's LLM trigger — an
`activationPoint` action of kind `feedback` (`llm_feedback.ex` find_llm_feedback_prompt;
attached to the response at `attempt_controller.ex:753-768`) — into a TOTAL
`llm_feedback_capable` facts map. `validateRouteCoverage` enforces totality and FAILS
CLOSED on any true value: an LLM-capable screen's plan kind is not archive-determined
(runtime llmFeedback outranks authored actions in planTransition), and the strict
framework has no independent runtime reference for it yet — supporting such screens is an
explicit future contract, not an inference from the capture under judgment. LotE measures
0 of 22 capable, so the archive classifier IS coextensive with the planner for every
screen this gate judges. Downstream, the green envelope rejects any captured evaluation
carrying llmFeedback as impossible traffic on this archive — which also closes your
both-greens-hollowed path (hollowing an always-empty field is a no-op, and fabricating the
field is red). Witnesses: capable-screen facts fail the build (contract test); fabricated
llmFeedback fails the envelope (in-repo + env replay).

Both failure directions you named are closed for THIS gate: no genuine LotE run can go red
(no capable screens exist), and no substitution can exploit an unmodeled branch (the build
refuses archives where the branch is reachable).

## N1 — FIXED: `extract_lote_facts.py` (v7) writes `correct_plan` into every draft screen —
the draft regenerates reproducibly with the field; HANDOFF version/count updated.

## N2 — FIXED: the evidence-doc mandatory list now says "29 own-state save-traffic records
(13 pre-check commits + 16 post-check only_active rejections)"; saved-BARRIER stays step
4's receipt+permit rule.

## Verification

- Gate 7/7 on the fresh artifacts (unchanged counts; cross-green equality holding).
- FIVE r8 negative env replays KILLED: empty identity, foreign identity, laundered
  post-eval rejection (×2 identity forms), fabricated llmFeedback. All r4-r7 witnesses
  standing (25+ in-repo witnesses across five witness tests).
- Full suites 261/264 + the known authoring flake chain (adaptive-authoring.spec.ts:133,
  unrelated, on record). tsc: two fenced errors only. ESLint clean. Prettier applied.
- Facts regenerated with the llm map (0 of 22 capable); manifest unchanged except the
  already-present correct_plan fields; draft now reproducible.
